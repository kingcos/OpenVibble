# OpenVibble · iOS Hardware Buddy Bridge

[English](./README.md) | 中文

<p align="center">
  <img src="./docs/readme/icon.png" alt="OpenVibble Icon" width="120" height="120" />
</p>

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-FA7343" />
  <img alt="License" src="https://img.shields.io/badge/License-AGPLv3-3DA639" />
</p>

OpenVibble 是一个 iOS App，通过 BLE（Nordic UART Service）与 Claude Desktop 配对，作为 iOS 端的“Hardware Buddy”。

它也是 [Claude Desktop Buddy](https://github.com/anthropics/claude-desktop-buddy) 的配套桥接实现，提供 iOS 原生交互与运行时支持。

<p align="center"><strong>M5Stack 开发板还在路上？先用 OpenVibble 体验起来！</strong></p>

## 效果图

| Claude Desktop 连接成功 | iOS App | 灵动岛 |
| --- | --- | --- |
| ![Claude Desktop connected](./docs/readme/connected.png) | ![OpenVibble App 主界面](./docs/readme/iphone-main.png) | ![OpenVibble 灵动岛 Live Activity](./docs/readme/dynamic-island.jpg) |

核心能力包括：
- 与 Claude Desktop Hardware Buddy 模式建立 BLE 连接
- 在手机端处理权限提示（批准/拒绝）
- 角色状态流转（idle/attention/busy/sleep/dizzy/celebrate/heart）
- 基于传感器的互动（摇一摇、设备朝下）
- 内置与桌面端下发的 GIF 角色包
- Live Activity 状态展示

## 环境要求

- macOS + Xcode 17+
- iOS 最低版本：18.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- 建议真机调试 BLE 外设广播（模拟器对 BLE 支持有限）

## 快速开始

```sh
make bootstrap
open OpenVibble.xcodeproj
```

命令行构建：

```sh
make build
```

运行测试：

```sh
make test
```

## 与 Claude Desktop 配对

1. 在 Claude Desktop 通过 `Help -> Troubleshooting -> Enable Developer Mode` 开启开发者模式。
2. 打开 `Developer -> Open Hardware Buddy...`，点击 `Connect`，然后选择你的 iOS 设备。
3. 在 iOS 设备上启动 OpenVibble，并在提示时授权蓝牙。

说明：
- iOS 对 BLE/GAP 有系统级限制，部分 MCU 固件中的底层能力无法直接映射。
- 桌面端下发的角色包会保存在 App 沙盒目录，并自动出现在角色/物种选择中。

## 贡献

欢迎提交 Issue 和 Pull Request。反馈问题时建议附上可复现步骤与环境信息。

## 本地化

当前提供英文（`en`）与简体中文（`zh-Hans`）资源。

## 许可证

使用 GNU AGPLv3，详见 [LICENSE](./LICENSE)。
