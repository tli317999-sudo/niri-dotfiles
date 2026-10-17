# `install-arch.sh` fails on Arch/pacman 7.1: `-Qp --print-format` rejected, and missing `-debug` artifacts treated as fatal

Two separate failures hit while running `install-arch.sh` from `v2026.9.25` on an up-to-date Arch
box. Both abort the whole installation *after* `makepkg` succeeded, so the build work is thrown
away and the user cannot tell what went wrong from the final one-line error.

## Environment

| | |
|---|---|
| OS | Arch Linux (rolling, 2026-10-17) |
| pacman | 7.1.0 / libalpm 16.0.1 |
| makepkg | `/etc/makepkg.conf`: `OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge debug lto)` |
| Installer | `install-arch.sh` from release `v2026.9.25` |

## Bug 1 — `pacman -Qp --print-format` is not accepted by pacman 7.1

After `key-cli` built successfully:

```
==> Finished making: key-cli 2026.9.25-1
Installation failed during source build key-cli:
Command '['pacman', '-Qp', '--print-format', '%n',
          '/tmp/clavis-build-f_af7xey/key-cli/key-cli-2026.9.25-1-x86_64.pkg.tar.zst']'
returned non-zero exit status 1.
```

Reproduced with any package file on this system, so it is not specific to `key-cli`:

```console
$ pacman -Qp --print-format '%n' /var/cache/pacman/pkg/acl-2.4.0-1-x86_64.pkg.tar.zst
error: invalid option '--print-format'        # exit status 1

$ pacman -Qp /var/cache/pacman/pkg/acl-2.4.0-1-x86_64.pkg.tar.zst
acl 2.4.0-1                                   # works, prints "name version"
```

`--print-format` is valid for `-Q`/`-Si`, but not combined with `-Qp` in pacman 7.x.

**Suggestion:** read the name from plain `-Qp` output, which already prints `name version`:

```python
meta = run(["pacman", "-Qp", str(artifact)], capture=True).stdout.split()[0]
```

(`pacman -Qip` + parsing `Name` also works, but plain `-Qp` is cheaper.)

## Bug 2 — `makepkg --packagelist` lists `-debug` packages that data-only packages never produce

Then `ttf-lxgw-wenkai-screen` built successfully:

```
==> Finished making: ttf-lxgw-wenkai-screen 1.520-1
Installation failed during source build ttf-lxgw-wenkai-screen:
Missing or external package artifact:
  /tmp/clavis-build-ec9m9g7o/ttf-lxgw-wenkai-screen/ttf-lxgw-wenkai-screen-debug-1.520-1-any.pkg.tar.zst
```

The font package contains no ELF files, so with `debug` in `OPTIONS` makepkg lists the debug
package via `--packagelist` but never emits it. The current check treats any missing artifact as
fatal:

```python
if not artifact.is_relative_to(path.resolve()) or not artifact.is_file():
    raise ValueError(f"Missing or external package artifact: {item}")
```

**Suggestion:** only the "outside the build directory" part should be fatal. A missing
`*-debug-*` artifact is expected for data-only packages (fonts, icons, docs):

```python
if not artifact.is_relative_to(path.resolve()):
    raise ValueError(f"Missing or external package artifact: {item}")
if not artifact.is_file():
    if "-debug-" in artifact.name:
        continue
    raise ValueError(f"Missing or external package artifact: {item}")
```

The two patches above were enough to complete the installation end to end
(`key-cli`, `libcava`, `qt6-m3shapes-git`, `ttf-lxgw-wenkai-screen`, `clavis-shell` all built and
installed).

## Nice-to-have

- The `finally` cleanup removes the build tree on failure, so a retry recompiles everything from
  scratch (including `clavis-shell`, which is the slow one). Keeping the built artifacts, or
  reusing an existing build directory, would make retries far less painful.
- Printing which *step* failed in the summary line (build / name resolution / `pacman -U`) would
  make these two failures distinguishable without reading a Python traceback.
