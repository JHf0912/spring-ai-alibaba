# 核心数据模型

> 基于 Entity 类、DTO 和建表 SQL 整理，覆盖 admin-schema（12 张表）和 agentscope-schema（15 张表）。

---

## 0. 平台基础模块（agentscope-schema）

### 0.1 account — 用户账号

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| account_id | VARCHAR(64) | 账号唯一标识 | UK |
| username | VARCHAR(255) | 用户名 | |
| email | VARCHAR(255) | 邮箱 | |
| mobile | VARCHAR(255) | 手机号 | |
| password | VARCHAR(255) | 密码（Argon2 哈希） | |
| nickname | VARCHAR(255) | 昵称 | |
| icon | VARCHAR(255) | 头像 | |
| type | VARCHAR(64) | 账号类型 | 枚举: `basic`, `admin` |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（正常） |
| gmt_create | DATETIME | 创建时间 | |
| gmt_modified | DATETIME | 修改时间 | |
| gmt_last_login | DATETIME | 最后登录时间 | |
| creator | VARCHAR(64) | 创建者 | |
| modifier | VARCHAR(64) | 修改者 | |

### 0.2 workspace — 工作空间

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| workspace_id | VARCHAR(64) | 工作空间唯一标识 | UK |
| account_id | VARCHAR(64) | 所属账号 | FK → account.account_id |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（正常） |
| name | VARCHAR(255) | 名称 | |
| description | VARCHAR(4096) | 描述 | |
| config | TEXT | 配置 | |
| gmt_create | DATETIME | 创建时间 | |
| gmt_modified | DATETIME | 修改时间 | |
| creator / modifier | VARCHAR(64) | 操作者 | |

### 0.3 application — 应用

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| app_id | VARCHAR(64) | 应用唯一标识 | UK |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| name | VARCHAR(255) | 应用名称 | |
| description | VARCHAR(4096) | 描述 | |
| icon | VARCHAR(255) | 图标 | |
| source | VARCHAR(64) | 来源 | |
| type | VARCHAR(64) | 类型 | 枚举: `agent`, `workflow` |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（草稿）, `2`（已发布）, `3`（发布编辑中） |
| gmt_create / gmt_modified | DATETIME | 时间戳 | |
| creator / modifier | VARCHAR(64) | 操作者 | |

### 0.4 application_version — 应用版本

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| app_id | VARCHAR(64) | 所属应用 | FK → application.app_id |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| config | LONGTEXT | 应用配置 | |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（草稿）, `2`（已发布）, `3`（发布编辑中） |
| version | VARCHAR(32) | 版本号 | 默认 `0.0.1` |
| description | VARCHAR(4096) | 版本描述 | |
| gmt_create / gmt_modified | DATETIME | 时间戳 | |

### 0.5 application_component — 应用组件

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| code | VARCHAR(64) | 组件编码 | |
| name | VARCHAR(128) | 组件名称 | |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| type | VARCHAR(64) | 类型 | 枚举: `agent`, `workflow` |
| app_id | VARCHAR(64) | 关联应用 | |
| config | LONGTEXT | 组件配置 | |
| description | VARCHAR(4096) | 描述 | |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（正常）, `2`（已发布） |
| need_update | TINYINT | 是否需要更新 | 枚举: `0`, `1` |

### 0.6 api_key — API 密钥

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| account_id | VARCHAR(64) | 所属账号 | |
| api_key | VARCHAR(512) | API Key 值 | UK |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（正常） |
| description | VARCHAR(4096) | 描述 | |

### 0.7 plugin — 插件

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| plugin_id | VARCHAR(64) | 插件唯一标识 | UK |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| type | VARCHAR(64) | 插件类型 | 枚举: `1`（官方）, `2`（自定义） |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（正常） |
| name | VARCHAR(255) | 插件名称 | |
| description | VARCHAR(4096) | 描述 | |
| config | TEXT | 配置 | |
| source | VARCHAR(64) | 来源 | |

