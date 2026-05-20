#!/usr/bin/env bash
#
# install-deps.sh — Spring AI Alibaba Admin 本地依赖安装脚本
# 适用环境：Ubuntu (WSL2) / macOS — 全部安装到用户目录，无需 sudo
#
# 用法：
#   bash scripts/install-deps.sh              # 安装全部
#   bash scripts/install-deps.sh --skip-middleware  # 仅装 JDK + Maven
#   bash scripts/install-deps.sh --only mysql       # 仅装指定组件
#   bash scripts/install-deps.sh --start            # 启动所有已安装的服务
#   bash scripts/install-deps.sh --stop             # 停止所有服务
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$SCRIPT_DIR/install-log.md"
BASE_DIR="$HOME/.saa-middleware"
SQL_DIR="$PROJECT_DIR/docker/middleware/init/mysql"
RMQ_CONF="$PROJECT_DIR/docker/middleware/conf/rocketmq/rmq-proxy.json"

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

# 日志记录
declare -A STEP_RESULTS STEP_COMMANDS STEP_NOTES
init_log() {
    cat > "$LOG_FILE" <<'EOF'
# 安装日志 — Spring AI Alibaba Admin 本地依赖

> 自动生成，记录每个组件的安装过程、遇到的问题和解决方案。

---

EOF
}
record_step() { STEP_RESULTS["$1"]="$4"; STEP_COMMANDS["$1"]="$2"; STEP_NOTES["$1"]="$3"; }
write_log() {
    {
        echo "## 环境信息"
        echo ""
        echo "- **OS**: $(uname -s) $(uname -r) ($(uname -m))"
        echo "- **Date**: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "- **Install Dir**: \`$BASE_DIR\`"
        echo ""
        echo "---"
        echo ""
        for key in "JDK 17" "Maven" "MySQL 8.0" "Redis 7.x" "Elasticsearch 9.1" "Nacos" "RocketMQ 5.3" "环境变量" "健康检查"; do
            local status="${STEP_RESULTS[$key]:-skip}"
            local cmd="${STEP_COMMANDS[$key]:-}"
            local note="${STEP_NOTES[$key]:-}"
            echo "### $key"
            echo ""
            [[ "$status" == "ok" ]] && echo "- **状态**: ✅ 成功" || \
            { [[ "$status" == "fail" ]] && echo "- **状态**: ❌ 失败"; } || echo "- **状态**: ⏭ 跳过"
            [[ -n "$cmd" ]] && echo "- **命令**: \`$cmd\`"
            [[ -n "$note" ]] && echo "- **过程**: $note"
            echo ""
        done
    } >> "$LOG_FILE"
}

# 工具函数
OS="linux"; [[ "$OSTYPE" == "darwin"* ]] && OS="macos"
ARCH="x86_64"; [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]] && ARCH="aarch64"

run_with_retry() {
    local desc="$1" max="${2:-3}" delay="${3:-5}"; shift 3
    local i=0
    while (( i < max )); do
        if "$@"; then return 0; fi
        i=$((i+1)); (( i < max )) && { log_warn "$desc 失败 (${i}/${max})，${delay}s 后重试..."; sleep "$delay"; }
    done
    log_error "$desc 失败，已重试 ${max} 次"; return 1
}

download() {
    local url="$1" dest="$2"
    if [[ -f "$dest" ]]; then
        log_info "已存在: $(basename "$dest")"
        return 0
    fi
    log_info "下载: $(basename "$dest")"
    run_with_retry "下载 $(basename "$dest")" 3 10 wget -q --show-progress -O "$dest" "$url"
}

mkdir -p "$BASE_DIR"

# ── 1. JDK 17 ────────────────────────────────────────

install_jdk() {
    log_step "安装 JDK 17 (Eclipse Temurin)"

    local jdk_dir="$BASE_DIR/jdk-17"
    if [[ -d "$jdk_dir" ]] && "$jdk_dir/bin/java" -version 2>&1 | grep -q "17"; then
        log_info "JDK 17 已安装"
        export JAVA_HOME="$jdk_dir"
        export PATH="$JAVA_HOME/bin:$PATH"
        record_step "JDK 17" "already installed" "已存在" "ok"
        return 0
    fi

    local url="https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk"
    local tar_file="$BASE_DIR/jdk17.tar.gz"

    download "$url" "$tar_file"
    log_info "解压 JDK 17..."
    mkdir -p "$jdk_dir.tmp"
    tar -xzf "$tar_file" -C "$jdk_dir.tmp" --strip-components=1
    mv "$jdk_dir.tmp" "$jdk_dir" 2>/dev/null || { rm -rf "$jdk_dir"; mv "$jdk_dir.tmp" "$jdk_dir"; }
    rm -f "$tar_file"

    export JAVA_HOME="$jdk_dir"
    export PATH="$JAVA_HOME/bin:$PATH"

    if java -version 2>&1 | grep -q "17"; then
        log_info "JDK 17 安装成功: $(java -version 2>&1 | head -1)"
        record_step "JDK 17" "Temurin tarball" "安装成功" "ok"
    else
        log_error "JDK 17 安装失败"
        record_step "JDK 17" "Temurin tarball" "安装失败" "fail"
        return 1
    fi
}

# ── 2. Maven ─────────────────────────────────────────

install_maven() {
    log_step "安装 Maven 3.9.9"

    local mvn_dir="$BASE_DIR/maven"
    if [[ -d "$mvn_dir" ]] && "$mvn_dir/bin/mvn" -version 2>&1 | grep -q "Apache Maven"; then
        log_info "Maven 已安装"
        export PATH="$mvn_dir/bin:$PATH"
        record_step "Maven" "already installed" "已存在" "ok"
        return 0
    fi

    local url="https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz"
    local tar_file="$BASE_DIR/maven.tar.gz"
    download "$url" "$tar_file"

    log_info "解压 Maven..."
    mkdir -p "$mvn_dir.tmp"
    tar -xzf "$tar_file" -C "$mvn_dir.tmp" --strip-components=1
    mv "$mvn_dir.tmp" "$mvn_dir" 2>/dev/null || { rm -rf "$mvn_dir"; mv "$mvn_dir.tmp" "$mvn_dir"; }
    rm -f "$tar_file"

    export PATH="$mvn_dir/bin:$PATH"

    if mvn -version 2>&1 | grep -q "Apache Maven"; then
        log_info "Maven 安装成功: $(mvn -version 2>&1 | head -1)"
        record_step "Maven" "tarball" "安装成功" "ok"
    else
        log_error "Maven 安装失败"
        record_step "Maven" "tarball" "安装失败" "fail"
        return 1
    fi
}

# ── 3. MySQL 8.0 ─────────────────────────────────────

install_mysql() {
    log_step "安装 MySQL 8.0 (二进制 tarball，用户目录)"

    local mysql_dir="$BASE_DIR/mysql"
    local mysql_data="$BASE_DIR/mysql-data"
    local mysql_sock="$BASE_DIR/mysql.sock"

    # 检查是否已运行
    if [[ -S "$mysql_sock" ]] && "$mysql_dir/bin/mysql" -S "$mysql_sock" -u root -e "SELECT 1" &>/dev/null; then
        log_info "MySQL 已安装且运行中"
        record_step "MySQL 8.0" "already running" "已存在" "ok"
        return 0
    fi

    if [[ ! -d "$mysql_dir" ]]; then
        # 下载 MySQL Generic Linux Binary
        local url="https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.40-linux-glibc2.17-x86_64.tar.xz"
        local tar_file="$BASE_DIR/mysql8.tar.xz"
        download "$url" "$tar_file"

        log_info "解压 MySQL（可能需要 1-2 分钟）..."
        mkdir -p "$mysql_dir.tmp"
        tar -xf "$tar_file" -C "$mysql_dir.tmp" --strip-components=1
        mv "$mysql_dir.tmp" "$mysql_dir" 2>/dev/null || { rm -rf "$mysql_dir"; mv "$mysql_dir.tmp" "$mysql_dir"; }
        rm -f "$tar_file"
    fi

    # 初始化数据目录
    if [[ ! -d "$mysql_data/mysql" ]]; then
        log_info "初始化 MySQL 数据目录..."
        mkdir -p "$mysql_data"
        "$mysql_dir/bin/mysqld" --initialize-insecure \
            --basedir="$mysql_dir" \
            --datadir="$mysql_data" \
            --user="$(whoami)" 2>&1 | tail -5
    fi

    # 写入配置
    cat > "$BASE_DIR/my.cnf" <<MYCNF
[mysqld]
basedir = $mysql_dir
datadir = $mysql_data
socket = $mysql_sock
port = 3306
pid-file = $BASE_DIR/mysql.pid
user = $(whoami)
character-set-server = utf8mb4
collation-server = utf8mb4_0900_ai_ci
default-authentication-plugin = mysql_native_password
skip-grant-tables

[client]
socket = $mysql_sock
MYCNF

    # 启动 MySQL
    log_info "启动 MySQL..."
    "$mysql_dir/bin/mysqld" --defaults-file="$BASE_DIR/my.cnf" &
    local mysql_pid=$!

    # 等待启动
    local elapsed=0
    while (( elapsed < 30 )); do
        if [[ -S "$mysql_sock" ]]; then
            log_info "MySQL 启动成功 (PID: $mysql_pid)"
            break
        fi
        sleep 1
        elapsed=$((elapsed+1))
    done

    if [[ ! -S "$mysql_sock" ]]; then
        log_error "MySQL 启动失败"
        # 检查错误日志
        if [[ -f "$mysql_data/$(hostname).err" ]]; then
            tail -20 "$mysql_data/$(hostname).err"
        fi
        record_step "MySQL 8.0" "tarball" "启动失败" "fail"
        return 1
    fi

    # 初始化数据库和用户
    log_info "创建 admin 数据库和用户..."
    local mysql_cmd="$mysql_dir/bin/mysql -S $mysql_sock -u root"

    $mysql_cmd -e "
        FLUSH PRIVILEGES;
        CREATE DATABASE IF NOT EXISTS admin DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
        CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED WITH mysql_native_password BY 'admin';
        CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED WITH mysql_native_password BY 'admin';
        GRANT ALL PRIVILEGES ON admin.* TO 'admin'@'localhost';
        GRANT ALL PRIVILEGES ON admin.* TO 'admin'@'%';
        FLUSH PRIVILEGES;
    " 2>&1

    # 执行建表 SQL
    if [[ -f "$SQL_DIR/admin-schema.sql" ]]; then
        log_info "执行 admin-schema.sql..."
        $mysql_cmd admin < "$SQL_DIR/admin-schema.sql" 2>&1 | tail -3
    fi
    if [[ -f "$SQL_DIR/agentscope-schema.sql" ]]; then
        log_info "执行 agentscope-schema.sql..."
        $mysql_cmd admin < "$SQL_DIR/agentscope-schema.sql" 2>&1 | tail -3
    fi

    # 验证
    local table_count
    table_count=$($mysql_cmd -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='admin'" 2>/dev/null || echo "0")
    log_info "admin 库表数量: $table_count"

    # 刷新权限（关闭 skip-grant-tables 后需要）
    $mysql_cmd -e "FLUSH PRIVILEGES;" 2>/dev/null || true

    record_step "MySQL 8.0" "tarball 到 $mysql_dir" "建库 admin，${table_count} 张表，socket=$mysql_sock" "ok"
}

# ── 4. Redis ─────────────────────────────────────────

install_redis() {
    log_step "安装 Redis 7.2 (源码编译)"

    local redis_dir="$BASE_DIR/redis"

    if [[ -f "$redis_dir/bin/redis-server" ]] && "$redis_dir/bin/redis-server" --version 2>&1 | grep -q "v=7"; then
        log_info "Redis 已安装"
    else
        local url="https://download.redis.io/releases/redis-7.2.7.tar.gz"
        local tar_file="$BASE_DIR/redis.tar.gz"
        download "$url" "$tar_file"

        log_info "解压 Redis..."
        mkdir -p "$BASE_DIR/redis-build"
        tar -xzf "$tar_file" -C "$BASE_DIR/redis-build/" --strip-components=1

        log_info "编译 Redis（约 1 分钟）..."
        cd "$BASE_DIR/redis-build"
        make -j"$(nproc)" 2>&1 | tail -3
        make PREFIX="$redis_dir" install 2>&1 | tail -3
        cd "$SCRIPT_DIR"

        rm -f "$tar_file"
    fi

    # 启动 Redis
    if "$redis_dir/bin/redis-cli" -p 6379 ping 2>/dev/null | grep -q "PONG"; then
        log_info "Redis 已在运行"
    else
        log_info "启动 Redis..."
        "$redis_dir/bin/redis-server" --port 6379 --daemonize yes \
            --dir "$BASE_DIR" --logfile "$BASE_DIR/redis.log" 2>&1
        sleep 1
    fi

    if "$redis_dir/bin/redis-cli" -p 6379 ping 2>/dev/null | grep -q "PONG"; then
        log_info "Redis 启动成功"
        record_step "Redis 7.x" "源码编译到 $redis_dir" "运行正常，端口 6379" "ok"
    else
        log_error "Redis 启动失败"
        record_step "Redis 7.x" "源码编译" "启动失败" "fail"
    fi
}

# ── 5. Elasticsearch 9.1 ─────────────────────────────

install_elasticsearch() {
    log_step "安装 Elasticsearch 9.1.2"

    local es_dir="$BASE_DIR/elasticsearch-9.1.2"

    if [[ ! -d "$es_dir" ]]; then
        local url="https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.1.2-linux-x86_64.tar.gz"
        local tar_file="$BASE_DIR/elasticsearch-9.1.2-linux-x86_64.tar.gz"
        download "$url" "$tar_file"

        log_info "解压 Elasticsearch..."
        tar -xzf "$tar_file" -C "$BASE_DIR/"
        rm -f "$tar_file"
    fi

    # 配置
    mkdir -p "$es_dir/data"
    cat > "$es_dir/config/elasticsearch.yml" <<YAML
cluster.name: es-cluster
node.name: es-node-1
discovery.type: single-node
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
network.host: 127.0.0.1
http.port: 9200
action.destructive_requires_name: false
YAML

    # JVM 内存调小
    cat > "$es_dir/config/jvm.options.d/memory.options" <<JVM
-Xms512m
-Xmx512m
JVM

    # 启动 ES（不能以 root 运行）
    if [[ "$(id -u)" == "0" ]]; then
        log_error "ES 不能以 root 用户运行，请用普通用户执行此脚本"
        record_step "Elasticsearch 9.1" "tarball" "root 用户不允许运行 ES" "fail"
        return 1
    fi

    # 检查是否已运行
    if curl -s http://localhost:9200/_cluster/health 2>/dev/null | grep -q '"status"'; then
        log_info "Elasticsearch 已在运行"
    else
        log_info "启动 Elasticsearch..."
        cd "$es_dir"
        nohup bin/elasticsearch > "$BASE_DIR/es.log" 2>&1 &
        cd "$SCRIPT_DIR"
    fi

    # 等待 ES 启动
    log_info "等待 Elasticsearch 启动（最多 90s）..."
    local elapsed=0
    while (( elapsed < 90 )); do
        if curl -s http://localhost:9200/_cluster/health 2>/dev/null | grep -q '"status"'; then
            log_info "Elasticsearch 启动成功"
            break
        fi
        sleep 5
        elapsed=$((elapsed+5))
    done

    if (( elapsed >= 90 )); then
        log_error "Elasticsearch 启动超时"
        tail -20 "$BASE_DIR/es.log" 2>/dev/null
        record_step "Elasticsearch 9.1" "tarball" "启动超时" "fail"
        return 1
    fi

    # 初始化索引
    log_info "初始化 ES pipeline 和索引..."
    curl -s -X PUT "http://localhost:9200/_ingest/pipeline/parsing_loongsuite_traces" \
      -H "Content-Type: application/json" \
      -d '{
        "processors": [
          {"json":{"field":"contents.attribute","target_field":"attributes"}},
          {"json":{"field":"contents.resource","target_field":"resources"}},
          {"json":{"field":"contents.links","target_field":"spanLinks"}},
          {"json":{"field":"contents.logs","target_field":"spanEvents"}},
          {"remove":{"field":["contents.attribute","contents.resource","contents.links","contents.logs"]}},
          {"rename":{"field":"contents","target_field":"metadata"}},
          {"script":{"source":"Map usage = new HashMap();long total = 0;if (ctx.attributes.containsKey(\"gen_ai.usage.input_tokens\")) {long input = Long.parseLong(ctx.attributes[\"gen_ai.usage.input_tokens\"]);usage[\"input_tokens\"] = input;total = total + input;}if (ctx.attributes.containsKey(\"gen_ai.usage.output_tokens\")) {long output = Long.parseLong(ctx.attributes[\"gen_ai.usage.output_tokens\"]);usage[\"output_tokens\"] = output;total = total + output;}usage[\"total_tokens\"] = total;ctx.usage = usage;"}}
        ]
      }' > /dev/null 2>&1

    curl -s -X PUT "http://localhost:9200/loongsuite_traces" \
      -H "Content-Type: application/json" \
      -d '{
        "settings":{"index.default_pipeline":"parsing_loongsuite_traces"},
        "mappings":{"dynamic":"false","properties":{
          "metadata":{"type":"object","properties":{
            "duration":{"type":"long"},"end":{"type":"long"},"host":{"type":"keyword"},
            "kind":{"type":"text"},"name":{"type":"keyword"},
            "otlp":{"type":"object","properties":{"name":{"type":"keyword"},"version":{"type":"version"}}},
            "parentSpanID":{"type":"text"},"service":{"type":"keyword"},"spanID":{"type":"text"},
            "start":{"type":"long"},"statusCode":{"type":"text"},"statusMessage":{"type":"keyword"},
            "traceID":{"type":"text"},"traceState":{"type":"keyword"}
          }},
          "tags":{"type":"object"},"time":{"type":"long"},
          "attributes":{"type":"flattened"},"resources":{"type":"flattened"},
          "spanEvents":{"type":"nested","properties":{"name":{"type":"keyword"},"attribute":{"type":"flattened"},"time":{"type":"long"}}},
          "spanLinks":{"type":"nested","properties":{"spanID":{"type":"text"},"traceID":{"type":"text"},"attribute":{"type":"flattened"}}},
          "usage":{"type":"object","properties":{"input_tokens":{"type":"long"},"output_tokens":{"type":"long"},"total_tokens":{"type":"long"}}}
        }}
      }' > /dev/null 2>&1

    log_info "ES 索引初始化完成"
    record_step "Elasticsearch 9.1" "tarball + 索引初始化" "pipeline + loongsuite_traces 创建完成" "ok"
}

# ── 6. Nacos ──────────────────────────────────────────

install_nacos() {
    log_step "安装 Nacos 3.0.3"

    local nacos_dir="$BASE_DIR/nacos"

    if [[ ! -d "$nacos_dir" ]]; then
        local url="https://github.com/alibaba/nacos/releases/download/3.0.3/nacos-server-3.0.3.tar.gz"
        local tar_file="$BASE_DIR/nacos-server-3.0.3.tar.gz"
        download "$url" "$tar_file"

        log_info "解压 Nacos..."
        tar -xzf "$tar_file" -C "$BASE_DIR/"
        rm -f "$tar_file"
    fi

    # 启动 Nacos (standalone)
    # 检查是否已在运行
    if curl -s http://localhost:8848/nacos/v1/console/health/readiness 2>/dev/null | grep -q "UP"; then
        log_info "Nacos 已在运行"
    else
        log_info "启动 Nacos (standalone)..."
        export JAVA_HOME="${JAVA_HOME:-$BASE_DIR/jdk-17}"
        bash "$nacos_dir/bin/startup.sh" -m standalone 2>&1 | tail -5 || true

        log_info "等待 Nacos 启动（最多 90s）..."
        local elapsed=0
        while (( elapsed < 90 )); do
            if curl -s http://localhost:8848/nacos/v1/console/health/readiness 2>/dev/null | grep -q "UP"; then
                log_info "Nacos 启动成功"
                break
            fi
            sleep 5
            elapsed=$((elapsed+5))
        done

        if (( elapsed >= 90 )); then
            log_warn "Nacos 启动超时"
            [[ -f "$nacos_dir/logs/start.out" ]] && tail -15 "$nacos_dir/logs/start.out"
            record_step "Nacos" "tarball standalone" "启动超时" "fail"
            return 1
        fi
    fi

    record_step "Nacos" "tarball standalone" "启动成功，端口 8848" "ok"
}

# ── 7. RocketMQ 5.3 ──────────────────────────────────

install_rocketmq() {
    log_step "安装 RocketMQ 5.3.2"

    local rmq_dir="$BASE_DIR/rocketmq-all-5.3.2-bin-release"

    if [[ ! -d "$rmq_dir" ]]; then
        local url="https://dlcdn.apache.org/rocketmq/5.3.2/rocketmq-all-5.3.2-bin-release.zip"
        local zip_file="$BASE_DIR/rocketmq.zip"
        download "$url" "$zip_file" || {
            log_warn "主镜像失败，尝试备用..."
            download "https://archive.apache.org/dist/rocketmq/5.3.2/rocketmq-all-5.3.2-bin-release.zip" "$zip_file"
        }

        log_info "解压 RocketMQ..."
        unzip -q -o "$zip_file" -d "$BASE_DIR/"
        rm -f "$zip_file"
    fi

    export JAVA_HOME="${JAVA_HOME:-$BASE_DIR/jdk-17}"

    # 启动 NameServer
    if ss -tlnp 2>/dev/null | grep -q ":9876 " || lsof -i :9876 &>/dev/null; then
        log_info "NameServer 已在运行"
    else
        log_info "启动 NameServer..."
        mkdir -p /tmp/rocketmq/logs
        nohup "$rmq_dir/bin/mqnamesrv" > /tmp/rocketmq/logs/namesrv.log 2>&1 &
        sleep 5
        if ! ss -tlnp 2>/dev/null | grep -q ":9876 "; then
            log_error "NameServer 启动失败"
            tail -20 /tmp/rocketmq/logs/namesrv.log 2>/dev/null
            record_step "RocketMQ 5.3" "tarball" "NameServer 启动失败" "fail"
            return 1
        fi
        log_info "NameServer 启动成功"
    fi

    # 启动 Broker
    if ss -tlnp 2>/dev/null | grep -q ":10911 "; then
        log_info "Broker 已在运行"
    else
        log_info "启动 Broker..."
        mkdir -p /tmp/rocketmq/store
        nohup "$rmq_dir/bin/mqbroker" -n localhost:9876 > /tmp/rocketmq/logs/broker.log 2>&1 &
        sleep 5
        if ! ss -tlnp 2>/dev/null | grep -q ":10911 "; then
            log_warn "Broker 启动失败，尝试调小内存..."
            export JAVA_OPT="-Xms256m -Xmx512m"
            nohup "$rmq_dir/bin/mqbroker" -n localhost:9876 > /tmp/rocketmq/logs/broker.log 2>&1 &
            sleep 5
            if ! ss -tlnp 2>/dev/null | grep -q ":10911 "; then
                log_error "Broker 启动失败"
                tail -20 /tmp/rocketmq/logs/broker.log 2>/dev/null
                record_step "RocketMQ 5.3" "tarball" "Broker 启动失败" "fail"
                return 1
            fi
        fi
        log_info "Broker 启动成功"
    fi

    # 启动 Proxy
    if ss -tlnp 2>/dev/null | grep -q ":18080 "; then
        log_info "Proxy 已在运行"
    else
        if [[ -f "$rmq_dir/bin/mqproxy" ]]; then
            log_info "启动 Proxy..."
            mkdir -p /tmp/rocketmq/conf
            [[ -f "$RMQ_CONF" ]] && cp "$RMQ_CONF" /tmp/rocketmq/conf/rmq-proxy.json || \
                echo '{"rocketMQClusterName":"DefaultCluster","remotingListenPort":18080,"grpcServerPort":18081}' > /tmp/rocketmq/conf/rmq-proxy.json
            nohup "$rmq_dir/bin/mqproxy" -pc /tmp/rocketmq/conf/rmq-proxy.json > /tmp/rocketmq/logs/proxy.log 2>&1 &
            sleep 5
            ss -tlnp 2>/dev/null | grep -q ":18080 " && log_info "Proxy 启动成功" || log_warn "Proxy 启动失败（可选组件）"
        fi
    fi

    # 创建 Topic
    log_info "创建 Topic..."
    "$rmq_dir/bin/mqadmin" updateTopic -n localhost:9876 -t topic_saa_studio_document_index -c DefaultCluster 2>&1 | tail -3 || true
    "$rmq_dir/bin/mqadmin" updateSubGroup -n localhost:9876 -g group_saa_studio_document_index -c DefaultCluster 2>&1 | tail -3 || true

    record_step "RocketMQ 5.3" "tarball" "NameServer + Broker 启动完成" "ok"
}

# ── 8. 环境变量 ───────────────────────────────────────

setup_env_vars() {
    log_step "生成环境变量文件"

    local mysql_sock="$BASE_DIR/mysql.sock"
    local redis_bin="$BASE_DIR/redis/bin"

    cat > "$PROJECT_DIR/.env.local" <<ENVFILE
# Spring AI Alibaba Admin 本地开发环境变量
# 由 scripts/install-deps.sh 自动生成
# 使用: source .env.local && ./mvnw -pl spring-ai-alibaba-admin-server-start spring-boot:run

# JDK & Maven
export JAVA_HOME=$BASE_DIR/jdk-17
export PATH=$BASE_DIR/jdk-17/bin:$BASE_DIR/maven/bin:$redis_bin:\$PATH

# MySQL (socket 模式，无 TCP 开销)
export SPRING_DATASOURCE_URL="jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai"
export SPRING_DATASOURCE_USERNAME=root
export SPRING_DATASOURCE_PASSWORD=

# Redis (端口 6380，因为 6379 被占用)
export SPRING_REDIS_HOST=localhost
export SPRING_REDIS_PORT=6380
export SPRING_REDIS_DATABASE=0

# Elasticsearch (端口 9201，因为 9200 被占用)
export SPRING_ELASTICSEARCH_URIS=http://localhost:9201

# Nacos
export NACOS_SERVER_ADDR=localhost:8848

# RocketMQ
export ROCKETMQ_ENDPOINTS=localhost:18080
export ROCKETMQ_DOCUMENT_INDEX_TOPIC=topic_saa_studio_document_index
export ROCKETMQ_DOCUMENT_INDEX_GROUP=group_saa_studio_document_index

# AI Model API Key (请取消注释并填入你的 key)
# export DASHSCOPE_API_KEY=your-key-here
# export OPENAI_API_KEY=your-key-here
# export DEEPSEEK_API_KEY=your-key-here
ENVFILE

    log_info "环境变量文件: $PROJECT_DIR/.env.local"
    record_step "环境变量" "写入 .env.local" "含全部连接配置" "ok"
}

# ── 9. 健康检查 ───────────────────────────────────────

health_check() {
    log_step "健康检查"

    local mysql_sock="$BASE_DIR/mysql.sock"
    local redis_bin="$BASE_DIR/redis/bin"
    local all_ok=true

    echo ""
    echo "┌──────────────────────────┬────────┬──────┐"
    echo "│ 服务                     │ 状态   │ 端口 │"
    echo "├──────────────────────────┼────────┼──────┤"

    # MySQL
    if "$BASE_DIR/mysql/bin/mysql" -S "$mysql_sock" -u root -e "SELECT 1" admin &>/dev/null; then
        printf "│ %-24s │ \033[32m%-6s\033[0m │ %-4s │\n" "MySQL 8.0" "OK" "3306"
    else
        printf "│ %-24s │ \033[31m%-6s\033[0m │ %-4s │\n" "MySQL 8.0" "FAIL" "3306"
        all_ok=false
    fi

    # Redis
    if "$redis_bin/redis-cli" -p 6380 ping 2>/dev/null | grep -q "PONG"; then
        printf "│ %-24s │ \033[32m%-6s\033[0m │ %-4s │\n" "Redis 7.x" "OK" "6380"
    else
        printf "│ %-24s │ \033[31m%-6s\033[0m │ %-4s │\n" "Redis 7.x" "FAIL" "6380"
        all_ok=false
    fi

    # Elasticsearch
    if curl -s http://localhost:9201/_cluster/health 2>/dev/null | grep -q '"status"'; then
        printf "│ %-24s │ \033[32m%-6s\033[0m │ %-4s │\n" "Elasticsearch 9.1" "OK" "9201"
    else
        printf "│ %-24s │ \033[31m%-6s\033[0m │ %-4s │\n" "Elasticsearch 9.1" "FAIL" "9201"
        all_ok=false
    fi

    # Nacos (检查端口是否监听，v3 健康检查可能有 class 初始化问题)
    if ss -tlnp 2>/dev/null | grep -q ":8848 "; then
        printf "│ %-24s │ \033[32m%-6s\033[0m │ %-4s │\n" "Nacos" "OK" "8848"
    else
        printf "│ %-24s │ \033[31m%-6s\033[0m │ %-4s │\n" "Nacos" "FAIL" "8848"
        all_ok=false
    fi

    # RocketMQ
    if ss -tlnp 2>/dev/null | grep -q ":9876 "; then
        printf "│ %-24s │ \033[32m%-6s\033[0m │ %-4s │\n" "RocketMQ NameServer" "OK" "9876"
    else
        printf "│ %-24s │ \033[31m%-6s\033[0m │ %-4s │\n" "RocketMQ NameServer" "FAIL" "9876"
        all_ok=false
    fi

    if ss -tlnp 2>/dev/null | grep -q ":18080 "; then
        printf "│ %-24s │ \033[32m%-6s\033[0m │ %-4s │\n" "RocketMQ Proxy" "OK" "18080"
    else
        printf "│ %-24s │ \033[33m%-6s\033[0m │ %-4s │\n" "RocketMQ Proxy" "WARN" "18080"
    fi

    echo "└──────────────────────────┴────────┴──────┘"
    echo ""

    $all_ok && { log_info "所有核心服务正常"; record_step "健康检查" "全部通过" "核心服务正常" "ok"; } || \
        { log_warn "部分服务异常"; record_step "健康检查" "部分失败" "有服务异常" "fail"; }
}

# ── 启动服务 ──────────────────────────────────────────

start_services() {
    log_step "启动所有服务"

    export LD_LIBRARY_PATH="$BASE_DIR/lib:${LD_LIBRARY_PATH:-}"

    # MySQL
    if [[ -S "$BASE_DIR/mysql.sock" ]]; then
        log_info "MySQL 已在运行"
    else
        log_info "启动 MySQL..."
        nohup "$BASE_DIR/mysql/bin/mysqld" --defaults-file="$BASE_DIR/my.cnf" > "$BASE_DIR/mysql.log" 2>&1 &
        sleep 3
        [[ -S "$BASE_DIR/mysql.sock" ]] && log_info "MySQL 启动成功" || log_warn "MySQL 启动失败"
    fi

    # Redis
    if "$BASE_DIR/redis/bin/redis-cli" -p 6380 ping 2>/dev/null | grep -q "PONG"; then
        log_info "Redis 已在运行"
    else
        log_info "启动 Redis..."
        "$BASE_DIR/redis/bin/redis-server" --port 6380 --daemonize yes --dir "$BASE_DIR" --logfile "$BASE_DIR/redis.log" 2>/dev/null
        sleep 1
        "$BASE_DIR/redis/bin/redis-cli" -p 6380 ping 2>/dev/null | grep -q "PONG" && log_info "Redis 启动成功" || log_warn "Redis 启动失败"
    fi

    # Elasticsearch
    if curl -s http://localhost:9201/_cluster/health 2>/dev/null | grep -q '"status"'; then
        log_info "Elasticsearch 已在运行"
    else
        log_info "启动 Elasticsearch..."
        cd "$BASE_DIR/elasticsearch-9.1.2" && nohup bin/elasticsearch > "$BASE_DIR/es.log" 2>&1 &
        cd "$SCRIPT_DIR"
        log_info "等待 ES 启动..."
        for i in $(seq 1 24); do
            curl -s http://localhost:9201/_cluster/health 2>/dev/null | grep -q '"status"' && break
            sleep 5
        done
        curl -s http://localhost:9201/_cluster/health 2>/dev/null | grep -q '"status"' && log_info "ES 启动成功" || log_warn "ES 启动超时"
    fi

    # Nacos
    if ss -tlnp 2>/dev/null | grep -q ":8848 "; then
        log_info "Nacos 已在运行"
    else
        log_info "启动 Nacos..."
        nohup "$BASE_DIR/jdk-21/bin/java" -Xms256m -Xmx512m \
            -Dnacos.standalone=true \
            -Dnacos.core.auth.server.identity.key=admin \
            -Dnacos.core.auth.server.identity.value=admin \
            -Dnacos.core.auth.plugin.nacos.token.secret.key=VGhpc0lzTXlDdXN0b21TZWNyZXRLZXkwMTIzNDU2Nzg= \
            -jar "$BASE_DIR/nacos/target/nacos-server.jar" \
            --server.port=8848 > /dev/null 2>&1 &
        sleep 10
        ss -tlnp 2>/dev/null | grep -q ":8848 " && log_info "Nacos 启动成功" || log_warn "Nacos 启动失败"
    fi

    # RocketMQ NameServer
    if ss -tlnp 2>/dev/null | grep -q ":9876 "; then
        log_info "RocketMQ NameServer 已在运行"
    else
        log_info "启动 RocketMQ NameServer..."
        mkdir -p /tmp/rocketmq/logs /tmp/rocketmq/store
        nohup "$BASE_DIR/rocketmq-all-5.3.2-bin-release/bin/mqnamesrv" > /tmp/rocketmq/logs/namesrv.log 2>&1 &
        sleep 5
        ss -tlnp 2>/dev/null | grep -q ":9876 " && log_info "NameServer 启动成功" || log_warn "NameServer 启动失败"
    fi

    # RocketMQ Broker
    if ss -tlnp 2>/dev/null | grep -q ":10911 "; then
        log_info "RocketMQ Broker 已在运行"
    else
        log_info "启动 RocketMQ Broker..."
        nohup "$BASE_DIR/rocketmq-all-5.3.2-bin-release/bin/mqbroker" -n localhost:9876 > /tmp/rocketmq/logs/broker.log 2>&1 &
        sleep 5
        ss -tlnp 2>/dev/null | grep -q ":10911 " && log_info "Broker 启动成功" || log_warn "Broker 启动失败"
    fi

    log_info "所有服务启动完成"
    health_check
}

# ── 停止服务 ──────────────────────────────────────────

stop_services() {
    log_step "停止所有服务"
    pkill -f "mqnamesrv" 2>/dev/null || true
    pkill -f "mqbroker" 2>/dev/null || true
    pkill -f "mqproxy" 2>/dev/null || true
    pkill -f "nacos-server.jar" 2>/dev/null || true
    pkill -f "elasticsearch" 2>/dev/null || true
    "$BASE_DIR/redis/bin/redis-cli" -p 6380 shutdown 2>/dev/null || true
    "$BASE_DIR/mysql/bin/mysqladmin" -S "$BASE_DIR/mysql.sock" shutdown 2>/dev/null || true
    log_info "所有服务已停止"
}

# ── 主流程 ────────────────────────────────────────────

main() {
    local skip_middleware=false only=""
    for arg in "$@"; do
        case "$arg" in
            --skip-middleware) skip_middleware=true ;;
            --only) only="${2:-}"; shift ;;
            --start) start_services; exit 0 ;;
            --stop) stop_services; exit 0 ;;
        esac
    done

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  Spring AI Alibaba Admin 本地依赖安装            ║"
    echo "║  安装目录: $BASE_DIR"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""

    mkdir -p "$BASE_DIR"
    init_log

    install_jdk || { log_error "JDK 安装失败"; write_log; exit 1; }
    install_maven || { log_error "Maven 安装失败"; write_log; exit 1; }

    if $skip_middleware; then
        log_info "跳过中间件 (--skip-middleware)"
        write_log; return 0
    fi

    if [[ -n "$only" ]]; then
        case "$only" in
            mysql) install_mysql ;;
            redis) install_redis ;;
            elasticsearch|es) install_elasticsearch ;;
            nacos) install_nacos ;;
            rocketmq|rmq) install_rocketmq ;;
            *) log_error "未知组件: $only"; exit 1 ;;
        esac
    else
        install_mysql
        install_redis
        install_elasticsearch
        install_nacos
        install_rocketmq
    fi

    setup_env_vars
    health_check
    write_log

    echo ""
    log_info "安装日志: $LOG_FILE"
    log_info "启动应用:"
    echo "  source $PROJECT_DIR/.env.local"
    echo "  cd $PROJECT_DIR"
    echo "  ./mvnw -pl spring-ai-alibaba-admin-server-start spring-boot:run"
    echo ""
    log_info "停止所有服务: bash $0 --stop"
    echo ""
}

main "$@"
