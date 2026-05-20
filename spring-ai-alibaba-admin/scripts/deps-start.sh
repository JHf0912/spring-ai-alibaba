#!/usr/bin/env bash
#
# deps-start.sh — 一键启动 Spring AI Alibaba Admin 全部依赖中间件
#
# 支持的启动方式：
#   - 用户目录二进制（~/.saa-middleware/）
#   - brew services（macOS）
#   - systemd（Linux 有 sudo）
#   - 手动 jar（Nacos）
#
# 用法：bash scripts/deps-start.sh
#
set -uo pipefail

BASE="$HOME/.saa-middleware"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✔${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail() { echo -e "  ${RED}✘${NC} $*"; }
info() { echo -e "  ${CYAN}→${NC} $*"; }

# ── 工具函数 ──────────────────────────────────────────

# 检查端口是否在监听
port_up() { ss -tlnp 2>/dev/null | grep -q ":$1 " || lsof -i :"$1" &>/dev/null; }

# 等待端口就绪，返回 0=成功 1=超时
wait_port() {
    local port="$1" name="$2" timeout="${3:-60}"
    local elapsed=0
    while (( elapsed < timeout )); do
        port_up "$port" && return 0
        sleep 2
        elapsed=$((elapsed+2))
    done
    return 1
}

# 等待 HTTP 端点就绪
wait_http() {
    local url="$1" name="$2" timeout="${3:-60}"
    local elapsed=0
    while (( elapsed < timeout )); do
        if curl -sf "$url" >/dev/null 2>&1; then return 0; fi
        sleep 2
        elapsed=$((elapsed+2))
    done
    return 1
}

# 检测启动方式：优先 brew → systemd → 用户目录
detect_launcher() {
    local service="$1"
    # macOS brew services
    if command -v brew &>/dev/null && brew services list 2>/dev/null | grep -q "$service"; then
        echo "brew"
        return
    fi
    # Linux systemd
    if command -v systemctl &>/dev/null && systemctl list-unit-files "${service}.service" &>/dev/null; then
        echo "systemd"
        return
    fi
    # 用户目录
    echo "manual"
}

# ── MySQL ─────────────────────────────────────────────

start_mysql() {
    echo -e "\n${CYAN}[MySQL 8.0]${NC}"

    if port_up 3306 || [[ -S "$BASE/mysql.sock" ]]; then
        ok "已在运行 (3306)"
        return 0
    fi

    local launcher
    launcher=$(detect_launcher "mysql")

    case "$launcher" in
        brew)
            info "通过 brew services 启动..."
            brew services start mysql@8.0 2>/dev/null || brew services start mysql
            ;;
        systemd)
            info "通过 systemctl 启动..."
            sudo systemctl start mysql
            ;;
        manual)
            info "启动 mysqld..."
            export LD_LIBRARY_PATH="$BASE/lib:${LD_LIBRARY_PATH:-}"
            nohup "$BASE/mysql/bin/mysqld" \
                --defaults-file="$BASE/my.cnf" \
                > "$BASE/mysql.log" 2>&1 &
            ;;
    esac

    if wait_port 3306 "MySQL" 15 || [[ -S "$BASE/mysql.sock" ]]; then
        ok "启动成功 (3306)"
        return 0
    else
        fail "启动超时"
        return 1
    fi
}

# ── Redis ─────────────────────────────────────────────

start_redis() {
    echo -e "\n${CYAN}[Redis 7.x]${NC}"

    local port=6380
    # 检查 6379 或 6380
    if port_up 6379; then
        ok "已在运行 (6379)"
        return 0
    fi
    if port_up $port; then
        ok "已在运行 ($port)"
        return 0
    fi

    local launcher
    launcher=$(detect_launcher "redis")

    case "$launcher" in
        brew)
            info "通过 brew services 启动..."
            brew services start redis
            port=6379
            ;;
        systemd)
            info "通过 systemctl 启动..."
            sudo systemctl start redis-server
            port=6379
            ;;
        manual)
            info "启动 redis-server (端口 $port)..."
            export LD_LIBRARY_PATH="$BASE/lib:${LD_LIBRARY_PATH:-}"
            "$BASE/redis/bin/redis-server" \
                --port $port \
                --daemonize yes \
                --dir "$BASE" \
                --logfile "$BASE/redis.log" 2>/dev/null
            ;;
    esac

    if wait_port $port "Redis" 10; then
        ok "启动成功 ($port)"
        return 0
    else
        fail "启动超时"
        return 1
    fi
}

# ── Elasticsearch ─────────────────────────────────────

start_elasticsearch() {
    echo -e "\n${CYAN}[Elasticsearch 9.1]${NC}"

    local port=9201
    # 检查 9200 或 9201
    if curl -sf http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        ok "已在运行 (9200)"
        return 0
    fi
    if curl -sf http://localhost:$port/_cluster/health >/dev/null 2>&1; then
        ok "已在运行 ($port)"
        return 0
    fi

    local launcher
    launcher=$(detect_launcher "elasticsearch")

    case "$launcher" in
        brew)
            info "通过 brew services 启动..."
            brew services start elasticsearch-full
            port=9200
            ;;
        systemd)
            info "通过 systemctl 启动..."
            sudo systemctl start elasticsearch
            port=9200
            ;;
        manual)
            info "启动 Elasticsearch (端口 $port)..."
            local es_dir="$BASE/elasticsearch-9.1.2"
            if [[ ! -d "$es_dir" ]]; then
                fail "未找到 ES 安装目录: $es_dir"
                return 1
            fi
            cd "$es_dir"
            nohup bin/elasticsearch > "$BASE/es.log" 2>&1 &
            cd - >/dev/null
            ;;
    esac

    info "等待 ES 集群就绪 (最多 90s)..."
    if wait_http "http://localhost:$port/_cluster/health" "ES" 90; then
        local status
        status=$(curl -sf "http://localhost:$port/_cluster/health" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        ok "启动成功 ($port) — 集群状态: $status"
        return 0
    else
        fail "启动超时 (90s)"
        return 1
    fi
}

