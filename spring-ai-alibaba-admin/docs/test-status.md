# 测试覆盖现状

> 扫描时间：2026-05-17
> 扫描范围：`spring-ai-alibaba-admin` 全部子模块

---

## 概览

| 指标 | 数量 |
|------|------|
| 测试文件总数 | **7** |
| 单元测试 | 7 |
| 集成测试 | 0 |
| E2E 测试 | 0 |
| Controller 测试 | 0 / 32 |
| Service 测试 | 0 / 35 |
| 有测试的模块 | 1 / 4（仅 `admin-server-core`） |

**结论：测试极度匮乏。** 212 个 API 接口、35 个 Service、32 个 Controller，仅 7 个底层工具类有单元测试。所有业务链路零覆盖。

---

## 现有测试清单

全部 7 个测试文件均在 `admin-server-core` 模块，属于底层工具类，不涉及业务逻辑：

| # | 测试文件 | 类型 | 测什么 |
|---|----------|------|--------|
| 1 | `PasswordCryptTest.java` | 单元 | 密码加密/解密（Argon2） |
| 2 | `RSACryptTest.java` | 单元 | RSA 加密/解密 |
| 3 | `DateUtilsTests.java` | 单元 | 日期工具方法 |
| 4 | `TextSplitterTest.java` | 单元 | 文本分块（RAG 基础组件） |
| 5 | `TextDocumentReaderTest.java` | 单元 | 文档读取（RAG 基础组件） |
| 6 | `DashscopeRerankerTest.java` | 单元 | DashScope 重排序（RAG 基础组件） |
| 7 | `KnowledgeBaseIndexPipelineTest.java` | 单元 | 知识库索引管线（parse→transform→store） |

其中 #4-#7 使用 `@Mock`，不依赖外部服务，是纯单元测试。

---

## Controller 测试覆盖

| Controller | 有测试 | 说明 |
|------------|:------:|------|
| AuthController | ❌ | 登录/刷新/登出 |
| AccountController | ❌ | 用户 CRUD |
| WorkspaceController | ❌ | 工作空间 CRUD |
| AppController | ❌ | 应用 CRUD + 发布 |
| AppChatController | ❌ | 应用对话 |
| WorkflowController | ❌ | 工作流调试 |
| AgentSchemaController | ❌ | Agent 配置 CRUD |
| ProviderController | ❌ | 模型提供商 CRUD |
| ModelController | ❌ | 模型查询 |
| PluginController | ❌ | 插件 CRUD |
| ToolController | ❌ | 工具 CRUD |
| KnowledgeBaseController | ❌ | 知识库 CRUD |
| DocumentController | ❌ | 文档 CRUD |
| DocumentChunkController | ❌ | 分块 CRUD |
| McpServerController | ❌ | MCP 服务器 CRUD |
| AppComponentController | ❌ | 组件 CRUD |
| ApiKeyController | ❌ | API Key CRUD |
| FileController | ❌ | 文件上传/下载 |
| Oauth2Controller | ❌ | OAuth2 登录 |
| SystemController | ❌ | 健康检查/全局配置 |
| PromptController | ❌ | Prompt CRUD + 版本 + 模板 |
| DatasetController | ❌ | 数据集 CRUD + 版本 + 数据项 |
| EvaluatorController | ❌ | 评估器 CRUD + 版本 + 模板 |
| ExperimentController | ❌ | 实验 CRUD + 执行 |
| ModelConfigController | ❌ | 模型配置 CRUD |
| ObservabilityController | ❌ | Trace 查询 |
| ChatController | ❌ | OpenAPI 对话/工作流 |
| ApplicationController | ❌ | Graph Studio 应用 CRUD |
| DSLController | ❌ | DSL 导入导出 |
| RunnerController | ❌ | 应用运行 |
| GeneratorController | ❌ | 项目生成 |
| ApiExampleController | ❌ | 测试示例 |

---

## Service 测试覆盖

| Service | 有测试 | 说明 |
|---------|:------:|------|
| AccountService | ❌ | 用户管理 |
| WorkspaceService | ❌ | 工作空间 |
| AppService | ❌ | 应用管理 |
| AgentSchemaService | ❌ | Agent 配置 |
| AgentService | ❌ | Agent 执行 |
| PromptService | ❌ | Prompt CRUD |
| PromptVersionService | ❌ | Prompt 版本 |
| PromptRunService | ❌ | Prompt 运行/调试 |
| PromptTemplateService | ❌ | Prompt 模板 |
| DatasetService | ❌ | 数据集 CRUD |
| DatasetVersionService | ❌ | 数据集版本 |
| DatasetItemService | ❌ | 数据项 CRUD |
| EvaluatorService | ❌ | 评估器 CRUD |
| EvaluatorVersionService | ❌ | 评估器版本 |
| EvaluatorTemplateService | ❌ | 评估器模板 |
| ExperimentService | ❌ | 实验 CRUD + 执行 |
| KnowledgeBaseService | ❌ | 知识库 CRUD |
| DocumentService | ❌ | 文档 CRUD |
| ModelConfigService | ❌ | 模型配置 |
| ModelConfigBridgeService | ❌ | 模型配置桥接 |
| TracingService | ❌ | Trace 查询 |
| PluginService | ❌ | 插件 CRUD |
| ToolService | ❌ | 工具 CRUD |
| ToolExecutionService | ❌ | 工具执行 |
| McpServerService | ❌ | MCP 服务器 |
| AppComponentService | ❌ | 组件管理 |
| ApiKeyService | ❌ | API Key |
| Oauth2Service | ❌ | OAuth2 |
| ChatSessionService | ❌ | 会话管理 |
| NacosClientService | ❌ | Nacos 客户端 |
| ReferService | ❌ | 引用关系 |
| WorkflowService | ❌ | 工作流 |
| WorkflowInnerService | ❌ | 工作流内部 |
| ElasticSearchVectorStoreService | ❌ | ES 向量存储 |
| VectorStoreService | ❌ | 向量存储抽象 |

