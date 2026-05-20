# 外部依赖清单 — 环境检查手册

> 项目运行所需的全部外部依赖，含版本要求、端口、连接信息、初始化步骤。

---

## 1. 基础设施（必选）

### 1.1 MySQL

| 项目 | 值 |
|------|-----|
| 名称 | MySQL |
| 版本 | **8.0.x**（镜像: `mysql:8.0.35`） |
| 默认端口 | `3306` |
| 连接字符串 | `jdbc:mysql://{host}:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai` |
| 默认账号 | `admin` / `admin`（dev/local），环境变量 `SPRING_DATASOURCE_USERNAME` / `SPRING_DATASOURCE_PASSWORD` |
| 数据库名 | `admin` |
| 连接池 | Druid（initial-size=5, max-active=20） |
| 环境变量 | `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` |

**初始化要求：**
- 建库：`CREATE DATABASE admin DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_0900_ai_ci`
- 建表：执行 `docker/middleware/init/mysql/admin-schema.sql` + `agentscope-schema.sql`
- Docker 模式下自动执行（挂载到 `/docker-entrypoint-initdb.d/`）

---

### 1.2 Redis

| 项目 | 值 |
|------|-----|
| 名称 | Redis |
| 版本 | **7.2.x**（镜像: `redis:7.2.5`） |
| 默认端口 | `6379` |
| 连接信息 | `{host}:6379`，无密码（dev），环境变量 `SPRING_REDIS_HOST` / `SPRING_REDIS_PORT` |
| 数据库 | `0`（默认），环境变量 `SPRING_REDIS_DATABASE` |
| 客户端 | Redisson 3.27.2 |

**初始化要求：**
- 无特殊初始化，启动即可用
- 生产环境建议开启 `--appendonly yes` 持久化

---

### 1.3 Elasticsearch

| 项目 | 值 |
|------|-----|
| 名称 | Elasticsearch |
| 版本 | **9.1.x**（镜像: `docker.elastic.co/elasticsearch/elasticsearch:9.1.2`） |
| 默认端口 | `9200`（HTTP）, `9300`（transport） |
| 连接信息 | `http://{host}:9200`，环境变量 `SPRING_ELASTICSEARCH_URIS` |
| 超时配置 | connect-timeout=5s, socket-timeout=60s, max-connections=100 |
| 索引名 | `loongsuite_traces`（追踪数据） |

**初始化要求：**
- 索引自动创建：通过 `docker/middleware/init/elasticsearch/init-indices.sh`
- 创建 ingest pipeline: `parsing_loongsuite_traces`
- 创建索引 `loongsuite_traces`（1 shard, 0 replicas）
- 单节点模式：`discovery.type=single-node`
- 关闭安全认证：`xpack.security.enabled=false`
- JVM 内存：`-Xms1g -Xmx1g`

---

### 1.4 Nacos

| 项目 | 值 |
|------|-----|
| 名称 | Nacos |
| 版本 | **latest**（镜像: `nacos/nacos-server:latest`） |
| 默认端口 | `8848`（gRPC）, `9848`（client gRPC）, `8080`（console） |
| 连接信息 | `{host}:8848`，环境变量 `NACOS_SERVER_ADDR` |
| 认证 | Token: `dG9rZW5hbHNka2ZqbGFza2RqZmxhc2tkamZsYXNrZGpmb3dpZWpmbztzZGxm`，Identity: `admin` / `admin` |

**初始化要求：**
- 启动模式：`MODE=standalone`（单机）
- 创建命名空间（可选）：如需隔离环境，在 Nacos Console 创建
- 创建配置（可选）：`application.yml` 可通过 Nacos 动态下发
- 项目使用 Nacos 做：服务发现、动态配置、A2A Agent 注册

---

### 1.5 RocketMQ

| 项目 | 值 |
|------|-----|
| 名称 | RocketMQ |
| 版本 | **5.3.x**（镜像: `apache/rocketmq:5.3.2`） |
| 默认端口 | `9876`（NameServer）, `10911`（Broker）, `18080`（Proxy） |
| 连接信息 | `{host}:18080`（Proxy 端点），环境变量 `ROCKETMQ_ENDPOINTS` |
| Topic | `topic_saa_studio_document_index`，环境变量 `ROCKETMQ_DOCUMENT_INDEX_TOPIC` |
| Consumer Group | `group_saa_studio_document_index`，环境变量 `ROCKETMQ_DOCUMENT_INDEX_GROUP` |

