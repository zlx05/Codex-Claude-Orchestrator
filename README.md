# Codex-Claude Orchestrator

一个用于 Codex 的双智能体协作 skill：Codex 做“大脑”，负责分析、规划、调用、审查和控制循环；Claude 做“手”，通过 `claude -p` 非交互模式按计划执行代码修改。

这个仓库现在采用标准发布结构：仓库根目录用于 GitHub 展示、许可证和 demo，真正可安装的 skill 位于 [`codex-claude-orchestrator/`](codex-claude-orchestrator/)。

## 快速安装

在 Codex 中安装这个 skill 时，请安装子目录：

```text
https://github.com/zlx05/Codex-Claude-Orchestrator/tree/main/codex-claude-orchestrator
```

也可以手动下载后，把 `codex-claude-orchestrator/` 文件夹放到 Codex skills 目录：

```powershell
git clone https://github.com/zlx05/Codex-Claude-Orchestrator.git
Copy-Item -Recurse .\Codex-Claude-Orchestrator\codex-claude-orchestrator "$env:USERPROFILE\.codex\skills\codex-claude-orchestrator"
```

安装后重启 Codex，让它重新加载 skill。

## 如何调用

这个 skill 默认不会自动触发。你需要明确说：

```text
调用 Codex-Claude 协作 skill，帮我实现这个需求：...
```

或者：

```text
使用 codex-claude-orchestrator，让 Codex 规划和审查，Claude 执行。
```

如果你只想让 Codex 单独工作，不要提“协作 skill”即可。

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

## 适合场景

- 你明确想让 Codex 做“大脑”、Claude 做“手”。
- 你想用双智能体循环完成一个代码任务。
- 你想保留完整的计划、执行、审查记录。
- 你想让 Claude 执行，但由 Codex 控制范围和验收。

不适合：

- 普通问答。
- 简单代码修改。
- 只想用 Codex 单独完成任务。
- 不希望项目里生成 `task/` 记录。

## 仓库结构

```text
.
├─ README.md
├─ LICENSE
├─ demo/
│  ├─ index.html
│  ├─ styles.css
│  └─ script.js
└─ codex-claude-orchestrator/
   ├─ SKILL.md
   ├─ AGENT.md
   ├─ CLAUDE.md
   ├─ DESIGN.md
   ├─ config.json
   ├─ agents/
   │  └─ openai.yaml
   └─ scripts/
      ├─ new-request.ps1
      ├─ invoke-claude.ps1
      └─ capture-ui.ps1
```

其中：

- `README.md`：GitHub 首页中文说明。
- `LICENSE`：开源许可证。
- `demo/`：展示这个协作 skill 的静态网页。
- `codex-claude-orchestrator/`：真正的 Codex skill，可安装部分。

## Skill 内部文件

- `SKILL.md`：Codex skill 入口，定义触发方式和主流程。
- `AGENT.md`：Codex 作为“大脑”的工作协议。
- `CLAUDE.md`：Claude 作为执行者的工作协议。
- `DESIGN.md`：架构设计说明。
- `config.json`：语言、轮数、task 存储等配置。
- `agents/openai.yaml`：Codex 展示和触发元信息。
- `scripts/new-request.ps1`：创建一次新的需求记录。
- `scripts/invoke-claude.ps1`：组装上下文并调用 `claude -p`。
- `scripts/capture-ui.ps1`：通过 Chrome 或 Edge 捕获 UI 截图。

## 运行记录

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

## 配置语言

主要配置在 `codex-claude-orchestrator/config.json`：

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

如果你希望 task 报告用中文，可以把：

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

## 注意事项

- 这个 skill 不会自动上传代码到 GitHub。
- 这个 skill 不会自动提交、重置或丢弃你的 Git 改动。
- 如果目标项目不是 Git 仓库，Codex 会通过文件读取、时间戳和执行报告审查，不能依赖 `git diff`。
- 如果 Claude 没有按计划执行，Codex 会给出 `REVISE` 并进入下一轮。

