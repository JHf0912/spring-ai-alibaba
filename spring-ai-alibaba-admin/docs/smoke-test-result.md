# Smoke Test 结果

> 5 个核心接口冒烟测试，覆盖登录、Prompt、Dataset、Evaluator、Trace 五大模块。

---

## 测试环境

- **后端**: http://localhost:8081
- **日期**: 2026-05-17
- **数据库**: MySQL 8.0 (端口 13306, 库 admin)
- **Elasticsearch**: 9.1.2 (端口 9201)

---

## 测试结果

| # | 模块 | 接口 | 方法 | 状态 | 说明 |
|---|------|------|------|------|------|
| 1 | 登录 | `/console/v1/auth/login` | POST | ✅ 200 | 返回 access_token + refresh_token |
| 2 | Prompt | `/api/prompts` | GET | ✅ 200 | 返回空列表（无数据） |
| 3 | Dataset | `/api/dataset/datasets` | GET | ✅ 200 | 返回空列表（无数据） |
| 4 | Evaluator | `/api/evaluator/evaluators` | GET | ✅ 200 | 返回空列表（无数据） |
| 5 | Trace | `/api/observability/traces` | GET | ✅ 200 | 返回空列表（无 trace 数据） |

**通过率**: 5/5 (100%) ✅

---

## 详细结果

### [1] 登录 — ✅ 通过

```bash
curl -X POST http://localhost:8081/console/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"saa","password":"123456"}'
```

**响应**:
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiJ9...",
    "expires_in": 1779007847
  },
  "code": 200,
  "message": "success"
}
```

### [2] Prompt 列表 — ✅ 通过

```bash
curl http://localhost:8081/api/prompts?current=1&size=10
```

**响应**: `code: 200`, `totalCount: 0`（空列表，属正常）

### [3] Dataset 列表 — ✅ 通过

```bash
curl http://localhost:8081/api/dataset/datasets?current=1&size=10
```

**响应**: `code: 200`, `totalCount: 0`（空列表，属正常）

### [4] Evaluator 列表 — ✅ 通过

```bash
curl http://localhost:8081/api/evaluator/evaluators?current=1&size=10
```

**响应**: `code: 200`, `totalCount: 1`（含预置模板）

### [5] Trace 列表 — ✅ 通过

```bash
curl "http://localhost:8081/api/observability/traces?pageNumber=1&pageSize=10&startTime=2026-01-01T00:00:00.000Z&endTime=2026-12-31T23:59:59.000Z"
```

**响应**: `code: 200`（ES 索引 `loongsuite_traces` 已创建，无 trace 数据属正常）

---

## 踩坑记录

### Trace 接口首次返回 500

**根因**: 应用连接 ES 用的是 `elasticsearch.yml` 中的 `spring.elasticsearch.url`（默认 `http://localhost:9200`），而非 `application.yml` 中的 `spring.elasticsearch.uris`。两者是不同的配置属性。

**修复**: 启动时需同时设置两个环境变量：
```bash
export SPRING_ELASTICSEARCH_URL=http://localhost:9201   # elasticsearch.yml 用
export SPRING_ELASTICSEARCH_URIS=http://localhost:9201  # application.yml 用
```

### 应用启动后被 shell 杀掉

**根因**: `nohup ... &` 在某些 shell 环境下，父 shell 退出时会发送 SIGHUP 给子进程。

**修复**: 使用 `disown` 将进程从 shell 作业表中移除：
```bash
java -jar app.jar > /tmp/app.log 2>&1 &
APP_PID=$!
disown $APP_PID
```

### MySQL skip-grant-tables 导致 TCP 不可用

**根因**: MySQL 8.0 中 `--skip-grant-tables` 会自动启用 `--skip_networking`，禁用 TCP 连接。

**修复**: 先用 `--skip-grant-tables` 通过 socket 设置密码，再去掉该选项正常启动。
