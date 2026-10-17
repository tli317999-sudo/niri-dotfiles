#!/usr/bin/env bash
# install.sh — 把仓库里的配置装到当前用户
# 已存在的文件会备份成 *.bak.<时间戳>
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

say()  { printf '\033[36m▶\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m  ⚠\033[0m %s\n' "$*"; }

backup() {
    [[ -e $1 ]] || return 0
    mv "$1" "$1.bak.$STAMP"
    warn "已备份 $(basename "$1") → $(basename "$1").bak.$STAMP"
}

# ── 1. 脚本 ───────────────────────────────────
say "安装 bin/ 到 ~/.local/bin"
mkdir -p "$HOME/.local/bin"
for f in "$REPO"/bin/*; do
    backup "$HOME/.local/bin/$(basename "$f")"
    install -m 755 "$f" "$HOME/.local/bin/"
done
ok "$(ls "$REPO"/bin | wc -l) 个脚本"

# ── 2. 主题系统 ───────────────────────────────
say "安装 themes/ 到 ~/.config/themes"
mkdir -p "$HOME/.config/themes"/{palettes,templates}
install -m 755 "$REPO/themes/render.py" "$HOME/.config/themes/"
cp -n "$REPO"/themes/palettes/*.conf "$HOME/.config/themes/palettes/" 2>/dev/null || true
cp -n "$REPO"/themes/templates/* "$HOME/.config/themes/templates/" 2>/dev/null || true
chmod +x "$HOME/.config/themes/render.py"
ok "色板 + 模板就绪"

# ── 3. 直接落地的配置文件 ─────────────────────
say "安装 waybar / fuzzel / mako"
mkdir -p "$HOME/.config"/{waybar,fuzzel,mako}
backup "$HOME/.config/waybar/config.jsonc"
backup "$HOME/.config/waybar/style.css"
backup "$HOME/.config/fuzzel/fuzzel.ini"
backup "$HOME/.config/mako/config"
install -m 644 "$REPO/waybar/config.jsonc" "$HOME/.config/waybar/"
install -m 644 "$REPO/waybar/style.css"    "$HOME/.config/waybar/"
install -m 644 "$REPO/fuzzel/fuzzel.ini"   "$HOME/.config/fuzzel/"
install -m 644 "$REPO/mako/config"         "$HOME/.config/mako/"
ok "已写入"

# ── 3b. swaync / gtklock ──────────────────────
say "安装 swaync / gtklock 配置"
mkdir -p "$HOME/.config/swaync" "$HOME/.config/gtklock"
backup "$HOME/.config/swaync/config.json"
backup "$HOME/.config/gtklock/config.ini"
install -m 644 "$REPO/swaync/config.json" "$HOME/.config/swaync/"
install -m 644 "$REPO/gtklock/config.ini" "$HOME/.config/gtklock/"
ok "通知中心与锁屏配置就位（配色在下一步由 theme 渲染）"

# ── 4. Konsole / KDE ──────────────────────────
say "安装 Konsole 配色与 KDE 配色方案"
mkdir -p "$HOME/.local/share/konsole" "$HOME/.local/share/color-schemes"
cp -n "$REPO"/konsole/*.colorscheme "$HOME/.local/share/konsole/" 2>/dev/null || true
cp -n "$REPO"/kde/color-schemes/*.colors "$HOME/.local/share/color-schemes/" 2>/dev/null || true
ok "配色方案已就位"

if [[ -f $REPO/kde/darklyrc ]] && [[ ! -f $HOME/.config/darklyrc ]]; then
    cp "$REPO/kde/darklyrc" "$HOME/.config/darklyrc"
    ok "Darkly 透明度配置已安装"
elif [[ -f $REPO/kde/darklyrc ]]; then
    warn "~/.config/darklyrc 已存在，跳过（需要顶栏透明可手动对比）"
fi

# ── 5. 渲染真实配置 ───────────────────────────
say "渲染 niri / waybar / fuzzel / mako"
mkdir -p "$HOME/.config/niri"
backup "$HOME/.config/niri/config.kdl"
if "$HOME/.local/bin/theme" tokyonight; then
    ok "已按 tokyonight 渲染完成"
else
    warn "theme 渲染失败，改为直接复制预渲染的 config.kdl"
    install -m 644 "$REPO/niri/config.kdl" "$HOME/.config/niri/"
fi

# ── 6. 自检 ───────────────────────────────────
say "自检"
command -v niri >/dev/null && niri validate -c "$HOME/.config/niri/config.kdl" >/dev/null 2>&1 \
    && ok "niri 配置校验通过" || warn "niri 未安装或配置校验失败"

for c in waybar fuzzel mako awww matugen; do
    command -v "$c" >/dev/null || warn "缺少命令: $c"
done

cat <<EOF

装完了。下一步：
  1. 注销重登，在登录界面选择 Niri 会话
  2. 首次进入按 Mod+Shift+/ 看全部快捷键
  3. Mod+Alt+T 换主题；Mod+B 换壁纸（装了 matugen 会自动跟色）

想改壁纸目录：WALL_DIR=~/你的目录 wallpaper
想把登录页换成 SDDM：sudo bash ~/.local/bin/switch-to-sddm.sh <壁纸路径>
EOF
