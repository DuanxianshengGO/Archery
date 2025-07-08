# Archery Docker部署故障排除指南

## 常见问题及解决方案

### 1. 数据库表不存在错误

**错误信息**:
```
django.db.utils.ProgrammingError: (1146, "Table 'archery.sql_config' doesn't exist")
```

**原因**: 数据库连接正常，但表结构未创建

**解决方案**:

#### 方案A: 使用自动初始化脚本（推荐）
```bash
./manual-setup.sh
```

#### 方案B: 手动步骤
```bash
# 1. 确保服务运行
docker-compose up -d

# 2. 等待MySQL启动
sleep 15

# 3. 检查MySQL状态
docker-compose exec mysql mysqladmin ping

# 4. 创建数据库（如果不存在）
docker-compose exec mysql mysql -uroot -p123456 -e "CREATE DATABASE IF NOT EXISTS archery DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 5. 运行数据库迁移
docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py migrate"

# 6. 创建超级用户
docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py createsuperuser"
```

#### 方案C: 使用SQL脚本
```bash
# 执行初始化SQL
docker-compose exec mysql mysql -uroot -p123456 < init-database.sql

# 然后运行迁移
docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py migrate"
```

### 2. MySQL连接失败

**错误信息**:
```
django.db.utils.OperationalError: (2003, "Can't connect to MySQL server")
```

**解决方案**:
```bash
# 检查MySQL容器状态
docker-compose ps mysql

# 查看MySQL日志
docker-compose logs mysql

# 重启MySQL服务
docker-compose restart mysql

# 等待MySQL完全启动
sleep 10
```

### 3. 端口占用问题

**错误信息**:
```
ERROR: for mysql  Cannot start service mysql: driver failed programming external connectivity
```

**解决方案**:
```bash
# 检查端口占用
netstat -tlnp | grep -E '(3306|6379|4000|9123)'

# 停止占用端口的服务
sudo systemctl stop mysql  # 如果本地有MySQL
sudo systemctl stop redis  # 如果本地有Redis

# 或者修改docker-compose.yml中的端口映射
```

### 4. 权限问题

**错误信息**:
```
Permission denied
```

**解决方案**:
```bash
# 修复数据目录权限
sudo chown -R $USER:$USER data/
chmod -R 755 data/

# 修复脚本权限
chmod +x deploy.sh
chmod +x manual-setup.sh
chmod +x verify-setup.sh
```

### 5. 磁盘空间不足

**错误信息**:
```
No space left on device
```

**解决方案**:
```bash
# 检查磁盘空间
df -h

# 清理Docker资源
docker system prune -f
docker volume prune -f

# 清理旧镜像
docker image prune -a -f
```

### 6. 内存不足

**症状**: 容器频繁重启或OOM错误

**解决方案**:
```bash
# 检查内存使用
free -h
docker stats

# 调整docker-compose.yml中的内存限制
# 在服务配置中添加：
# mem_limit: 1g
# memswap_limit: 1g
```

### 7. Archery服务启动失败

**解决方案**:
```bash
# 查看详细日志
docker-compose logs -f archery

# 进入容器调试
docker-compose exec archery bash

# 手动启动服务
docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py runserver 0.0.0.0:9123"
```

### 8. 静态文件问题

**症状**: 页面样式丢失

**解决方案**:
```bash
# 收集静态文件
docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py collectstatic --noinput"

# 检查nginx配置
docker-compose exec archery cat /etc/nginx/nginx.conf
```

## 调试命令

### 查看服务状态
```bash
docker-compose ps
```

### 查看日志
```bash
# 所有服务日志
docker-compose logs -f

# 特定服务日志
docker-compose logs -f archery
docker-compose logs -f mysql
```

### 进入容器
```bash
# 进入Archery容器
docker-compose exec archery bash

# 进入MySQL容器
docker-compose exec mysql bash
```

### 数据库操作
```bash
# 连接数据库
docker-compose exec mysql mysql -uroot -p123456 archery

# 查看表
docker-compose exec mysql mysql -uroot -p123456 archery -e "SHOW TABLES;"

# 检查表结构
docker-compose exec mysql mysql -uroot -p123456 archery -e "DESCRIBE sql_config;"
```

### Django管理命令
```bash
# 进入Django shell
docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py shell"

# 检查迁移状态
docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py showmigrations"

# 创建迁移文件
docker-compose exec archery bash -c "cd /opt/archery && source /opt/venv4archery/bin/activate && python manage.py makemigrations"
```

## 完全重置

如果遇到无法解决的问题，可以完全重置：

```bash
# 停止所有服务
docker-compose down

# 删除数据（注意：这会删除所有数据）
rm -rf data/mysql/*

# 删除容器和镜像
docker-compose down --rmi all --volumes --remove-orphans

# 重新构建和启动
docker-compose build --no-cache
docker-compose up -d

# 重新初始化
./manual-setup.sh
```

## 获取帮助

如果以上方案都无法解决问题：

1. 查看完整的错误日志：`docker-compose logs -f`
2. 检查系统资源：`free -h` 和 `df -h`
3. 确认Docker版本：`docker --version` 和 `docker-compose --version`
4. 提供错误信息和环境信息寻求帮助
