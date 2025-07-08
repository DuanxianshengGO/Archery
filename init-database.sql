-- Archery数据库初始化脚本
-- 创建数据库和基本配置

-- 创建数据库
CREATE DATABASE IF NOT EXISTS archery DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 使用数据库
USE archery;

-- 设置字符集
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- 显示创建结果
SHOW DATABASES LIKE 'archery';
SELECT 'Archery数据库创建完成' as message;
