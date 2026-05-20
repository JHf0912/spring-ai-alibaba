# install-deps.ps1 — Spring AI Alibaba Admin 本地依赖安装脚本
# 适用于 Windows + Docker Desktop 环境
# 用法: .\scripts\install-deps.ps1

$ErrorActionPreference = "Continue"
$LogFile = "scripts\install-log.md"
$ProjectRoot = Get-Location

# 初始化日志
@"
# 安装日志

> 生成时间: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
> 环境: Windows $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Version)
> Docker: $(docker --version 2>&1 | Select-Object -First 1)

## 执行记录

"@ | Out-File -FilePath $LogFile -Encoding utf8

function Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $msg" -ForegroundColor Cyan
    "[$ts] $msg" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

function LogResult($step, $success, $detail) {
    $status = if ($success) { "OK" } else { "FAIL" }
    $color = if ($success) { "Green" } else { "Red" }
    Write-Host "  -> [$status] $step" -ForegroundColor $color
    "- **$step**: ``$status`` — $detail" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

# ============================================
# Step 0: 前置检查
# ============================================
Log "Step 0: 前置检查"

# 检查 Docker
$dockerOk = $null -ne (docker info 2>&1 | Select-String "Server Version")
if ($dockerOk) {
    LogResult "Docker 运行状态" $true "Docker Desktop 运行中"
} else {
    LogResult "Docker 运行状态" $false "Docker Desktop 未运行"
    Write-Host "请先启动 Docker Desktop，然后重新运行此脚本" -ForegroundColor Red
    exit 1
}

# 检查 docker compose
$composeOk = docker compose version 2>&1
LogResult "Docker Compose" ($LASTEXITCODE -eq 0) "$composeOk"

# ============================================
# Step 1: 启动中间件 (Docker Compose)
# ============================================
Log "Step 1: 启动中间件服务"

$composeFile = "docker\middleware\docker-compose-prod.yaml"
if (-not (Test-Path $composeFile)) {
    LogResult "Compose 文件检查" $false "找不到 $composeFile"
    exit 1
}
LogResult "Compose 文件检查" $true "找到 $composeFile"

# 生成 .env 文件
$envFile = "docker\middleware\.env"
$uid = id -u 2>$null; if (-not $uid) { $uid = 1000 }
$gid = id -g 2>$null; if (-not $gid) { $gid = 1000 }
@"
UID=$uid
GID=$gid
TZ=Asia/Shanghai
MIDDLEWARE_HOME=.
"@ | Out-File -FilePath $envFile -Encoding utf8
LogResult ".env 生成" $true "写入 $envFile"

# 启动所有中间件
Log "启动 Docker Compose 服务（首次拉取镜像可能需要几分钟）..."
$pullOutput = docker compose -f $composeFile pull 2>&1
LogResult "镜像拉取" ($LASTEXITCODE -eq 0) "pull 完成"

$upOutput = docker compose -f $composeFile up -d 2>&1
LogResult "服务启动" ($LASTEXITCODE -eq 0) "up -d 完成"

# 等待服务就绪
Log "等待服务就绪（最多 120 秒）..."
$services = @("mysql", "redis", "elasticsearch", "nacos", "rmq_namesrv", "rmq_broker")
$timeout = 120
$elapsed = 0
while ($elapsed -lt $timeout) {
    $allUp = $true
    foreach ($svc in $services) {
        $state = docker inspect --format='{{.State.Status}}' $svc 2>&1
        if ($state -ne "running") { $allUp = $false; break }
    }
    if ($allUp) { break }
    Start-Sleep -Seconds 5
    $elapsed += 5
    Write-Host "." -NoNewline
}
Write-Host ""
LogResult "服务状态检查" $allUp "等待 ${elapsed}s"

# ============================================
# Step 2: 验证各服务连通性
# ============================================
Log "Step 2: 验证服务连通性"

# MySQL
$mysqlOk = docker exec mysql mysqladmin ping -h localhost -u root -proot 2>&1
LogResult "MySQL ping" ($LASTEXITCODE -eq 0) "$mysqlOk"

# Redis
$redisOk = docker exec redis redis-cli ping 2>&1
LogResult "Redis ping" ($redisOk -match "PONG") "$redisOk"

# Elasticsearch
$esOk = Invoke-WebRequest -Uri "http://localhost:9200/_cluster/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
LogResult "ES health" ($null -ne $esOk) "HTTP $($esOk.StatusCode)"

# Nacos
$nacosOk = Invoke-WebRequest -Uri "http://localhost:8848/nacos/" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
LogResult "Nacos console" ($null -ne $nacosOk) "HTTP $($nacosOk.StatusCode)"

# RocketMQ
$rmqOk = Invoke-WebRequest -Uri "http://localhost:18080" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
LogResult "RocketMQ Proxy" ($null -ne $rmqOk -or $LASTEXITCODE -eq 0) "可连接"

# ============================================
# Step 3: 初始化 MySQL 数据库
# ============================================
Log "Step 3: 初始化 MySQL 数据库"

# 等待 MySQL 完全就绪
$mysqlReady = $false
for ($i = 0; $i -lt 30; $i++) {
    $check = docker exec mysql mysql -u root -proot -e "SELECT 1" 2>&1
    if ($LASTEXITCODE -eq 0) { $mysqlReady = $true; break }
    Start-Sleep -Seconds 2
}
LogResult "MySQL 就绪" $mysqlReady "等待数据库完全启动"

# 创建 admin 数据库
$createDb = docker exec mysql mysql -u root -proot -e "CREATE DATABASE IF NOT EXISTS admin DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_0900_ai_ci;" 2>&1
LogResult "创建 admin 数据库" ($LASTEXITCODE -eq 0) "$createDb"

# 执行 admin-schema.sql
$sqlFile = "docker\middleware\init\mysql\admin-schema.sql"
if (Test-Path $sqlFile) {
    $execSql = Get-Content $sqlFile -Raw | docker exec -i mysql mysql -u root -proot admin 2>&1
    LogResult "执行 admin-schema.sql" ($LASTEXITCODE -eq 0) "建表完成"
} else {
    LogResult "执行 admin-schema.sql" $false "文件不存在: $sqlFile"
}

# 执行 agentscope-schema.sql
$sqlFile2 = "docker\middleware\init\mysql\agentscope-schema.sql"
if (Test-Path $sqlFile2) {
    $execSql2 = Get-Content $sqlFile2 -Raw | docker exec -i mysql mysql -u root -proot admin 2>&1
    LogResult "执行 agentscope-schema.sql" ($LASTEXITCODE -eq 0) "建表完成"
} else {
    LogResult "执行 agentscope-schema.sql" $false "文件不存在: $sqlFile2"
}

# 验证表已创建
$tables = docker exec mysql mysql -u root -proot admin -e "SHOW TABLES;" 2>&1
$tableCount = ($tables | Select-String -Pattern "\w+" | Measure-Object).Count
LogResult "表数量验证" ($tableCount -gt 10) "共 $tableCount 张表"

# ============================================
# Step 4: 初始化 Elasticsearch 索引
# ============================================
Log "Step 4: 初始化 Elasticsearch 索引"

# 等待 ES 就绪
$esReady = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:9200/_cluster/health" -UseBasicParsing -TimeoutSec 3
        if ($resp.StatusCode -eq 200) { $esReady = $true; break }
    } catch { }
    Start-Sleep -Seconds 3
}
LogResult "ES 就绪" $esReady "等待 Elasticsearch 启动"

