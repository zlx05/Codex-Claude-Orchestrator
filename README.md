# Codex-Claude 双向协作编排器

一个支持双向双智能体协作的 skill：

- **在 Codex 中使用**：Codex 做”大脑”，负责分析、规划、调用、审查和控制循环；Claude 做”手”，通过 `claude -p` 非交互模式按计划执行代码修改。
- **在 Claude 中使用**：Claude 做”大脑”，负责分析、规划、调用、审查和控制循环；Codex 做”手”，通过 `codex exec` 非交互模式按计划执行代码修改。

哪个界面发起，哪个就是大脑。Codex 用户用 Codex 主导；Claude 用户用 Claude 主导。

这个仓库现在采用标准发布结构：仓库根目录用于 GitHub 展示、许可证和 demo，真正可安装的 skill 位于 [`codex-claude-orchestrator/`](codex-claude-orchestrator/)。

## 快速安装

在 Codex 中安装这个 skill 时，请安装子目录：

```text
https://github.com/zlx05/Codex-Claude-Orchestrator/tree/main/codex-claude-orchestrator
```

不要把整个仓库根目录当成 skill 安装。仓库根目录没有 `SKILL.md`，只包含 GitHub 说明、许可证、demo 和真正的 skill 子目录；如果安装根目录，Codex 通常无法把它识别成一个可用 skill，或者会把 README、demo 等展示文件一起复制到 skills 目录里，造成结构混乱。

正确安装目标永远是：

```text
codex-claude-orchestrator/
```

也可以手动下载后，把 `codex-claude-orchestrator/` 文件夹放到 Codex skills 目录：

```powershell
git clone https://github.com/zlx05/Codex-Claude-Orchestrator.git
Copy-Item -Recurse .\Codex-Claude-Orchestrator\codex-claude-orchestrator "$env:USERPROFILE\.codex\skills\codex-claude-orchestrator"
```

安装后重启 Codex，让它重新加载 skill。

## 双向协作

这个 skill 的核心特点是**双向**：你从哪个 AI 工具发起，哪个工具就是”大脑”。

| 发起方式 | 大脑（规划/审查） | 手（执行/验证） | 调用命令 |
|---|---|---|---|
| 在 Codex 中说 | Codex | Claude | `claude -p` |
| 在 Claude 中说 | Claude | Codex | `codex exec` |

两种模式使用相同的 task 记录结构、相同的 PASS/REVISE 审查标准、相同的配置。

## 如何调用

这个 skill 默认不会自动触发。你需要明确说：

**在 Codex 中：**

```text
调用 Codex-Claude 协作 skill，帮我实现这个需求：...
```

或者：

```text
使用 codex-claude-orchestrator，让 Codex 规划和审查，Claude 执行。
```

**在 Claude 中：**

Claude 不会自动加载 Codex 的 `SKILL.md`。在 Claude 对话框或 Claude Code 里使用反向模式时，把这个仓库下载到本地，然后让 Claude 读取：

```text
codex-claude-orchestrator/CLAUDE-ORCHESTRATOR.md
```

可以这样说：

```text
请读取 codex-claude-orchestrator/CLAUDE-ORCHESTRATOR.md，并按里面的 Claude 主导流程，让 Claude 规划、Codex 执行：...
```

或者：

```text
使用 codex-claude-orchestrator/CLAUDE-ORCHESTRATOR.md，运行双向 PASS/REVISE 循环，Claude 做大脑。
```

注意：正常情况下不需要手动配置 CLI 路径。`invoke-codex.ps1` 和 `invoke-claude.ps1` 会先查找当前终端里的命令，再自动扫描常见 VS Code / VS Code Insiders 扩展目录，例如 OpenAI ChatGPT 扩展自带的 `codex.exe`。

如果你只想让当前 AI 单独工作，不要提”协作 skill”即可。

## 工作方式

### Codex 主导模式（在 Codex 中使用）

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

### Claude 主导模式（在 Claude 中使用）

```text
用户提出需求
  -> Claude 分析目标项目
  -> Claude 写入 task/requests/<request-id>/plan.md
  -> Claude 组装 Codex 上下文
  -> Claude 调用 codex exec
  -> Codex 按计划改代码并写 execution.md
  -> Claude 审查代码、报告、测试和 UI 证据
  -> PASS 或 REVISE
```

默认最多循环 `config.json` 里的 `maxIterations` 次。通过后大脑返回结果；如果多轮仍不通过，会提示用户介入。

## 角色分工

### Codex 主导模式

| Codex（大脑） | Claude（手） |
|---|---|
| 分析需求 | 按计划执行 |
| 编写计划 | 修改代码 |
| 调用 Claude | 运行验证 |
| 审查 diff 和报告 | 写执行报告 |
| 审查 UI 截图 | 不自行扩大范围 |
| 控制 PASS / REVISE 循环 | 遇到阻塞如实说明 |

### Claude 主导模式

| Claude（大脑） | Codex（手） |
|---|---|
| 分析需求 | 按计划执行 |
| 编写计划 | 修改代码 |
| 调用 Codex | 运行验证 |
| 审查 diff 和报告 | 写执行报告 |
| 审查 UI 截图 | 不自行扩大范围 |
| 控制 PASS / REVISE 循环 | 遇到阻塞如实说明 |

## 适合场景

- 你想用双智能体循环完成一个代码任务。
- 你想保留完整的计划、执行、审查记录。
- 你想让 AI A 控制范围和验收，让 AI B 执行。
- 你在 Codex 中想让 Claude 写代码，但由 Codex 把关。
- 你在 Claude 中想让 Codex 写代码，但由 Claude 把关。

不适合：