### 0.8 tool — 工具

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| tool_id | VARCHAR(64) | 工具唯一标识 | UK |
| plugin_id | VARCHAR(64) | 所属插件 | FK → plugin.plugin_id |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（正常） |
| enabled | TINYINT | 启用状态 | 枚举: `0`（禁用）, `1`（启用） |
| test_status | TINYINT | 测试状态 | 枚举: `1`（未测试）, `2`（通过）, `3`（失败） |
| name | VARCHAR(255) | 工具名称 | |
| description | VARCHAR(4096) | 描述 | |
| config | LONGTEXT | 工具配置 | |
| api_schema | LONGTEXT | API Schema | |

### 0.9 knowledge_base — 知识库

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| kb_id | VARCHAR(64) | 知识库唯一标识 | UK |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| type | VARCHAR(64) | 类型 | 如 `unstructured` |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（正常） |
| name | VARCHAR(255) | 名称 | |
| description | VARCHAR(4096) | 描述 | |
| process_config | TEXT | 处理配置 | |
| index_config | TEXT | 索引配置 | |
| search_config | TEXT | 搜索配置 | |
| total_docs | BIGINT | 文档总数 | |

### 0.10 document — 文档

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| doc_id | VARCHAR(64) | 文档唯一标识 | UK |
| kb_id | VARCHAR(64) | 所属知识库 | FK → knowledge_base.kb_id |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| type | VARCHAR(64) | 类型 | 枚举: `file`, `url` |
| status | TINYINT | 状态 | 枚举: `0`（删除）, `1`（正常） |
| enabled | TINYINT | 启用状态 | 枚举: `0`（禁用）, `1`（启用） |
| name | VARCHAR(255) | 名称 | |
| format | VARCHAR(64) | 文件格式 | |
| size | BIGINT | 文件大小 | |
| metadata | TEXT | 元数据 | |
| index_status | TINYINT | 索引状态 | 枚举: `1`（待处理）, `2`（处理中）, `3`（完成） |
| path | VARCHAR(512) | 存储路径 | |
| parsed_path | VARCHAR(512) | 解析后路径 | |
| process_config | TEXT | 分块配置 | |
| source | VARCHAR(255) | 来源 | |
| error | TEXT | 错误信息 | |

### 0.11 mcp_server — MCP 服务器

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| server_code | VARCHAR(64) | 服务器编码 | UK |
| name | VARCHAR(64) | 名称 | |
| description | VARCHAR(1024) | 描述 | |
| source | VARCHAR(128) | 来源 | |
| deploy_env | VARCHAR(16) | 部署环境 | 枚举: `local`, `remote` |
| type | VARCHAR(32) | 类型 | 枚举: `OFFICIAL`, `CUSTOMER` |
| deploy_config | TEXT | 部署配置 | |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| account_id | VARCHAR(64) | 所属账号 | |
| status | TINYINT | 状态 | 枚举: `0`（禁用）, `1`（正常）, `3`（删除） |
| biz_type | VARCHAR(512) | 业务类型 | |
| detail_config | TEXT | 详细配置 | |
| host | VARCHAR(1024) | 主机地址 | |
| install_type | VARCHAR(32) | 安装方式 | 枚举: `npx`, `uvx`, `sse` |

### 0.12 agent_schema — Agent 配置

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| agent_id | VARCHAR(64) | Agent 唯一标识 | UK |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| name | VARCHAR(255) | 名称 | |
| description | VARCHAR(4096) | 描述 | |
| type | VARCHAR(64) | Agent 类型 | 枚举: `ReactAgent`, `ParallelAgent`, `SequentialAgent`, `LLMRoutingAgent`, `LoopAgent` |
| instruction | TEXT | 系统指令 | |
| input_keys | TEXT | 输入参数，JSON | |
| output_key | VARCHAR(255) | 输出参数 | |
| handle | LONGTEXT | 处理配置，JSON | |
| sub_agents | LONGTEXT | 子 Agent 配置，JSON | |
| yaml_schema | LONGTEXT | 生成的 YAML Schema | |
| status | VARCHAR(64) | 状态 | 枚举: `DRAFT`, `PUBLISHED`, `ARCHIVED` |
| enabled | TINYINT | 启用状态 | 枚举: `0`（禁用）, `1`（启用） |

