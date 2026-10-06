# CarSplit

CarPlay 双应用方案（iOS 越狱插件，原创实现）。目标形态与 DuoDash 类似，但**全部代码为全新原创**，与任何商业插件无代码关系。

- 让未做 CarPlay 适配的 App 出现在车机应用选择器、可在车机上启动
- CarPlay 连接后按设置自动启动两个 App（一个留在手机前台、一个上到车机）
- 设置面板：Settings > CarSplit（选 App A / App B、开关、分隔比例预留）
- 日志：`/var/tmp/carsplit.log`

> 当前版本：**v0.1.0（alpha）**。并排分屏容器（核心难点）在 v0.2，见 `docs/ROADMAP.md`。

## 支持环境

- iOS 14.0+（rootless 与 rootful 双打包）
- 越狱环境：Dopamine / palera1n（依赖 ElleKit 或 MobileSubstrate + preferenceloader）
- 需要在**越狱设备上实测**；本项目通过 GitHub Actions 自动编译验证

## 安装

1. 在本仓库 **Releases** 页下载 `.deb`（rootless 越狱选带 `rootless` 后缀的包）
2. 用 Sileo / Zebra 直接安装，或 SSH 到手机后：
   ```sh
   dpkg -i com.userspace.carsplit_*.deb
   killall -HUP SpringBoard
   ```
3. 打开 **设置 → CarSplit**：开启"全部应用上屏"，选择 App A / App B

## 使用流程

1. 设置好 App A（手机端）与 App B（车机端）
2. 连接 CarPlay，约 4 秒后自动启动两个 App
3. 查看运行日志：`ssh root@<手机IP> 'cat /var/tmp/carsplit.log'`

## 从源码构建

- **CI（推荐）**：推送代码后 GitHub Actions 自动在 macOS 上编译并产出 `.deb`
- **本机 macOS**：
  ```sh
  git clone --recursive https://github.com/theos/theos.git $THEOS
  # 放入 iPhoneOS14.5.sdk 到 $THEOS/sdks/
  gmake clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
  ```

## 需要真机确认的验证点（v0.1）

| 项目 | 预期 | 验证方式 |
| --- | --- | --- |
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
