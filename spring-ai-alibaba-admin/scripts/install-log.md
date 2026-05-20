# 安装日志 — Spring AI Alibaba Admin 本地依赖

> 自动生成于 2026-05-16，记录每个组件的安装过程、遇到的问题和解决方案。

## 环境信息

- **OS**: Linux 6.6.87.2-microsoft-standard-WSL2 (Ubuntu 24.04, x86_64)
- **Install Dir**: `~/.saa-middleware`
- **sudo**: 不可用（需要密码）
- **Docker**: 不可用（WSL2 未集成）

---

### JDK 17

- **状态**: ✅ 成功
- **命令**: 从 GitHub/Adoptium 下载 Temurin JDK 17.0.13 tarball
- **过程**: 直接下载解压，无问题
- **路径**: `~/.saa-middleware/jdk-17`

### JDK 21

- **状态**: ✅ 成功
- **命令**: 从 GitHub/Adoptium 下载 Temurin JDK 21.0.6 tarball
- **过程**: Nacos 3.x 需要 JDK 21+，额外下载
- **路径**: `~/.saa-middleware/jdk-21`

### Maven 3.9.9

- **状态**: ✅ 成功
- **命令**: 从 archive.apache.org 下载 tarball
- **过程**: dlcdn.apache.org 返回 404，换用 archive 源
- **路径**: `~/.saa-middleware/maven`

### MySQL 8.0.40

- **状态**: ✅ 成功
- **命令**: 从 dev.mysql.com 下载 generic linux binary tarball (819MB)
- **过程**:
  1. 缺 `libaio.so.1` → 从阿里云镜像下载 deb 包提取
  2. 缺 `libnuma.so.1` → 从阿里云镜像下载 deb 包提取
  3. mysql 客户端缺 `libncurses.so.5` + `libtinfo.so.5` → 创建符号链接到系统 libncurses6/libtinfo6
  4. `--skip-grant-tables` 模式启动（本地开发用）
- **数据库**: admin (27 张表，执行 admin-schema.sql + agentscope-schema.sql)
- **路径**: `~/.saa-middleware/mysql`
- **Socket**: `~/.saa-middleware/mysql.sock`
- **端口**: 3306

### Redis 7.0.15

- **状态**: ✅ 成功
- **命令**: `apt download redis-server redis-tools` + `apt download liblzf1 libjemalloc2`，提取 deb 中的二进制
- **过程**:
  1. 源码编译失败（无 gcc/cc）
  2. 改用 `apt download` 下载 deb 包并提取二进制
  3. 缺 `liblzf.so.1` → 从 deb 包提取
  4. 端口 6379 被占用 → 改用 6380
- **路径**: `~/.saa-middleware/redis`
- **端口**: 6380

### Elasticsearch 9.1.2

- **状态**: ✅ 成功
- **命令**: 从 artifacts.elastic.co 下载 tarball (635MB)
- **过程**:
  1. 端口 9200 被 Cpolar 占用 → 改用 9201
  2. JVM 内存调为 512m
  3. 创建 parsing_loongsuite_traces pipeline + loongsuite_traces 索引
- **路径**: `~/.saa-middleware/elasticsearch-9.1.2`
- **端口**: 9201

### Nacos 3.0.3

- **状态**: ⚠️ 部分成功
- **命令**: 从 GitHub releases 下载 tarball (186MB)
- **过程**:
  1. `Empty identity` 错误 → 在 application.properties 设置 identity key/value
  2. `token secret key` 错误 → 设置 token secret key (base64, 32+ bytes)
  3. JDK 17 不兼容 → 下载 JDK 21
  4. 配置文件路径问题 → Nacos 默认使用 `$HOME/nacos` 而非安装目录
  5. 最终通过 `-D` 系统属性传入配置启动成功
  6. 健康检查 API 返回 500（`ServerParamCheckConfig` 类初始化问题），但进程存活、端口监听正常
- **启动命令**:
  ```bash
  ~/.saa-middleware/jdk-21/bin/java -Xms256m -Xmx512m \
    -Dnacos.standalone=true \
    -Dnacos.core.auth.server.identity.key=admin \
    -Dnacos.core.auth.server.identity.value=admin \
    -Dnacos.core.auth.plugin.nacos.token.secret.key=VGhpc0lzTXlDdXN0b21TZWNyZXRLZXkwMTIzNDU2Nzg= \
    -jar ~/.saa-middleware/nacos/target/nacos-server.jar \
    --server.port=8848
  ```
- **路径**: `~/.saa-middleware/nacos`
- **端口**: 8848

### RocketMQ 5.3.2

- **状态**: ✅ 成功
- **命令**: 从 archive.apache.org 下载 zip (87MB)
- **过程**:
  1. dlcdn.apache.org 下载失败 → 换用 archive 源
  2. 系统无 unzip → `apt download unzip` 提取二进制
  3. NameServer + Broker 启动成功
  4. 创建 topic_saa_studio_document_index + group_saa_studio_document_index
- **路径**: `~/.saa-middleware/rocketmq-all-5.3.2-bin-release`
- **端口**: 9876 (NameServer), 10911 (Broker)

### 依赖 .so 文件

所有缺失的共享库通过 deb 包提取到 `~/.saa-middleware/lib/`:
- `libaio.so.1` (MySQL)
- `libnuma.so.1` (MySQL)
- `libncurses.so.5` → 符号链接到系统 libncurses6 (MySQL client)
- `libtinfo.so.5` → 符号链接到系统 libtinfo6 (MySQL client)
- `liblzf.so.1` (Redis)
- `libjemalloc.so.2` (Redis)

---

## 端口汇总

| 服务 | 端口 | 备注 |
|------|------|------|
| MySQL 8.0 | 3306 | socket: ~/.saa-middleware/mysql.sock |
| Redis 7.0 | 6380 | 6379 被占用 |
| Elasticsearch 9.1 | 9201 | 9200 被 Cpolar 占用 |
| Nacos 3.0 | 8848 | 健康检查有 class 初始化问题 |
| RocketMQ NameServer | 9876 | |
| RocketMQ Broker | 10911 | |

## 已知问题

1. **Nacos 健康检查**: `/nacos/v3/console/health/readiness` 返回 500，`ServerParamCheckConfig` 类初始化失败。进程和端口正常，可能影响部分管理功能。
2. **Redis 端口**: 使用 6380 而非默认 6379（被占用）。
3. **ES 端口**: 使用 9201 而非默认 9200（被 Cpolar 占用）。
4. **MySQL 认证**: 使用 `--skip-grant-tables` 模式，root 无密码。