### 0.13 provider — 模型提供商

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| name | VARCHAR(255) | 名称 | |
| description | VARCHAR(1024) | 描述 | |
| provider | VARCHAR(255) | 提供商标识 | |
| enable | TINYINT(1) | 启用状态 | 枚举: `0`（禁用）, `1`（启用） |
| source | VARCHAR(64) | 来源 | 枚举: `preset`, `custom` |
| credential | VARCHAR(1024) | 凭证，JSON | |
| supported_model_types | VARCHAR(255) | 支持的模型类型 | |
| protocol | VARCHAR(64) | 协议 | 如 `OpenAI` |

### 0.14 model — 模型

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| workspace_id | VARCHAR(64) | 所属工作空间 | |
| name | VARCHAR(100) | 模型名称 | |
| type | VARCHAR(100) | 模型类型 | 默认 `LLM` |
| mode | VARCHAR(100) | 模式 | 默认 `chat` |
| model_id | VARCHAR(100) | 模型标识 | |
| provider | VARCHAR(100) | 提供商 | |
| enable | TINYINT(1) | 启用状态 | 枚举: `0`（禁用）, `1`（启用） |
| tags | VARCHAR(255) | 标签 | |
| source | VARCHAR(100) | 来源 | 枚举: `preset`, `custom` |

### 0.15 reference — 通用引用关系

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| main_code | VARCHAR(64) | 主实体编码 | |
| main_type | TINYINT | 主实体类型 | |
| refer_code | VARCHAR(64) | 引用实体编码 | |
| refer_type | TINYINT | 引用实体类型 | |
| workspace_id | VARCHAR(64) | 工作空间 | |

---

## 1. Prompt 模块

### 1.1 prompt — Prompt 主表

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| prompt_key | VARCHAR(255) | Prompt 唯一标识 | UK |
| prompt_desc | VARCHAR(255) | 描述 | |
| latest_version | VARCHAR(32) | 最新版本号 | |
| tags | VARCHAR(255) | 标签，逗号分隔 | |
| create_time | DATETIME(3) | 创建时间 | |
| update_time | DATETIME(3) | 更新时间 | |

### 1.2 prompt_version — Prompt 版本

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| prompt_key | VARCHAR(255) | 所属 Prompt | FK → prompt.prompt_key |
| version | VARCHAR(32) | 版本号 | UK (prompt_key + version) |
| version_desc | VARCHAR(255) | 版本描述 | |
| template | LONGTEXT | Prompt 模板内容 | |
| variables | LONGTEXT | 可变参数定义，JSON | |
| model_config | LONGTEXT | 调试用模型参数，JSON | |
| status | VARCHAR(32) | 版本状态 | 枚举: `pre`（预发布）, `release`（正式） |
| previous_version | VARCHAR(32) | 前置版本，用于对比 | |
| create_time | DATETIME(3) | 创建时间 | |

### 1.3 prompt_build_template — Prompt 模板

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| prompt_template_key | VARCHAR(255) | 模板唯一标识 | UK |
| tags | VARCHAR(255) | 标签 | |
| template_desc | VARCHAR(255) | 模板描述 | |
| template | LONGTEXT | 模板内容 | |
| variables | LONGTEXT | 可变参数 | |
| model_config | LONGTEXT | 推荐模型参数，JSON | |

---

## 2. Dataset 模块

### 2.1 dataset — 数据集主表

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| name | VARCHAR(255) | 数据集名称 | |
| description | TEXT | 描述 | |
| columns_config | LONGTEXT | 列结构配置，JSON | |
| create_time | DATETIME | 创建时间 | |
| update_time | DATETIME | 更新时间 | |
| deleted | TINYINT(1) | 逻辑删除 | 枚举: `0`（正常）, `1`（已删除） |