**初始化要求：**
- 需要 3 个组件：NameServer + Broker + Proxy
- 自动创建 Topic：通过 `init-topic` 容器执行 `mqadmin updateTopic`
- 用于文档索引的异步消息处理

---

## 2. 可观测性（可选但推荐）

### 2.1 OpenTelemetry Collector / LoongCollector

| 项目 | 值 |
|------|-----|
| 名称 | LoongCollector（阿里云 OpenTelemetry 发行版） |
| 版本 | **3.1.x**（镜像: `loongcollector:3.1.4`） |
| 默认端口 | `4318`（OTLP HTTP） |
| 连接信息 | `http://{host}:4318/v1/traces`，环境变量 `MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT` |
| 服务名 | `spring-ai-alibaba-studio`（固定） |

**初始化要求：**
- 配置 pipeline：`docker/middleware/conf/loongcollector/otlp_pipeline`
- 数据写入 Elasticsearch 的 `loongsuite_traces` 索引
- 采样率：`management.tracing.sampling.probability: 1.0`（全量）

---

### 2.2 Kibana（可选）

| 项目 | 值 |
|------|-----|
| 名称 | Kibana |
| 版本 | **9.1.x**（镜像: `docker.elastic.co/kibana/kibana:9.1.2`） |
| 默认端口 | `5601` |
| 连接信息 | 自动连接 `http://elasticsearch:9200` |

**初始化要求：**
- 依赖 Elasticsearch healthy 后启动
- 用于查看 Trace 数据和日志

---

## 3. AI 模型服务（必选，三选一）

### 3.1 DashScope（阿里云通义千问）

| 项目 | 值 |
|------|-----|
| 名称 | DashScope |
| API 地址 | `https://dashscope.aliyuncs.com/compatible-mode` |
| 推荐模型 | `qwen-plus`（默认）, `qwen-max-latest` |
| API Key | 环境变量 `DASHSCOPE_API_KEY` |
| 获取地址 | https://bailian.console.aliyun.com/?tab=model#/api-key |

**初始化要求：**
- 注册阿里云账号
- 开通 DashScope 服务
- 获取 API Key 并设置环境变量

---

### 3.2 OpenAI

| 项目 | 值 |
|------|-----|
| 名称 | OpenAI |
| API 地址 | `https://api.openai.com/v1` |
| 推荐模型 | `gpt-4o` |
| API Key | 环境变量 `OPENAI_API_KEY` |

**初始化要求：**
- 注册 OpenAI 账号
- 获取 API Key
- 需要科学上网或代理

---

### 3.3 DeepSeek

| 项目 | 值 |
|------|-----|
| 名称 | DeepSeek |
| API 地址 | `https://api.deepseek.com`（默认） |
| 推荐模型 | `deepseek-chat` |
| API Key | 环境变量 `DEEPSEEK_API_KEY` |

**初始化要求：**
- 注册 DeepSeek 账号
- 获取 API Key

---

## 4. 模型配置切换

项目提供 3 个模板 YAML，复制为目标文件即可切换：

```bash
# 选择一个提供商
cp spring-ai-alibaba-admin-server-start/model-config-dashscope.yaml \
   spring-ai-alibaba-admin-server-start/model-config.yaml

# 设置对应环境变量
export DASHSCOPE_API_KEY=your-key-here
```

| 模板文件 | 环境变量 |
|----------|---------|
| `model-config-dashscope.yaml` | `DASHSCOPE_API_KEY` |
| `model-config-openai.yaml` | `OPENAI_API_KEY` |
| `model-config-deepseek.yaml` | `DEEPSEEK_API_KEY` |

---

## 5. 环境变量汇总