- 普通问答。
- 简单代码修改。
- 只想用单个 AI 单独完成任务。
- 不希望项目里生成 `task/` 记录。

## 仓库结构

```text
.
├─ README.md
├─ LICENSE
├─ demo/
│  └─ index.html
└─ codex-claude-orchestrator/
   ├─ SKILL.md
   ├─ AGENT.md
   ├─ CLAUDE.md
   ├─ CLAUDE-ORCHESTRATOR.md
   ├─ CODEX.md
   ├─ DESIGN.md
   ├─ config.json
   ├─ agents/
   │  └─ openai.yaml
   └─ scripts/
      ├─ new-request.ps1
      ├─ invoke-claude.ps1
      ├─ invoke-codex.ps1
      └─ capture-ui.ps1
```

其中：

- `README.md`：GitHub 首页中文说明。
- `LICENSE`：开源许可证。
- `demo/`：展示这个协作 skill 的单文件静态宣传页。
- `codex-claude-orchestrator/`：真正的 Codex skill，可安装部分。

## Skill 内部文件

- `SKILL.md`：Skill 入口，根据宿主界面自动选择 Codex 主导或 Claude 主导模式。
- `AGENT.md`：Codex 作为”大脑”的工作协议（Codex 主导模式）。
- `CLAUDE.md`：Claude 作为执行者的工作协议（Codex 主导模式）。
- `CLAUDE-ORCHESTRATOR.md`：Claude 作为”大脑”的工作协议（Claude 主导模式）。
- `CODEX.md`：Codex 作为执行者的工作协议（Claude 主导模式）。
- `DESIGN.md`：架构设计说明，含双向循环。
- `config.json`：语言、轮数、task 存储、双向模式等配置。
- `agents/openai.yaml`：Codex 展示和触发元信息。
- `scripts/new-request.ps1`：创建一次新的需求记录。
- `scripts/invoke-claude.ps1`：组装上下文并调用 `claude -p`（Codex 主导模式）。
- `scripts/invoke-codex.ps1`：组装上下文并调用 `codex exec`（Claude 主导模式）。
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
  "taskDirectory": "task",
  "supportedModes": ["codex-led", "claude-led"],
  "defaultModeByHost": {
    "codex": "codex-led",
    "claude": "claude-led"
  },
  "codexCommand": "codex",
  "claudeCommand": "claude"
}
```

常用项：

- `maxIterations`：最多循环轮数。
- `interactionLanguage`：大脑写给执行者的计划和上下文语言。
- `reportLanguage`：执行报告、审查记录语言。
- `userFacingLanguage`：大脑最终回复用户的语言。
- `activationMode`：触发模式，默认 `explicit`，表示只在用户明确要求时启用。
- `runtimeMode`：当前为 `skill-contained`，表示脚本和协议文件保留在 skill 内，不复制到目标项目。
- `taskStorage`：当前为 `project`，表示任务记录写入目标项目。
- `supportedModes`：支持的双向模式列表。`codex-led` 和 `claude-led`。
- `defaultModeByHost`：按宿主自动选择模式。Codex 宿主默认 Codex 主导，Claude 宿主默认 Claude 主导。
- `codexCommand` / `claudeCommand`：可自定义的 CLI 命令路径。

如果你希望 task 报告用中文，可以把：

```json
"reportLanguage": "zh-CN"
```

如果你希望大脑和执行者的交互也用中文，可以把：

```json
"interactionLanguage": "zh-CN"
```

## 环境要求

- PowerShell。
- VS Code / VS Code Insiders 里已经可用 Codex 和 Claude，或本机已经安装对应 CLI。
- 调用脚本会自动解析 `codex` / `claude` 命令；普通用户通常不需要配置路径。
- 如果要做 UI 截图审查，需要 Chrome 或 Edge。
- `capture-ui.ps1` 使用浏览器调试接口，不要求 Python Playwright。

如果你的 `claude` 命令底层接的是 DeepSeek，只要命令行接口兼容 `claude -p`，仍然可以使用。

### 自动发现失败时怎么办

少数环境里，VS Code 扩展目录不在默认位置，或者 CLI 安装方式比较特殊。这时先在当前终端测试：

```powershell
codex --help
codex exec --help
claude --help
```

如果仍然找不到，才需要任选一种 fallback：

1. 重启 VS Code / Claude Code，让终端重新加载环境。
2. 在 `codex-claude-orchestrator/config.json` 里填写完整路径，例如：

```json
"codexCommand": "C:\\Users\\你的用户名\\.vscode\\extensions\\openai.chatgpt-xxx\\bin\\windows-x86_64\\codex.exe"
```

3. 临时指定环境变量：

```powershell
$env:CODEX_COMMAND = "C:\path\to\codex.exe"
```

这只是少数情况下的兜底。默认体验应该是：用户装好 VS Code 里的 Codex / Claude，然后直接调用协作 skill。

## Demo

`demo/` 里包含一个单文件静态网页，用来展示这个协作 skill 的痛点、流程、轮次机制和下载地址。

可以直接打开：

```text
demo/index.html
```

这个 demo 不需要启动开发服务器，也可以部署到 GitHub Pages 或任意静态托管服务。

## 注意事项

- 这个 skill 不会自动上传代码到 GitHub。
- 这个 skill 不会自动提交、重置或丢弃你的 Git 改动。
- 如果目标项目不是 Git 仓库，大脑会通过文件读取、时间戳和执行报告审查，不能依赖 `git diff`。
- 如果执行者没有按计划执行，大脑会给出 `REVISE` 并进入下一轮。
- 不要在仓库根目录安装这个 skill，只安装 `codex-claude-orchestrator/` 子目录。

