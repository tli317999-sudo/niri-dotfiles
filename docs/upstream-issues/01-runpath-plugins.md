# Installed plugins can't find their sibling libraries (RUNPATH points at the makepkg build dir)

## Summary

After installing `clavis-shell 2026.9.25-1` on Arch, `key shell` fails immediately with:

```
ERROR: Failed to load configuration
ERROR:   caused by @shell.qml[8:5]: Type AppShell unavailable
ERROR:   caused by @AppShell.qml[94:5]: Type DisplayOverlays unavailable
ERROR:   caused by @Modules/ControlCenter/DisplayOverlays.qml[79:9]: Type CompositorBlurRegion unavailable
ERROR:   caused by @Widgets/common/CompositorBlurRegion.qml[-1:-1]: Type ApplicationService unavailable
ERROR:   caused by @Services/ApplicationService.qml[5:1]:
           Cannot load library /usr/lib/qt6/qml/Clavis/Files/libClavisFilesplugin.so:
           libClavisFiles.so: cannot open shared object file: No such file or directory
```

The QML error messages point at unrelated types, so it looks like a QML problem, but the real
cause is a dynamic-linker issue in the installed binaries.

## Environment

| | |
|---|---|
| OS | Arch Linux (rolling, 2026-10-17) |
| `clavis-shell` | 2026.9.25-1 (installed from `install-arch.sh` of release `v2026.9.25`) |
| `quickshell` | 0.3.2-1 (extra) |
| `qt6-base` | 6.12.0-3 |
| `pacman` | 7.1.0 / libalpm 16.0.1 |
| CPU | x86_64 |
| Compositor | niri |

Installed with `--enable-shell=no --start-now=no`, then started manually with `key shell`.
The same failure occurs via `systemctl --user start clavis-shell.service`.

## Root cause

The QML plugin and its backing library are installed side by side:

```
/usr/lib/qt6/qml/Clavis/Files/libClavisFiles.so
/usr/lib/qt6/qml/Clavis/Files/libClavisFilesplugin.so
```

but the plugin's `DT_RUNPATH` contains the **absolute makepkg build directory**, which no longer
exists after installation:

```console
$ readelf -d /usr/lib/qt6/qml/Clavis/Files/libClavisFilesplugin.so | grep -E 'NEEDED|RUNPATH'
 0x0000000000000001 (NEEDED)  Shared library: [libClavisFiles.so]
 ...
 0x000000000000001d (RUNPATH) Library runpath: [/tmp/clavis-build-d_x53m8h/clavis-shell/src/build/qml/Clavis/Files]

$ ls -l /usr/lib/qt6/qml/Clavis/Files/
-rw-r--r-- 1 root root ... libClavisFiles.so
-rw-r--r-- 1 root root ... libClavisFilesplugin.so

$ ldd /usr/lib/qt6/qml/Clavis/Files/libClavisFilesplugin.so | grep ClavisFiles
        libClavisFiles.so => not found
```

The library exists, but `ld.so` does not search the plugin's own directory (that is Windows
behaviour, not ELF), and the only place it was told to look is the deleted build tree.

Every module has the same problem:

```console
$ for f in /usr/lib/qt6/qml/Clavis/*/lib*plugin.so; do \
    printf '%-14s ' "$(basename "$(dirname "$f")")"; \
    readelf -d "$f" | grep -oE 'Library runpath: \[[^]]*\]'; done
Cava           Library runpath: [/tmp/clavis-build-d_x53m8h/.../Clavis/Cava]
DesktopCards   Library runpath: [/tmp/clavis-build-d_x53m8h/.../Clavis/DesktopCards]
Files          Library runpath: [/tmp/clavis-build-d_x53m8h/.../Clavis/Files]
Gamma          ...
```

## Why it works on the build machine

Because the build directory still exists there. Once `makepkg --cleanbuild` / the installer's
temporary tree is removed, the path dies with it — so this only shows up for people who install
the package, which is probably why it was not noticed.

## Workaround (works, used here)

```bash
export LD_LIBRARY_PATH=$(ls -d /usr/lib/qt6/qml/Clavis/*/ | tr '\n' ':' | sed 's/:$//')
key shell
```

`LD_LIBRARY_PATH` is searched before `RUNPATH`, so the plugins load. For the systemd unit:

```ini
# ~/.config/systemd/user/clavis-shell.service.d/10-rpath.conf
[Service]
Environment=LD_LIBRARY_PATH=/usr/lib/qt6/qml/Clavis/Cava/:/usr/lib/qt6/qml/Clavis/Files/:...
```

## Suggested fix

In the top-level `CMakeLists.txt`, install with an origin-relative runpath instead of the
build-tree path:

```cmake
set(CMAKE_INSTALL_RPATH "$ORIGIN")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH FALSE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)   # keep the build tree working during development
```

`$ORIGIN` resolves to the directory of the loading object at runtime, so the plugin finds
`libClavisFiles.so` next to itself no matter where it is installed. This is the standard
approach for shipping private shared libraries in Arch packages.

Equivalent one-off check without touching CMake (useful to confirm the diagnosis):

```bash
sudo pacman -S patchelf
sudo patchelf --set-rpath '$ORIGIN' /usr/lib/qt6/qml/Clavis/Files/libClavisFilesplugin.so
ldd /usr/lib/qt6/qml/Clavis/Files/libClavisFilesplugin.so | grep ClavisFiles   # now resolves
```

## Additional suggestion

Consider making the QML error more actionable: when a `Clavis*` plugin fails to load, printing
`ldd <plugin> | grep 'not found'` in the log would have pointed at the real cause immediately
instead of surfacing as `Type ApplicationService unavailable`.
