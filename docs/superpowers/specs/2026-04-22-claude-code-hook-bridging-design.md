# OpenVibbleDesktop — Claude Code Hook Bridging

日期：2026-04-22
状态：设计（待审阅）

## 背景

OpenVibbleDesktop 目前能作为 BLE central 连接 iOS 端 `OpenVibbleApp`，转发心跳 / 手动命令。下一步要让 **Mac 本机运行的 Claude Code** 把它的事件（tool 调用请求、用户发问、turn 结束、系统提示）实时推到 iOS 桌宠。关键特性：

- **双向**：PreToolUse 要阻塞等审批，iOS 点 Approve/Deny 能把决策回传 Claude Code
- **本地可替代**：用户坐电脑前也要能审批（Mac app 窗口按钮），不只是 iOS
- **可见**：用户能看到哪些事件被 hook、每条对应什么 BLE 动作/宠物状态
- **可扩展**：文档化的 HTTP 协议，让其他 coding agent（Cursor 等）将来也能接进来
- **不影响现有使用**：Mac app 不运行时，Claude Code 正常走原生流程，零副作用

## 范围

**v1（本次）**
- 仅 Claude Code 本地 hook 集成
- 4 个事件：`PreToolUse` / `UserPromptSubmit` / `Stop` / `Notification`
- Mac app 提供一键注册 / 注销
- iOS 端 **零改动**（现有 heartbeat.prompt + PermissionCommand 协议足够）

**明确不做（v2+）**
- Cursor / 其他 agent 的原生集成（但协议文档化，v1 就能手动接）
- PostToolUse（触发频率过高，v1 不做去重/节流）
- 多会话并发队列（v1 同一时刻只处理一个 pending）

## 关键决策（brainstorming 已定）

| # | 主题 | 决策 |
|---|---|---|
| 1 | 范围 | B：仅 Claude Code，双向 |
| 2 | 注册位置 | 用户全局 `~/.claude/settings.json` |
| 3 | 事件 | 4 个：PreToolUse + UserPromptSubmit + Stop + Notification |
| 4 | UI 可见性 | 独立 tab，事件卡片 + 实时活动日志 |
| 5 | 并行审批 | iOS / Mac 按钮 race，30s 超时 → `ask` 回落终端 Y/N |
| 6 | IPC | Localhost HTTP（`127.0.0.1:<随机端口>`），fail-open |
| 7 | 会话识别 | 将 cwd basename 注入 `prompt.hint`，不改 iOS 协议 |
| 8 | 注册实现 | 编辑 settings.json，每条带 `# OVD-MANAGED-v1` marker，注销只拆自己的 |
| 9 | UI 布局 | 单窗口多 tab |

## 架构

### 新增组件

**`HookBridge`**（`OpenVibbleDesktop/Bridge/HookBridge.swift`）
- 基于 `Network.framework` 的 `NWListener`，绑 `127.0.0.1` + 随机端口
- 启动时生成 32 字节 token（base64），写入 port 文件；quit 时删除
- 所有 POST 端点校验 `X-OVD-Token` header

**`HookRegistrar`**（`OpenVibbleDesktop/Bridge/HookRegistrar.swift`）
- 读写 `~/.claude/settings.json`（不存在时新建）
- Register：merge 4 个 hook，每条 command 尾部加 `# OVD-MANAGED-v1`
- Unregister：读 → 过滤掉 marker 命中的 → 写回
- 冲突检测：同事件下已有第三方 hook 时保留共存

**`PortFile`**（`OpenVibbleDesktop/Bridge/PortFile.swift`）
- 位置：`~/.claude/openvibble.port`
- 格式：`{"port": 41847, "token": "base64...", "pid": 12345, "version": "1"}`
- App 启动写、退出删；崩溃后残留 → 下次启动覆盖

**`HookActivity`**（`OpenVibbleDesktop/Bridge/HookActivity.swift`）
- 环形 buffer（最近 50 条），每条 `{timestamp, event, projectName, toolName?, decision?}`
- 每事件类型分别维护 `lastFiredAt` / `todayCount`

### 修改组件

- `AppState.swift`：持有 `HookBridge` / `HookRegistrar` / `HookActivity`，暴露 `pendingApproval` 发布者
- `MainView.swift`：改为 `TabView` 容器
- `OpenVibbleDesktop.entitlements`：移除 `app-sandbox`（需要 `~/.claude/` 访问 + HTTP 监听，沙盒化代价过高）

### iOS 端 vs Mac 侧协议层补强

**iOS app / BridgeRuntime / BuddyProtocol 零改动**。原因：

