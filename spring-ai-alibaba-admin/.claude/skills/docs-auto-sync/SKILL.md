---
name: docs-auto-sync
description: >
  检测文档与代码的漂移。扫描 Controller、Entity、SQL Schema，
  与 api-list.md、data-model.md、CLAUDE.md 交叉比对，报告不一致。
  只读不写，只报告不修正。
allowed-tools:
  - Read
  - Grep
---

# docs-auto-sync — 文档漂移检测

## 触发条件

用户说出以下意图时触发：

- "文档跟代码对得上吗" / "检查文档是否过期"
- "API 文档需要更新吗" / "接口清单准不准"
- "数据模型文档有没有漏" / "表结构文档过期了吗"
- PR review 时想确认文档是否跟上了代码变更

## 项目约定

本项目的关键文档与代码的映射关系：

| 文档 | 对应代码 | 位置 |
|------|----------|------|
| `docs/api-list.md` | Controller 类 | `spring-ai-alibaba-admin-server-start/src/main/java/.../controller/` |
| `docs/data-model.md` | Entity 类 + SQL | `.../entity/*DO.java` + `docker/middleware/init/mysql/*.sql` |
| `CLAUDE.md` | pom.xml 版本 | 根 `pom.xml` + admin `pom.xml` |

**命名约定**：
- Entity 类名格式：`{Name}DO.java`（如 `PromptDO.java`、`DatasetDO.java`）
- Controller 类名格式：`{Name}Controller.java`
- Request DTO：`{Name}Request.java`
- Response DTO：`{Name}Response.java`
- SQL 文件：`admin-schema.sql`（评估业务）+ `agentscope-schema.sql`（平台基础）

**Controller 包路径**（两个位置）：
- `.../admin/controller/` — 核心业务 Controller
- `.../admin/builder/controller/` — 平台基础 Controller

---

## 执行步骤

### Step 1：确定扫描范围

如果有 git 变更，只扫描变更文件；否则全量扫描。

```bash
# 检查最近变更
git diff --name-only HEAD~5...HEAD -- '*.java' '*.sql' '*.xml'

# 检查未提交变更
git diff --name-only
git diff --cached --name-only
```

将变更文件分类：
- `*Controller.java` → 进入 API 检查
- `*DO.java` / `*Entity.java` → 进入 Entity 检查
- `*.sql` → 进入 SQL 检查
- `pom.xml` → 进入版本检查

如果没有变更文件，执行全量扫描。

---

### Step 2：扫描 Controller → 比对 api-list.md

对每个 Controller 文件：

1. 用 `Grep` 提取类级别 `@RequestMapping` 得到路径前缀
2. 用 `Grep` 提取所有 `@GetMapping`、`@PostMapping`、`@PutMapping`、`@DeleteMapping`、`@PatchMapping`
3. 用 `Read` 读取方法签名，提取参数类型（`@RequestBody`、`@RequestParam`、`@PathVariable`）和返回类型
4. 用 `Read` 读取 `docs/api-list.md`，找到对应 Controller 的章节
5. 逐条比对

**比对清单**：

| 检查项 | 代码中有 → 文档没有 | 文档有 → 代码没有 | 不一致 |
|--------|:---:|:---:|:---:|
| 接口路径 | ⚠️ 缺失 | ⚠️ 幽灵接口 | — |
| HTTP 方法 | — | — | ⚠️ 方法不对 |
| 路径前缀 | — | — | ⚠️ 前缀不对 |
| 参数列表 | ⚠️ 缺参数 | — | ⚠️ 参数类型不对 |
| 返回类型 | — | — | ⚠️ 类型不对 |

**项目特定规则**：
- 管理接口前缀 `/console/v1/*` vs 核心业务前缀 `/api/*` vs OpenAPI `/api/v1/apps/*`
- 如果 Controller 有 `@RequestMapping` 但 api-list.md 中找不到对应模块，标记为 HIGH

---

### Step 3：扫描 Entity → 比对 data-model.md

对每个 `*DO.java` 文件：

1. 用 `Read` 读取 Entity 源码
2. 用 `Grep` 提取 `@Table(name = "...")` 得到表名
3. 用 `Grep` 提取所有 `private` 字段及其类型
4. 用 `Grep` 提取注解：`@Id`、`@Column`、枚举定义
5. 用 `Read` 读取 `docs/data-model.md`，找到对应表的章节
6. 逐字段比对

**比对清单**：

| 检查项 | 代码中有 → 文档没有 | 文档有 → 代码没有 | 不一致 |
|--------|:---:|:---:|:---:|
| 表名 | ⚠️ 缺失 | ⚠️ 幽灵表 | — |
| 字段名 | ⚠️ 缺字段 | ⚠️ 幽灵字段 | — |
| 字段类型 | — | — | ⚠️ 类型不对 |
| 主键/索引 | ⚠️ 缺约束 | — | — |
| 枚举值 | ⚠️ 缺枚举 | — | — |
| 注释/说明 | — | — | ⚠️ 描述不对 |