# 创建 ingest pipeline
$pipelineBody = @{
    description = "Parse loongsuite traces"
    processors = @(
        @{
            json = @{
                field = "message"
                target_field = "parsed"
            }
        }
    )
} | ConvertTo-Json -Depth 5

try {
    $pipelineResp = Invoke-WebRequest -Uri "http://localhost:9200/_ingest/pipeline/parsing_loongsuite_traces" `
        -Method PUT -Body $pipelineBody -ContentType "application/json" -UseBasicParsing -TimeoutSec 10
    LogResult "创建 ES Pipeline" $true "HTTP $($pipelineResp.StatusCode)"
} catch {
    LogResult "创建 ES Pipeline" $false "$($_.Exception.Message)"
}

# 创建 traces 索引
$indexBody = @{
    settings = @{
        number_of_shards = 1
        number_of_replicas = 0
    }
    mappings = @{
        properties = @{
            traceId = @{ type = "keyword" }
            spanId = @{ type = "keyword" }
            parentSpanId = @{ type = "keyword" }
            name = @{ type = "keyword" }
            serviceName = @{ type = "keyword" }
            startTime = @{ type = "long" }
            endTime = @{ type = "long" }
            duration = @{ type = "long" }
            status = @{ type = "keyword" }
            attributes = @{ type = "object"; enabled = $false }
        }
    }
} | ConvertTo-Json -Depth 10

try {
    $indexResp = Invoke-WebRequest -Uri "http://localhost:9200/loongsuite_traces" `
        -Method PUT -Body $indexBody -ContentType "application/json" -UseBasicParsing -TimeoutSec 10
    LogResult "创建 ES 索引 loongsuite_traces" $true "HTTP $($indexResp.StatusCode)"
} catch {
    if ($_.Exception.Message -match "resource_already_exists") {
        LogResult "创建 ES 索引 loongsuite_traces" $true "索引已存在，跳过"
    } else {
        LogResult "创建 ES 索引 loongsuite_traces" $false "$($_.Exception.Message)"
    }
}

# ============================================
# Step 5: 配置 Nacos
# ============================================
Log "Step 5: 配置 Nacos"

