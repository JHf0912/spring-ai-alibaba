# Spring AI Alibaba Admin — 本地开发环境搭建指南

> 面向新人的完整搭建手册，基于实际踩坑经验整理。

---

## 前置条件

| 项目 | 要求 | 检查命令 |
|------|------|----------|
| OS | Linux (Ubuntu 20.04+) 或 macOS | `uname -a` |
| JDK | 17（构建用），21（Nacos 用） | `java -version` |
| Maven | 3.8+ | `mvn -version` |
| 内存 | ≥ 8GB 可用 | `free -h` |
| 磁盘 | ≥ 5GB 可用空间 | `df -h` |
| 端口 | 3306/6379/8080/8848/9200 未被占用 | `ss -tlnp` |

如果没有 JDK/Maven，可以用项目自带的一键安装脚本：

```bash
bash scripts/install-deps.sh
```

该脚本会把所有依赖装到 `~/.saa-middleware/`，不需要 sudo。

---

## 方案选择

| 方案 | 适用场景 | 命令 |
|------|----------|------|
| **Docker** | 有 Docker Desktop，想快速跑起来 | `docker compose -f docker-compose.dev.yml up -d` |
| **手动安装** | 没有 Docker，或需要调试中间件 | 见下方步骤 |
| **一键脚本** | Ubuntu/macOS，想自动化 | `bash scripts/install-deps.sh` |

---

## 方案一：Docker（推荐）

```bash
# 1. 启动全部中间件
docker compose -f docker-compose.dev.yml up -d

# 2. 等待就绪（约 1 分钟）
docker compose -f docker-compose.dev.yml ps

# 3. 构建并启动应用
mvn -B clean package -DskipTests=true
source .env.local
java -Dserver.port=8080 -jar spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar
```

---

## 方案二：手动安装

### Step 1：安装 JDK 17

```bash
# Ubuntu
sudo apt-get install -y openjdk-17-jdk-headless

# macOS
brew install openjdk@17

# 验证
java -version  # 应显示 17.x
```

### Step 2：安装 Maven

```bash
# Ubuntu
sudo apt-get install -y maven

# macOS
brew install maven

# 验证
mvn -version
```

### Step 3：安装 MySQL 8.0

```bash
# Ubuntu
sudo apt-get install -y mysql-server mysql-client
sudo systemctl start mysql

# macOS
brew install mysql@8.0
brew services start mysql@8.0

# 创建数据库和用户
mysql -u root -e "
  CREATE DATABASE IF NOT EXISTS admin DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
  CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED BY 'admin';
  GRANT ALL PRIVILEGES ON admin.* TO 'admin'@'localhost';
  FLUSH PRIVILEGES;
"

# 初始化表结构
mysql -u root admin < docker/middleware/init/mysql/admin-schema.sql
mysql -u root admin < docker/middleware/init/mysql/agentscope-schema.sql

# 验证
mysql -u root -e "SHOW TABLES FROM admin"  # 应显示 27 张表
```

### Step 4：安装 Redis

```bash
# Ubuntu
sudo apt-get install -y redis-server
sudo systemctl start redis-server

# macOS
brew install redis
brew services start redis

# 验证
redis-cli ping  # 应返回 PONG
```

### Step 5：安装 Elasticsearch 9.1

```bash
# 下载
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.1.2-linux-x86_64.tar.gz
tar -xzf elasticsearch-9.1.2-linux-x86_64.tar.gz

# 配置（单节点模式）
cat > elasticsearch-9.1.2/config/elasticsearch.yml <<EOF
cluster.name: es-cluster
node.name: es-node-1
discovery.type: single-node
xpack.security.enabled: false
network.host: 127.0.0.1
http.port: 9200
EOF

# 启动（不能用 root 用户）
cd elasticsearch-9.1.2
bin/elasticsearch -d

# 验证
curl http://localhost:9200/_cluster/health
```

初始化索引：

