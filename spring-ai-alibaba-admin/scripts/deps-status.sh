#!/usr/bin/env bash
#
# deps-status.sh — 查看 Spring AI Alibaba Admin 全部依赖中间件的运行状态
#
# 输出每个中间件的：运行状态、PID、端口监听、额外信息
#
# 用法：bash scripts/deps-status.sh
#
set -uo pipefail

BASE="$HOME/.saa-middleware"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

# ── 检测函数 ──────────────────────────────────────────

port_pid() {
    # 返回监听指定端口的 PID，无则返回空
    ss -tlnp 2>/dev/null | grep ":$1 " | grep -oP 'pid=\K[0-9]+' | head -1
}

port_up() { ss -tlnp 2>/dev/null | grep -q ":$1 "; }

proc_alive() {
    # 检查是否有匹配 pattern 的进程
    pgrep -f "$1" >/dev/null 2>&1
}

# ── 单个服务状态 ──────────────────────────────────────

check_service() {
    local name="$1" port="$2" pattern="$3" alt_port="${4:-}"

    local pid="" status="" extra="" actual_port=""

    # 检查主端口
    pid=$(port_pid "$port")
    if [[ -n "$pid" ]]; then
        actual_port="$port"
    elif [[ -n "$alt_port" ]]; then
        # 检查备用端口
        pid=$(port_pid "$alt_port")
        [[ -n "$pid" ]] && actual_port="$alt_port"
    fi

    if [[ -n "$pid" ]]; then
        status="${GREEN}RUNNING${NC}"
        extra="PID=$pid"
    elif proc_alive "$pattern"; then
        # 进程存在但端口没监听（可能还在启动中）
        pid=$(pgrep -f "$pattern" | head -1)
        status="${YELLOW}STARTING${NC}"
        extra="PID=$pid (端口未就绪)"
        actual_port="-"
    else
        status="${RED}STOPPED${NC}"
        extra="-"
        actual_port="-"
    fi

    printf "  %-24s  %-20b  %-6s  %-8s  %s\n" "$name" "$status" "${actual_port:--}" "${pid:--}" "$extra"
}

# ── 特殊检查 ──────────────────────────────────────────

check_mysql() {
    local pid="" status="" extra="" port="-"
    pid=$(port_pid 3306)
    local sock_alive=false
    [[ -S "$BASE/mysql.sock" ]] && sock_alive=true

    if [[ -n "$pid" ]] || $sock_alive; then
        [[ -n "$pid" ]] && port=3306 || port="sock"
        # 如果没有 TCP PID，从 pgrep 获取
        [[ -z "$pid" ]] && pid=$(pgrep -x mysqld 2>/dev/null | head -1)
        # 尝试查询
        local ver=""
        if $sock_alive; then
            ver=$("$BASE/mysql/bin/mysql" -S "$BASE/mysql.sock" -u root -N -e "SELECT VERSION()" 2>/dev/null)
        fi
        status="${GREEN}RUNNING${NC}"
        extra="PID=${pid:--}"
        [[ -n "$ver" ]] && extra="$extra  v$ver"
    elif proc_alive "mysqld"; then
        pid=$(pgrep -f mysqld | head -1)
        status="${YELLOW}STARTING${NC}"
        extra="PID=$pid (端口未就绪)"
    else
        status="${RED}STOPPED${NC}"
        extra="-"
    fi

    printf "  %-24s  %-20b  %-6s  %-8s  %s\n" "MySQL 8.0" "$status" "$port" "${pid:--}" "$extra"
}

