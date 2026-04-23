# iOS 多会话管理 — 设计稿

2026-04-23

## 背景

用户反馈 iOS 端 `HomeLogSheet` 的 RUN tab 把来自多个 Claude 会话（不同项目）的消息混在一起，需要做分组。

## 约束

- **协议不改**：`HeartbeatSnapshot.entries` 仍是 `[String]`，没有 session id。
- **UI 风格保持 TerminalStyle**：和当前 RUN/BLE 胶囊 tab 一脉相承。
- **改动范围最小**：只改主屏 INFO 模式的 CLAUDE 子页，其它页/模式不动。

## 关键洞察

Desktop 侧 [AppState.swift:618-627](../../../OpenVibbleDesktop/AppState.swift) 保证了 entries 的格式：

```
HH:mm:ss event [project] tool
```

`[project]` 是稳定的文本约定，等价于 iOS 视角下的"会话分组 key"。同一个项目多次调用 Claude 会归到同一组。

## 架构

**改动点**：只动 INFO 模式的 CLAUDE 页（[HomeScreen.swift:1313-1319](../../../OpenVibbleApp/Home/HomeScreen.swift)）。

| 层 | 改动 |
|---|---|
| 协议 | 零 |
| Desktop | 零 |
| iOS 新文件 `Shared/ProjectEntryParser.swift` | 纯函数，把 `[String]` 解析为 `[ParsedEntry]` |
| iOS `BridgeAppModel` | 新增计算属性 `projects: [ProjectSummary]` |
| iOS 新文件 `Home/ClaudeSessionsView.swift` | CLAUDE 页的新子视图 |
| iOS `HomeScreen.InfoBody` | CLAUDE 分支替换为 `ClaudeSessionsView` |

不做持久化，不改 Live Activity，不做通知分组。

## 数据模型

```swift
struct ParsedEntry: Equatable {
    let raw: String
    let time: String           // "HH:mm:ss"
    let event: String          // "SessionStart" / "PermissionRequest" / ...
    let project: String?       // [project] 捕获，可能 nil
    let detail: String?        // 剩余（如 tool 名）
}

struct ProjectSummary: Equatable {
    let name: String
    let entries: [ParsedEntry]     // 只属于该 project
    let isActive: Bool
    let hasPendingPrompt: Bool
}
```

**解析正则**：`^(\S+)\s+(\S+)(?:\s+\[([^\]]+)\])?(?:\s+(.+))?$`

**`projects` 派生**：从 `parsedEntries` 过滤出带 `project` 的，按 name 分桶，计算活跃状态。

**Prompt 归属**：当 `prompt != nil` 时，扫 parsedEntries 找最近的 `event == "PermissionRequest"`，取其 project。找不到 → ALL。

**排序**（ALL 钉最左不参与）：
1. `hasPendingPrompt` 优先
2. `isActive` 次之
3. 其余按最新出现位置倒序

**isActive 定义**：最近一条该项目事件的 `event ∈ { SessionStart, UserPromptSubmit, PermissionRequest }` 且之后未见 `{ Stop, SessionEnd }`。

## UI 布局

CLAUDE 页新结构（替换当前的 5 行 pair）：

```
┌─ INFO · CLAUDE ─────────────────── 3/6 ┐
│  CLAUDE                                │
│  ─────────────────────                 │
│  [ ALL ] [ openvibble 1 ] [ bridge ・] │  ← 横滑 胶囊
│  ─────────────────────                 │
│  选中 ALL：                             │
│    sessions    3                       │
│    running     1                       │
│    waiting     1                       │
│    state       thinking                │
│    tok/day     1234                    │
│  选中某 project：                       │
│    status      running                 │
│    prompt      PermissionRequest Bash  │
│    ─── recent ───                      │
│    10:42 PermissionRequest Bash        │
│    10:41 UserPromptSubmit              │
│    10:40 SessionStart                  │
└────────────────────────────────────────┘
```

- 胶囊高度/字号沿用 [HomeScreen.swift:1681-1703](../../../OpenVibbleApp/Home/HomeScreen.swift) 的样式
- `ScrollView(.horizontal, showsIndicators: false)` 包 HStack
- 胶囊右侧 badge：`N`（pending prompt 数，0 省略）、`・`（running 指示，对齐 `BreathingLED` 风格）

**水平滑动手势**：现有 INFO 页是左右滑翻页（ABOUT→BUTTONS→…→CREDITS）。需要让胶囊条的横滑**只吃胶囊区域的手势**，不让它触发 page 翻页。`ScrollView` 自然会截断手势，但要验证。

**空态**：若 `projects` 为空（只收到设备原生 entries），只显示 ALL 胶囊，内容同现在，不做额外处理。

## 数据流

```
heartbeat → BridgeRuntime.ingestLine
          → BridgeAppModel.parsedEntries 更新
          → projects 计算属性自动重算（SwiftUI 观察）
          → ClaudeSessionsView 重绘
```

无额外 `@Published`，无新 store，无持久化。

## 测试策略

**单测**（Swift Package `OpenVibbleKit` 里）：
- `ProjectEntryParserTests`：
  - 标准格式 → 字段齐全
  - 设备原生 entries（`"10:42 git push"`）→ `project == nil`
  - 不带 tool → `detail == nil`
  - 奇异 `[]` 里含空格 → 按贪婪匹配，承认
- `ProjectSummaryBuilderTests`（在 iOS target 内，因为需要访问 model 逻辑）：
  - 多项目 → 分桶正确
  - isActive 的三种典型序列：start→running, start→stop 后不活跃, permission 后不活跃
  - prompt 归属推导：最近 PermissionRequest 的 project
  - 排序：pending > active > recent

**UI 不写 snapshot 测试**（项目没有该基础设施，TerminalStyle 主观）。手动验收在 simulator + 真机。

## 非目标（YAGNI）

- 跨 app 重启的历史持久化
- 会话未读计数的持久化
- 项目级通知分组
- 长按胶囊的 clear/hide 项目
- 搜索、过滤

## 分阶段实施 + 增量 commit

1. `Phase 1`：新增 `ProjectEntryParser` + 单测。独立 commit。
2. `Phase 2`：`BridgeAppModel.projects` 计算 + 单测。独立 commit。
3. `Phase 3`：`ClaudeSessionsView`（胶囊条 + ALL 视图）。独立 commit。
4. `Phase 4`：项目详情视图（选中胶囊后的内容）。独立 commit。
5. `Phase 5`：接入 `InfoBody.CLAUDE` 分支 + 本地化字符串。独立 commit。

每个 Phase 落地可跑，然后再下一个。

## 承认的局限

1. 历史只有 ~200 行滑动窗口（Desktop 侧本来就只缓存 20 行）。
2. `isActive` 是启发式：若 Stop 行被挤出窗口，会误判为活跃。
3. entries 只有 `HH:mm:ss` 不带日期，跨天活动会同桶。
4. 同一项目的多次独立 Claude 会话会揉在一起（没 session id，无法区分）。