**项目特定规则**：
- Entity 用 `@Data @Builder` 注解（Lombok），字段类型来自 Lombok 生成
- `deleted` 字段是逻辑删除标记（0/1）
- JSON 字段用 `LONGTEXT` 存储，应用层解析
- 主表 + 版本表 1:N 模式（prompt → prompt_version, dataset → dataset_version, evaluator → evaluator_version）

---

### Step 4：扫描 SQL → 比对 data-model.md

对 `docker/middleware/init/mysql/` 下的每个 SQL 文件：

1. 用 `Read` 读取 SQL 文件
2. 用 `Grep` 提取 `CREATE TABLE` 语句
3. 解析列名、类型、约束（`PRIMARY KEY`、`UNIQUE KEY`、`FOREIGN KEY`、`NOT NULL`、`DEFAULT`）
4. 解析 `COMMENT` 得到字段说明
5. 与 `docs/data-model.md` 逐表比对

**比对清单**：

| 检查项 | SQL 有 → 文档没有 | 文档有 → SQL 没有 | 不一致 |
|--------|:---:|:---:|:---:|
| 表名 | ⚠️ 缺失 | ⚠️ 幽灵表 | — |
| 列名 | ⚠️ 缺列 | ⚠️ 幽灵列 | — |
| 列类型 | — | — | ⚠️ 类型不匹配 |
| 约束 | ⚠️ 缺约束 | — | — |
| 注释 | — | — | ⚠️ 描述不一致 |

**项目特定规则**：
- 两套 Schema：`admin-schema.sql`（评估业务）+ `agentscope-schema.sql`（平台基础）
- `agentscope-schema.sql` 包含 `INSERT` 语句（初始数据），需要忽略
- `admin-schema.sql` 包含 `DROP TABLE IF EXISTS`，只需关注 `CREATE TABLE`

---

### Step 5：扫描 pom.xml → 比对 CLAUDE.md

1. 用 `Read` 读取根 `pom.xml`，提取 `<properties>` 中的版本号
2. 用 `Read` 读取 admin `pom.xml`，提取版本号
3. 用 `Read` 读取 `CLAUDE.md`，找到版本声明（如 "Spring Boot 3.3.6"）
4. 比对

**关键版本号**：
- `spring-boot.version`
- `spring-ai.version`
- `java.version`
- `lombok.version`
- 其他在 CLAUDE.md 中明确声明的版本

---

### Step 6：交叉完整性检查

检查文档之间的引用完整性：

1. `api-list.md` 中引用的实体类型是否都在 `data-model.md` 中有定义
2. `data-model.md` 中的表是否都在 SQL 文件中有建表语句
3. `CLAUDE.md` 中提到的模块是否都存在于项目中

---

## 输出格式

```markdown
## Docs Sync Report — {日期}

### Summary
- Controllers scanned: {N}
- Endpoints checked: {N}
- Entities checked: {N}
- SQL tables checked: {N}
- Discrepancies found: {N} (HIGH: x, MEDIUM: y, LOW: z)

### HIGH — 代码可能有 bug
| # | 文件:行号 | 接口/表 | 问题 |
|---|-----------|---------|------|
| 1 | DatasetController.java:160 | GET /api/dataset/dataItem | @PathVariable 缺少路径中的 {id} |

### MEDIUM — 文档缺失
| # | 文档文件 | 缺失内容 | 来源 |
|---|----------|----------|------|
| 1 | api-list.md | GET /api/new-endpoint | NewController.java:42 |

### LOW — 描述不一致
| # | 文档文件 | 章节 | 问题 |
|---|----------|------|------|
| 1 | data-model.md | prompt 表 | 文档写 VARCHAR(32)，代码写 VARCHAR(64) |

### 文档覆盖度
| 文档 | 已覆盖 | 实际存在 | 缺失 |
|------|:------:|:--------:|:----:|
| api-list.md | {N} endpoints | {N} endpoints | {N} |
| data-model.md | {N} tables | {N} tables | {N} |
```

---

## 严重级别定义

| 级别 | 定义 | 示例 |
|------|------|------|
| **HIGH** | 代码有 bug 或接口会崩溃 | `@PathVariable` 缺少路径参数、HTTP 方法不对 |
| **MEDIUM** | 文档缺失或误导 | 新接口没写进 api-list.md、新表没写进 data-model.md |
| **LOW** | 描述不一致 | 字段类型文档写的和代码不一样、注释过时 |

---

## 扫描范围

| 范围 | 说明 |
|------|------|
| `full` | 全部 Controller、Entity、SQL、pom.xml |
| `changed` | 仅 git 变更文件（默认，如有变更） |
| `api` | 仅 Controller → api-list.md |
| `data` | 仅 Entity/SQL → data-model.md |
| `single <file>` | 单个文件深度检查 |

---

## 规则

- **只读不写**：不修改任何文件，只输出报告
- **不误报**：不确定的标 "needs review"，不标 "confirmed"
- **具体到行**：每条问题必须带文件路径和行号
- **先 HIGH 后 LOW**：严重问题优先
- **实时读取**：每次都读取文件实际内容，不依赖缓存