- iOS 已经通过 RX 收 NDJSON 行，`BridgeRuntime.ingestLine(_:)` 解码 `HeartbeatSnapshot`，抽 `heartbeat.prompt` 显示到 UI / LiveActivity。Mac 侧只要合成一条带 `prompt` 字段的 heartbeat 行、经 BLE 写到 iOS RX，iOS 就会展示。
- iOS user 点 Approve/Deny 时，现有 `BridgeRuntime.respondPermission(_:)` 会把 `PermissionCommand` 编成 NDJSON 行、通过 TX notify 发给 central。

**但 `NUSCentral.CentralInboundMessage` 当前只识别 `.heartbeat / .turn / .timeSync / .ack`**，没有 `.permission(PermissionCommand)` case —— 即便 iOS 把决策发过来也会被丢进 `.unknown`。v1 必须：
1. 给 `CentralInboundMessage` 加 `.permission(PermissionCommand)` case
2. `CentralInboundDecoder.decode` 识别 `cmd:"permission"` 行

这只动 `Packages/OpenVibbleKit/Sources/NUSCentral/CentralInboundMessage.swift`，不碰 iOS target。

### Mac → iOS 的 prompt 推送

HookBridge 收到 PreToolUse 后，通过 `central.sendEncodable(...)` 向 iOS 写一条合成的 `HeartbeatSnapshot`：

```swift
HeartbeatSnapshot(
    total: existing.total + 1,      // 可以直接用最近一次 iOS 报上来的 heartbeat
    running: existing.running,
    waiting: existing.waiting + 1,
    msg: "pending",
    entries: [],
    tokens: existing.tokens,
    tokensToday: existing.tokensToday,
    prompt: HeartbeatPrompt(id: pendingId, tool: payload.toolName,
                            hint: "[\(projectName)] \(hintSummary)"),
    completed: false
)
```

`prompt.id = 我们分配的 pendingId`（UUID.string），`hint` 前缀加项目名。决策落定后再推一条 `prompt: nil` 清除 iOS 端显示。

## Hook 生命周期

### 注册（用户在 Hooks tab 点 Register）

1. `HookRegistrar.register()` 读 `~/.claude/settings.json`（缺失则 `{}`）
2. 定位 `hooks.PreToolUse` / `hooks.UserPromptSubmit` / `hooks.Stop` / `hooks.Notification`（缺失则 `[]`）
3. 每事件 append 一条（见下表），command 尾部 `# OVD-MANAGED-v1`
4. `JSONSerialization` 回写，保留用户其它字段

**注入的 hook 条目**

```json
{
  "type": "command",
  "command": "curl -s --max-time 30 -H \"X-OVD-Token: $(jq -r .token ~/.claude/openvibble.port 2>/dev/null)\" http://127.0.0.1:$(jq -r .port ~/.claude/openvibble.port 2>/dev/null)/pretooluse -d @- 2>/dev/null || echo '{}' # OVD-MANAGED-v1"
}
```

`PreToolUse` 用 `--max-time 30`；`UserPromptSubmit` / `Stop` / `Notification` 用 `--max-time 1 ... >/dev/null 2>&1; echo '{}'`（不等响应）。

**依赖**：`jq` 和 `curl`（macOS 自带 curl；jq 非默认，需提示用户 `brew install jq`，或改用纯 shell 解析 port 文件 —— v1 选 jq 更简洁，Register 前做一次 `command -v jq` 检测，缺失弹提示）。

### 注销

1. 读 settings.json
2. 遍历所有 hook arrays，过滤掉 `command` 字符串包含 `# OVD-MANAGED-v1` 的条目
3. 空数组 key 删掉（keep 干净）
4. 回写

### PreToolUse（阻塞决策）

```
CC → curl POST /pretooluse (headers + stdin body, max 30s)
     ↓
HookBridge 收到 → 解析 JSON → 生成 pendingId
     ↓
AppState.setPending(PendingApproval{...})
     ↓
并行：
  • Overview tab 显示横幅
  • BuddyCentralService 下次 status ack 携带 prompt
     ↓
Race（先到先得，取消其余）：
  • iOS BLE: PermissionCommand(id, approve) → AppState.resolvePending(.allow/.deny)
  • Mac 按钮: HookBridge.resolvePending(.allow/.deny)
  • 30s 超时: HookBridge.resolvePending(.ask)
     ↓
HTTP response body：
  allow → {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
  deny  → {...,"permissionDecision":"deny","permissionDecisionReason":"Denied from OpenVibbleDesktop"}
  ask   → {...,"permissionDecision":"ask"}（CC 回落原生 Y/N）
     ↓
pendingApproval 清空，HookActivity 记一条 {decision: allow/deny/ask, ...}
```

