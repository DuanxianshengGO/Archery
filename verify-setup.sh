#!/bin/bash

# Archery Docker部署验证脚本

set -e

echo "🔍 验证Archery Docker部署环境..."

# 检查必要的文件
echo "📋 检查必要文件..."

required_files=(
    "docker-compose.yml"
    "Dockerfile"
    ".dockerignore"
    "config/mysql/my.cnf"
    "config/inception/config.toml"
    "config/archery/local_settings.py"
    "config/archery/soar.yaml"
    "sql/engines/odps.py"
)

missing_files=()

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
        echo "❌ 缺少文件: $file"
    else
        echo "✅ 文件存在: $file"
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    echo ""
    echo "❌ 发现缺少文件，请检查部署环境"
    exit 1
fi

# 检查目录结构
echo ""
echo "📁 检查目录结构..."

required_dirs=(
    "config/mysql"
    "config/inception"
    "config/archery"
    "data/mysql"
    "data/archery/logs"
    "data/archery/downloads"
    "data/archery/keys"
)

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "❌ 缺少目录: $dir"
        mkdir -p "$dir"
        echo "✅ 已创建目录: $dir"
    else
        echo "✅ 目录存在: $dir"
    fi
done

# 检查Docker环境
echo ""
echo "🐳 检查Docker环境..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装"
    exit 1
else
    echo "✅ Docker已安装: $(docker --version)"
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose未安装"
    exit 1
else
    echo "✅ Docker Compose已安装: $(docker-compose --version)"
fi

# 检查端口占用
echo ""
echo "🔌 检查端口占用..."

ports=(3306 4000 6379 9123)

for port in "${ports[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "⚠️  端口 $port 已被占用，可能需要停止相关服务"
    else
        echo "✅ 端口 $port 可用"
    fi
done

# 检查ODPS引擎功能
echo ""
echo "🔧 检查ODPS引擎功能..."

if grep -q "def execute_check" sql/engines/odps.py; then
    echo "✅ ODPS引擎包含execute_check方法"
else
    echo "❌ ODPS引擎缺少execute_check方法"
    exit 1
fi

if grep -q "def execute_workflow" sql/engines/odps.py; then
    echo "✅ ODPS引擎包含execute_workflow方法"
else
    echo "❌ ODPS引擎缺少execute_workflow方法"
    exit 1
fi

if grep -q "ReviewSet" sql/engines/odps.py; then
    echo "✅ ODPS引擎导入ReviewSet"
else
    echo "❌ ODPS引擎未导入ReviewSet"
    exit 1
fi

# 验证docker-compose配置
echo ""
echo "📝 验证docker-compose配置..."

if docker-compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml 配置有效"
else
    echo "❌ docker-compose.yml 配置无效"
    docker-compose config
    exit 1
fi

# 检查磁盘空间
echo ""
echo "💾 检查磁盘空间..."

available_space=$(df . | tail -1 | awk '{print $4}')
required_space=10485760  # 10GB in KB

if [ "$available_space" -gt "$required_space" ]; then
    echo "✅ 磁盘空间充足: $(($available_space / 1024 / 1024))GB 可用"
else
    echo "⚠️  磁盘空间不足: $(($available_space / 1024 / 1024))GB 可用，建议至少10GB"
fi

# 检查内存
echo ""
echo "🧠 检查系统内存..."

total_mem=$(free -m | awk 'NR==2{print $2}')
if [ "$total_mem" -gt 4096 ]; then
    echo "✅ 系统内存充足: ${total_mem}MB"
else
    echo "⚠️  系统内存较少: ${total_mem}MB，建议至少4GB"
fi

echo ""
echo "🎉 环境验证完成！"
echo ""
echo "📋 验证结果总结："
echo "  - 必要文件: ✅ 完整"
echo "  - 目录结构: ✅ 正确"
echo "  - Docker环境: ✅ 就绪"
echo "  - ODPS功能: ✅ 已集成"
echo "  - 配置文件: ✅ 有效"
echo ""
echo "🚀 现在可以运行部署脚本："
echo "  ./deploy.sh"
echo ""
echo "📚 或者手动部署："
echo "  docker-compose build"
echo "  docker-compose up -d"