### 2.2 dataset_version — 数据集版本

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| dataset_id | BIGINT | 所属数据集 | FK → dataset.id, CASCADE |
| version | VARCHAR(32) | 版本号 | UK (dataset_id + version) |
| description | TEXT | 版本描述 | |
| data_count | INT | 数据条数 | |
| status | VARCHAR(32) | 版本状态 | 枚举: `DRAFT`, `PUBLISHED`, `ARCHIVED` |
| experiments | TEXT | 关联实验，JSON | |
| dataset_items | TEXT | 数据项集合，JSON | |
| create_time | DATETIME | 创建时间 | |
| update_time | DATETIME | 更新时间 | |

### 2.3 dataset_item — 数据集条目

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| dataset_id | BIGINT | 所属数据集 | FK → dataset.id, CASCADE |
| columns_config | LONGTEXT | 列结构配置，JSON | |
| data_content | LONGTEXT | 数据内容，JSON | |
| create_time | DATETIME | 创建时间 | |
| update_time | DATETIME | 更新时间 | |
| deleted | TINYINT(1) | 逻辑删除 | 枚举: `0`, `1` |

---

## 3. Evaluator 模块

### 3.1 evaluator — 评估器主表

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| name | VARCHAR(255) | 评估器名称 | |
| description | TEXT | 描述 | |
| create_time | DATETIME | 创建时间 | |
| update_time | DATETIME | 更新时间 | |
| deleted | TINYINT(1) | 逻辑删除 | 枚举: `0`, `1` |

### 3.2 evaluator_version — 评估器版本

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| evaluator_id | BIGINT | 所属评估器 | FK → evaluator.id, CASCADE |
| version | VARCHAR(32) | 版本号 | UK (evaluator_id + version) |
| description | TEXT | 版本描述 | |
| model_config | TEXT | 模型配置 | |
| prompt | LONGTEXT | 评估 Prompt，JSON | |
| variables | LONGTEXT | 可变参数 | |
| status | VARCHAR(32) | 版本状态 | 枚举: `DRAFT`, `PUBLISHED`, `ARCHIVED` |
| experiments | TEXT | 关联实验，JSON | |
| create_time | DATETIME | 创建时间 | |
| update_time | DATETIME | 更新时间 | |

### 3.3 evaluator_template — 评估器模板

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| evaluator_template_key | VARCHAR(255) | 模板唯一标识 | UK |
| template_desc | VARCHAR(255) | 模板描述 | |
| template | LONGTEXT | 模板内容 | |
| variables | LONGTEXT | 可变参数 | |
| model_config | LONGTEXT | 推荐模型参数 | |

---

## 4. Experiment 模块

### 4.1 experiment — 实验主表

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| name | VARCHAR(255) | 实验名称 | |
| description | TEXT | 描述 | |
| dataset_id | BIGINT | 关联数据集 | FK → dataset.id |
| dataset_version_id | BIGINT | 关联数据集版本 | FK → dataset_version.id |
| dataset_version | VARCHAR(32) | 数据集版本号 | 冗余存储 |
| evaluation_object_config | LONGTEXT | 评估对象配置，JSON | |
| evaluator_config | TEXT | 评估器配置 | |
| status | VARCHAR(32) | 实验状态 | 枚举: `DRAFT`, `RUNNING`, `COMPLETED`, `FAILED`, `STOPPED` |
| progress | INT(3) | 进度百分比 | 0-100 |
| complete_time | DATETIME | 完成时间 | |
| create_time | DATETIME | 创建时间 | |
| update_time | DATETIME | 更新时间 | |

### 4.2 experiment_result — 实验结果

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| experiment_id | BIGINT | 所属实验 | FK → experiment.id |
| input | LONGTEXT | 输入内容 | |
| actual_output | LONGTEXT | 模型实际输出 | |
| reference_output | LONGTEXT | 参考输出 | |
| score | DECIMAL(3,2) | 评分 | 0.00-1.00 |
| reason | TEXT | 评分理由 | |
| evaluation_time | DATETIME | 评估执行时间 | |
| evaluator_version_id | BIGINT | 使用的评估器版本 | FK → evaluator_version.id |
| create_time | DATETIME | 创建时间 | |
| update_time | DATETIME | 更新时间 | |

---

## 5. Model Config 模块

### 5.1 model_config — 模型配置