# 等待 Nacos 就绪
$nacosReady = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:8848/nacos/v1/console/health/readiness" -UseBasicParsing -TimeoutSec 3
        if ($resp.Content -match "UP") { $nacosReady = $true; break }
    } catch { }
    Start-Sleep -Seconds 3
}
LogResult "Nacos 就绪" $nacosReady "等待 Nacos 启动"

# Nacos 无需额外配置，项目使用默认 public 命名空间
LogResult "Nacos 命名空间" $true "使用默认 public 命名空间"

# ============================================
# Step 6: 检查模型配置
# ============================================
Log "Step 6: 模型配置检查"

$modelConfig = "spring-ai-alibaba-admin-server-start\model-config.yaml"
if (Test-Path $modelConfig) {
    LogResult "model-config.yaml" $true "已存在"
} else {
    # 从 DashScope 模板复制
    $template = "spring-ai-alibaba-admin-server-start\model-config-dashscope.yaml"
    if (Test-Path $template) {
        Copy-Item $template $modelConfig
        LogResult "model-config.yaml" $true "从 dashscope 模板创建，请设置 DASHSCOPE_API_KEY 环境变量"
    } else {
        LogResult "model-config.yaml" $false "模板文件不存在，请手动创建"
    }
}

# ============================================
# Step 7: 生成 .env.local 环境变量文件
# ============================================
Log "Step 7: 生成环境变量文件"

$envLocal = @"
# Spring AI Alibaba Admin 本地开发环境变量
# 使用方法: 在 IDE 中加载此文件，或在 PowerShell 中执行: Get-Content .env.local | ForEach-Object { Invoke-Expression "`$_" }

# MySQL
SPRING_DATASOURCE_URL=jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai
SPRING_DATASOURCE_USERNAME=admin
SPRING_DATASOURCE_PASSWORD=admin

# Redis
SPRING_REDIS_HOST=localhost
SPRING_REDIS_PORT=6379
SPRING_REDIS_DATABASE=0

# Elasticsearch
SPRING_ELASTICSEARCH_URIS=http://localhost:9200

# Nacos
NACOS_SERVER_ADDR=localhost:8848

# RocketMQ
ROCKETMQ_ENDPOINTS=localhost:18080
ROCKETMQ_DOCUMENT_INDEX_TOPIC=topic_saa_studio_document_index
ROCKETMQ_DOCUMENT_INDEX_GROUP=group_saa_studio_document_index

# OTLP Tracing
MANAGEMENT_OTLP_TRACING_EXPORT_ENDPOINT=http://localhost:4318/v1/traces

# AI Model API Key (三选一，取消注释并填入你的 Key)
# DASHSCOPE_API_KEY=your-key-here
# OPENAI_API_KEY=your-key-here
# DEEPSEEK_API_KEY=your-key-here
"@
$envLocal | Out-File -FilePath ".env.local" -Encoding utf8
LogResult "生成 .env.local" $true "环境变量文件已创建"

# ============================================
# Step 8: 最终验证
# ============================================
Log "Step 8: 最终验证"

$checks = @(
    @{ name = "MySQL"; cmd = "docker exec mysql mysqladmin ping -h localhost -u root -proot 2>&1" },
    @{ name = "Redis"; cmd = "docker exec redis redis-cli ping 2>&1" },
    @{ name = "ES"; cmd = "curl -s http://localhost:9200/_cluster/health 2>&1" },
    @{ name = "Nacos"; cmd = "curl -s http://localhost:8848/nacos/v1/console/health/readiness 2>&1" }
)

$allPass = $true
foreach ($check in $checks) {
    $result = Invoke-Expression $check.cmd
    $pass = $result -match "PONG|UP|green|yellow"
    if (-not $pass) { $allPass = $false }
    LogResult "$($check.name) 最终验证" $pass "$result"
}

# 汇总
""
if ($allPass) {
    Log "===== 全部服务就绪 ====="
    Write-Host ""
    Write-Host "所有依赖已安装并启动！" -ForegroundColor Green
    Write-Host ""
    Write-Host "下一步:" -ForegroundColor Yellow
    Write-Host "  1. 设置 API Key: `$env:DASHSCOPE_API_KEY = 'your-key'"
    Write-Host "  2. 启动后端: make backend-start"
    Write-Host "  3. 启动前端: make frontend-start"
    Write-Host "  4. 访问: http://localhost:8000"
    Write-Host ""
    Write-Host "环境变量文件: .env.local" -ForegroundColor Cyan
    Write-Host "安装日志: scripts/install-log.md" -ForegroundColor Cyan
} else {
    Log "===== 部分服务未就绪 ====="
    Write-Host "部分服务启动失败，请查看 scripts/install-log.md" -ForegroundColor Red
}

# 追加汇总到日志
@"

## 汇总

- 总步骤: 8
- 全部通过: $allPass
- 完成时间: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Out-File -FilePath $LogFile -Append -Encoding utf8
