# CarSplit 路线图

## 已交付（v0.1.0 alpha）

- [x] 任意 App 上屏能力（运行时安全替换 `LSApplicationProxy` / `SBApplication` 的上屏能力钩子）
- [x] 设置面板：App A / App B 选择、全部应用上屏、自动启动、分隔比例（预留）
- [x] CarPlay 连接后自动启动双应用
- [x] 全量日志 `/var/tmp/carsplit.log`
- [x] GitHub Actions 自动编译（rootless + rootful）+ 打标签自动发布 Release

## 进行中（v0.2：分屏容器 —— 核心难点）

目标：在车机屏幕上把两个 App 并排渲染，中间分隔条可拖拽到任意比例。
技术路径评估（需在真机上逐个验证）：

1. **SBAppLayout 方案（首选）**
   SpringBoard 的 iPad 多任务引擎通过 `SBAppLayout` + `SBMainWorkspaceTransaction` 排布多 App。
   验证点：iPhone 上创建两个 item 的 `SBAppLayout` 是否能被 `SBLayoutStateManager` 接受；
   若被拒绝，尝试给 CarPlay 场景（`CarPlay.app` 进程）挂载同样的布局引擎。

2. **窗口重定位方案（App Bridge）**
   手机前台 App 的 `UIWindow` 图层经 `CAContext` / IOSurface 捕获后，在车机侧宿主窗口内实时渲染，
   与车机前台 App 并排。验证点：`CAContext` 跨进程投递与触控事件回传。

3. **兜底方案**
   若 1、2 都不可行，退化为"镜像 + 定时截图刷新"的低帧率静态并排，先打通交互与布局骨架。

## 规划中

- v0.3 键盘中继：车机端面板输入时弹统一键盘（参照 iOS 键盘可编程接口），密码框除外
- v0.4 HUD：车速 / 限速 / 摄像头提示（需要定位权限与车速源），方向盘语音键接管
- v0.5 性能优化：深睡、帧率优化、断开 CarPlay 自动关闭面板 App

## 协作方式

每轮真机验证后，把 `/var/tmp/carsplit.log` 的关键行反馈到 Issue：
- `hooked ...` 表示钩子命中
- `skip hook: ... (method absent)` 表示该 iOS 版本没有此方法，需要换钩子点
- 崩溃则附带 `crashlog` 与系统版本、越狱环境（Dopamine/palera1n + iOS 版本 + 机型）