```bash
# 创建 pipeline
curl -X PUT "http://localhost:9200/_ingest/pipeline/parsing_loongsuite_traces" \
  -H "Content-Type: application/json" \
  -d '{"processors":[{"json":{"field":"contents.attribute","target_field":"attributes"}},{"json":{"field":"contents.resource","target_field":"resources"}},{"json":{"field":"contents.links","target_field":"spanLinks"}},{"json":{"field":"contents.logs","target_field":"spanEvents"}},{"remove":{"field":["contents.attribute","contents.resource","contents.links","contents.logs"]}},{"rename":{"field":"contents","target_field":"metadata"}},{"script":{"source":"Map usage = new HashMap();long total = 0;if (ctx.attributes.containsKey(\"gen_ai.usage.input_tokens\")) {long input = Long.parseLong(ctx.attributes[\"gen_ai.usage.input_tokens\"]);usage[\"input_tokens\"] = input;total = total + input;}if (ctx.attributes.containsKey(\"gen_ai.usage.output_tokens\")) {long output = Long.parseLong(ctx.attributes[\"gen_ai.usage.output_tokens\"]);usage[\"output_tokens\"] = output;total = total + output;}usage[\"total_tokens\"] = total;ctx.usage = usage;"}}]}'

# 创建索引（完整 JSON 见 docker/middleware/init/elasticsearch/init-indices.sh）
curl -X PUT "http://localhost:9200/loongsuite_traces" \
  -H "Content-Type: application/json" \
  -d '{"settings":{"index.default_pipeline":"parsing_loongsuite_traces"},"mappings":{"dynamic":"false","properties":{"metadata":{"type":"object"},"attributes":{"type":"flattened"},"resources":{"type":"flattened"},"usage":{"type":"object"}}}}'
```

### Step 6：安装 Nacos 3.x

> **注意**: Nacos 3.x 需要 JDK 21，不是 JDK 17。

```bash
# 下载
wget https://github.com/alibaba/nacos/releases/download/3.0.3/nacos-server-3.0.3.tar.gz
tar -xzf nacos-server-3.0.3.tar.gz

# 启动（必须用 JDK 21）
export JAVA_HOME=/path/to/jdk-21
bin/startup.sh -m standalone

# 验证（等待 30 秒）
curl http://localhost:8848/nacos/
```

### Step 7：安装 RocketMQ 5.3

```bash
# 下载
wget https://archive.apache.org/dist/rocketmq/5.3.2/rocketmq-all-5.3.2-bin-release.zip
unzip rocketmq-all-5.3.2-bin-release.zip
cd rocketmq-all-5.3.2-bin-release

# 启动 NameServer
nohup bin/mqnamesrv > /tmp/namesrv.log 2>&1 &

# 启动 Broker
nohup bin/mqbroker -n localhost:9876 > /tmp/broker.log 2>&1 &

# 创建 Topic
bin/mqadmin updateTopic -n localhost:9876 -t topic_saa_studio_document_index -c DefaultCluster
bin/mqadmin updateSubGroup -n localhost:9876 -g group_saa_studio_document_index -c DefaultCluster
```

---

## Step 8：构建项目

```bash
cd spring-ai-alibaba-admin

export JAVA_HOME=/path/to/jdk-17
mvn -B clean package -DskipTests=true

# 构建产物
ls spring-ai-alibaba-admin-server-start/target/*.jar
```

---

## Step 9：启动应用

```bash
export JAVA_HOME=/path/to/jdk-17
export SPRING_DATASOURCE_URL="jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai"
export SPRING_DATASOURCE_USERNAME=root
export SPRING_DATASOURCE_PASSWORD=root
export SPRING_REDIS_HOST=localhost
export SPRING_REDIS_PORT=6379
export SPRING_ELASTICSEARCH_URIS=http://localhost:9200
export SPRING_ELASTICSEARCH_URL=http://localhost:9200
export NACOS_SERVER_ADDR=localhost:8848
export ROCKETMQ_ENDPOINTS=localhost:18080
export MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT=http://localhost:4318/v1/traces

java -Dserver.port=8080 \
  -jar spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar
```

> **WSL2 用户注意**: 如果 8080 端口被占用，改用 `-Dserver.port=8081`。

---

## Step 10：启动前端（可选）

```bash
cd frontend
npm install
npm run build:flow   # 先构建 spark-flow 子包
npm run dev           # 启动开发服务器（默认 8000 端口）
```

前端会自动代理 `/api`、`/console` 请求到后端。

---

## 常见踩坑

### 1. MySQL: skip-grant-tables 导致 TCP 不可用

**现象**: `Access denied for user 'root'@'localhost' (using password: NO)`

**原因**: MySQL 8.0 的 `--skip-grant-tables` 会自动启用 `--skip_networking`，禁用 TCP 端口。

**解决**:
```bash
# 先通过 socket 设置密码
mysql -u root -S /tmp/mysql.sock -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root'; FLUSH PRIVILEGES;"

# 再去掉 skip-grant-tables 正常启动
```

### 2. ES: 应用连接的是 9200 但 ES 在 9201

**现象**: Trace 接口返回 500，日志显示 `TransportException: node: http://localhost:9200/`

