# SKILL 候选清单 — Top 3

> 基于项目扫描，按「频率高 × 痛点深 × 自动化收益大」排序。

---

## 1. local-ci-precheck

**Name:** `local-ci-precheck`

**Description:** 在提 PR 前本地跑完整 CI 预检流水线（format-check → checkstyle → lint → test → build），一次性发现问题，避免 CI 打回。每步只报告失败原因和修复命令，不自动修。

**Frequency:** 每次提 PR（日均 2-5 次）

**Pain:** CI 被打回 → 等 5-10 分钟 → 改一行 → 再等 5-10 分钟。一个格式问题可能浪费半小时。

**Automation Value:** 把 CI 的 4 阶段串行检查搬到本地并行跑，失败即时反馈，省掉每次 CI 排队等待。

**Steps:**
1. 检测当前分支和未提交变更（`git status`, `git diff --name-only`）
2. 如果有变更文件，只对变更范围做增量检查；否则全量
3. 并行跑 `make format-check`、`make checkstyle-check`、`make lint`
4. 如果前三步全绿，跑 `make test`
5. 如果测试全绿，跑 `make build`
6. 生成报告：通过/失败的步骤、失败原因、修复命令
7. 如果全部通过，输出"可以提 PR 了"

**Allowed Tools:** `Bash`, `Read`, `Grep`, `Glob`

**Triggers:** 用户说"跑一下 CI"、"提 PR 前检查"、"precheck"

---

## 2. lint-fix-guide

**Name:** `lint-fix-guide`

**Description:** CI 挂了时，自动诊断是哪种 linter 失败，给出对应的修复命令和具体失败文件/行号。不直接改代码，而是告诉用户跑什么命令能修。

**Frequency:** CI 失败时（每周 3-5 次）

**Pain:** CI 报错信息分散在多个 job 日志里，开发者需要自己判断是 format、checkstyle、codespell 还是 license 问题，然后找对应的 `make xxx-fix` 命令。

**Automation Value:** 把"看 CI 日志 → 判断 linter 类型 → 找修复命令"这个 3 步手动流程变成一步自动诊断。

**Steps:**
1. 读取 CI 失败日志（用户粘贴或从 git log/gh CLI 获取）
2. 匹配失败模式：
   - `spring-javaformat` → format 问题 → `make format-fix`
   - `checkstyle` → style 问题 → `make spotless-apply` + 手动修
   - `codespell` → 拼写问题 → 修对应文件
   - `license-eye` → license header → `make licenses-fix`
   - `yamllint` → YAML 格式 → `make yaml-lint-fix`
   - `gitleaks` → 密钥泄露 → 移除密钥
3. 输出：linter 类型、失败文件列表、修复命令、是否可自动修复
4. 如果用户确认，执行修复命令

**Allowed Tools:** `Bash`, `Read`, `Grep`, `Glob`

**Triggers:** 用户说"CI 挂了"、"lint 报错"、"帮我看看 CI"

---

## 3. model-switch

**Name:** `model-switch`

**Description:** 一键切换 AI 模型提供商（DashScope / DeepSeek / OpenAI），自动从模板 YAML 生成 model-config.yaml，设置环境变量，验证连通性。

**Frequency:** 每次切换模型测试（每周 2-3 次）

**Pain:** 手动复制模板 → 替换 API Key → 改 baseUrl → 改 modelName → 重启应用。步骤多容易漏，尤其是忘记设环境变量导致启动报错。

**Automation Value:** 把 5 步手动配置变成 1 步命令，附带连通性验证，消除配置遗漏。

**Steps:**
1. 列出可用的模型提供商模板（`model-config-dashscope.yaml`、`model-config-deepseek.yaml`、`model-config-openai.yaml`）
2. 用户选择提供商（或从参数获取）
3. 检查对应环境变量是否已设置（`DASHSCOPE_API_KEY` / `DEEPSEEK_API_KEY` / `OPENAI_API_KEY`）
4. 如果未设置，提示用户设置
5. 从模板生成 `model-config.yaml`，替换 API Key 占位符为环境变量引用
6. 验证：检查 YAML 语法、检查 baseUrl 可达（curl health check）
7. 输出：当前配置摘要、启动命令

**Allowed Tools:** `Bash`, `Read`, `Write`, `Grep`, `Glob`

**Triggers:** 用户说"切模型"、"用 DeepSeek"、"换 OpenAI"、"model switch"

---

## 总结

| # | Name | 类型 | 频率 | 痛点 | 自动化收益 | 理由 |
|---|------|------|------|------|-----------|------|
| 1 | `local-ci-precheck` | 预防型 | 日均 2-5 次 | CI 打回等 10 分钟 | 高 — 本地秒级反馈 | 频率最高，每次提 PR 都用，省掉 CI 排队 |
| 2 | `lint-fix-guide` | 诊断型 | 每周 3-5 次 | CI 日志分散难定位 | 中 — 自动匹配修复命令 | 痛点深，CI 失败时最焦虑，诊断链路长 |
| 3 | `model-switch` | 配置型 | 每周 2-3 次 | 手动 5 步容易漏 | 高 — 一步完成+验证 | 配置错误导致启动失败，排查成本高 |
