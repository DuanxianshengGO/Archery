# Archery Docker部署指南

本指南将帮助您使用Docker Compose部署包含ODPS审核功能的Archery系统。

## 🎯 特性

- ✅ **完整的Archery功能** - 包含所有原生功能
- ✅ **ODPS审核支持** - 新增的ODPS SQL上线申请审核功能
- ✅ **一键部署** - 使用Docker Compose快速部署
- ✅ **数据持久化** - 数据和配置文件持久化存储
- ✅ **易于维护** - 清晰的目录结构和配置管理

## 📋 系统要求

- Docker >= 20.10
- Docker Compose >= 1.29
- 至少4GB可用内存
- 至少10GB可用磁盘空间

## 🚀 快速开始

### 1. 克隆代码

```bash
git clone https://github.com/DuanxianshengGO/Archery.git
cd Archery
```

### 2. 一键部署

```bash
./deploy.sh
```

部署脚本将自动：
- 检查系统依赖
- 构建包含ODPS功能的自定义镜像
- 启动所有服务
- 初始化数据库
- 创建超级用户（可选）

### 3. 访问系统

部署完成后，访问 http://localhost:9123

## 📁 目录结构

```
.
├── docker-compose.yml          # Docker Compose配置
├── Dockerfile                  # 自定义镜像构建文件
├── deploy.sh                   # 一键部署脚本
├── config/                     # 配置文件目录
│   ├── archery/
│   │   ├── local_settings.py   # Archery配置
│   │   └── soar.yaml          # SOAR配置
│   ├── mysql/
│   │   └── my.cnf             # MySQL配置
│   └── inception/
│       └── config.toml        # GoInception配置
├── data/                       # 数据持久化目录
│   ├── mysql/                 # MySQL数据
│   └── archery/
│       ├── logs/              # 应用日志
│       ├── downloads/         # 下载文件
│       └── keys/              # 密钥文件
└── sql/engines/odps.py        # ODPS引擎（包含审核功能）
```

## ⚙️ 服务配置

### 服务列表

| 服务 | 端口 | 说明 |
|------|------|------|
| archery | 9123 | Archery Web界面 |
| mysql | 3306 | MySQL数据库 |
| redis | 6379 | Redis缓存（内部） |
| goinception | 4000 | GoInception SQL审核 |

### 默认账号

- **MySQL**: root/123456
- **Redis**: 密码123456
- **Archery**: 部署时创建

## 🔧 常用操作

### 查看服务状态

```bash
docker-compose ps
```

### 查看日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f archery
```

### 重启服务

```bash
# 重启所有服务
docker-compose restart

# 重启特定服务
docker-compose restart archery
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
# 执行数据库迁移
docker-compose exec archery bash -c "source /opt/venv4archery/bin/activate && python manage.py migrate"

# 创建超级用户
docker-compose exec archery bash -c "source /opt/venv4archery/bin/activate && python manage.py createsuperuser"

# 收集静态文件
docker-compose exec archery bash -c "source /opt/venv4archery/bin/activate && python manage.py collectstatic --noinput"
```

## 🛠️ 自定义配置

### 修改Archery配置

编辑 `config/archery/local_settings.py` 文件，然后重启服务：

```bash
docker-compose restart archery
```

### 修改MySQL配置

编辑 `config/mysql/my.cnf` 文件，然后重启服务：

```bash
docker-compose restart mysql
```

### 修改GoInception配置

编辑 `config/inception/config.toml` 文件，然后重启服务：

```bash
docker-compose restart goinception
```

## 🔍 ODPS功能使用

### 1. 添加ODPS实例

1. 登录Archery管理界面
2. 进入"实例管理" -> "实例列表"
3. 点击"添加实例"
4. 选择数据库类型为"ODPS"
5. 填写ODPS连接信息：
   - 实例名称：自定义名称
   - 主机地址：ODPS Endpoint
   - 端口：443（HTTPS）
   - 用户名：AccessKey ID
   - 密码：AccessKey Secret
   - 数据库：Project名称

### 2. 创建SQL上线申请

1. 进入"SQL上线" -> "提交SQL上线申请"
2. 选择ODPS实例
3. 填写SQL内容（支持的类型见下方）
4. 提交审核

### 3. 支持的ODPS SQL类型

- ✅ SELECT - 查询语句
- ✅ INSERT - 插入语句
- ✅ UPDATE - 更新语句
- ✅ DELETE - 删除语句
- ✅ CREATE - 创建表/视图
- ✅ DROP - 删除表/视图
- ✅ ALTER - 修改表结构
- ✅ TRUNCATE - 清空表
- ✅ MERGE - 合并语句
- ✅ WITH - CTE语句
- ✅ DESC/DESCRIBE - 描述表结构
- ✅ SHOW - 显示信息
- ✅ EXPLAIN - 执行计划

## 🚨 故障排除

### 服务启动失败

1. 检查端口是否被占用：
   ```bash
   netstat -tlnp | grep -E '(3306|6379|4000|9123)'
   ```

2. 检查磁盘空间：
   ```bash
   df -h
   ```

3. 查看详细错误日志：
   ```bash
   docker-compose logs archery
   ```

### 数据库连接失败

1. 确认MySQL服务正常：
   ```bash
   docker-compose exec mysql mysqladmin ping
   ```

2. 检查数据库配置：
   ```bash
   docker-compose exec archery cat /opt/archery/local_settings.py | grep DATABASE
   ```

### ODPS连接测试失败

1. 检查网络连接
2. 验证AccessKey权限
3. 确认Project名称正确
4. 查看Archery日志中的详细错误信息

## 📚 更多信息

- [Archery官方文档](https://github.com/hhyo/Archery)
- [ODPS文档](https://help.aliyun.com/product/27797.html)
- [Docker Compose文档](https://docs.docker.com/compose/)

## 🤝 支持

如有问题，请查看：
1. 本文档的故障排除部分
2. 项目的Issue页面
3. Archery官方文档
