# 踩坑记录与解决方案 — Spring AI Alibaba Admin

> 知识沉淀文档。记录从环境搭建到 CI 跑通全过程中的所有问题、根因分析和验证过的解决方案。
>
> 最后更新: 2026-05-22

---

## 目录

1. [前置条件](#1-前置条件)
2. [中间件安装步骤](#2-中间件安装步骤)
3. [应用构建踩坑](#3-应用构建踩坑)
4. [应用启动踩坑](#4-应用启动踩坑)
5. [中间件踩坑](#5-中间件踩坑)
6. [CI/CD 踩坑](#6-cicd-踩坑)
7. [测试踩坑](#7-测试踩坑)
8. [验证清单](#8-验证清单)
9. [环境变量速查](#9-环境变量速查)
10. [端口分配表](#10-端口分配表)

---

## 1. 前置条件

| 项目 | 要求 | 检查命令 |
|------|------|----------|
| JDK | 17（构建 + 运行） | `java -version` |
| JDK | 21（仅 Nacos 3.x 需要） | `java -version` |
| Maven | 3.8+ | `mvn -version` |
| 内存 | ≥ 8GB 可用 | `free -h` |
| 磁盘 | ≥ 5GB 可用 | `df -h` |
| Docker | 20.10+（CI 和 Docker 方案需要） | `docker --version` |
| Git | 2.30+ | `git --version` |

### 无 sudo 环境安装方案

所有依赖可安装到用户空间 `~/.saa-middleware/`，无需 root 权限：

```bash
# 一键安装脚本
bash scripts/install-deps.sh

# 或手动下载到 ~/.saa-middleware/
# 目录结构：
# ~/.saa-middleware/
# ├── jdk-17/          # Temurin 17
# ├── jdk-21/          # Temurin 21 (Nacos 专用)
# ├── maven/           # Maven 3.9.x
# ├── mysql/           # MySQL 8.0
# ├── redis/           # Redis 7.x
# ├── elasticsearch/   # ES 9.1
# ├── nacos/           # Nacos 3.0
# ├── rocketmq/        # RocketMQ 5.3
# └── lib/             # 共享库 (libaio, libnuma, etc.)
```

---

## 2. 中间件安装步骤

### 2.1 MySQL 8.0

```bash
# 安装
cd ~/.saa-middleware
tar -xzf mysql-8.0.x-linux-x86_64.tar.xz
ln -sf mysql-8.0.x-linux-x86_64 mysql

# 配置 (my.cnf)
cat > ~/.saa-middleware/my.cnf <<EOF
[mysqld]
port = 13306
socket = ~/.saa-middleware/mysql.sock
pid-file = ~/.saa-middleware/mysql.pid
datadir = ~/.saa-middleware/mysql/data
basedir = ~/.saa-middleware/mysql
skip-grant-tables
EOF

# 初始化
~/.saa-middleware/mysql/bin/mysqld --defaults-file=~/.saa-middleware/my.cnf --initialize-insecure

# 启动（skip-grant-tables 模式）
~/.saa-middleware/mysql/bin/mysqld --defaults-file=~/.saa-middleware/my.cnf &

# 设置密码（通过 socket，见踩坑 #1）
~/.saa-middleware/mysql/bin/mysql -u root -S ~/.saa-middleware/mysql.sock -e \
  "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root'; FLUSH PRIVILEGES;"

# 停掉，去掉 skip-grant-tables，重启
# 编辑 my.cnf 删除 skip-grant-tables 行
~/.saa-middleware/mysql/bin/mysqld --defaults-file=~/.saa-middleware/my.cnf &

# 创建数据库
~/.saa-middleware/mysql/bin/mysql -u root -proot -P 13306 -e \
  "CREATE DATABASE IF NOT EXISTS admin DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

# 导入 Schema
~/.saa-middleware/mysql/bin/mysql -u root -proot -P 13306 admin < docker/middleware/init/mysql/admin-schema.sql
~/.saa-middleware/mysql/bin/mysql -u root -proot -P 13306 admin < docker/middleware/init/mysql/agentscope-schema.sql
```

### 2.2 Redis

```bash
cd ~/.saa-middleware
tar -xzf redis-7.x.tar.gz
ln -sf redis-7.x redis

# 启动
~/.saa-middleware/redis/src/redis-server --port 6380 --daemonize yes

# 验证
~/.saa-middleware/redis/src/redis-cli -p 6380 ping  # PONG
```

### 2.3 Elasticsearch 9.1

```bash
cd ~/.saa-middleware
tar -xzf elasticsearch-9.1.2-linux-x86_64.tar.gz
ln -sf elasticsearch-9.1.2 elasticsearch

# 配置
cat >> ~/.saa-middleware/elasticsearch/config/elasticsearch.yml <<EOF
cluster.name: es-cluster
node.name: es-node-1
discovery.type: single-node
xpack.security.enabled: false
network.host: 127.0.0.1
http.port: 9201
EOF

# 启动（不能用 root 用户）
~/.saa-middleware/elasticsearch/bin/elasticsearch -d

# 初始化索引
curl -X PUT "http://localhost:9201/_ingest/pipeline/parsing_loongsuite_traces" \
  -H "Content-Type: application/json" \
  -d '{"processors":[{"json":{"field":"contents.attribute","target_field":"attributes"}},{"json":{"field":"contents.resource","target_field":"resources"}},{"json":{"field":"contents.links","target_field":"spanLinks"}},{"json":{"field":"contents.logs","target_field":"spanEvents"}},{"remove":{"field":["contents.attribute","contents.resource","contents.links","contents.logs"]}},{"rename":{"field":"contents","target_field":"metadata"}},{"script":{"source":"Map usage = new HashMap();long total = 0;if (ctx.attributes.containsKey(\"gen_ai.usage.input_tokens\")) {long input = Long.parseLong(ctx.attributes[\"gen_ai.usage.input_tokens\"]);usage[\"input_tokens\"] = input;total = total + input;}if (ctx.attributes.containsKey(\"gen_ai.usage.output_tokens\")) {long output = Long.parseLong(ctx.attributes[\"gen_ai.usage.output_tokens\"]);usage[\"output_tokens\"] = output;total = total + output;}usage[\"total_tokens\"] = total;ctx.usage = use;"}}]}'

curl -X PUT "http://localhost:9201/loongsuite_traces" \
  -H "Content-Type: application/json" \
  -d '{"settings":{"index.default_pipeline":"parsing_loongsuite_traces"},"mappings":{"dynamic":"false","properties":{"metadata":{"type":"object"},"attributes":{"type":"flattened"},"resources":{"type":"flattened"},"usage":{"type":"object"}}}}'
```

### 2.4 Nacos 3.0

> **关键**: Nacos 3.x 要求 JDK 21，不能用 JDK 17。

```bash
cd ~/.saa-middleware
tar -xzf nacos-server-3.0.3.tar.gz
ln -sf nacos-server-3.0.3 nacos

# 配置 identity 和 token
cat >> ~/.saa-middleware/nacos/conf/application.properties <<EOF
nacos.core.auth.server.identity.key=admin
nacos.core.auth.server.identity.value=admin
nacos.core.auth.plugin.nacos.token.secret.key=VGhpc0lzTXlDdXN0b21TZWNyZXRLZXkwMTIzNDU2Nzg=
EOF

# 用 JDK 21 启动
export JAVA_HOME=~/.saa-middleware/jdk-21
~/.saa-middleware/nacos/bin/startup.sh -m standalone

# 验证（等 30 秒）
curl http://localhost:8848/nacos/
```

### 2.5 RocketMQ 5.3

```bash
cd ~/.saa-middleware
unzip rocketmq-all-5.3.2-bin-release.zip
ln -sf rocketmq-all-5.3.2-bin-release rocketmq

# 启动 NameServer
export JAVA_HOME=~/.saa-middleware/jdk-17
nohup ~/.saa-middleware/rocketmq/bin/mqnamesrv > /tmp/namesrv.log 2>&1 &

# 启动 Broker
nohup ~/.saa-middleware/rocketmq/bin/mqbroker -n localhost:9876 > /tmp/broker.log 2>&1 &

# 创建 Topic（应用需要）
~/.saa-middleware/rocketmq/bin/mqadmin updateTopic -n localhost:9876 \
  -t topic_saa_studio_document_index -c DefaultCluster
~/.saa-middleware/rocketmq/bin/mqadmin updateSubGroup -n localhost:9876 \
  -g group_saa_studio_document_index -c DefaultCluster

# 启动 Proxy
nohup ~/.saa-middleware/rocketmq/bin/mqproxy -n localhost:9876 > /tmp/proxy.log 2>&1 &
```

---

## 3. 应用构建踩坑

### 踩坑 #1: Lombok `@AllArgsConstructor` 枚举构造器不生成

**症状**:
```
constructor ToolCallType in enum cannot be applied to given types;
  required: no arguments
  found:    java.lang.String
```

**根因**: `maven-compiler-plugin` 未配置 Lombok 注解处理器路径。默认情况下 `annotationProcessorPaths` 为空，Lombok 的 `@AllArgsConstructor` 注解不会被处理。

**解决方案**: 在根 `pom.xml` 的 `maven-compiler-plugin` 中添加：

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-compiler-plugin</artifactId>
  <configuration>
    <annotationProcessorPaths>
      <path>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <version>${lombok.version}</version>
      </path>
    </annotationProcessorPaths>
  </configuration>
</plugin>
```

同时升级 Lombok 到 1.18.34+。

**验证**: `mvn clean compile` 不再报构造器错误。

---

### 踩坑 #2: ToolExample.java 文件内容被替换

**症状**:
```
class ToolsExample is public, should be declared in a file named ToolsExample.java
package com.alibaba.cloud.ai.dashscope.api does not exist
```

**根因**: `admin-server-runtime` 模块中的 `ToolExample.java` 被错误替换为文档示例代码（`ToolsExample` 类），包名错误且导入了不存在的依赖。

**解决方案**: 恢复文件为正确的数据类：

```java
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ToolExample {
    private String description;
    private String input;
    private String output;
}
```

**验证**: `mvn -pl :spring-ai-alibaba-admin-server-runtime compile` 成功。

---

### 踩坑 #3: 环境变量用 `-D` 传递不生效

**症状**:
```
Could not resolve placeholder 'MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT'
```

**根因**: YAML 配置文件中使用 `${VAR}` 占位符，需要操作系统级环境变量。Java 系统属性（`-D` 标志）和环境变量是两套不同的机制：
- `-Dfoo=bar` 设置的是 `System.getProperty("foo")`
- `${SPRING_DATASOURCE_URL}` 需要 `System.getenv("SPRING_DATASOURCE_URL")`

Spring Boot 的 `${VAR}` 占位符优先读环境变量，其次读系统属性。但 YAML 中如果写的是 `${SPRING_DATASOURCE_URL}`，`-Dspring.datasource.url=xxx` 并不等价。

**解决方案**: 使用 `export` 设置环境变量：

```bash
export SPRING_DATASOURCE_URL="jdbc:mysql://localhost:3306/admin?..."
export MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT="http://localhost:4318/v1/traces"
```

**注意**: CI 中 `env:` 块等价于 `export`，但如果 YAML key 和 Java property name 不同（如 `SPRING_DATASOURCE_URL` vs `spring.datasource.url`），必须匹配 YAML 中的占位符名。

---

## 4. 应用启动踩坑

### 踩坑 #4: 应用端口 8080 被占用（WSL2）

**症状**:
```
Web server failed to start. Port 8080 was already in use.
```

**根因**: WSL2 环境中端口 8080 被 Windows 侧进程占用，`ss -tlnp` 在 Linux 侧看不到占用者。

**解决方案**: 使用其他端口启动应用：

```bash
java -Dserver.port=8081 -jar spring-ai-alibaba-admin-server-start/target/*.jar
```

---

### 踩坑 #5: 应用进程被 shell 杀掉

**症状**: `nohup java -jar app.jar &` 后进程消失。

**根因**: 某些 shell 环境下，后台进程在 shell 退出时收到 SIGHUP。

**解决方案**: 使用 `disown` 脱离 shell：

```bash
java -jar app.jar > /tmp/app.log 2>&1 &
disown $!
```

或在 CI 中直接用 `&` + PID 文件管理（CI 的 step 不会提前退出）。

---

## 5. 中间件踩坑

### 踩坑 #6: MySQL `--skip-grant-tables` 导致 TCP 不可用

**症状**:
```
Access denied for user 'root'@'localhost' (using password: NO)
```
或通过 TCP 连接时 `Can't connect to MySQL server on 'localhost'`。

**根因**: MySQL 8.0 的 `--skip-grant-tables` 模式会**自动启用 `--skip_networking`**，禁用所有 TCP 连接，只允许 socket 连接。这是安全设计，防止未认证的远程连接。

**解决方案**: 分两步走：

```bash
# Step 1: 用 skip-grant-tables 启动（仅 socket 可用）
mysqld --skip-grant-tables &

# Step 2: 通过 socket 设置密码
mysql -u root -S /path/to/mysql.sock -e \
  "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root'; FLUSH PRIVILEGES;"

# Step 3: 停掉，去掉 skip-grant-tables，正常启动
kill %1
# 编辑 my.cnf 删除 skip-grant-tables
mysqld --defaults-file=my.cnf &
```

**验证**: `mysql -u root -proot -h 127.0.0.1 -P 13306 -e "SELECT 1"` 成功。

---

### 踩坑 #7: Nacos 3.x 要求 JDK 21

**症状**:
```
NoClassDefFoundError: Could not initialize class ...TopNConfig
```

**根因**: Nacos 3.x 使用了 JDK 21 的新 API（如 `SequencedCollection`），JDK 17 缺少这些类。

**解决方案**: Nacos 单独用 JDK 21 启动，应用用 JDK 17。两个 JDK 可以共存：

```bash
# Nacos
export JAVA_HOME=~/.saa-middleware/jdk-21
nacos/bin/startup.sh -m standalone

# 应用
export JAVA_HOME=~/.saa-middleware/jdk-17
java -jar app.jar
```

---

### 踩坑 #8: Nacos "Empty identity" 错误

**症状**:
```
errCode: 50002, errMsg: Empty identity
```

**根因**: Nacos 3.x 默认开启身份验证，必须配置 `identity.key` 和 `identity.value`。

**解决方案**: 在 `application.properties` 中设置：

```properties
nacos.core.auth.server.identity.key=admin
nacos.core.auth.server.identity.value=admin
```

或启动时通过 `-D` 传递（注意：这是 Nacos 自身的 JVM 参数，不是应用的）。

---

### 踩坑 #9: Nacos token secret key 错误

**症状**:
```
Caused by: java.lang.IllegalArgumentException: The length of the secret key must be at least 32 bytes
```

**根因**: Nacos 3.x 要求 token 密钥至少 32 字节（Base64 编码后至少 44 字符）。

**解决方案**: 使用合法的 Base64 密钥：

```properties
nacos.core.auth.plugin.nacos.token.secret.key=VGhpc0lzTXlDdXN0b21TZWNyZXRLZXkwMTIzNDU2Nzg=
```

---

### 踩坑 #10: WSL2 端口冲突（MySQL/ES/应用）

**症状**: `Bind on TCP/IP port: Address already in use`，但 Linux 侧 `ss -tlnp` 看不到占用。

**根因**: WSL2 共享 Windows 网络栈，Windows 侧进程可能占用相同端口。

**解决方案**: 改用非标准端口：

| 服务 | 默认端口 | WSL2 建议端口 |
|------|----------|---------------|
| MySQL | 3306 | 13306 |
| Redis | 6379 | 6380 |
| Elasticsearch | 9200 | 9201 |
| Admin 应用 | 8080 | 8081 |

---

### 踩坑 #11: 缺少共享库（libaio, libnuma, libncurses）

**症状**:
```
error while loading shared libraries: libaio.so.1
error while loading shared libraries: libnuma.so.1
error while loading shared libraries: libncurses.so.5
error while loading shared libraries: libtinfo.so.5
```

**根因**: MySQL 和 ES 依赖系统库，在最小化安装的 WSL2 环境中缺失。

**解决方案**: 下载 deb 包提取 .so 文件到 `~/.saa-middleware/lib/`：

```bash
# 从 Aliyun 镜像下载 deb
wget http://mirrors.aliyun.com/ubuntu/pool/main/liba/libaio/libaio1_0.3.112-13build1_amd64.deb
dpkg -x libaio1_*.deb /tmp/libaio
cp /tmp/libaio/lib/x86_64-linux-gnu/libaio.so.1* ~/.saa-middleware/lib/

# ncurses5 兼容：创建符号链接指向 ncurses6
ln -sf libncursesw.so.6 ~/.saa-middleware/lib/libncurses.so.5
ln -sf libtinfo.so.6 ~/.saa-middleware/lib/libtinfo.so.5

# 启动应用时设置
export LD_LIBRARY_PATH=~/.saa-middleware/lib:$LD_LIBRARY_PATH
```

---

## 6. CI/CD 踩坑

### 踩坑 #12: CI 中 `redis-cli` 命令不存在

**症状**:
```
Checking middleware...
Redis not ready
```

**根因**: GitHub Actions 的 `redis:7.2.5` 服务容器有 `redis-cli`，但 `nc` 更通用。某些镜像精简后没有 `redis-cli`。

**解决方案**: 用 `nc -z` 代替 `redis-cli ping`：

```yaml
- name: Verify middleware
  run: |
    nc -z localhost 6379 || { echo "Redis not ready"; exit 1; }
```

---

### 踩坑 #13: CI 中应用端口 8080 被占用

**症状**: 应用启动失败，`Connection refused`。

**根因**: GitHub Actions runner 上端口 8080 可能被其他服务占用。

**解决方案**: 始终使用 `-Dserver.port=8081`：

```yaml
java -Dserver.port=8081 -jar app.jar &
```

---

### 踩坑 #14: RocketMQ Proxy gRPC 服务未就绪

**症状**:
```
Expected the service ProducerImpl-0 [FAILED] to be RUNNING
Connection refused: localhost/127.0.0.1:18080
```

**根因**: RocketMQ 5.3 的 Proxy 组件有两层端口：
- 18080: remoting 端口（TCP 就绪快）
- 18081: gRPC 端口（需要额外初始化时间）

TCP 端口打开（`nc -z` 通过）不代表 gRPC 服务可用。Proxy 启动时先监听 TCP，再初始化 gRPC 服务端，中间有 10-30 秒的窗口期。

**解决方案**: 不仅检查端口，还要验证 Proxy 能处理实际请求：

```bash
# 等待 Proxy 端口打开
for i in $(seq 1 30); do
  nc -z localhost 18080 && break
  sleep 3
done

# 验证 Proxy 功能（不是仅端口）
for i in $(seq 1 30); do
  if docker exec saa-rmq-broker sh mqadmin topicList \
    -n saa-rmq-proxy:18080 2>/dev/null | grep -q "topic"; then
    echo "Proxy operational"
    break
  fi
  sleep 5
done
```

**备选方案**: 如果 Proxy 始终不稳定，可以绕过 Proxy，让应用直连 Broker：

```bash
# 不设置 ROCKETMQ_ENDPOINTS，或设置为空
export ROCKETMQ_ENDPOINTS=""
# 配置 namesrv 地址
export ROCKETMQ_NAMESRV_ADDR=localhost:9876
```

（需要修改应用配置支持 namesrv 直连模式）

---

### 踩坑 #15: CI 中应用进程启动后立即死亡

**症状**: `kill -0 $APP_PID` 检查失败，进程不存在。

**根因**: 应用启动过程中遇到致命错误（如中间件连接失败）导致 JVM 退出。

**解决方案**: 在启动等待循环中同时检查进程存活和健康接口：

```bash
APP_PID=$!
for i in $(seq 1 60); do
  # 先检查进程是否还活着
  if ! kill -0 $APP_PID 2>/dev/null; then
    echo "Application died during startup!"
    tail -100 /tmp/saa-admin.log
    exit 1
  fi
  # 再检查健康接口
  if curl -sf http://localhost:8081/console/v1/system/health 2>/dev/null | grep -q "ok"; then
    echo "Health check passed"
    break
  fi
  sleep 3
done
```

---

### 踩坑 #16: CI workflow 文件位置

**症状**: push 代码后 workflow 不触发。

**根因**: GitHub Actions 要求 workflow 文件在**仓库根目录**的 `.github/workflows/` 下。如果项目是 monorepo 的子目录，workflow 文件必须在根目录。

**解决方案**: 将 `test.yml` 放在仓库根目录的 `.github/workflows/` 下，用 `working-directory` 指定子模块路径：

```yaml
jobs:
  build:
    defaults:
      run:
        working-directory: spring-ai-alibaba-admin
    steps:
      - run: mvn -B clean package -DskipTests=true
```

---

### 踩坑 #17: CI 重复步骤名导致 YAML 解析异常

**症状**: workflow 文件语法错误，或步骤执行顺序混乱。

**根因**: YAML 中两个步骤使用了相同的 `name:` 值，某些解析器会合并或丢弃重复项。

**解决方案**: 确保每个步骤有唯一名称。如果两个步骤功能相同但阶段不同，加上阶段前缀：

```yaml
# 错误：两个都叫 "Run integration tests"
- name: Run integration tests  # 第一个
  run: mvn test ...
- name: Run integration tests  # 第二个 — 冲突！
  run: mvn test ...

# 正确：加阶段前缀
- name: Pre-flight check
  run: ...
- name: Run integration tests
  run: mvn test ...
```

---

### 踩坑 #18: Nacos Docker 容器需要认证参数

**症状**: Nacos 启动后返回 403 或 "authorization failed"。

**根因**: Nacos 3.x Docker 镜像默认开启认证，需要设置 token 和 identity 环境变量。

**解决方案**: Docker 启动时传入认证参数：

```yaml
docker run -d --name saa-nacos \
  -e NACOS_AUTH_TOKEN=dG9rZW5hbHNka2ZqbGFza2RqZmxhc2tkamZsYXNrZGpmb3dpZWpmbztzZGxm \
  -e NACOS_AUTH_IDENTITY_KEY=admin \
  -e NACOS_AUTH_IDENTITY_VALUE=admin \
  nacos/nacos-server:v3.0.3
```

---

### 踩坑 #19: ES 9.1 Docker 健康检查失败

**症状**: ES 服务容器始终显示 `starting`，不会变为 `healthy`。

**根因**: ES 9.1 启动慢（需要 30-60 秒），默认健康检查超时太短。

**解决方案**: 加大健康检查的启动等待时间：

```yaml
elasticsearch:
  options: >-
    --health-cmd="curl -sf http://localhost:9200/_cluster/health || exit 1"
    --health-interval=10s
    --health-timeout=5s
    --health-retries=15
    --health-start-period=60s
```

---

## 7. 测试踩坑

### 踩坑 #20: Characterization 测试需要运行中的应用

**症状**: `Connection refused: localhost/127.0.0.1:8081`。

**根因**: Characterization 测试（`*CharacterizationTest`）是集成测试，通过 HTTP 调用运行中的应用。它们不启动 Spring Context，需要外部应用实例。

**解决方案**:
- 本地：先启动应用，再运行测试
- CI：分两个 job（unit-test 排除 `*CharacterizationTest`，integration-test 只跑 `*CharacterizationTest`）

```yaml
# Job 1: 单元测试（排除集成测试）
- run: mvn test -Dtest='!*CharacterizationTest'

# Job 2: 集成测试（只跑集成测试）
- run: mvn test -Dtest='*CharacterizationTest'
```

---

### 踩坑 #21: 测试 BASE_URL 需要环境变量传递

**症状**: 测试连接 `localhost:8080` 但应用在 `8081`。

**根因**: 测试代码中 `BASE_URL` 默认值和实际端口不匹配。

**解决方案**: 通过环境变量覆盖：

```yaml
- name: Run integration tests
  env:
    TEST_BASE_URL: http://localhost:8081
  run: mvn test -Dtest='*CharacterizationTest'
```

测试代码中读取：

```java
private static final String BASE_URL =
    System.getenv().getOrDefault("TEST_BASE_URL", "http://localhost:8080");
```

---

### 踩坑 #22: Prompt 版本 `latestVersion` 空字符串 vs null

**症状**: `assertThat(prompt.getLatestVersion()).isNotNull()` 通过，但 `isEqualTo("v1")` 失败。

**根因**: 创建 Prompt 时 `latestVersion` 字段返回空字符串 `""` 而不是 `null`。创建版本后该字段才更新为实际版本号。

**解决方案**: Characterization 测试记录实际行为：

```java
// 创建 Prompt 时 latestVersion 是空字符串
assertThat(result.getLatestVersion()).isEqualTo("");

// 创建版本后才更新
assertThat(updatedPrompt.getLatestVersion()).isEqualTo("v1");
```

---

### 踩坑 #23: 重复创建版本会静默覆盖

**症状**: 创建两个同名版本，第二个不会报错，但数据被覆盖。

**根因**: API 实现使用 `INSERT ... ON DUPLICATE KEY UPDATE`，重复版本号不会报 409。

**解决方案**: 这是已知行为。Characterization 测试记录这个行为：

```java
// 创建版本 v1
createVersion("v1", "content-1");

// 再创建 v1 — 静默覆盖，不是 409
createVersion("v1", "content-2");

// 验证内容被覆盖
assertThat(getVersion("v1").getContent()).isEqualTo("content-2");
```

---

## 8. 验证清单

### 8.1 构建验证

```bash
# 构建成功
mvn -B clean package -DskipTests=true
# 预期: BUILD SUCCESS

# 产物存在
ls -la spring-ai-alibaba-admin-server-start/target/*.jar
# 预期: 446MB+ jar 文件
```

### 8.2 中间件验证

```bash
# MySQL
mysql -h 127.0.0.1 -P 13306 -u root -proot -e "SELECT 1"
# 预期: 1

# MySQL Schema
mysql -h 127.0.0.1 -P 13306 -u root -proot admin -e "SHOW TABLES"
# 预期: 27+ 表

# Redis
nc -z localhost 6380 && echo "OK"
# 预期: OK

# Elasticsearch
curl -sf http://localhost:9201/_cluster/health | jq .status
# 预期: "green" 或 "yellow"

# ES 索引
curl -sf http://localhost:9201/loongsuite_traces | jq '.["loongsuite_traces"].mappings'
# 预期: 有 mappings 定义

# Nacos
curl -sf http://localhost:8848/nacos/ && echo "OK"
# 预期: OK

# RocketMQ NameServer
nc -z localhost 9876 && echo "OK"
# 预期: OK

# RocketMQ Broker
nc -z localhost 10911 && echo "OK"
# 预期: OK

# RocketMQ Proxy
nc -z localhost 18080 && echo "OK"
# 预期: OK

# RocketMQ Topic
~/.saa-middleware/rocketmq/bin/mqadmin topicList -n localhost:9876 | grep topic_saa
# 预期: topic_saa_studio_document_index
```

### 8.3 应用验证

```bash
# 健康检查
curl http://localhost:8081/console/v1/system/health
# 预期: ok

# 登录
curl -X POST http://localhost:8081/console/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"saa","password":"123456"}'
# 预期: code 200, 返回 access_token + refresh_token

# Prompt 列表
curl http://localhost:8081/api/prompts?current=1&size=10
# 预期: code 200

# Dataset 列表
curl http://localhost:8081/api/dataset/datasets?current=1&size=10
# 预期: code 200

# Evaluator 列表
curl http://localhost:8081/api/evaluator/evaluators?current=1&size=10
# 预期: code 200

# Trace 列表
curl "http://localhost:8081/api/observability/traces?pageNumber=1&pageSize=10&startTime=2026-01-01T00:00:00.000Z&endTime=2026-12-31T23:59:59.000Z"
# 预期: code 200
```

### 8.4 测试验证

```bash
# 单元测试（不含集成测试）
mvn test -Dtest='!*CharacterizationTest'
# 预期: 14 tests pass

# 集成测试（需要应用运行中）
TEST_BASE_URL=http://localhost:8081 mvn -pl :spring-ai-alibaba-admin-server-start test -Dtest='*CharacterizationTest'
# 预期: 14 tests pass (7 Auth + 7 Prompt)
```

---

## 9. 环境变量速查

### 应用启动必需

```bash
export SPRING_DATASOURCE_URL="jdbc:mysql://localhost:13306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai"
export SPRING_DATASOURCE_USERNAME=root
export SPRING_DATASOURCE_PASSWORD=root
export SPRING_REDIS_HOST=localhost
export SPRING_REDIS_PORT=6380
export SPRING_REDIS_DATABASE=0
export SPRING_ELASTICSEARCH_URIS=http://localhost:9201
export SPRING_ELASTICSEARCH_URL=http://localhost:9201
export NACOS_SERVER_ADDR=localhost:8848
export ROCKETMQ_ENDPOINTS=localhost:18080
export MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT=http://localhost:4318/v1/traces
```

### CI 中使用（端口与本地不同）

```bash
export SPRING_DATASOURCE_URL="jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai"
export SPRING_DATASOURCE_USERNAME=root
export SPRING_DATASOURCE_PASSWORD=root
export SPRING_REDIS_HOST=localhost
export SPRING_REDIS_PORT=6379
export SPRING_ELASTICSEARCH_URIS=http://localhost:9200
export NACOS_SERVER_ADDR=localhost:8848
export ROCKETMQ_ENDPOINTS=localhost:18080
export MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT=http://localhost:4318/v1/traces
```

---

## 10. 端口分配表

| 服务 | 默认端口 | WSL2/本地建议 | CI 端口 | 说明 |
|------|----------|---------------|---------|------|
| Admin 应用 | 8080 | 8081 | 8081 | `-Dserver.port=` |
| MySQL | 3306 | 13306 | 3306 | `my.cnf` 中 `port=` |
| Redis | 6379 | 6380 | 6379 | `--port` 参数 |
| Elasticsearch | 9200 | 9201 | 9200 | `elasticsearch.yml` 中 `http.port` |
| Nacos | 8848 | 8848 | 8848 | 默认端口 |
| RocketMQ NameServer | 9876 | 9876 | 9876 | |
| RocketMQ Broker | 10911 | 10911 | 10911 | |
| RocketMQ Proxy remoting | 18080 | 18080 | 18080 | |
| RocketMQ Proxy gRPC | 18081 | 18081 | 18081 | |
| OpenTelemetry Collector | 4318 | 4318 | 4318 | gRPC HTTP endpoint |

---

## 快速恢复指南

如果环境挂了，按顺序重启：

```bash
# 1. 停掉所有服务
bash scripts/deps-stop.sh

# 2. 清理残留
pkill -f "rocketmq" 2>/dev/null
pkill -f "elasticsearch" 2>/dev/null
pkill -f "nacos" 2>/dev/null
pkill -f "redis-server" 2>/dev/null
pkill -f "mysqld" 2>/dev/null

# 3. 重新启动中间件
bash scripts/deps-start.sh

# 4. 检查状态
bash scripts/deps-status.sh

# 5. 启动应用
export JAVA_HOME=~/.saa-middleware/jdk-17
source ~/.saa-middleware/env.sh  # 包含所有环境变量
java -Dserver.port=8081 -jar spring-ai-alibaba-admin-server-start/target/*.jar
```
