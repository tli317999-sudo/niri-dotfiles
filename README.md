# niri-dotfiles

一套在 Arch Linux 上跑 **niri**（滚动平铺 Wayland compositor）的配置，包含状态栏、启动器、通知、终端配色，以及一套「整套换肤」的主题系统和「跟随壁纸取色」的自动化。

从 KDE/Plasma 迁移过来的，所以里面也处理了 KDE 应用在 niri 下的配色、图标、平台主题等坑。

## 里面有什么

| 目录 | 内容 |
|---|---|
| `niri/` | niri 主配置（`config.kdl`） |
| `waybar/` | 顶栏：胶囊式模块，CPU/内存/网络/音量/电池/电源都可点击 |
| `fuzzel/` | 应用启动器配色 |
| `mako/` | 通知配置 |
| `konsole/` | 终端配色方案（Catppuccin Mocha / Tokyo Night） |
| `swaync/` | 通知中心布局（配色由 theme 渲染） |
| `gtklock/` | 锁屏配置（壁纸由 lock 脚本写入） |
| `kde/` | KDE 配色方案、Darkly 控件风格透明度、SDDM drop-in |
| `themes/` | 主题系统：色板 + 模板 + 渲染器 |
| `docs/` | 上游 bug 报告存档（见 `docs/upstream-issues/`） |
| `bin/` | 各种小脚本（见下） |

## 脚本

| 脚本 | 作用 |
|---|---|
| `wallpaper` | 选壁纸（fuzzel 列表 / `--random` / `--apply <路径>`），换完自动跟色 |
| `wallpaper-start` | 开机还原上次的壁纸 |
| `matugen-palette` | 把 matugen 的 JSON 转成 theme 能读的色板 |
| `theme` | 整套换肤：niri / waybar / fuzzel / mako / KDE / Konsole / GTK |
| `apply-kde-colors` | 把配色文件的所有 `[Colors:*]` 段写进 kdeglobals（绕开 plasma 工具的合并问题） |
| `term` | 开终端：有 ghostty 用它，否则回退 konsole |
| `shot` | 区域截图 → satty 标注 → 存盘 + 进剪贴板 |
| `lock` | 锁屏：有 gtklock 用它，否则回退 swaylock |
| `vol` / `bright` | 音量/亮度：有 swayosd 就弹 OSD，否则静默调 |
| `wifi-menu` / `wifi-toggle` | fuzzel 选网 / 开关无线电 |
| `power-menu` | 电源菜单（锁屏/注销/挂起/重启/关机） |
| `grey-folders` | 生成灰文件夹图标主题（基于 Papirus 覆盖） |
| `switch-to-sddm.sh` | 从 Plasma Login Manager 换回经典 SDDM |

## 依赖

```bash
# niri 本体 + 日常配套
sudo pacman -S niri xwayland-satellite fuzzel waybar awww mako swaylock \
               grim slurp wl-clipboard cliphist playerctl brightnessctl \
               papirus-icon-theme

# 跟随壁纸取色（可选）
sudo pacman -S matugen

# 屏幕共享 / KDE 应用集成（可选）
sudo pacman -S xdg-desktop-portal-gnome plasma-integration
```

字体：`ttf-jetbrains-mono-nerd`、`noto-fonts-cjk`。

## 安装

```bash
git clone https://github.com/tli317999-sudo/niri-dotfiles.git
cd niri-dotfiles
./install.sh
```

`install.sh` 会：

1. 把 `bin/*` 装到 `~/.local/bin`
2. 把 `themes/{palettes,templates,render.py}` 装到 `~/.config/themes`
3. 备份已存在的配置，再写入 niri / waybar / fuzzel / mako
4. 跑一次 `theme tokyonight` 生成实际配置文件

> 已有的同名文件会被备份成 `*.bak.<时间戳>`，不会直接覆盖。

## 主题系统怎么工作

配置文件里的颜色不写死，而是写成占位符：

```css
# 模板（themes/templates/waybar-style.css）
background: #{{base}};
color: #{{text}};
```

色板（`themes/palettes/*.conf`）提供 17 个角色的色值：

```ini
NAME="Tokyo Night"
base=1a1b26
text=c0caf5
blue=7aa2f7
...
```

`theme <名字>` 会渲染所有模板，并顺带生成 KDE 配色方案、Konsole 配色、GTK 主题，然后热重载 niri / waybar / mako。

```bash
theme                  # 列出可用主题
theme tokyonight       # 切换
theme pick             # fuzzel 里选
```

色板里还可以放可选覆盖项：

```ini
KDE_SCHEME=Nordic          # 用系统里现成的配色方案
ICON_THEME=Nordic-darker   # 图标主题
GTK_THEME=Nordic           # 现成的 GTK 主题（不做重着色）
GTK_BAR_ROLE=mantle        # 窗口顶栏取哪个角色
GTK_BAR_ALPHA=0.80         # 顶栏透明度 0-1
DARKLY_BAR_OPACITY=80      # Qt 应用的工具栏/标签栏透明度
```

## 跟随壁纸取色

开启后（默认开启），换壁纸会：

```
换壁纸 → matugen 提取主色 → 生成 palettes/wallpaper.conf
       → theme wallpaper（渲染全部配置 + 生成 KDE/Konsole/GTK 主题）
       → 热重载
```

约 2 秒。同一张壁纸不会重复计算（靠 `~/.config/niri/wallpaper-follow-source` 缓存）。