**Mac app 未运行**：
- `~/.claude/openvibble.port` 不存在 → `jq` 输出空 → URL 形如 `http://127.0.0.1:/pretooluse` → curl 失败 → `|| echo '{}'` → CC 看到空对象 → 走原生权限流程
- 端口文件存在但连接拒绝（进程崩溃残留文件）→ curl 超时 30s 后失败 → 同上
- **优化**：fire-and-forget hook 的 `--max-time 1` 保证非阻塞；PreToolUse 的 30s 上限是硬性等待，这是用户选择代价

### Fire-and-forget（UserPromptSubmit / Stop / Notification）

```
CC → curl POST /<endpoint> (max 1s, 丢弃响应)
     ↓
HookBridge → HookActivity.append(...) → triggerPersonaState(...)
     ↓
iOS 下次心跳读到新的 persona state
```

## HTTP 协议（Bridge API）

所有端点位于 `http://127.0.0.1:<port>`，端口 / token 读 `~/.claude/openvibble.port`。

### 鉴权

Header：`X-OVD-Token: <token>`。未带或错误 → 401。

### `POST /pretooluse`

**请求体**（Claude Code hook 透传的 JSON）：
```json
{
  "session_id": "uuid",
  "cwd": "/path/to/project",
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf /" }
}
```

**响应**：见 PreToolUse race 一节。

### `POST /prompt` `/stop` `/notification`

**请求体**：hook 原样转发（各自字段不同）。响应：`204 No Content`（`/notification` 额外带 `message` 字段文本）。

### `GET /health`

未授权。返回：
```json
{
  "name": "OpenVibbleDesktop",
  "version": "0.2.0",
  "connected": true,
  "registered": true
}
```

### 给第三方 agent 的用法

Cursor / 其它 agent 只需：
1. 读 `~/.claude/openvibble.port` 拿 port + token（或自行协商路径）
2. 在合适时机 curl 这些端点
3. PreToolUse 等价场景（需审批）调 `/pretooluse`，读响应 JSON

→ 这套说明直接在 **Bridge API tab** 内嵌展示，带 copy 按钮。

## UI 布局

### Header（所有 tab 共享）

- 左：连接指示灯 + 设备名
- 右：Connect / Disconnect（语言切换移到 Settings）

### Tab 1 · Overview / 概览

- **Pending Approval Banner**（条件显示）：橙色横幅，显示项目名 + 工具 + hint + `Approve` / `Deny` 按钮
- Device info（精简）：battery / level / approved / velocity
- Pet state 当前值 + 3 条最近 hook 活动

### Tab 2 · Hooks / 钩子

- **状态徽章**：`Registered` / `Not registered` / `Partially registered`（4 条都在才算 registered）
- **Register / Unregister 按钮**
- **4 张事件卡**（grid 2x2）：
  - 标题：事件名
  - 一句话说明：触发时机
  - BLE 动作：发什么消息给 iOS
  - Pet state：触发后宠物变啥
  - 统计：今天 N 次 / 上次 X 分钟前
- **实时日志**：最近 20 条（时间 / 事件 / 项目 / 决策）

### Tab 3 · Test Panel / 测试面板

现 MainView 的所有手动测试内容整体搬过来：
- Battery / Stats / System（复用现有 section）
- 手动命令（status / time / unpair）
- Rename / Owner
- Species picker
- Install character pack
- Activity log

### Tab 4 · Bridge API / 桥接说明

- 一段介绍：OpenVibbleDesktop 本质是个本地 HTTP ↔ BLE 桥，任何能 curl 的 agent 都能把事件推到 iOS 桌宠
- **当前桥状态**：`http://127.0.0.1:<port>` / token 脱敏显示 / `~/.claude/openvibble.port` 路径
- **端点表**：`/pretooluse` / `/prompt` / `/stop` / `/notification` / `/health`
- **curl 示例**（每条带 Copy 按钮）
- **当前注册的 hook 预览**：解析 settings.json 中带 OVD-MANAGED 标记的条目，只读展示
- **链接**：GitHub repo

### Tab 5 · Settings / 设置

- 语言切换（中 / 英 / 跟随系统）
- 登录时启动（可选）
- About：版本 / 作者 / 仓库链接 / License（吸纳现有 AboutSheet 的内容，保留独立 About 窗口入口作为菜单栏便捷项）

## Pet State 映射

| Hook event | 即时 state | Overlay | 时长 |
|---|---|---|---|
| PreToolUse（pending） | `attention` | `heart`（等待中） | 直到决策 |
| PreToolUse 决议 allow | `celebrate` | — | 1s |
| PreToolUse 决议 deny | `idle` | `dizzy` | 1.5s |
| PreToolUse 决议 ask / 超时 | `idle` | — | — |
| UserPromptSubmit | `busy` | — | 瞬闪 1s |
| Stop | `celebrate` | — | 3s 后回 idle |
| Notification | `attention` | — | 2s |

