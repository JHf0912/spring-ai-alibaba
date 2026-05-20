# 启动日志 — Spring AI Alibaba Admin

> 记录 `mvn clean package` + 应用启动过程中的问题与修复。

---

## 环境

- **JDK**: Temurin 17.0.13 (`~/.saa-middleware/jdk-17`)
- **Maven**: 3.9.9 (`~/.saa-middleware/maven`)
- **日期**: 2026-05-17

---

## 构建过程

### 第 1 次构建：Lombok 枚举构造器失败

**错误**:
```
constructor ToolCallType in enum cannot be applied to given types;
  required: no arguments
  found:    java.lang.String
```

**原因**: `ToolCallType.java`、`ChunkType.java`、`AccountType.java` 使用了 `@AllArgsConstructor`，但 Lombok 注解处理器未正确生成构造器。

**修复**: 在 `pom.xml` 的 `maven-compiler-plugin` 中添加 `annotationProcessorPaths` 配置 Lombok 处理器。

**结果**: 仍然失败 — 真正的错误被 Lombok 问题掩盖了。

### 第 2 次构建：ToolExample.java 内容错乱

**错误**:
```
class ToolsExample is public, should be declared in a file named ToolsExample.java
package com.alibaba.cloud.ai.dashscope.api does not exist
package com.alibaba.cloud.ai.graph does not exist
```

**原因**: `ToolExample.java` 文件内容被替换为一个文档示例代码（`ToolsExample` 类），包名错误（`com.alibaba.cloud.ai.examples.documentation.framework.tutorials`），且导入了不存在的依赖。

**修复**: 将 `ToolExample.java` 替换为正确的数据类（`@Data @NoArgsConstructor @AllArgsConstructor`），仅包含 `description`、`input`、`output` 三个字段。

**结果**: 构建成功 ✅

### 第 3 次构建：升级 Lombok 版本

**操作**: 将 Lombok 从 1.18.30 升级到 1.18.34（预防性修复）。

**结果**: 构建成功 ✅

### 构建命令

```bash
export JAVA_HOME=~/.saa-middleware/jdk-17
mvn -B clean package -DskipTests=true
```

**产物**: `spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar` (446MB)

---

## 启动过程

### 第 1 次启动：缺少环境变量

**错误**:
```
Could not resolve placeholder 'MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT'
```

**修复**: 添加环境变量 `MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT=http://localhost:4318/v1/traces`。

### 第 2 次启动：MySQL 认证失败

**错误**:
```
Access denied for user 'root'@'localhost' (using password: NO)
```

**原因**: MySQL 使用 `--skip-grant-tables` 模式启动，但该模式在 MySQL 8.0 中会自动启用 `--skip_networking`，导致 TCP 连接不可用。

**修复**:
1. 通过 socket 连接设置 root 密码：`ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root'`
2. 去掉 `skip-grant-tables`，正常启动 MySQL

### 第 3 次启动：MySQL 端口冲突

**错误**:
```
Can't start server: Bind on TCP/IP port: Address already in use
```

**原因**: WSL2 环境中端口 3306 被 Windows 进程占用。

**修复**: 将 MySQL 端口改为 13306。

### 第 4 次启动：RocketMQ Proxy 未运行

**错误**:
```
Connection refused: localhost/127.0.0.1:18080
```

**原因**: RocketMQ Proxy 未启动，且配置文件缺少 `namesrvAddr`。

**修复**:
1. 更新 `rmq-proxy.json` 添加 `namesrvAddr: "localhost:9876"`
2. 手动启动 Proxy

### 第 5 次启动：应用端口冲突

**错误**:
```
Web server failed to start. Port 8080 was already in use.
```

**原因**: WSL2 环境中端口 8080 被占用。

**修复**: 使用 `-Dserver.port=8081` 启动应用。

### 启动成功 ✅

---

## 最终服务状态

| 服务 | 端口 | 状态 |
|------|------|------|
| MySQL 8.0 | 13306 | ✅ RUNNING |
| Redis 7.0 | 6380 | ✅ RUNNING |
| Elasticsearch 9.1 | 9201 | ✅ RUNNING |
| Nacos 3.0 | 8848 | ✅ RUNNING |
| RocketMQ NameServer | 9876 | ✅ RUNNING |
| RocketMQ Broker | 10911 | ✅ RUNNING |
| RocketMQ Proxy | 18080 | ✅ RUNNING |
| **Admin 应用** | **8081** | **✅ RUNNING** |

## 访问地址

- **管理界面**: http://localhost:8081
- **API 文档**: http://localhost:8081/swagger-ui.html
- **健康检查**: http://localhost:8081/console/v1/system/health

## 启动命令（完整）

```bash
export JAVA_HOME=~/.saa-middleware/jdk-17
export PATH=$JAVA_HOME/bin:$PATH
export LD_LIBRARY_PATH=~/.saa-middleware/lib:$LD_LIBRARY_PATH

export SPRING_DATASOURCE_URL="jdbc:mysql://localhost:13306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai"
export SPRING_DATASOURCE_USERNAME=root
export SPRING_DATASOURCE_PASSWORD=root
export SPRING_REDIS_HOST=localhost
export SPRING_REDIS_PORT=6380
export SPRING_REDIS_DATABASE=0
export SPRING_ELASTICSEARCH_URIS=http://localhost:9201
export NACOS_SERVER_ADDR=localhost:8848
export ROCKETMQ_ENDPOINTS=localhost:18080
export MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT=http://localhost:4318/v1/traces

java -Dserver.port=8081 -jar spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar
```