Material You 的深色面永远是近黑（三张不同壁纸只差 2~4 个 RGB 单位），所以 `matugen-palette` 会把中间几档 surface 重新染上壁纸主色的色相，否则顶栏「换壁纸也看不出变化」。

```bash
wallpaper --no-follow   # 关掉跟随，壁纸和配色解耦
wallpaper --follow      # 重新打开
WALL_CONTRAST=0.3 wallpaper   # 取色对比度更高
```

## 可选：用 Clavis 接管顶部 UI

这套配置默认用 waybar + fuzzel + mako/swaync。也可以把整个顶部 UI 交给
[Clavis](https://github.com/StatIndet/quickshell)（Quickshell 写的 niri shell：状态栏、Spotlight、
侧栏、控制中心、锁屏、桌面卡片）。

它**不会**改你的 niri 主配置，只写自己的片段；本仓库已经把 include 和占位文件准备好了：

```kdl
include "clavis/binds.kdl"        // 快捷键（预填了它的默认 11 个键）
include "clavis/cursor.kdl"
include "clavis/effects.kdl"
include "clavis/layer-rules.kdl"
```

接管步骤：

```bash
systemctl --user enable --now clavis-shell clavis-clipboard
# niri 配置里注释掉 waybar / mako / swaync / swayosd 的启动项
# 剪贴板 Mod+Alt+V 让给 Clavis（模板里已注释掉 fuzzel 版本）
```

踩过的坑都写进 [`docs/upstream-issues/`](docs/upstream-issues/)：插件 `RUNPATH` 指向临时构建目录、
安装器在 pacman 7.1 上跑不完。本机绕行方案也在那个目录里。

想退回 waybar：停掉两个服务、取消模板里 waybar 那行注释、跑一次 `theme <名字>`。

## 快捷键

`Mod` = Super（Windows 键）。

| 键 | 作用 |
|---|---|
| `Mod+T` / `Mod+D` | 终端 / 启动器 |
| `Mod+Q` | 关窗口 |
| `Mod+O` | 窗口总览 |
| `Mod+B` / `Mod+Shift+B` | 换壁纸 / 随机壁纸 |
| `Mod+Alt+T` | 换主题 |
| `Mod+S` | 系统设置 |
| `Mod+Shift+S` | 区域截图 → satty 标注（`Ctrl+S` 存盘，`Esc` 取消） |
| `Mod+Alt+N` | 打开/关闭通知中心（右键 = 免打扰） |
| `Mod+Alt+V` | 剪贴板历史 |
| `Mod+1..9` | 切工作区 |
| `Super+Alt+L` | 锁屏（gtklock，当前壁纸做背景） |
| `Mod+Shift+E` | 退出 niri |
| `Mod+Shift+/` | 全部快捷键 |

## 踩过的坑（写在这里省得别人再踩）

1. **KDE 应用在 niri 里只认图标不认配色** —— 缺 `QT_QPA_PLATFORMTHEME=kde`，Qt 会退回 Fusion 亮色板。niri 配置里用 `environment {}` 块补上。
2. **`plasma-apply-colorscheme` 会「跳过」同名方案**，壁纸跟随模式下方案名不变、内容变了，它就不重写 `kdeglobals`。而且它合并时某些段（`[Colors:Selection]`）会保留旧值。解法：`apply-kde-colors` 直接整段覆盖。
3. **libadwaita 无视 `gtk-theme-name`**，要往 `~/.config/gtk-4.0/gtk.css` 里 `@import` 主题的 CSS；改 headerbar 还必须加 `!important`。
4. **niri 没有模糊协议**，窗口半透明只会透出壁纸像素，透明度别给太低（> 60%）。
5. **`flock` 的 fd 会被后台守护进程继承** —— `awww-daemon` 拿着锁不放，之后每次换壁纸都卡到超时。启动守护进程时要 `9>&-`。
6. **`prefer-no-csd` 后 Qt 应用没有标题栏**，所谓「顶栏」其实是工具栏/headerbar。
7. **PowerDevil 在 niri 下不会自启**（systemd user service 没有 `[Install]`），不启动的话电源管理页面是空的。
8. **Papirus-Dark 的各尺寸目录是指向 Papirus 的符号链接**，直接复制改色改的是没人用的副本；只覆盖 places 下文件夹图标、其余继承才划算（4.4M vs 1.6G）。

9. **GTK CSS 不支持 `!important`** —— 写了不会报错退出，只是在日志里丢一句 `Junk at end of value` 然后整条规则失效。改 headerbar 要用 `@define-color headerbar_bg_color` + `:root { --headerbar-bg-color }`，但 libadwaita 会把 alpha 拍平（实测 0.8/0.5/0.3 得到同一像素），所以 GTK 顶栏只能跟颜色、不能半透明。Qt 侧（Darkly）的透明度是真的有效。
10. **satty 的参数要看清版本** —— 0.22 没有 `--copy-to-clipboard`，只有 `--copy-command`；传错参数它会**静默退到后台失败**（退出码 2），表现为"框选完什么都没出现"。另外 niri 会平铺新窗口，得加 `--floating-hack`，否则标注窗口可能被塞到别的列去。
11. **`spawn-sh` 只吃一个字符串** —— `spawn-sh "cmd" "arg"` 会报 `unexpected argument`，要写成 `spawn-sh "cmd arg"`。而 `spawn` 才是多参数形式。

## 许可

配置和脚本随你取用，不附带任何担保。第三方主题（Nordic / Papirus / Catppuccin GTK）各有自己的许可。