check_es() {
    local pid="" status="" extra="" port="-"
    pid=$(port_pid 9201)
    [[ -z "$pid" ]] && pid=$(port_pid 9200)

    if [[ -n "$pid" ]]; then
        port=$(port_pid 9201 &>/dev/null && echo 9201 || echo 9200)
        [[ -n "$(port_pid 9201)" ]] && port=9201 || port=9200
        local cluster_status
        cluster_status=$(curl -sf "http://localhost:$port/_cluster/health" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        status="${GREEN}RUNNING${NC}"
        extra="PID=$pid"
        [[ -n "$cluster_status" ]] && extra="$extra  cluster=$cluster_status"
    elif proc_alive "elasticsearch"; then
        pid=$(pgrep -f elasticsearch | head -1)
        status="${YELLOW}STARTING${NC}"
        extra="PID=$pid (端口未就绪)"
    else
        status="${RED}STOPPED${NC}"
        extra="-"
    fi

    printf "  %-24s  %-20b  %-6s  %-8s  %s\n" "Elasticsearch 9.1" "$status" "$port" "${pid:--}" "$extra"
}

check_redis() {
    local pid="" status="" extra="" port="-"
    pid=$(port_pid 6380)
    [[ -z "$pid" ]] && pid=$(port_pid 6379)

    if [[ -n "$pid" ]]; then
        [[ -n "$(port_pid 6380)" ]] && port=6380 || port=6379
        local pong
        pong=$("$BASE/redis/bin/redis-cli" -p "$port" ping 2>/dev/null)
        status="${GREEN}RUNNING${NC}"
        extra="PID=$pid"
        [[ "$pong" == "PONG" ]] && extra="$extra  PONG"
    elif proc_alive "redis-server"; then
        pid=$(pgrep -f redis-server | head -1)
        status="${YELLOW}STARTING${NC}"
        extra="PID=$pid (端口未就绪)"
    else
        status="${RED}STOPPED${NC}"
        extra="-"
    fi

    printf "  %-24s  %-20b  %-6s  %-8s  %s\n" "Redis 7.x" "$status" "$port" "${pid:--}" "$extra"
}

check_nacos() {
    local pid="" status="" extra="" port="-"
    pid=$(port_pid 8848)

    if [[ -n "$pid" ]]; then
        port=8848
        local http_code
        http_code=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:8848/nacos/" 2>/dev/null || echo "000")
        status="${GREEN}RUNNING${NC}"
        extra="PID=$pid  HTTP=$http_code"
    elif proc_alive "nacos-server"; then
        pid=$(pgrep -f "nacos-server" | head -1)
        status="${YELLOW}STARTING${NC}"
        extra="PID=$pid (端口未就绪)"
    else
        status="${RED}STOPPED${NC}"
        extra="-"
    fi

    printf "  %-24s  %-20b  %-6s  %-8s  %s\n" "Nacos 3.0" "$status" "$port" "${pid:--}" "$extra"
}

check_rmq() {
    local name="$1" port="$2" pattern="$3"
    local pid="" status="" extra="-"

    pid=$(port_pid "$port")

    if [[ -n "$pid" ]]; then
        status="${GREEN}RUNNING${NC}"
        extra="PID=$pid"
    elif proc_alive "$pattern"; then
        pid=$(pgrep -f "$pattern" | head -1)
        status="${YELLOW}STARTING${NC}"
        extra="PID=$pid (端口未就绪)"
    else
        status="${RED}STOPPED${NC}"
    fi

    printf "  %-24s  %-20b  %-6s  %-8s  %s\n" "$name" "$status" "$port" "${pid:--}" "$extra"
}

# ── 端口占用汇总 ──────────────────────────────────────

print_ports() {
    echo ""
    echo -e "${BOLD}端口监听汇总:${NC}"
    echo "  ┌──────────┬───────────┬─────────────────────────────┐"
    echo "  │ 端口     │ 协议      │ 进程                        │"
    echo "  ├──────────┼───────────┼─────────────────────────────┤"

    for port in 3306 6379 6380 8848 9200 9201 9876 10911 18080; do
        local info
        info=$(ss -tlnp 2>/dev/null | grep ":$port " | head -1)
        if [[ -n "$info" ]]; then
            local pid proc
            pid=$(echo "$info" | grep -oP 'pid=\K[0-9]+' | head -1)
            proc=$(echo "$info" | grep -oP 'users:\(\("\K[^"]+' | head -1)
            printf "  │ %-8s │ TCP       │ %-27s │\n" "$port" "${proc:--} (PID ${pid:--})"
        fi
    done

    echo "  └──────────┴───────────┴─────────────────────────────┘"
}

# ── 主流程 ────────────────────────────────────────────

main() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  Spring AI Alibaba Admin — 依赖中间件状态                             ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    printf "  ${BOLD}%-24s  %-20s  %-6s  %-8s  %s${NC}\n" "服务" "状态" "端口" "PID" "详情"
    echo "  ────────────────────────  ──────────────────  ──────  ────────  ─────────"

    check_mysql
    check_redis
    check_es
    check_nacos
    check_rmq "RocketMQ NameServer" 9876 "mqnamesrv"
    check_rmq "RocketMQ Broker"     10911 "mqbroker"

    # 可选组件
    local proxy_pid
    proxy_pid=$(port_pid 18080)
    if [[ -n "$proxy_pid" ]]; then
        printf "  %-24s  %-20b  %-6s  %-8s  %s\n" "RocketMQ Proxy" "${GREEN}RUNNING${NC}" "18080" "$proxy_pid" "PID=$proxy_pid"
    fi

    print_ports

    # 汇总（含 socket 检测）
    local total=0 running=0
    # MySQL: socket 或端口
    ((total++))
    { port_up 3306 || [[ -S "$BASE/mysql.sock" ]]; } && ((running++))
    # 其他 TCP 端口
    for port in 6380 9201 8848 9876 10911; do
        ((total++))
        port_up "$port" && ((running++))
    done

    echo ""
    if (( running == total )); then
        echo -e "  ${GREEN}${BOLD}全部 $total 个核心服务运行中 ✔${NC}"
    else
        echo -e "  ${YELLOW}${BOLD}$running/$total 个核心服务运行中${NC}"
        echo -e "  ${YELLOW}启动缺失服务: bash scripts/deps-start.sh${NC}"
    fi
    echo ""
}

main "$@"
