#!/usr/bin/env bash
# switch-to-sddm — 把登录页从 Plasma Login Manager 换回经典 SDDM
# 需要 root：sudo bash ~/.local/bin/switch-to-sddm.sh
#
# 为什么不用 plasmalogin：它的 greeter QML 里写死了 FastBlur / BlurScreenBridge，
# 登录背景必然虚化+提亮，没有配置项能关。SDDM 的 breeze 主题没有这个效果。
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "请用 sudo 运行" >&2; exit 1; }

WALL=${1:-}
[[ -n $WALL ]] || { echo "用法: sudo bash $0 <壁纸路径>" >&2; exit 1; }
SRC=/usr/share/sddm/themes/breeze
DST=/usr/share/sddm/themes/breeze-niri

[[ -f $WALL ]] || { echo "找不到壁纸: $WALL" >&2; exit 1; }
[[ -d $SRC ]] || { echo "找不到 breeze 主题: $SRC" >&2; exit 1; }

echo "▶ 1/4 基于 breeze 复制一份自定义主题"
rm -rf "$DST"
cp -r "$SRC" "$DST"

echo "▶ 2/4 把壁纸放进主题目录（greeter 以 sddm 用户运行，读不到普通用户家目录）"
cp "$WALL" "$DST/background.jpg"
chmod 644 "$DST/background.jpg"
sed -i 's|^background=.*|background=background.jpg|' "$DST/theme.conf"
grep -E '^(background|type|color)=' "$DST/theme.conf"

echo "▶ 3/4 指定 SDDM 使用这个主题"
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-niri.conf <<'EOF'
[Theme]
Current=breeze-niri
EOF
cat /etc/sddm.conf.d/10-niri.conf

echo "▶ 4/4 切换 display manager"
systemctl disable plasmalogin.service 2>/dev/null || true
systemctl enable sddm.service

echo
echo "✔ 完成。重启后生效：reboot"
echo "  想退回去：sudo systemctl disable sddm.service && sudo systemctl enable plasmalogin.service"
