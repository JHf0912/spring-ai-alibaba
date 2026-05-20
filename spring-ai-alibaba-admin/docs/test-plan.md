# P0 测试补全计划

> 基于 `test-gaps.md` 中 10 个 P0 缺口，拆为 6 批。
> 排序原则：Characterization（锁定当前行为）→ 集成（链路兜底）→ 单元（复杂逻辑）。

---

## 批次总览

| 批次 | 测试类型 | 覆盖缺口 | 核心链路 | 预计工作量 |
|:----:|----------|:--------:|----------|-----------|
| 1 | Characterization | #1, #2 | 登录鉴权 | 0.5 天 |
| 2 | Characterization | #3, #4, #5 | Prompt 版本化 | 0.5 天 |
| 3 | Characterization | #6 | 数据集级联删除 | 0.5 天 |
| 4 | 集成测试 | #9, #10 | 实验状态机 | 1 天 |
| 5 | 集成测试 | #11 | 实验跨模块校验 | 0.5 天 |
| 6 | 集成测试 | #18 | Trace 参数校验 | 0.5 天 |

**总预计工作量**：3.5 天

---

## 各批次详情

### Batch 1：登录鉴权 Characterization Test

| 项目 | 内容 |
|------|------|
| **缺口** | #1 登录→Token 签发→携带 Token 访问受保护接口；#2 Token 过期/无效→401 |
| **测试类型** | Characterization Test（先跑出当前行为快照，作为后续改造的安全网） |
| **覆盖链路** | 链路 1：登录鉴权 |
| **做法** | 用真实 DB（MySQL + account 表），跑通完整登录流程，记录：(1) 正确密码返回 Token 结构；(2) 错误密码返回什么 code/message；(3) 携带 Token 能访问 profile 接口；(4) 无 Token / 过期 Token 返回 401。不做 Mock，捕获当前真实行为。 |
| **关键断言** | response.code、token 结构、profile 返回值、401 状态码 |
| **预计工作量** | 0.5 天 |

---

### Batch 2：Prompt 版本化 Characterization Test

| 项目 | 内容 |
|------|------|
| **缺口** | #3 创建 Prompt→自动首版本→latest_version 一致；#4 新版本→旧版本不丢；#5 重复版本被拒 |
| **测试类型** | Characterization Test |
| **覆盖链路** | 链路 2：Prompt 版本化 |
| **做法** | 用真实 DB，跑通：(1) 创建 Prompt 后查 prompt 表和 prompt_version 表，记录 latest_version 值；(2) 创建第二版本，验证 latest_version 更新且第一版本仍在；(3) 尝试重复版本号，记录拒绝行为（code/message）。捕获「主表+版本表」模式的当前行为。 |
| **关键断言** | prompt.latest_version == prompt_version.version；旧版本 count == 1；重复版本返回非 200 |
| **预计工作量** | 0.5 天 |

---

### Batch 3：数据集级联删除 Characterization Test

| 项目 | 内容 |
|------|------|
| **缺口** | #6 删除 Dataset→CASCADE 删除 Version 和 Item |
| **测试类型** | Characterization Test |
| **覆盖链路** | 链路 3：数据集全生命周期 |
| **做法** | 用真实 DB，跑通：(1) 创建 Dataset + Version + Item；(2) 删除 Dataset；(3) 查 dataset_version 表和 dataset_item 表，确认记录数为 0。捕获 CASCADE 删除的实际行为（MySQL FK 约束 + Service 层清理）。 |
| **关键断言** | 删除后 dataset_version.count == 0；dataset_item.count == 0 |
| **预计工作量** | 0.5 天 |

---

### Batch 4：实验状态机集成测试

| 项目 | 内容 |
|------|------|
| **缺口** | #9 合法状态流转；#10 非法转换被拒 |
| **测试类型** | 集成测试（Mock 外部服务，测状态机逻辑本身） |
| **覆盖链路** | 链路 4：实验执行 |
| **做法** | 测状态机的全部合法路径和关键非法路径：(1) DRAFT→RUNNING→COMPLETED；(2) DRAFT→RUNNING→FAILED；(3) RUNNING→STOPPED；(4) COMPLETED→RUNNING（应拒绝）；(5) DRAFT→COMPLETED（应拒绝）。Mock 掉 Model 调用，只测状态转换逻辑。 |
| **关键断言** | 合法转换后 status 正确；非法转换抛异常或返回错误码 |
| **预计工作量** | 1 天 |

---

### Batch 5：实验跨模块校验集成测试

| 项目 | 内容 |
|------|------|
| **缺口** | #11 创建实验时校验 dataset_id 和 evaluator_id 存在 |
| **测试类型** | 集成测试 |
| **覆盖链路** | 链路 4：实验执行 |
| **做法** | 测创建实验时的引用校验：(1) dataset_id 不存在→拒绝；(2) evaluator_id 不存在→拒绝；(3) 全部存在→成功创建。需要在 DB 中准备测试数据（或用 @Sql 注入）。 |
| **关键断言** | 不存在时返回明确错误（不是 DB FK 异常）；存在时 status=DRAFT |
| **预计工作量** | 0.5 天 |

---

### Batch 6：Trace 参数校验集成测试

| 项目 | 内容 |
|------|------|
| **缺口** | #18 startTime/endTime 缺失返回 400 而非 500 |
| **测试类型** | 集成测试（Mock ES，测参数校验） |
| **覆盖链路** | 链路 8：Trace 查询 |
| **做法** | 测 TracesQueryRequest 的 @NotBlank 校验：(1) 缺 startTime→400；(2) 缺 endTime→400；(3) 两个都缺→400；(4) 格式错误→400 或 500（记录当前行为）。Mock 掉 ES Client，只测参数校验层。 |
| **关键断言** | 返回 400（不是 500）；错误信息包含"开始时间不能为空" |
| **预计工作量** | 0.5 天 |

---

## 后续批次（P1，暂不排期）

P1 的 8 项缺口在 P0 全部完成后按同样模式推进：

- Batch 7：数据集 JSON 校验 + data_count 维护（#7, #8）
- Batch 8：实验 evaluator_config JSON 解析（#12）
- Batch 9：应用发布状态同步 + OpenAPI 鉴权（#13, #14）
- Batch 10：文档索引异步链路（#15）
- Batch 11：Agent Schema YAML 生成 + 引用校验（#16, #17）
