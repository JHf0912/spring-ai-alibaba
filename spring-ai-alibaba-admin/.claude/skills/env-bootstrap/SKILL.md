---
name: env-bootstrap
description: >
  一键搭建 Spring AI Alibaba Admin 本地开发环境。
  覆盖依赖盘点、中间件安装、启停脚本、编译启动、接口冒烟测试全流程。
  触发场景：新接手项目、重置环境、定期验证环境健康。
allowed-tools:
  - Read
  - Bash
  - Write
---

# env-bootstrap — 本地环境搭建 Skill

## 触发条件

用户说出以下意图时触发：

- "帮我搭环境" / "新电脑怎么跑起来"
- "环境重置" / "重新装一遍"
- "检查环境是否正常" / "环境健康检查"
- "跑一下冒烟测试"

## 执行流程

按顺序执行 5 个阶段，每阶段完成后再进入下一阶段。
任何阶段失败时，先自主修复（最多重试 3 次同类型错误），3 次仍失败则停下来汇报。

---

### Phase 1：依赖盘点

**目标**: 确认当前环境缺什么，决定安装策略。

```bash
# 检查 OS
uname -s && uname -r && uname -m

# 检查 JDK
java -version 2>&1 || echo "JDK: 未安装"

# 检查 Maven
mvn -version 2>&1 | head -1 || echo "Maven: 未安装"

# 检查 Node.js（前端需要）
node --version 2>&1 || echo "Node: 未安装"

# 检查 Docker
docker --version 2>&1 || echo "Docker: 未安装"

# 检查 sudo 权限
sudo -n true 2>&1 && echo "sudo: 可用" || echo "sudo: 不可用"

# 检查端口占用
ss -tlnp 2>/dev/null | grep -E "3306|6379|8080|8848|9200|9876" || echo "端口: 全部空闲"

# 检查已有安装
ls ~/.saa-middleware/ 2>/dev/null || echo "安装目录: 不存在"
```

**决策**:

| 条件 | 策略 |
|------|------|
| 有 Docker | 优先用 `docker-compose.dev.yml` |
| 有 sudo | 用 `apt`/`brew` 安装 |
| 无 sudo 无 Docker | 全部 tarball 装到 `~/.saa-middleware/` |

记录到 `docs/startup-log.md`。

---

### Phase 2：安装中间件

**目标**: 6 个中间件全部就绪。

按依赖顺序安装：JDK → Maven → MySQL → Redis → Elasticsearch → Nacos → RocketMQ。

#### 2.1 JDK 17（构建用）

```bash
# Ubuntu with sudo
sudo apt-get install -y openjdk-17-jdk-headless

# 无 sudo：下载 Temurin tarball
curl -L -o /tmp/jdk17.tar.gz \
  "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.13%2B11/OpenJDK17U-jdk_x64_linux_hotspot_17.0.13_11.tar.gz"
mkdir -p ~/.saa-middleware/jdk-17
tar -xzf /tmp/jdk17.tar.gz -C ~/.saa-middleware/jdk-17 --strip-components=1
export JAVA_HOME=~/.saa-middleware/jdk-17
```

#### 2.2 JDK 21（Nacos 3.x 需要）

```bash
curl -L -o /tmp/jdk21.tar.gz \
  "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jdk_x64_linux_hotspot_21.0.6_7.tar.gz"
mkdir -p ~/.saa-middleware/jdk-21
tar -xzf /tmp/jdk21.tar.gz -C ~/.saa-middleware/jdk-21 --strip-components=1
```

#### 2.3 Maven

```bash
curl -L -o /tmp/maven.tar.gz \
  "https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz"
mkdir -p ~/.saa-middleware/maven
tar -xzf /tmp/maven.tar.gz -C ~/.saa-middleware/maven --strip-components=1
```

#### 2.4 MySQL 8.0

```bash
# 有 sudo
sudo apt-get install -y mysql-server mysql-client
sudo systemctl start mysql
mysql -u root -e "CREATE DATABASE IF NOT EXISTS admin DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
mysql -u root admin < docker/middleware/init/mysql/admin-schema.sql
mysql -u root admin < docker/middleware/init/mysql/agentscope-schema.sql
```

无 sudo 时：下载 MySQL generic binary tarball 到 `~/.saa-middleware/mysql`，
需要额外下载 `libaio.so.1`、`libnuma.so.1` 等共享库到 `~/.saa-middleware/lib/`。
详见 `scripts/install-log.md`。

**关键踩坑**: MySQL 8.0 的 `--skip-grant-tables` 会自动启用 `--skip_networking`，
导致 TCP 连接不可用。正确做法：先用 socket 设密码，再去掉该选项。

#### 2.5 Redis

