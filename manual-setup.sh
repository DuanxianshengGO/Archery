#!/bin/bash

# Archery 手动数据库初始化脚本

set -e

echo "🗄️ Archery 手动数据库初始化..."

# 检查服务是否运行
echo "📋 检查Docker服务状态..."
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Docker服务未运行，请先启动服务："
    echo "   docker-compose up -d"
    exit 1
fi

# 等待MySQL就绪
echo "⏳ 等待MySQL服务就绪..."
until docker-compose exec mysql mysqladmin ping -h"localhost" --silent 2>/dev/null; do
    echo "  等待MySQL启动..."
    sleep 3
done

echo "✅ MySQL已启动"

# 检查数据库是否存在
echo "🔍 检查archery数据库..."
DB_EXISTS=$(docker-compose exec mysql mysql -uroot -p123456 -e "SHOW DATABASES LIKE 'archery';" --skip-column-names 2>/dev/null | wc -l)

if [ "$DB_EXISTS" -eq 0 ]; then
    echo "📝 创建archery数据库..."
    docker-compose exec mysql mysql -uroot -p123456 -e "CREATE DATABASE IF NOT EXISTS archery DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    echo "✅ 数据库创建完成"
else
    echo "✅ archery数据库已存在"
fi

# 检查Archery服务是否就绪
echo "⏳ 等待Archery服务就绪..."
until docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python -c 'import django; print(\"Django ready\")'" 2>/dev/null; do
    echo "  等待Archery服务启动..."
    sleep 3
done

echo "✅ Archery服务已就绪"

# 运行数据库迁移
echo "🔄 运行数据库迁移..."
docker-compose exec archery bash -c "
    cd /opt/archery &&
    source /opt/venv4archery/bin/activate &&
    python manage.py makemigrations &&
    python manage.py migrate
"

if [ $? -eq 0 ]; then
    echo "✅ 数据库迁移完成"
else
    echo "❌ 数据库迁移失败"
    exit 1
fi

# 收集静态文件
echo "📁 收集静态文件..."
docker-compose exec archery bash -c "
    cd /opt/archery &&
    source /opt/venv4archery/bin/activate &&
    python manage.py collectstatic --noinput
"

if [ $? -eq 0 ]; then
    echo "✅ 静态文件收集完成"
else
    echo "⚠️  静态文件收集失败，但不影响核心功能"
fi

# 检查表是否创建成功
echo "🔍 验证数据库表..."
TABLE_COUNT=$(docker-compose exec mysql mysql -uroot -p123456 archery -e "SHOW TABLES;" --skip-column-names 2>/dev/null | wc -l)

if [ "$TABLE_COUNT" -gt 0 ]; then
    echo "✅ 数据库表创建成功，共 $TABLE_COUNT 个表"
else
    echo "❌ 数据库表创建失败"
    exit 1
fi

# 创建超级用户提示
echo ""
echo "🎉 数据库初始化完成！"
echo ""
echo "📋 下一步操作："
echo "1. 创建超级用户（管理员账号）："
echo "   docker-compose exec archery bash -c \"cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py createsuperuser\""
echo ""
echo "2. 访问Archery："
echo "   http://localhost:9123"
echo ""
echo "3. 查看服务状态："
echo "   docker-compose ps"
echo ""
echo "4. 查看日志："
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