| 字段 | 类型 | 说明 | 备注 |
|------|------|------|------|
| id | BIGINT | 主键 | PK, 自增 |
| name | VARCHAR(100) | 配置名称 | UK |
| provider | VARCHAR(50) | 提供商 | 如 openai, azure, dashscope |
| model_name | VARCHAR(100) | 模型标识 | 如 gpt-4, qwen-max |
| base_url | VARCHAR(500) | 模型服务地址 | |
| api_key | VARCHAR(500) | API 密钥 | |
| default_parameters | JSON | 默认参数 | |
| supported_parameters | JSON | 支持的参数定义 | |
| status | TINYINT | 状态 | 枚举: `1`（启用）, `0`（禁用） |
| create_time | DATETIME | 创建时间 | |
| update_time | DATETIME | 更新时间 | |
| deleted | TINYINT(1) | 逻辑删除 | 枚举: `0`（正常）, `1`（已删除） |

---

## 6. 枚举值汇总

| 实体 | 字段 | 可选值 |
|------|------|--------|
| prompt_version | status | `pre`, `release` |
| dataset_version | status | `DRAFT`, `PUBLISHED`, `ARCHIVED` |
| evaluator_version | status | `DRAFT`, `PUBLISHED`, `ARCHIVED` |
| experiment | status | `DRAFT`, `RUNNING`, `COMPLETED`, `FAILED`, `STOPPED` |
| model_config | status | `1`（启用）, `0`（禁用） |
| dataset / evaluator | deleted | `0`（正常）, `1`（已删除） |
| DatasetColumn | dataType | `STRING`, `NUMBER`, `BOOLEAN`, `JSON`, `ARRAY` |
| DatasetColumn | displayFormat | `PLAIN_TEXT`, `MARKDOWN`, `CODE`, `JSON`, `TABLE` |

---

## 7. 实体关系

### 平台基础层（agentscope-schema）

```
account ──1:N──→ workspace              (via account_id)
account ──1:N──→ api_key                (via account_id)
workspace ──1:N──→ application          (via workspace_id)
workspace ──1:N──→ plugin               (via workspace_id)
workspace ──1:N──→ knowledge_base       (via workspace_id)
workspace ──1:N──→ mcp_server           (via workspace_id)
workspace ──1:N──→ agent_schema         (via workspace_id)
workspace ──1:N──→ provider             (via workspace_id)
application ──1:N──→ application_version (via app_id)
application ──1:N──→ application_component (via app_id)
plugin ──1:N──→ tool                    (via plugin_id)
knowledge_base ──1:N──→ document        (via kb_id)
provider ──1:N──→ model                 (via provider)
```

### 评估业务层（admin-schema）

```
prompt ──1:N──→ prompt_version          (via prompt_key)
prompt ──1:N──→ prompt_build_template   (独立，通过 key 关联)

dataset ──1:N──→ dataset_version        (via dataset_id, FK CASCADE)
dataset ──1:N──→ dataset_item           (via dataset_id, FK CASCADE)

evaluator ──1:N──→ evaluator_version    (via evaluator_id, FK CASCADE)
evaluator ──1:N──→ evaluator_template   (独立，通过 key 关联)

experiment ──N:1──→ dataset             (via dataset_id)
experiment ──N:1──→ dataset_version     (via dataset_version_id)
experiment ──1:N──→ experiment_result   (via experiment_id)

experiment_result ──N:1──→ evaluator_version (via evaluator_version_id)

model_config                            (独立表)
```

---

## 8. 关键设计模式

**版本化管理**：Prompt、Dataset、Evaluator 三个核心实体都采用「主表 + 版本表」的 1:N 模式，主表持有 `latest_version` 指针，版本表存储完整快照。

**逻辑删除**：Dataset 和 Evaluator 使用 `deleted` 字段做软删除，不物理删除数据。

**JSON 字段**：模板内容、变量定义、模型配置、列结构等灵活结构统一用 LONGTEXT/JSON 存储，由应用层解析。

**实验关联**：Experiment 同时关联 Dataset 和 Evaluator，通过 `evaluator_config` 和 `evaluation_object_config` JSON 字段存储多评估器配置。ExperimentResult 按评估器版本拆分评分。