```bash
# 有 sudo
sudo apt-get install -y redis-server
sudo systemctl start redis-server

# 无 sudo：用 apt download 提取 deb 中的二进制
cd /tmp && apt download redis-server redis-tools liblzf1 libjemalloc2
mkdir -p redis-extract
dpkg-deb -x redis-server_*.deb redis-extract/
dpkg-deb -x redis-tools_*.deb redis-extract/
cp redis-extract/usr/bin/redis-server ~/.saa-middleware/redis/bin/
cp redis-extract/usr/bin/redis-cli ~/.saa-middleware/redis/bin/
```

#### 2.6 Elasticsearch 9.1

```bash
curl -L -o /tmp/es.tar.gz \
  "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.1.2-linux-x86_64.tar.gz"
tar -xzf /tmp/es.tar.gz -C ~/.saa-middleware/

# 配置单节点
cat > ~/.saa-middleware/elasticsearch-9.1.2/config/elasticsearch.yml <<EOF
cluster.name: es-cluster
node.name: es-node-1
discovery.type: single-node
xpack.security.enabled: false
network.host: 127.0.0.1
http.port: 9200
EOF

# 启动（不能用 root）
~/.saa-middleware/elasticsearch-9.1.2/bin/elasticsearch -d
```

启动后需执行 `docker/middleware/init/elasticsearch/init-indices.sh` 中的
pipeline 和索引创建命令。

#### 2.7 Nacos 3.x

```bash
curl -L -o /tmp/nacos.tar.gz \
  "https://github.com/alibaba/nacos/releases/download/3.0.3/nacos-server-3.0.3.tar.gz"
tar -xzf /tmp/nacos.tar.gz -C ~/.saa-middleware/
```

**关键踩坑**:
- Nacos 3.x **必须用 JDK 21**，JDK 17 会报 `NoClassDefFoundError`
- 必须配置 identity 和 token secret key，否则启动失败
- 配置文件实际读取路径是 `$HOME/nacos/conf/`，不是安装目录

```bash
# 启动命令
~/.saa-middleware/jdk-21/bin/java -Xms256m -Xmx512m \
  -Dnacos.standalone=true \
  -Dnacos.core.auth.server.identity.key=admin \
  -Dnacos.core.auth.server.identity.value=admin \
  -Dnacos.core.auth.plugin.nacos.token.secret.key=VGhpc0lzTXlDdXN0b21TZWNyZXRLZXkwMTIzNDU2Nzg= \
  -jar ~/.saa-middleware/nacos/target/nacos-server.jar \
  --server.port=8848
```

#### 2.8 RocketMQ 5.3

```bash
curl -L -o /tmp/rocketmq.zip \
  "https://archive.apache.org/dist/rocketmq/5.3.2/rocketmq-all-5.3.2-bin-release.zip"
unzip /tmp/rocketmq.zip -d ~/.saa-middleware/

# 启动 NameServer + Broker
cd ~/.saa-middleware/rocketmq-all-5.3.2-bin-release
nohup bin/mqnamesrv > /tmp/namesrv.log 2>&1 &
sleep 5
nohup bin/mqbroker -n localhost:9876 > /tmp/broker.log 2>&1 &

# 创建 Topic
bin/mqadmin updateTopic -n localhost:9876 -t topic_saa_studio_document_index -c DefaultCluster
bin/mqadmin updateSubGroup -n localhost:9876 -g group_saa_studio_document_index -c DefaultCluster
```

**关键踩坑**: 启动时 `JAVA_HOME` 必须在环境中，`nohup` 不能继承未 export 的变量。
用 `env JAVA_HOME=... nohup ...` 或确保已 export。

---

### Phase 3：启停脚本

**目标**: 验证一键启停脚本可用。

```bash
# 查看状态
bash scripts/deps-status.sh

# 一键启动
bash scripts/deps-start.sh

# 一键停止
bash scripts/deps-stop.sh
```

如果某个服务启动失败，检查：
1. 端口是否被占用：`ss -tlnp | grep <port>`
2. 日志：`/tmp/rocketmq/logs/`、`~/.saa-middleware/mysql.log`、`~/.saa-middleware/es.log`
3. 依赖库：`LD_LIBRARY_PATH` 是否包含 `~/.saa-middleware/lib`

---

### Phase 4：编译启动

**目标**: `mvn clean package` 成功，应用启动并响应请求。

#### 4.1 构建

```bash
export JAVA_HOME=~/.saa-middleware/jdk-17
export PATH=$JAVA_HOME/bin:~/.saa-middleware/maven/bin:$PATH

cd spring-ai-alibaba-admin
mvn -B clean package -DskipTests=true
```

**常见构建错误**:

| 错误 | 原因 | 修复 |
|------|------|------|
| Lombok 枚举构造器不生成 | compiler plugin 缺 annotationProcessorPaths | pom.xml 添加配置 |
| `ToolExample.java` 包名错误 | 文件内容被替换为文档示例代码 | 恢复为正确数据类 |
| `package does not exist` | 上游模块未构建 | 用 `-am` 参数构建依赖链 |

#### 4.2 启动应用

