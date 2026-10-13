# Super Ping for macOS

基于 [lolPing](https://github.com/darrenprx/lolPing) 的交互和资源，用 Swift + AppKit + SwiftUI 重构二次开发的原生菜单栏应用，无 Electron、Node 或 WebView 运行时。macOS 13+，可在 Apple Silicon / Intel 上从源码构建。正式发布为 Apple Silicon + Intel 通用包。

## 项目来源与二次开发

Super Ping 基于 [darrenprx/lolPing](https://github.com/darrenprx/lolPing) 的轮盘交互与资源进行 macOS 原生重构和二次开发，并非原仓库的官方版本。感谢原作者 Danrui Meng。新增可配置动作、带 Ping 标记的截图、Codex 联动、应用与浏览器上下文识别以及原生菜单栏设置。

本项目代码以 MIT 许可证发布，原项目的 MIT 版权声明保留在 [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt)。Ping 图标（包括应用问号图标）与音效来自原仓库，属于 Riot Games，不包含在 MIT 授权中。Super Ping 不受 Riot Games 认可或赞助。

## 下载安装

从 [GitHub Releases](https://github.com/norvancc/super-ping/releases/latest) 下载通用 DMG，打开后将 Super Ping 拖入 Applications。支持 macOS 13+、Apple Silicon 和 Intel。正式发布包使用 Developer ID 签名并完成 Apple 公证。

## 开始使用

打开 `dist/Super Ping.app`。也可以将它复制到 Applications 后再授权，以免移动应用导致权限失效。

1. 在系统设置 → 隐私与安全性 → 辅助功能中添加并允许 Super Ping，授权后自动连接，也可返回设置点击“重新连接”。
2. 按住 **Option + 鼠标左键拖动**，松开鼠标选择 Ping；问号在左侧。回到中心、Esc、右键或松开 Option 可取消。移动超过 8 点展开轮盘，中心 86 点以内取消；普通 Option + 单击会回放给原应用。
3. 首次使用截图动作，在系统设置中允许屏幕录制，重新启动 Super Ping。首次控制 Terminal 时，允许系统的自动化提示。
4. **Control + Option + P** 暂停/恢复；菜单栏图标打开设置或退出。

“试用轮盘与 Hover”打开可交互的原生轮盘，不需要辅助功能权限。可悬停、从中心拖向任意方向并松开，查看高亮和发送反馈。“预览 Ping”及试用轮盘均不执行绑定动作。

## 默认问号动作

隐藏轮盘 → 显示真实 Ping 动画 → 在 0.4 秒的完整问号和波纹画面暂停 → 保持浮层可见并等待绘制提交 → 截取显示器 → 保存 PNG → 隐藏浮层 → 打开 Terminal

```sh
codex --image '/path/to/screenshot.png' -- 'What'"'"'s this mean?'
```

请先安装 Codex CLI 并在 Terminal 中完成 `codex login`。设置中可指定 Codex 完整路径、工作目录和提示词。这里使用 CLI 的图片附件参数，不模拟粘贴或键盘输入，也不更改 Codex 的审批或沙箱设置。CLI 的启动、登录和连接错误会显示在 Terminal 中；应用的“已执行”仅表示启动命令已交给 Terminal，并不表示模型已成功回答。

整屏截图可能包含其他窗口内容，并会作为附件交给 Codex。截图保存在 `~/Library/Application Support/PingAgent/Screenshots/`，不会自动删除，可从设置打开文件夹管理。

## 自定义动作

八个方向独立配置，设置自动保存到 `~/Library/Application Support/PingAgent/settings.json`。

| 动作 | 配置 |
| --- | --- |
| 仅显示 Ping | 动画与声音 |
| 截图并询问 Codex | 可编辑提示词 |
| 仅截图并保存 | 截取 Ping 所在显示器，保留标记并保存 PNG；不打开 Terminal，不发送给 AI |
| 截图并复制到剪贴板 | 保存 PNG 并复制图片，可直接粘贴 |
| 截图并打开预览 | 保存 PNG 后使用默认图片应用打开 |
| 打开网页 | 在默认浏览器打开指定 HTTP / HTTPS 链接 |
| 打开文件或文件夹 | 选择本地文件或文件夹，使用默认应用打开 |
| 运行快捷指令 | 填写快捷指令完整名称，直接调用 macOS 快捷指令 |
| 复制文字 | 将预设文字写入剪贴板 |
| 打开应用 | `.app` 路径或 Bundle ID；提供文件选择器 |
| 运行脚本文件 | `.sh`/`.zsh` 用 zsh，`.bash` 用 bash，`.scpt`/`.applescript` 用 osascript；其他脚本须有 shebang 和执行权限 |
| 执行 Mac 命令 | 如 `open -a Safari`、`shortcuts run '我的快捷指令'`，支持多行 |

脚本和命令可在 Terminal 中运行，或后台以 `/bin/zsh -lc` 执行。后台任务限时 60 秒，超时向直接子进程发送终止请求；不负责管理脚本自行派生的后台任务。交互或长时间任务请选择 Terminal。命令按用户输入执行，拥有当前用户权限。

提供 `PING_KIND`、`PING_X`、`PING_Y` 环境变量；坐标采用 AppKit 全局坐标系。应用路径、脚本路径、Codex 路径、图片路径及提示词均独立转义。

## 构建与测试

安装 Xcode 或 Command Line Tools，运行：

```sh
bash scripts/build-app.sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" swift test --disable-sandbox
```

输出 `dist/Super Ping.app`，包含所需资源。默认 ad-hoc 签名；可使用 `SIGNING_IDENTITY` 指定自己的开发者签名。公开分发前需自行完成 Developer ID 签名和公证。本地重新构建后，macOS 可能要求移除并重新添加辅助功能权限。

## 移植范围与验证

已实现八向 Ping、原始图标与音效、原生波纹动画、跨桌面浮层、菜单栏、暂停快捷键、设置持久化和自定义动作。轮盘几何参数已与上游对齐，包含灰金色静态图标、彩色悬停放大及渐变扇区高亮。动画改为三重扩散波纹、弹出与浮动；全力进攻双图碰撞等细节尚未逐帧复刻。尚未移植上游表情轮盘、轮盘重排、自定义触发键、自动更新和登录启动。

自动测试覆盖八方向选择、中心取消、默认动作、配置序列化、实际 shell 参数转义及 Codex 命令构造。系统授权、真实鼠标手势和 Codex 网络回答需要在授权后的桌面完成验收；构建测试不等于这些流程已验证。

## 来源与许可

上游源码采用 MIT；本项目源码采用 MIT。原项目图标与音效归 Riot Games 所有，不在 MIT 许可范围内。完整上游许可保存在 `THIRD_PARTY_NOTICES.txt`，并随 app 打包。项目不隶属 Riot Games，也未获其背书。

### 0.2 手势修复验收

- 修复吞掉 `leftMouseDragged` 冻结 macOS 鼠标的问题：移动事件始终透传，读取当前 `CGEvent.location`。
- 回调中异步执行绘制与音效；权限和监听断开后自动重连。
- 10 项测试通过，包括拖动高亮与发送、阈值、取消、成对抬起抑制和普通点击回放。
- 真实 UI 验收：试用窗口从中心拖向问号，扇区高亮、图标彩色放大、松开显示已发送。
- 全局手势仍需系统辅助功能授权后验收；试用窗口验证不等于全局监听验证。
- 构建采用暂存后替换，不覆盖运行中的二进制。

### 0.3 截图标记修复

最终 PNG 直接合成 Ping 图标、定位圈及连接线，不依赖动画帧或系统对浮层的捕获时机。圈中心是手势起点，不是松开鼠标的位置；图标在屏幕边缘会移入可见范围。使用实际截图像素与显示器逻辑尺寸映射，支持 Retina 和负坐标副屏。合成失败会停止发送，不再传出没有标记的图片。

### 0.4 截图顺序修复

截图前先播放 Ping 1 秒，随后清理动画浮层并等待 180 毫秒，再获取当时的屏幕内容、合成定位标记。PNG 保存成功后才启动 Terminal。等待期间暂时不接受新的 Ping 手势，避免另一个轮盘进入截图。

### 0.5 真实浮层截图（取代 0.3/0.4 的静态合成）

不再调用 MarkedScreenshot 合成问号/定位圈。保持真实 Overlay 可见，将动画固定在 0.4 秒后进行显示器捕获；捕获完成前不隐藏浮层。设置中的“实测截图（不发送 Codex）”使用同一截图流程，直接打开实际 PNG 供验收。自动化时序测试不代表真实桌面截图已通过。

### 0.5.1 拖动性能

图标灰金色滤镜在启动时生成位图缓存；同一扇区内鼠标移动不重复发布高亮和设置状态；轮盘展开/高亮动画结束后停止定时重绘。保留 0.5 的真实浮层截图流程。

本机离屏绘制基准（每帧八个图标，200 帧）：实时 Core Image 表示约 14.22 ms/帧，位图缓存约 0.074 ms/帧。这只测图标绘制成本，不是整体应用帧率或真实拖动延迟。回归测试共 17 项通过，其中 1,000 次同扇区移动只产生一次 hover 更新。

复现基准：`swift scripts/benchmark-icons.swift Sources/PingAgent/Resources/textures/enemy_missing.png`，需要图形服务可用。

### 0.5.2 音效卡顿修复

根据开关声音的对照反馈，移除主线程的 NSSound stop/play。所有音频加载、预准备、播放和播放状态检查统一在独立串行队列执行；每种声音预备三个 AVAudioPlayer，不打断正在播放的声音。Hover 最短间隔 65 毫秒，排队超过 120 毫秒的提示音丢弃，播放器满载时不积压。此策略优先保证拖动反馈及时，极快扫过扇区时允许省略提示音。

### 0.6 应用和网页上下文

开始 Ping 时记录鼠标下方最上层普通应用窗口，后台识别应用名、Bundle ID、窗口标题。Safari、Chrome（含 Beta/Canary）、Edge、Brave、Vivaldi、Chromium 尝试通过 AppleScript 读取该窗口的当前标签页标题和 HTTP(S) URL。按窗口边界匹配，不使用浏览器 front window 兜底，避免多窗口/多屏时取错链接。其他应用只附应用/窗口信息。

浏览器首次可能请求自动化权限；超时、拒绝授权、窗口不匹配或特殊页面无法读取时，仍发送截图和已知上下文。查询最多等待约 4 秒，工作在后台；不会激活浏览器、切换标签或打开链接。

提示词保留原有问题，再附带标记位置说明和 JSON 格式上下文；网页标题和窗口标题作为数据处理。截图同目录会保存同名 `.txt`，内容就是传给 Codex 的实际提示词。“实测截图（不发送 Codex）”也会写入该文件。页面链接不意味着 Codex 能访问登录后的页面正文。

已核对本机 Chrome 脚本字典并测试提示词格式、URL 过滤及标题转义；浏览器自动化授权后的完整读取仍需桌面验收。

## 安装包

运行 `bash scripts/package-release.sh` 生成 DMG 和 ZIP。打开 DMG 后，将 Super Ping 拖入 Applications，再退出旧版并打开新应用。沿用原有配置目录和应用标识。默认构建为 Apple Silicon + Intel 通用架构、ad-hoc 签名；指定 `SIGNING_IDENTITY` 时启用 Developer ID 签名、Hardened Runtime 和安全时间戳。0.7.0 universal 安装包已完成 Developer ID 签名和 Apple 公证，应用及 DMG 均已附加公证凭据，并通过 macOS 分发检查。要求 macOS 13 或更新版本。

正式发布：设置 `SIGNING_IDENTITY` 为自己的 Developer ID 签名身份、`NOTARY_PROFILE` 为已保存的 notarytool 配置名称，然后运行 `bash scripts/package-release.sh`。该流程会向 Apple 上传应用和 DMG 完成公证。
