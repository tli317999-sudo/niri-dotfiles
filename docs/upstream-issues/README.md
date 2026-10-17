# Upstream issue reports

提给上游项目的 bug 报告存档。保留原始内容（英文），方便以后回查「当时提了什么、对方怎么回」。

## Clavis shell（[StatIndet/quickshell](https://github.com/StatIndet/quickshell)）

针对 `clavis-shell 2026.9.25-1` / `install-arch.sh`，2026-10-17 记录。

| 文件 | 问题 | 状态 |
|---|---|---|
| [01-runpath-plugins.md](01-runpath-plugins.md) | 安装后 QML 插件找不到同目录的 `libClavis*.so`——`DT_RUNPATH` 写死了 makepkg 的临时构建目录（`/tmp/clavis-build-*`）。表现为 `Type ApplicationService unavailable` 这类误导性的 QML 错误。 | 待上游修复 |
| [02-installer-pacman71-and-debug.md](02-installer-pacman71-and-debug.md) | 安装器在 pacman 7.1 上跑不完：① `pacman -Qp --print-format` 被拒绝；② `makepkg --packagelist` 列出的 `-debug` 包对纯数据包（字体）不存在，却被当作致命错误。 | 待上游修复 |

### 本机采用的绕行方案

**RUNPATH**：`~/.config/systemd/user/clavis-shell.service.d/10-rpath.conf` 补 `LD_LIBRARY_PATH`；
手动调试走 `bin` 里同名的 `clavis` wrapper（只对该进程生效）。

**安装器**：`install-arch.sh` 里打了两处补丁（
`pacman -Qp` 取第一列 / 缺失的 `-debug` 制品跳过）。补丁带注释，重装时会丢失，需重新套用。

### 冒烟检查

```bash
# 插件依赖是否还能解析（应该列出所有 libClavis*.so，没有 not found）
for f in /usr/lib/qt6/qml/Clavis/*/lib*plugin.so; do
    ldd "$f" | grep -q 'not found' && echo "❌ $f"
done

# 服务是否正常
systemctl --user is-active clavis-shell clavis-clipboard
```