```bash
export JAVA_HOME=~/.saa-middleware/jdk-17
export PATH=$JAVA_HOME/bin:$PATH
export LD_LIBRARY_PATH=~/.saa-middleware/lib:$LD_LIBRARY_PATH

# 数据库（按实际端口调整）
export SPRING_DATASOURCE_URL="jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai"
export SPRING_DATASOURCE_USERNAME=root
export SPRING_DATASOURCE_PASSWORD=root

# Redis
export SPRING_REDIS_HOST=localhost
export SPRING_REDIS_PORT=6379

# Elasticsearch（注意两个都要设）
export SPRING_ELASTICSEARCH_URIS=http://localhost:9200
export SPRING_ELASTICSEARCH_URL=http://localhost:9200

# Nacos & RocketMQ
export NACOS_SERVER_ADDR=localhost:8848
export ROCKETMQ_ENDPOINTS=localhost:18080

# OTLP（必须，否则启动报 placeholder 错误）
export MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT=http://localhost:4318/v1/traces

# 启动
java -Dserver.port=8080 \
  -jar spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar
```

**关键踩坑**:
- `SPRING_ELASTICSEARCH_URL` 和 `SPRING_ELASTICSEARCH_URIS` 是**两个不同属性**，
  分别被 `elasticsearch.yml` 和 `application.yml` 使用，都要设。
- `MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT` 是必填项，缺失会直接启动失败。
- WSL2 中 8080/3306/9200 可能被 Windows 进程占用，需换端口。

#### 4.3 启动前端（可选）

```bash
cd frontend
npm install
npm run build:flow   # 必须先构建 spark-flow
npm run dev           # 默认 8000 端口
```

---

### Phase 5：接口冒烟

**目标**: 5 个核心接口全部返回 200。

```bash
BASE=http://localhost:8080

# 1. 登录
curl -sf -o /dev/null -w "Login:     HTTP %{http_code}\n" \
  -X POST "$BASE/console/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"saa","password":"123456"}'

# 2. Prompt 列表
curl -sf -o /dev/null -w "Prompt:    HTTP %{http_code}\n" \
  "$BASE/api/prompts?current=1&size=10"

# 3. Dataset 列表
curl -sf -o /dev/null -w "Dataset:   HTTP %{http_code}\n" \
  "$BASE/api/dataset/datasets?current=1&size=10"

# 4. Evaluator 列表
curl -sf -o /dev/null -w "Evaluator: HTTP %{http_code}\n" \
  "$BASE/api/evaluator/evaluators?current=1&size=10"

# 5. Trace 列表（需要时间参数）
curl -sf -o /dev/null -w "Trace:     HTTP %{http_code}\n" \
  "$BASE/api/observability/traces?pageNumber=1&pageSize=10&startTime=2026-01-01T00:00:00.000Z&endTime=2026-12-31T23:59:59.000Z"
```

预期结果：

| 接口 | HTTP | 说明 |
|------|------|------|
| Login | 200 | 返回 access_token |
| Prompt | 200 | 空列表正常 |
| Dataset | 200 | 空列表正常 |
| Evaluator | 200 | 含预置模板 |
| Trace | 200 | 空列表正常（无 trace 数据） |

---

## 输出物

执行完成后，生成以下文件：

| 文件 | 内容 |
|------|------|
| `docs/startup-log.md` | 每阶段遇到的问题和修复过程 |
| `docs/smoke-test-result.md` | 5 个接口的测试结果 |

---

## 端口速查

| 服务 | 默认端口 | WSL2 建议 | 环境变量 |
|------|----------|-----------|----------|
| MySQL | 3306 | 13306 | `SPRING_DATASOURCE_URL` |
| Redis | 6379 | 6380 | `SPRING_REDIS_PORT` |
| Elasticsearch | 9200 | 9201 | `SPRING_ELASTICSEARCH_URL` + `SPRING_ELASTICSEARCH_URIS` |
| Nacos | 8848 | 8848 | `NACOS_SERVER_ADDR` |
| RocketMQ | 9876/10911/18080 | 同左 | `ROCKETMQ_ENDPOINTS` |
| Admin 应用 | 8080 | 8081 | `-Dserver.port=` |
| 前端 | 8000 | 8000 | — |

---

## 快速回退

如果环境彻底损坏，一键清理：

```bash
# 停止所有服务
bash scripts/deps-stop.sh

# 删除安装目录（数据全丢）
rm -rf ~/.saa-middleware

# 删除构建产物
mvn -f spring-ai-alibaba-admin/pom.xml clean

# 重新开始
# 触发本 Skill 即可
```

---

## 参考文档

- `docs/env-checklist.md` — 外部依赖版本和端口清单
- `docs/api-list.md` — 212 个 API 接口完整列表
- `scripts/install-log.md` — 中间件安装详细日志
- `docs/startup-log.md` — 构建启动踩坑记录
- `docs/smoke-test-result.md` — 冒烟测试结果
- `scripts/deps-start.sh` / `deps-stop.sh` / `deps-status.sh` — 启停管理脚本
- `docker-compose.dev.yml` — Docker 一键启动方案
