# Codex-Claude 协作 Skill

这是一个给 Codex 使用的双智能体协作 skill：Codex 负责规划、调用、审查和控制循环，Claude 通过 `claude -p` 非交互模式负责按计划执行代码修改。

核心目标不是让两个模型自由聊天，而是把协作过程变成可审计、可复盘、可迭代的工程流程。

## 工作方式

```text
用户提出需求
  -> Codex 分析目标项目
  -> Codex 写入 task/requests/<request-id>/plan.md
  -> Codex 组装 Claude 上下文
  -> Codex 调用 claude -p
  -> Claude 按计划改代码并写 execution.md
  -> Codex 审查代码、报告、测试和 UI 证据
  -> PASS 或 REVISE
```

默认最多循环 `config.json` 里的 `maxIterations` 次。通过后 Codex 返回结果；如果多轮仍不通过，会提示用户介入。

## 角色分工

| Codex | Claude |
|---|---|
| 分析需求 | 按计划执行 |
| 编写计划 | 修改代码 |
| 调用 Claude | 运行验证 |
| 审查 diff 和报告 | 写执行报告 |
| 审查 UI 截图 | 不自行扩大范围 |
| 控制 PASS / REVISE 循环 | 遇到阻塞如实说明 |

## 什么时候使用

适合这些场景：

- 你明确想让 Codex 做“大脑”、Claude 做“手”。
- 你想用双智能体循环完成一个代码任务。
- 你想保留完整的计划、执行、审查记录。
- 你想让 Claude 执行，但由 Codex 控制范围和验收。

不适合这些场景：

- 普通问答。
- 简单代码修改。
- 只想用 Codex 单独完成任务。
- 不希望项目里生成 `task/` 记录。

本 skill 默认是显式触发，不会因为普通代码需求自动启用。

## 如何调用

在 Codex 里明确说类似下面的话：

```text
调用 Codex-Claude 协作 skill，帮我实现这个需求：...
```

或者：

```text
使用 codex-claude-orchestrator，让 Codex 规划和审查，Claude 执行。
```

如果你只想让 Codex 单独工作，不要提“协作 skill”即可。

## 目录结构

```text
.
├─ SKILL.md                 # Codex skill 入口说明
├─ AGENT.md                 # Codex 作为大脑的工作协议
├─ CLAUDE.md                # Claude 作为执行者的工作协议
├─ DESIGN.md                # 架构设计说明
├─ config.json              # 协作流程配置
├─ agents/
│  └─ openai.yaml           # Codex skill 展示和触发元信息
├─ scripts/
│  ├─ new-request.ps1       # 创建一次新的需求记录
│  ├─ invoke-claude.ps1     # 组装上下文并调用 claude -p
│  └─ capture-ui.ps1        # 捕获 UI 截图用于审查
└─ demo/
   ├─ index.html            # 静态演示页面
   ├─ styles.css            # 演示页面样式
   └─ script.js             # 演示页面交互
```

运行协作任务时，目标项目里会生成：

```text
task/
├─ CURRENT.md
└─ requests/
   └─ <request-id>/
      ├─ request.md
      ├─ plan.md
      ├─ context.md
      ├─ execution.md
      ├─ review.md
      ├─ artifacts/
      └─ history/
```

`task/` 是运行记录，默认不作为 skill 源码上传。

## 配置说明

主要配置在 `config.json`：

```json
{
  "maxIterations": 10,
  "interactionLanguage": "en-US",
  "reportLanguage": "en-US",
  "userFacingLanguage": "zh-CN",
  "activationMode": "explicit",
  "runtimeMode": "skill-contained",
  "taskStorage": "project",
  "taskDirectory": "task"
}
```

常用项：

- `maxIterations`：最多循环轮数。
- `interactionLanguage`：Codex 写给 Claude 的计划和上下文语言。
- `reportLanguage`：执行报告、审查记录语言。
- `userFacingLanguage`：Codex 最终回复用户的语言。
- `activationMode`：触发模式，默认 `explicit`，表示只在用户明确要求时启用。
- `runtimeMode`：当前为 `skill-contained`，表示脚本和协议文件保留在 skill 内，不复制到目标项目。
- `taskStorage`：当前为 `project`，表示任务记录写入目标项目。

如果你希望 task 报告也用中文，可以把：

```json
"reportLanguage": "zh-CN"
```

如果你希望 Codex 和 Claude 的交互也用中文，可以把：

```json
"interactionLanguage": "zh-CN"
```

## 环境要求

- PowerShell。
- 已安装可用的 `claude` 命令。
- `claude -p` 支持非交互调用。
- 如果要做 UI 截图审查，需要 Chrome 或 Edge。
- `capture-ui.ps1` 使用浏览器调试接口，不要求 Python Playwright。

如果你的 `claude` 命令底层接的是 DeepSeek，只要命令行接口兼容 `claude -p`，仍然可以使用。

## Demo

`demo/` 里包含一个静态网页，用来展示这个协作 skill 的理念和交互效果。

可以直接打开：

```text
demo/index.html
```

这个 demo 不需要启动开发服务器。

## 设计原则

- Codex 不直接把任务交给 Claude 自由发挥，而是先写精确计划。
- Claude 只能按计划修改允许范围内的文件。
- 每一轮都要留下计划、上下文、执行报告、审查记录。
- 审查第一行必须是 `PASS` 或 `REVISE`。
- UI 类任务需要尽量提供截图或可视化证据。
- 目标项目不需要复制本 skill 的脚本和配置，只保存 `task/` 运行记录。

## 注意事项

- 这个 skill 不会自动上传代码到 GitHub。
- 这个 skill 不会自动提交、重置或丢弃你的 Git 改动。
- 如果目标项目不是 Git 仓库，Codex 会通过文件读取、时间戳和执行报告审查，不能依赖 `git diff`。
- 如果 Claude 没有按计划执行，Codex 会给出 `REVISE` 并进入下一轮。