---

## 核心链路测试覆盖（对照 critical-paths.md）

| # | 链路 | 覆盖 | 说明 |
|---|------|:----:|------|
| 1 | 登录鉴权 | ❌ 没有 | AuthController、AccountService 无测试 |
| 2 | Prompt 版本化 | ❌ 没有 | PromptService、PromptVersionService 无测试 |
| 3 | 数据集全生命周期 | ❌ 没有 | DatasetService、DatasetVersionService、DatasetItemService 无测试 |
| 4 | 实验执行 | ❌ 没有 | ExperimentService 无测试，状态机零覆盖 |
| 5 | 应用发布→对话 | ❌ 没有 | AppService、ChatController 无测试 |
| 6 | 知识库文档索引 | ⚠️ 部分 | KnowledgeBaseIndexPipelineTest 覆盖了 parse→transform→store 管线，但 DocumentService、RocketMQ 消费链路无测试 |
| 7 | Agent Schema 生成 | ❌ 没有 | AgentSchemaService 无测试 |
| 8 | Trace 查询 | ❌ 没有 | TracingService、ObservabilityController 无测试 |

---

## 优先补测建议

按业务影响和改造风险排序：

| 优先级 | 目标 | 理由 |
|:------:|------|------|
| P0 | AuthController + AccountService | 所有接口的入口，改坏全局瘫痪 |
| P0 | PromptService + PromptVersionService | 「主表+版本表」模式的标杆，Dataset/Evaluator 照抄 |
| P0 | ExperimentService | 跨 3 模块 + 状态机，最复杂的业务逻辑 |
| P1 | DatasetService + DatasetVersionService | 三层嵌套 + CASCADE 删除 |
| P1 | AppService + ChatController | 管理后台到 OpenAPI 的跨模块调用 |
| P1 | TracingService | ES 查询链路，配置敏感 |
| P2 | DocumentService + RocketMQ 消费 | 异步链路，排障困难 |
| P2 | AgentSchemaService | JSON→YAML 转换，5 种类型 |

---

## 实际运行结果

> 运行时间：2026-05-17 20:04:53
> 命令：`mvn -B test`
> 总耗时：**1 分 49 秒**（其中测试执行 ~8.5 秒，其余为编译和依赖解析）

### 汇总

| 指标 | 数值 |
|------|------|
| Tests run | 14 |
| Pass | 14 |
| Fail | 0 |
| Error | 0 |
| Skip | 0 |
| 通过率 | 100% |

### 各模块结果

| 模块 | 测试数 | 结果 | 耗时 | 备注 |
|------|:------:|------|------|------|
| admin-server-runtime | 0 | ✅ | 12s | 无测试，仅编译 |
| admin-server-core | 14 | ✅ 14/14 | 54s | 全部通过 |
| admin-server-openapi | 0 | ✅ | 10s | 无测试，仅编译 |
| admin-server-start | 0 | ✅ | 33s | 无测试，仅编译 |

### 各测试类明细

| 测试类 | 测试数 | 通过 | 失败 | 跳过 | 耗时 |
|--------|:------:|:----:|:----:|:----:|------|
| PasswordCryptTest | 2 | 2 | 0 | 0 | 1.1s |
| RSACryptTest | 2 | 2 | 0 | 0 | 0.2s |
| KnowledgeBaseIndexPipelineTest | 3 | 3 | 0 | 0 | 5.9s |
| TextDocumentReaderTest | 1 | 1 | 0 | 0 | 0.05s |
| DashscopeRerankerTest | 2 | 2 | 0 | 0 | 0.2s |
| TextSplitterTest | 2 | 2 | 0 | 0 | 0.3s |
| DateUtilsTests | 2 | 2 | 0 | 0 | 0.6s |

### 失败分类

无失败。

### 测试健康度

| 维度 | 评级 | 说明 |
|------|------|------|
| 通过率 | 🟢 绿 | 14/14 = 100% |
| 覆盖度 | 🔴 红 | 7 个测试文件仅覆盖底层工具类，212 个 API 接口零测试 |
| 综合判断 | 🔴 红 | **测试形同虚设** |

> **结论**：通过率 100% 是假象。14 个测试全部是工具类单元测试（密码加密、日期处理、RAG 组件），不涉及任何业务逻辑。
> 所有 Controller、所有 Service、所有核心链路均无测试。改任何业务代码都不会触发测试失败。
> 这不是"绿"，是"没有测试"。
