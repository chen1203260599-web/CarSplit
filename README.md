# CarSplit

CarPlay 双应用方案（iOS 越狱插件，原创实现）。目标形态与 DuoDash 类似，但**全部代码为全新原创**，与任何商业插件无代码关系。

- 让未做 CarPlay 适配的 App 出现在车机应用选择器、可在车机上启动
- CarPlay 连接后按设置自动启动两个 App（一个留在手机前台、一个上到车机）
- **v0.2 分屏预览**：手机屏上双面板容器 + 可拖拽分隔条，无需车机即可测试分屏 UI
- 设置面板：Settings > CarSplit（选 App A / App B、预览开关、分隔比例）
- 日志：`/var/tmp/carsplit.log`

> 当前版本：**v0.2.0（alpha）**。App 实时画面桥接（真正把两个 App 的画面并排渲染）在 v0.3，见 `docs/ROADMAP.md`。

## 支持环境

- iOS 14.0+（rootless 与 rootful 双打包）
- 越狱环境：Dopamine / palera1n（依赖 ElleKit 或 MobileSubstrate + preferenceloader）
- 需要在**越狱设备上实测**；本项目通过 GitHub Actions 自动编译验证

## 安装

1. 在本仓库 **Releases** 页下载 `.deb`（rootless 越狱选 `carsplit-rootless.deb`）
2. 用 Sileo / Zebra 直接安装，或 SSH 到手机后：
   ```sh
   dpkg -i com.userspace.carsplit_*.deb
   killall -HUP SpringBoard
   ```
3. 打开 **设置 → CarSplit**：开启"全部应用上屏"，选择 App A / App B

## 使用流程

### 分屏预览（v0.2，先测这个）
1. 设置里选好 App A / App B，保持"允许分屏预览"开启
2. 点 **立即显示分屏预览** → 手机屏出现双面板容器
3. 拖动中间分隔条调整比例（自动保存）
4. 点面板里的 **启动 App** → 查看 `/var/tmp/carsplit.log` 中的桥接探测结果
5. 点右上角 **✕ 关闭** 退出预览

### 车机流程（v0.1）
1. 设置好 App A（手机端）与 App B（车机端）
2. 连接 CarPlay，约 4 秒后自动启动两个 App
3. 运行日志：`ssh root@<手机IP> 'cat /var/tmp/carsplit.log'`

## 从源码构建

- **CI（推荐）**：推送代码后 GitHub Actions 自动在 macOS 上编译并产出 `.deb`
- **本机 macOS**：
  ```sh
  git clone --recursive https://github.com/theos/theos.git $THEOS
  # 放入 iPhoneOS14.5.sdk 到 $THEOS/sdks/
  gmake clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
  ```

## 需要真机确认的验证点

| 项目 | 预期 | 验证方式 |
| --- | --- | --- |
| 分屏预览容器显示 | 双面板 + 分隔条 | 设置里点"立即显示分屏预览" |
| 分隔条拖拽 | 比例 0.3–0.7 可调并保存 | 拖动后看日志 `ratio saved` |
| 面板"启动 App"按钮 | App 被拉起 | 看日志 `launch ... -> OK` |
| 桥接探测 | 输出 FBScene 探测结果 | 看日志 `[bridge] ...` |
| 任意 App 出现在车机应用列表 | 开启开关后可见 | 连接车机看应用网格 |
| App 在车机上可启动 | 启动到车机屏幕 | 选择 App B 后触发 |
| `CARSessionDidConnectNotification` 通知名 | 自动启动生效 | 看 `/var/tmp/carsplit.log` |
| `LSApplicationProxy` 钩子是否命中 | 日志显示 hooked | 同上 |

> 若某个钩子未命中，日志会输出 `skip hook: ... (method absent)`，请把它反馈到 Issue，我们会按对应 iOS 版本补钩子。

## 免责声明

- 本项目是独立开发的原创代码，仅用于学习和研究目的
- 越狱与非 App Store 途径安装的插件存在风险，请自行评估并做好备份
- 请遵守当地法律法规与交通安全法规，驾驶时不要操作手机

## 许可证

MIT，见 [LICENSE](LICENSE)。