**原因**: 项目有两个 ES 配置：
- `application.yml` 用 `spring.elasticsearch.uris`（环境变量 `SPRING_ELASTICSEARCH_URIS`）
- `elasticsearch.yml` 用 `spring.elasticsearch.url`（环境变量 `SPRING_ELASTICSEARCH_URL`）

**解决**: 两个都要设：
```bash
export SPRING_ELASTICSEARCH_URIS=http://localhost:9201
export SPRING_ELASTICSEARCH_URL=http://localhost:9201
```

### 3. Nacos: Empty identity 错误

**现象**: `errCode: 50002, errMsg: Empty identity`

**原因**: Nacos 3.x 要求显式配置认证信息。

**解决**: 启动时加 `-D` 参数：
```bash
-Dnacos.core.auth.server.identity.key=admin
-Dnacos.core.auth.server.identity.value=admin
-Dnacos.core.auth.plugin.nacos.token.secret.key=VGhpc0lzTXlDdXN0b21TZWNyZXRLZXkwMTIzNDU2Nzg=
```

### 4. Nacos: JDK 版本不兼容

**现象**: `NoClassDefFoundError: Could not initialize class ...TopNConfig`

**原因**: Nacos 3.x 需要 JDK 21+，不兼容 JDK 17。

**解决**: Nacos 用 JDK 21 启动，应用用 JDK 17。

### 5. 构建: Lombok 枚举构造器不生成

**现象**: `constructor ToolCallType in enum cannot be applied to given types; required: no arguments`

**原因**: `maven-compiler-plugin` 未配置 Lombok 注解处理器。

**解决**: 在 `pom.xml` 的 compiler plugin 中添加：
```xml
<annotationProcessorPaths>
  <path>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <version>${lombok.version}</version>
  </path>
</annotationProcessorPaths>
```

### 6. 应用启动后被 shell 杀掉

**现象**: `nohup java -jar app.jar &` 后进程消失。

**解决**: 用 `disown` 脱离 shell：
```bash
java -jar app.jar > /tmp/app.log 2>&1 &
disown $!
```

### 7. WSL2 端口冲突

**现象**: `Bind on TCP/IP port: Address already in use`，但 `ss -tlnp` 看不到占用。

**原因**: WSL2 中端口被 Windows 侧进程占用。

**解决**: 换端口（MySQL 用 13306，应用用 8081）。

---

## 验证清单

启动完成后，逐项检查：

```bash
# 1. 中间件状态
bash scripts/deps-status.sh

# 2. 应用健康检查
curl http://localhost:8080/console/v1/system/health
# 预期: ok

# 3. 登录接口
curl -X POST http://localhost:8080/console/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"saa","password":"123456"}'
# 预期: code 200, 返回 access_token

# 4. Prompt 列表
curl http://localhost:8080/api/prompts?current=1&size=10
# 预期: code 200

# 5. Dataset 列表
curl http://localhost:8080/api/dataset/datasets?current=1&size=10
# 预期: code 200

# 6. Evaluator 列表
curl http://localhost:8080/api/evaluator/evaluators?current=1&size=10
# 预期: code 200

# 7. Trace 列表（需要 startTime/endTime）
curl "http://localhost:8080/api/observability/traces?pageNumber=1&pageSize=10&startTime=2026-01-01T00:00:00.000Z&endTime=2026-12-31T23:59:59.000Z"
# 预期: code 200

# 8. 前端页面（如果启动了）
curl -sf http://localhost:8000/ | grep "<title>"
# 预期: <title>SAA</title>
```

---

## 端口速查

| 服务 | 默认端口 | WSL2 建议端口 | 说明 |
|------|----------|---------------|------|
| Admin 应用 | 8080 | 8081 | `-Dserver.port=` 指定 |
| 前端 | 8000 | 8000 | `npm run dev` |
| MySQL | 3306 | 13306 | `my.cnf` 中 `port=` |
| Redis | 6379 | 6380 | `--port` 参数 |
| Elasticsearch | 9200 | 9201 | `elasticsearch.yml` 中 `http.port` |
| Nacos | 8848 | 8848 | `--server.port=` |
| RocketMQ NameServer | 9876 | 9876 | |
| RocketMQ Broker | 10911 | 10911 | |
| RocketMQ Proxy | 18080 | 18080 | |

---

## 相关文档

- [API 接口清单](api-list.md) — 212 个接口完整列表
- [安装日志](../scripts/install-log.md) — 每个中间件的安装过程
- [启动日志](startup-log.md) — 构建和启动的踩坑记录
- [冒烟测试结果](smoke-test-result.md) — 5 个核心接口测试结果
- [环境检查手册](env-checklist.md) — 外部依赖版本和端口清单
