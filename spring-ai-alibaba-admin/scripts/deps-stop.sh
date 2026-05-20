#!/usr/bin/env bash
#
# deps-stop.sh — 一键停止 Spring AI Alibaba Admin 全部依赖中间件
#
# 按依赖关系逆序停止：Broker → NameServer → Nacos → ES → Redis → MySQL
# 支持 brew services / systemd / 手动进程三种方式
#
# 用法：bash scripts/deps-stop.sh
#
set -uo pipefail

BASE="$HOME/.saa-middleware"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✔${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
info() { echo -e "  ${CYAN}→${NC} $*"; }

port_up() { ss -tlnp 2>/dev/null | grep -q ":$1 " || lsof -i :"$1" &>/dev/null; }

# 尝试多种方式停止一个服务
stop_service() {
    local name="$1" port="$2" pattern="$3" brew_name="$4" systemd_name="$5" shutdown_cmd="$6"

    echo -e "\n${CYAN}[$name]${NC}"

    if ! port_up "$port"; then
        ok "未在运行"
        return 0
    fi

    # 方式 1: 专用 shutdown 命令
    if [[ -n "$shutdown_cmd" ]]; then
        info "尝试 shutdown 命令..."
        eval "$shutdown_cmd" 2>/dev/null && sleep 2
        if ! port_up "$port"; then
            ok "已停止"
            return 0
        fi
    fi

    # 方式 2: brew services
    if command -v brew &>/dev/null && [[ -n "$brew_name" ]]; then
        if brew services list 2>/dev/null | grep -q "$brew_name"; then
            info "通过 brew services 停止..."
            brew services stop "$brew_name" 2>/dev/null && sleep 2
            if ! port_up "$port"; then
                ok "已停止"
                return 0
            fi
        fi
    fi

    # 方式 3: systemd
    if command -v systemctl &>/dev/null && [[ -n "$systemd_name" ]]; then
        if systemctl is-active "$systemd_name" &>/dev/null; then
            info "通过 systemctl 停止..."
            sudo systemctl stop "$systemd_name" 2>/dev/null && sleep 2
            if ! port_up "$port"; then
                ok "已停止"
                return 0
            fi
        fi
    fi

    # 方式 4: pkill
    if [[ -n "$pattern" ]]; then
        info "终止进程 (pattern: $pattern)..."
        pkill -f "$pattern" 2>/dev/null
        sleep 2
        # 如果还活着，SIGKILL
        if pgrep -f "$pattern" >/dev/null 2>&1; then
            pkill -9 -f "$pattern" 2>/dev/null
            sleep 1
        fi
    fi

    if ! port_up "$port"; then
        ok "已停止"
        return 0
    else
        warn "端口 $port 仍被占用"
        return 1
    fi
}

main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║  停止全部依赖中间件                       ║"
    echo "╚══════════════════════════════════════════╝"

    # 按依赖关系逆序停止
    stop_service "RocketMQ Broker"      10911 "mqbroker"      "" "" ""
    stop_service "RocketMQ NameServer"  9876  "mqnamesrv"     "" "" ""
    stop_service "Nacos 3.0"            8848  "nacos-server"  "" "" ""
    stop_service "Elasticsearch 9.1"    9201  "elasticsearch" "elasticsearch-full" "elasticsearch" ""
    # ES 也检查 9200
    if port_up 9200; then
        pkill -f "elasticsearch" 2>/dev/null
        sleep 2
    fi
    stop_service "Redis 7.x"           6380  "redis-server"  "redis" "redis-server" "$BASE/redis/bin/redis-cli -p 6380 shutdown 2>/dev/null"
    # Redis 也检查 6379
    if port_up 6379; then
        if command -v brew &>/dev/null; then
            brew services stop redis 2>/dev/null
        else
            "$BASE/redis/bin/redis-cli" -p 6379 shutdown 2>/dev/null
            pkill -f "redis-server" 2>/dev/null
        fi
        sleep 1
    fi
    stop_service "MySQL 8.0"           3306  "mysqld"        "mysql" "mysql" "$BASE/mysql/bin/mysqladmin -S $BASE/mysql.sock shutdown 2>/dev/null"

    echo ""
    echo -e "${GREEN}全部停止完成 ✔${NC}"
    echo ""
    echo "查看状态: bash scripts/deps-status.sh"
    echo "启动服务: bash scripts/deps-start.sh"
    echo ""
}

main "$@"
