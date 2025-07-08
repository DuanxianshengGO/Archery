#!/bin/bash

# Archery 快速修复脚本
# 解决常见的路径和配置问题

set -e

echo "🔧 Archery 快速修复脚本"
echo "解决Docker Compose版本警告和路径问题"

# 检查服务状态
echo ""
echo "📋 检查当前服务状态..."
docker-compose ps

# 停止服务
echo ""
echo "🛑 停止现有服务..."
docker-compose down

# 等待服务完全停止
echo "⏳ 等待服务完全停止..."
sleep 5

# 重新启动服务
echo ""
echo "🚀 重新启动服务..."
docker-compose up -d

# 等待服务启动
echo ""
echo "⏳ 等待服务启动..."
sleep 20

# 检查MySQL状态
echo ""
echo "🔍 检查MySQL状态..."
until docker-compose exec mysql mysqladmin ping -h"localhost" --silent 2>/dev/null; do
    echo "  等待MySQL启动..."
    sleep 3
done
echo "✅ MySQL已启动"

# 检查Archery容器状态
echo ""
echo "🔍 检查Archery容器状态..."
if docker-compose exec archery bash -c "cd /opt/archery && ls manage.py" >/dev/null 2>&1; then
    echo "✅ Archery容器正常，manage.py文件存在"
else
    echo "❌ Archery容器异常，manage.py文件不存在"
    echo "📋 容器内文件列表："
    docker-compose exec archery bash -c "ls -la /opt/"
    exit 1
fi

# 检查Python环境
echo ""
echo "🐍 检查Python环境..."
if docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python --version" >/dev/null 2>&1; then
    echo "✅ Python环境正常"
else
    echo "❌ Python环境异常"
    exit 1
fi

# 运行数据库迁移
echo ""
echo "🗄️ 运行数据库迁移..."
if docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py migrate"; then
    echo "✅ 数据库迁移完成"
else
    echo "❌ 数据库迁移失败"
    echo "📋 查看详细错误："
    docker-compose logs archery
    exit 1
fi

# 收集静态文件
echo ""
echo "📁 收集静态文件..."
if docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py collectstatic --noinput"; then
    echo "✅ 静态文件收集完成"
else
    echo "⚠️  静态文件收集失败，但不影响核心功能"
fi

# 验证数据库表
echo ""
echo "🔍 验证数据库表..."
TABLE_COUNT=$(docker-compose exec mysql mysql -uroot -p123456 archery -e "SHOW TABLES;" --skip-column-names 2>/dev/null | wc -l)
if [ "$TABLE_COUNT" -gt 0 ]; then
    echo "✅ 数据库表创建成功，共 $TABLE_COUNT 个表"
else
    echo "❌ 数据库表创建失败"
    exit 1
fi

# 检查服务最终状态
echo ""
echo "📊 检查服务最终状态..."
docker-compose ps

# 测试Web访问
echo ""
echo "🌐 测试Web访问..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:9123 | grep -q "200\|302\|403"; then
    echo "✅ Web服务正常访问"
else
    echo "⚠️  Web服务可能还在启动中，请稍后再试"
fi

echo ""
echo "🎉 快速修复完成！"
echo ""
echo "📋 下一步操作："
echo "1. 创建超级用户："
echo "   docker-compose exec archery bash -c \"cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py createsuperuser\""
echo ""
echo "2. 访问Archery："
echo "   http://localhost:9123"
echo ""
echo "3. 查看日志（如有问题）："
echo "   docker-compose logs -f archery"

# 询问是否创建超级用户
echo ""
read -p "是否现在创建超级用户？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "👤 创建超级用户..."
    docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py createsuperuser"
fi

echo ""
echo "🚀 Archery已准备就绪！"