# ── Nacos ─────────────────────────────────────────────

start_nacos() {
    echo -e "\n${CYAN}[Nacos 3.0]${NC}"

    if port_up 8848; then
        ok "已在运行 (8848)"
        return 0
    fi

    info "启动 Nacos (standalone)..."

    local nacos_jar="$BASE/nacos/target/nacos-server.jar"
    local nacos_jdk="$BASE/jdk-21/bin/java"

    if [[ ! -f "$nacos_jar" ]]; then
        fail "未找到 Nacos jar: $nacos_jar"
        return 1
    fi
    if [[ ! -x "$nacos_jdk" ]]; then
        fail "未找到 JDK 21: $nacos_jdk"
        return 1
    fi

    # 确保 $HOME/nacos/conf 有正确配置
    mkdir -p "$HOME/nacos/conf"
    if [[ -f "$BASE/nacos/conf/application.properties" ]]; then
        cp "$BASE/nacos/conf/application.properties" "$HOME/nacos/conf/" 2>/dev/null
    fi

    nohup "$nacos_jdk" -Xms256m -Xmx512m \
        -Dnacos.standalone=true \
        -Dnacos.core.auth.server.identity.key=admin \
        -Dnacos.core.auth.server.identity.value=admin \
        -Dnacos.core.auth.plugin.nacos.token.secret.key=VGhpc0lzTXlDdXN0b21TZWNyZXRLZXkwMTIzNDU2Nzg= \
        -jar "$nacos_jar" \
        --server.port=8848 \
        > "$HOME/nacos/logs/start.out" 2>&1 &

    info "等待 Nacos 就绪 (最多 60s)..."
    if wait_port 8848 "Nacos" 60; then
        ok "启动成功 (8848)"
        return 0
    else
        fail "启动超时"
        return 1
    fi
}

# ── RocketMQ NameServer ───────────────────────────────

start_rmq_namesrv() {
    echo -e "\n${CYAN}[RocketMQ NameServer]${NC}"

    if port_up 9876; then
        ok "已在运行 (9876)"
        return 0
    fi

    local rmq_dir="$BASE/rocketmq-all-5.3.2-bin-release"
    if [[ ! -f "$rmq_dir/bin/mqnamesrv" ]]; then
        fail "未找到 RocketMQ: $rmq_dir"
        return 1
    fi

    info "启动 NameServer..."
    export JAVA_HOME="$BASE/jdk-17"
    mkdir -p /tmp/rocketmq/logs
    env JAVA_HOME="$BASE/jdk-17" nohup "$rmq_dir/bin/mqnamesrv" > /tmp/rocketmq/logs/namesrv.log 2>&1 &

    if wait_port 9876 "NameServer" 15; then
        ok "启动成功 (9876)"
        return 0
    else
        fail "启动超时"
        return 1
    fi
}

# ── RocketMQ Broker ───────────────────────────────────

start_rmq_broker() {
    echo -e "\n${CYAN}[RocketMQ Broker]${NC}"

    if port_up 10911; then
        ok "已在运行 (10911)"
        return 0
    fi

    local rmq_dir="$BASE/rocketmq-all-5.3.2-bin-release"

    info "启动 Broker..."
    export JAVA_HOME="$BASE/jdk-17"
    mkdir -p /tmp/rocketmq/store
    env JAVA_HOME="$BASE/jdk-17" nohup "$rmq_dir/bin/mqbroker" -n localhost:9876 > /tmp/rocketmq/logs/broker.log 2>&1 &

    if wait_port 10911 "Broker" 15; then
        ok "启动成功 (10911)"
        return 0
    else
        # 可能内存不够，调小重试
        warn "启动失败，调小内存重试..."
        export JAVA_OPT="-Xms256m -Xmx512m"
        env JAVA_HOME="$BASE/jdk-17" nohup "$rmq_dir/bin/mqbroker" -n localhost:9876 > /tmp/rocketmq/logs/broker.log 2>&1 &
        if wait_port 10911 "Broker" 15; then
            ok "启动成功 (10911, 调小内存)"
            return 0
        fi
        fail "启动超时"
        return 1
    fi
}

# ── 主流程 ────────────────────────────────────────────

main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║  启动全部依赖中间件                       ║"
    echo "╚══════════════════════════════════════════╝"

    local failed=0

    start_mysql      || ((failed++))
    start_redis      || ((failed++))
    start_elasticsearch || ((failed++))
    start_nacos      || ((failed++))
    start_rmq_namesrv || ((failed++))
    start_rmq_broker || ((failed++))

    echo ""
    if (( failed == 0 )); then
        echo -e "${GREEN}全部启动完成 ✔${NC}"
    else
        echo -e "${YELLOW}启动完成，${failed} 个服务异常 ⚠${NC}"
    fi
    echo ""
    echo "查看状态: bash scripts/deps-status.sh"
    echo "停止服务: bash scripts/deps-stop.sh"
    echo ""

    return $failed
}

main "$@"
