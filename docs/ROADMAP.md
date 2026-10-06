# CarSplit 路线图

## 已交付

- [x] **v0.1** 任意 App 上屏能力（运行时安全替换 `LSApplicationProxy` / `SBApplication` 的上屏能力钩子）
- [x] **v0.1** 设置面板：App A / App B 选择、全部应用上屏、自动启动
- [x] **v0.1** CarPlay 连接后自动启动双应用
- [x] **v0.2** 分屏预览容器：手机屏双面板 + 可拖拽分隔条（0.3–0.7 自动保存）+ 启动按钮 + 关闭按钮
- [x] **v0.2** 设置面板按钮 → Darwin 通知 → SpringBoard 引擎（`split.show` / `split.hide`）
- [x] **v0.2** 实时画面桥接探针：启动 App 后探测 `FBSceneManager` 中的 scene 与 `sceneHostManager`，输出到日志
- [x] **v0.2** 全量日志 `/var/tmp/carsplit.log`
- [x] GitHub Actions 自动编译（rootless + rootful）+ 打标签自动发布 Release

## 进行中（v0.3：App 实时画面桥接 —— 核心难点）

目标：把两个 App 的**实时画面**并排渲染进分屏容器（真正"双应用同屏"）。

基于 v0.2 探针的三种路径，需在真机上逐个验证：

1. **FBSceneHostManager 宿主路径（首选）**
   探测到目标 App 的 `FBScene` 后，用 `sceneHostManager` 注册宿主 view，把实时 layer 挂到面板。
   验证点：`probeSceneForApp:` 日志是否 FOUND scene；hostManager 的宿主 API 签名在 iOS 14/15/16/17 上的差异。

2. **CAContext / IOSurface 跨进程路径**
   在目标 App 进程内 hook 其 `UIWindow`，用 `CAContext` 产出可跨进程投递的 layer id，
   在 SpringBoard 侧远程挂载并回传触控事件。验证点：contextId 的创建与投递。

3. **兜底路径**
   若 1、2 不可行，退化为低帧率画面捕获（`drawViewHierarchyInRect:` 定时快照）先打通"同屏"体验，再优化帧率。

## 规划中

- v0.4 键盘中继：车机端面板输入时弹统一键盘（参照 iOS 键盘可编程接口），密码框除外
- v0.5 HUD：车速 / 限速 / 摄像头提示（需要定位权限与车速源），方向盘语音键接管
- v0.6 性能优化：深睡、帧率优化、断开 CarPlay 自动关闭面板 App

## 协作方式

每轮真机验证后，把 `/var/tmp/carsplit.log` 的关键行反馈到 Issue：
- `hooked ...` 表示钩子命中
- `skip hook: ... (method absent)` 表示该 iOS 版本没有此方法，需要换钩子点
- `[bridge] FOUND scene ...` / `no FBScene` 决定 v0.3 走哪条路径
- 崩溃则附带 `crashlog` 与系统版本、越狱环境（Dopamine/palera1n + iOS 版本 + 机型）
