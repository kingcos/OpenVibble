# Claude Buddy Bridge · iOS

> 中文 / English bilingual README

## 中文说明

### 项目简介

Claude Buddy Bridge 是一个 iPhone App，通过 BLE（Nordic UART Service）与 **Claude Desktop** 配对，充当“Hardware Buddy”。

它替代了 ESP32 固件方案，把 Buddy 直接放到 iPhone 上：
- 根据 Claude Desktop 会话状态变化动画
- 在手机端批准/拒绝权限请求
- 随 Token 累积成长升级

上游参考项目：[claude-desktop-buddy](https://github.com/claude-desktop-buddy-main)

### 环境要求

- iOS 18+
- Xcode 17+（含命令行工具）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）
- 真机设备（iOS 模拟器不支持 BLE 外设广播）

### 构建

```sh
xcodegen generate
open ClaudeBuddyBridge.xcodeproj
# 或：xcodebuild -project ClaudeBuddyBridge.xcodeproj -scheme ClaudeBuddyBridgeApp build
```

单元测试：

```sh
swift test --package-path Packages/ClaudeBuddyKit
```

### 与 Claude Desktop 配对

1. 在 Claude Desktop 打开开发者模式，进入 `Developer → Hardware Buddy`。
2. 在 iPhone 启动 Claude Buddy Bridge，App 会开始广播 BLE 外设服务（NUS）。
3. 将 iPhone 名称改为以 `Claude` 开头（`设置 → 通用 → 关于本机 → 名称`，例如 `Claude` / `Claude-iPhone`）。
4. 在 Claude Desktop 的 Hardware Buddy 面板选择该设备。

当 Claude Desktop 推送角色包时，文件会落到：

`~/Library/Containers/kingcos.me.claude.buddy.bridge/.../Application Support/ClaudeBuddyBridge/characters/<name>/`

并自动出现在物种选择器中。

### 交互控制

| 手势/操作 | 效果 |
|---|---|
| 摇一摇 | 触发眩晕动画（2 秒） |
| 设备朝下 ≥ 3 秒 | 进入睡眠，累计午睡时长 |
| 再翻回正面 | 唤醒恢复 |
| 长按宠物 | 打开主菜单（数据/物种/信息） |
| 右上角爪印按钮 | 打开物种选择 |
| 权限提示 5 秒内批准 | 心动动画（2 秒） |
| Token 跨越 50K 阈值 | 升级庆祝（3 秒） |

Terminal 页保留底层调试能力：连接状态、事件日志、广播控制与诊断回调。

### iOS 相比 ESP32 的限制

| 未实现项 | 原因 |
|---|---|
| BLE passkey bonding / encrypted-only | CoreBluetooth 外设侧无 ACL 配置 API |
| 自定义 GAP 设备名 | iOS 不允许 App 自定义 GAP 名称，只能用系统设备名 |
| 屏幕亮度/旋转/LED/蜂鸣器 | iPhone 无对应硬件接口 |
| 额外 ASCII 物种（当前仅猫） | 由 Claude Desktop 推送 GIF 角色包补足 |
| Demo/idle 自动走动模式 | 未连接 BLE 时保持 idle |
| `heap` 与电量 mV/mA 字段 | iOS 无公开 API，当前回传 0 |

状态上报会包含真实电量百分比（`UIDevice.batteryLevel/batteryState`）以及真实统计值（审批、拒绝、中位响应、午睡、等级）。

### 架构

- **BuddyProtocol / NUSPeripheral / BuddyStorage**：NDJSON、BLE 外设、文件落盘
- **BuddyPersona**：状态枚举、状态推导、manifest 解析、角色目录
- **BuddyStats**：统计模型与持久化
- **BuddyUI**：ASCII/GIF 渲染
- **BridgeRuntime**：心跳解析、快照与提示状态、传输状态
- **ClaudeBuddyBridgeApp**：界面、动作控制、传感器与入口流程

---

## English

### Overview

Claude Buddy Bridge is an iPhone app that pairs with **Claude Desktop** over BLE (Nordic UART Service) and acts as the “Hardware Buddy”.

It replaces the ESP32 firmware path and keeps the buddy directly on iPhone:
- Reacts to Claude Desktop session status
- Lets you approve/deny permission prompts on phone
- Levels up with token accumulation

Upstream inspiration: [claude-desktop-buddy](https://github.com/claude-desktop-buddy-main)

### Requirements

- iOS 18+
- Xcode 17+ (with command-line tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Physical iOS device (BLE peripheral advertising is not supported in Simulator)

### Build

```sh
xcodegen generate
open ClaudeBuddyBridge.xcodeproj
# or: xcodebuild -project ClaudeBuddyBridge.xcodeproj -scheme ClaudeBuddyBridgeApp build
```

Unit tests:

```sh
swift test --package-path Packages/ClaudeBuddyKit
```

### Pairing with Claude Desktop

1. Enable Developer Mode in Claude Desktop and open `Developer → Hardware Buddy`.
2. Launch Claude Buddy Bridge on iPhone; it starts BLE advertising (NUS).
3. Rename iPhone so its name starts with `Claude` (`Settings → General → About → Name`).
4. Select the device in Claude Desktop Hardware Buddy panel.

When Claude Desktop pushes a character pack, files land in:

`~/Library/Containers/kingcos.me.claude.buddy.bridge/.../Application Support/ClaudeBuddyBridge/characters/<name>/`

and appear in the species picker automatically.

### Controls

| Gesture / Action | Effect |
|---|---|
| Shake | Dizzy animation (2s) |
| Face-down for ≥ 3s | Sleep + nap accumulation |
| Face-up | Wake to active state |
| Long-press buddy | Main menu (Stats / Species / Info) |
| Pawprint button (top-right) | Species picker |
| Prompt approved within 5s | Heart animation (2s) |
| Tokens cross 50K threshold | Level-up celebration (3s) |

Terminal tab keeps low-level diagnostics: connection state, event logs, advertising control, and callback traces.

### iOS limitations vs ESP32 firmware

| Not ported | Why |
|---|---|
| BLE passkey bonding / encrypted-only | No ACL-level control in CoreBluetooth peripheral API |
| Custom GAP device name | iOS does not allow app-defined GAP name |
| LCD brightness / rotation / LEDs / buzzer | No matching iPhone hardware API |
| Additional ASCII species set | Replaced by pushed GIF character packs |
| Demo / idle auto-walk modes | App remains idle when BLE is disconnected |
| `heap` and battery mV/mA fields | No public iOS API; currently reported as 0 |

Status ack still reports real battery percent (`UIDevice.batteryLevel/batteryState`) and real persona stats.

### Architecture

- **BuddyProtocol / NUSPeripheral / BuddyStorage**: NDJSON framing, BLE peripheral, file landing
- **BuddyPersona**: persona state, manifest parsing, installed catalog
- **BuddyStats**: stats model + persistence
- **BuddyUI**: ASCII/GIF renderers
- **BridgeRuntime**: heartbeat ingest, runtime snapshot/prompt/transfer state
- **ClaudeBuddyBridgeApp**: app shell, screens, motion and onboarding flow