| 变量名 | 用途 | 必选 | 默认值 |
|--------|------|:---:|--------|
| `SPRING_DATASOURCE_URL` | MySQL 连接串 | ✓ | — |
| `SPRING_DATASOURCE_USERNAME` | MySQL 用户名 | ✓ | `admin` |
| `SPRING_DATASOURCE_PASSWORD` | MySQL 密码 | ✓ | `admin` |
| `SPRING_REDIS_HOST` | Redis 地址 | ✓ | `localhost` |
| `SPRING_REDIS_PORT` | Redis 端口 | ✓ | `6379` |
| `SPRING_REDIS_DATABASE` | Redis DB 编号 | | `0` |
| `SPRING_ELASTICSEARCH_URIS` | ES 地址 | ✓ | `http://localhost:9200` |
| `NACOS_SERVER_ADDR` | Nacos 地址 | ✓ | — |
| `ROCKETMQ_ENDPOINTS` | RocketMQ Proxy 地址 | ✓ | — |
| `ROCKETMQ_DOCUMENT_INDEX_TOPIC` | 文档索引 Topic | | `topic_saa_studio_document_index` |
| `ROCKETMQ_DOCUMENT_INDEX_GROUP` | 文档索引消费组 | | `group_saa_studio_document_index` |
| `MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT` | OTLP 追踪地址 | | `http://localhost:4318/v1/traces` |
| `DASHSCOPE_API_KEY` | DashScope API Key | 三选一 | — |
| `OPENAI_API_KEY` | OpenAI API Key | 三选一 | — |
| `DEEPSEEK_API_KEY` | DeepSeek API Key | 三选一 | — |

---

## 6. 端口清单

| 服务 | 端口 | 协议 | 用途 |
|------|------|------|------|
| Admin Backend | `8080` | HTTP | 应用主端口 |
| Admin Frontend | `8000` | HTTP | 前端开发服务器 |
| MySQL | `3306` | TCP | 数据库 |
| Redis | `6379` | TCP | 缓存 |
| Elasticsearch | `9200` | HTTP | 搜索/向量存储 |
| Elasticsearch | `9300` | TCP | 节点通信 |
| Kibana | `5601` | HTTP | 日志可视化 |
| Nacos | `8848` | gRPC | 服务发现/配置 |
| Nacos | `9848` | gRPC | 客户端通信 |
| Nacos Console | `8080` | HTTP | 管理控制台 |
| RocketMQ NameServer | `9876` | TCP | 名称服务 |
| RocketMQ Broker | `10911` | TCP | 消息代理 |
| RocketMQ Proxy | `18080` | HTTP | 消息代理 REST |
| LoongCollector | `4318` | HTTP | OTLP 接收端 |

---

## 7. 快速检查脚本

```bash
#!/bin/bash
# env-check.sh — 检查所有外部依赖是否就绪

echo "=== MySQL ==="
mysqladmin ping -h ${SPRING_REDIS_HOST:-localhost} -P 3306 -u ${SPRING_DATASOURCE_USERNAME:-admin} -p${SPRING_DATASOURCE_PASSWORD:-admin} 2>/dev/null && echo "OK" || echo "FAIL"

echo "=== Redis ==="
redis-cli -h ${SPRING_REDIS_HOST:-localhost} -p ${SPRING_REDIS_PORT:-6379} ping 2>/dev/null && echo "OK" || echo "FAIL"

echo "=== Elasticsearch ==="
curl -s http://${SPRING_ELASTICSEARCH_URIS:-localhost:9200}/_cluster/health | grep -q '"status"' && echo "OK" || echo "FAIL"

echo "=== Nacos ==="
curl -s http://${NACOS_SERVER_ADDR:-localhost:8848}/nacos/v1/console/health/readiness && echo "OK" || echo "FAIL"

echo "=== RocketMQ ==="
curl -s http://${ROCKETMQ_ENDPOINTS:-localhost:18080} >/dev/null 2>&1 && echo "OK" || echo "FAIL"

echo "=== OTLP ==="
curl -s -o /dev/null -w "%{http_code}" http://${MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT:-localhost:4318}/v1/traces && echo " OK" || echo "FAIL"

echo "=== AI Model API Key ==="
if [ -n "$DASHSCOPE_API_KEY" ]; then echo "DashScope: SET"; fi
if [ -n "$OPENAI_API_KEY" ]; then echo "OpenAI: SET"; fi
if [ -n "$DEEPSEEK_API_KEY" ]; then echo "DeepSeek: SET"; fi
if [ -z "$DASHSCOPE_API_KEY" ] && [ -z "$OPENAI_API_KEY" ] && [ -z "$DEEPSEEK_API_KEY" ]; then echo "FAIL: No API key set"; fi
```

---

## 8. Docker 一键启动

```bash
# Dev 模式（仅 MySQL）
make env-start MODE=dev

# Prod 模式（全部中间件）
make env-start MODE=prod

# 全栈（中间件 + 后端 + 前端）
make local-all-start
```
