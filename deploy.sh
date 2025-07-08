#!/bin/bash

# Archery Docker部署脚本
# 包含ODPS审核功能的自定义镜像构建和部署

set -e

echo "🚀 开始部署Archery（包含ODPS审核功能）..."

# 检查Docker和Docker Compose是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose未安装，请先安装Docker Compose"
    exit 1
fi

# 检查必要的配置文件
echo "📋 检查配置文件..."
if [ ! -f "config/mysql/my.cnf" ]; then
    echo "❌ MySQL配置文件不存在: config/mysql/my.cnf"
    exit 1
fi

if [ ! -f "config/inception/config.toml" ]; then
    echo "❌ GoInception配置文件不存在: config/inception/config.toml"
    exit 1
fi

if [ ! -f "config/archery/local_settings.py" ]; then
    echo "❌ Archery配置文件不存在: config/archery/local_settings.py"
    exit 1
fi

echo "✅ 配置文件检查完成"

# 停止现有容器（如果存在）
echo "🛑 停止现有容器..."
docker-compose down --remove-orphans || true

# 清理旧镜像（可选）
read -p "是否清理旧的Archery镜像？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧹 清理旧镜像..."
    docker image prune -f
    docker rmi $(docker images | grep archery | awk '{print $3}') 2>/dev/null || true
fi

# 构建自定义镜像
echo "🔨 构建包含ODPS审核功能的Archery镜像..."
docker-compose build --no-cache archery

# 启动服务
echo "🚀 启动服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo "📊 检查服务状态..."
docker-compose ps

# 等待数据库就绪
echo "⏳ 等待数据库就绪..."
until docker-compose exec mysql mysqladmin ping -h"localhost" --silent; do
    echo "等待MySQL启动..."
    sleep 2
done

# 初始化数据库
echo "🗄️ 初始化数据库..."
docker-compose exec archery bash -c "source /opt/venv4archery/bin/activate && python manage.py migrate"

# 创建超级用户（可选）
read -p "是否创建超级用户？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "👤 创建超级用户..."
    docker-compose exec archery bash -c "source /opt/venv4archery/bin/activate && python manage.py createsuperuser"
fi

# 显示访问信息
echo ""
echo "🎉 部署完成！"
echo ""
echo "📋 服务信息："
echo "  - Archery Web界面: http://localhost:9123"
echo "  - MySQL数据库: localhost:3306"
echo "  - GoInception: localhost:4000"
echo ""
echo "📁 数据目录："
echo "  - MySQL数据: ./data/mysql"
echo "  - Archery日志: ./data/archery/logs"
echo "  - 下载文件: ./data/archery/downloads"
echo ""
echo "⚙️ 配置文件："
echo "  - Archery配置: ./config/archery/local_settings.py"
echo "  - MySQL配置: ./config/mysql/my.cnf"
echo "  - GoInception配置: ./config/inception/config.toml"
echo ""
echo "🔧 常用命令："
echo "  - 查看日志: docker-compose logs -f archery"
echo "  - 重启服务: docker-compose restart"
echo "  - 停止服务: docker-compose down"
echo "  - 进入容器: docker-compose exec archery bash"
echo ""
echo "✨ ODPS审核功能已集成，可以在实例管理中添加ODPS实例并使用SQL上线申请功能！"