映射放在 `HookEvent.toPersonaIntent()`，由 AppState 消费后走 `derivePersonaState` 管线。

## 本地化

新增 key（在 `Localizable.xcstrings`）：
- `desktop.tab.overview` / `tab.hooks` / `tab.testPanel` / `tab.bridge` / `tab.settings`
- `desktop.hooks.title` / `.registered` / `.notRegistered` / `.register` / `.unregister` / `.preToolUse.title` / `.preToolUse.desc` / `.userPromptSubmit.*` / `.stop.*` / `.notification.*` / `.lastFired` / `.todayCount`
- `desktop.pending.banner.title` / `.project` / `.approve` / `.deny`
- `desktop.bridge.intro` / `.endpoints` / `.example` / `.currentState` / `.tokenHidden`
- `desktop.settings.language` / `.autoLaunch` / `.about`
- `desktop.hooks.jqMissing`（提示 brew install jq）

每个 key 同时提供 `en` 和 `zh-Hans`。

## 安全

- Token 长度 32 字节随机，每次 app 启动重生成
- `~/.claude/openvibble.port` 权限 `0600`
- HTTP 绑 `127.0.0.1`，拒绝 `0.0.0.0`/`::`
- 所有 mutating 端点要求 token；`/health` 可不验（便于诊断）
- PreToolUse 回传的 `tool_input` 里可能含敏感路径 —— 日志脱敏（全路径改相对）

## 文件清单

**新建**
- `OpenVibbleDesktop/Bridge/HookBridge.swift`
- `OpenVibbleDesktop/Bridge/HookRegistrar.swift`
- `OpenVibbleDesktop/Bridge/HookEvent.swift`
- `OpenVibbleDesktop/Bridge/HookActivity.swift`
- `OpenVibbleDesktop/Bridge/PortFile.swift`
- `OpenVibbleDesktop/Views/Tabs/OverviewTab.swift`
- `OpenVibbleDesktop/Views/Tabs/HooksTab.swift`
- `OpenVibbleDesktop/Views/Tabs/TestPanelTab.swift`
- `OpenVibbleDesktop/Views/Tabs/BridgeDocsTab.swift`
- `OpenVibbleDesktop/Views/Tabs/SettingsTab.swift`
- `OpenVibbleDesktop/Views/PendingApprovalBanner.swift`
- `OpenVibbleDesktop/Views/EventCard.swift`

**修改**
- `OpenVibbleDesktop/AppState.swift` — 集成 HookBridge + pendingApproval
- `OpenVibbleDesktop/Views/MainView.swift` — 改为 TabView 壳
- `OpenVibbleDesktop/Views/MenuBarView.swift` — 加 pending 提示
- `OpenVibbleDesktop/OpenVibbleDesktop.entitlements` — 移除 app-sandbox
- `OpenVibbleDesktop/Resources/Localizable.xcstrings` — 新增 key（中英双语）
- `OpenVibbleDesktop/L10n.swift` — 语言切换 UI 迁移到 SettingsTab
- `project.yml` — 如需调整（依赖不变）

## 验证

1. **注册/注销**：
   - 空 settings.json → Register → 4 个事件 key 正确生成 → Unregister → 文件清空
   - 有用户自写 hook 的 settings.json → Register 后用户 hook 保留 → Unregister 只拆我们那条
2. **PreToolUse race**：
   - iOS 先 Approve → CC 收 `"allow"`，Mac 按钮变灰
   - Mac 按钮先 Deny → iOS 横幅消失，CC 收 `"deny"`
   - 都不点 → 30s 后 CC 收 `"ask"`，终端出现 Y/N
3. **Fail-open**：
   - Mac app 未启动时，CC 运行 `Bash` 命令 → 终端出现原生 Y/N，无阻塞
   - Mac app 运行但 BLE 未连 iOS → PreToolUse 仍走 race（Mac 按钮 / 30s → ask）
4. **多语言**：Settings tab 切换 → 所有 tab 标签 / 事件卡文案 / 横幅瞬时切换
5. **Bridge API tab**：curl 示例可 copy；端点表显示当前 port / 脱敏 token
6. **回归**：原 `OpenVibbleApp`（iOS）和手动测试面板（Test Panel tab）无回归

## 非目标

- PostToolUse、SessionStart/End、SubagentStop、PreCompact 事件
- Hook 去重 / 节流（PostToolUse 才需要，v1 不做）
- 多 session 并发审批队列
- Cursor 原生集成（协议已文档化，用户可手接）
- 用户可配置超时时长（固定 30s）
- 自动重启 HookBridge（绑端口失败就显示错误，让用户重启 app）
