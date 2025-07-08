# ODPS引擎审核功能增强

## 概述

本次改造为ODPS引擎添加了完整的SQL上线申请审核功能，使其能够支持完整的工作流审核流程。

## 改造内容

### 1. 新增导入模块

```python
import traceback
from .models import ReviewSet, ReviewResult
from common.utils.timer import FuncTimer
```

### 2. 新增 `execute_check` 方法

**功能**: 上线单执行前的检查，返回ReviewSet

**特性**:
- 支持多种ODPS SQL类型：select, insert, update, delete, create, drop, alter, truncate, merge, with, desc, describe, show, explain
- 自动解析和切分SQL语句
- 去除SQL注释
- 对每条SQL语句进行类型检查
- 返回详细的审核结果

**示例**:
```python
engine = ODPSEngine(instance=instance)
result = engine.execute_check(db_name="project_name", sql="SELECT * FROM table1; INSERT INTO table2 VALUES (1, 'test');")
```

### 3. 新增 `execute` 方法

**功能**: 执行SQL语句，返回ReviewSet

**特性**:
- 支持批量SQL执行
- 区分查询和非查询语句
- 自动等待ODPS任务完成
- 详细的错误处理和日志记录
- 执行时间统计

### 4. 新增 `execute_workflow` 方法

**功能**: 执行上线单，返回ReviewSet

**特性**:
- 从工作流对象中提取SQL内容
- 调用execute方法执行SQL
- 完整的工作流集成

## 支持的SQL类型

### ✅ 支持的SQL类型
- **SELECT** - 查询语句
- **INSERT** - 插入语句
- **UPDATE** - 更新语句
- **DELETE** - 删除语句
- **CREATE** - 创建表/视图等
- **DROP** - 删除表/视图等
- **ALTER** - 修改表结构
- **TRUNCATE** - 清空表
- **MERGE** - 合并语句
- **WITH** - CTE语句
- **DESC/DESCRIBE** - 描述表结构
- **SHOW** - 显示信息
- **EXPLAIN** - 执行计划

### ❌ 不支持的SQL类型
- **GRANT/REVOKE** - 权限管理
- **SET** - 设置参数
- **USE** - 切换数据库
- 其他非标准ODPS SQL

## 审核流程支持

### 工作流类型支持对比

| 功能 | 改造前 | 改造后 |
|------|--------|--------|
| 查询权限申请 | ✅ | ✅ |
| SQL上线申请 | ❌ | ✅ |
| 工单执行 | ❌ | ✅ |
| 审核流程配置 | ✅ | ✅ |

### 审核结果结构

```python
ReviewResult(
    id=1,                           # 语句序号
    errlevel=0,                     # 错误级别 (0:正常, 1:警告, 2:错误)
    stagestatus="Audit completed",  # 审核状态
    errormessage="通过审核",         # 审核消息
    sql="SELECT * FROM table",      # SQL语句
    affected_rows=0,                # 影响行数
    execute_time=0.1                # 执行时间
)
```

## 使用示例

### 1. 审核检查

```python
from sql.engines.odps import ODPSEngine

# 创建引擎实例
engine = ODPSEngine(instance=odps_instance)

# 执行审核检查
sql = """
SELECT * FROM user_table;
INSERT INTO log_table SELECT * FROM temp_table;
CREATE TABLE new_table AS SELECT * FROM old_table;
"""

result = engine.execute_check(db_name="my_project", sql=sql)

# 检查结果
print(f"错误数量: {result.error_count}")
print(f"警告数量: {result.warning_count}")

for row in result.rows:
    print(f"语句: {row.sql}")
    print(f"状态: {row.stagestatus}")
    print(f"消息: {row.errormessage}")
```

### 2. 执行工单

```python
# 执行工单
execute_result = engine.execute_workflow(workflow)

# 检查执行结果
if execute_result.error:
    print(f"执行失败: {execute_result.error}")
else:
    print("执行成功")
    for row in execute_result.rows:
        print(f"语句: {row.sql}")
        print(f"状态: {row.stagestatus}")
        print(f"执行时间: {row.execute_time}秒")
```

## 错误处理

### 1. SQL解析错误
- 自动捕获sqlparse解析异常
- 返回详细的错误信息

### 2. 执行错误
- 捕获ODPS执行异常
- 记录详细的错误日志
- 停止后续语句执行
- 标记未执行的语句

### 3. 连接错误
- 自动处理连接异常
- 清理连接资源

## 注意事项

1. **ODPS特性**: ODPS的execute_sql方法返回Instance对象，需要调用wait_for_completion()等待执行完成
2. **影响行数**: ODPS暂不支持获取准确的影响行数，非查询语句返回0
3. **连接管理**: ODPS连接通常不需要显式关闭，但会在执行完成后清理连接对象
4. **权限要求**: 需要确保ODPS实例具有相应的执行权限

## 测试验证

运行测试脚本验证功能：

```bash
python test_odps_audit.py
```

测试覆盖：
- SQL解析功能
- 审核逻辑验证
- 支持和不支持的SQL类型
- 错误处理机制

## 总结

通过本次改造，ODPS引擎现在完全支持Archery的SQL上线申请审核流程，包括：

1. ✅ **完整的审核功能** - execute_check方法
2. ✅ **工单执行功能** - execute_workflow方法  
3. ✅ **错误处理机制** - 完善的异常捕获和处理
4. ✅ **日志记录** - 详细的执行日志
5. ✅ **性能监控** - 执行时间统计

ODPS引擎现在与Redis、MySQL等引擎一样，支持完整的审核工作流程。
