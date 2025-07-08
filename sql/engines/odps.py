# -*- coding: UTF-8 -*-

import re
import logging
import traceback
import sqlparse

from . import EngineBase
from .models import ResultSet, ReviewSet, ReviewResult
from common.utils.timer import FuncTimer

from odps import ODPS


logger = logging.getLogger("default")


class ODPSEngine(EngineBase):
    test_query = "SELECT 1"

    def get_connection(self, db_name=None):
        if self.conn:
            return self.conn

        db_name = db_name if db_name else self.instance.db_name

        if db_name is None:
            raise ValueError("db_name不能为空")

        self.conn = ODPS(self.user, self.password, project=db_name, endpoint=self.host)

        return self.conn

    name = "ODPS"

    info = "ODPS engine"

    def get_all_databases(self):
        """获取数据库列表, 返回一个ResultSet
        ODPS只有project概念, 直接返回project名称
        TODO: 目前ODPS获取所有项目接口比较慢, 暂时支持返回一个project，后续再优化
        """
        result = ResultSet()

        try:
            conn = self.get_connection()

            # 判断project是否存在
            db_exist = conn.exist_project(self.instance.db_name)

            if db_exist is False:
                raise ValueError(f"[{self.instance.db_name}]项目不存在")

            result.rows = [conn.project]
        except Exception as e:
            logger.warning(f"ODPS执行异常, {e}")
            result.error = str(e)
        return result

    def get_all_tables(self, db_name, **kwargs):
        """获取table 列表, 返回一个ResultSet"""

        db_name = db_name if db_name else self.instance.db_name
        result_set = ResultSet()

        try:
            conn = self.get_connection(db_name=db_name)

            rows = [t.name for t in conn.list_tables()]
            result_set.rows = rows

        except Exception as e:
            logger.warning(f"ODPS语句执行报错, 错误信息{e}")
            result_set.error = str(e)

        return result_set

    def get_all_columns_by_tb(self, db_name, tb_name, **kwargs):
        """获取所有字段, 返回一个ResultSet"""

        column_list = ["COLUMN_NAME", "COLUMN_TYPE", "COLUMN_COMMENT"]

        conn = self.get_connection(db_name)

        table = conn.get_table(tb_name)

        schema_cols = table.schema.columns

        rows = []

        for col in schema_cols:
            rows.append([col.name, str(col.type), col.comment])

        result = ResultSet()
        result.column_list = column_list
        result.rows = rows
        return result

    def describe_table(self, db_name, tb_name, **kwargs):
        """return ResultSet 类似查询"""

        result = self.get_all_columns_by_tb(db_name, tb_name)

        return result

    def query(self, db_name=None, sql="", limit_num=0, close_conn=True, **kwargs):
        """返回 ResultSet"""
        result_set = ResultSet(full_sql=sql)

        if not re.match(r"^select", sql, re.I):
            result_set.error = str("仅支持ODPS查询语句")

        # 存在limit，替换limit; 不存在，添加limit
        if re.search("limit", sql):
            sql = re.sub("limit.+(\d+)", "limit " + str(limit_num), sql)
        else:
            if sql.strip()[-1] == ";":
                sql = sql[:-1]
            sql = sql + " limit " + str(limit_num) + ";"

        try:
            conn = self.get_connection(db_name)
            effect_row = conn.execute_sql(sql)
            reader = effect_row.open_reader()
            rows = [row.values for row in reader]
            column_list = getattr(reader, "_schema").names

            result_set.column_list = column_list
            result_set.rows = rows
            result_set.affected_rows = len(rows)

        except Exception as e:
            logger.warning(f"ODPS语句执行报错, 语句：{sql}，错误信息{e}")
            result_set.error = str(e)
        return result_set

    def query_check(self, db_name=None, sql=""):
        # 查询语句的检查、注释去除、切分
        result = {"msg": "", "bad_query": False, "filtered_sql": sql, "has_star": False}
        keyword_warning = ""
        sql_whitelist = ["select"]
        # 根据白名单list拼接pattern语句
        whitelist_pattern = re.compile("^" + "|^".join(sql_whitelist), re.IGNORECASE)
        # 删除注释语句，进行语法判断，执行第一条有效sql
        try:
            sql = sqlparse.format(sql, strip_comments=True)
            sql = sqlparse.split(sql)[0]
            result["filtered_sql"] = sql.strip()
            # sql_lower = sql.lower()
        except IndexError:
            result["bad_query"] = True
            result["msg"] = "没有有效的SQL语句"
            return result
        if whitelist_pattern.match(sql) is None:
            result["bad_query"] = True
            result["msg"] = "仅支持{}语法!".format(",".join(sql_whitelist))
            return result
        if result.get("bad_query"):
            result["msg"] = keyword_warning
        return result

    def execute_check(self, db_name=None, sql=""):
        """上线单执行前的检查, 返回Review set"""
        check_result = ReviewSet(full_sql=sql)

        # ODPS支持的SQL类型白名单
        sql_whitelist = [
            "select", "insert", "update", "delete", "create", "drop", "alter",
            "truncate", "merge", "with", "desc", "describe", "show", "explain"
        ]

        # 删除注释语句，切分SQL
        try:
            sql_formatted = sqlparse.format(sql, strip_comments=True)
            split_sql = sqlparse.split(sql_formatted)
            split_sql = [stmt.strip() for stmt in split_sql if stmt.strip()]
        except Exception as e:
            check_result.error = f"SQL解析失败: {str(e)}"
            return check_result

        if not split_sql:
            check_result.error = "没有有效的SQL语句"
            return check_result

        # 检查每条SQL语句
        line = 1
        for statement in split_sql:
            statement = statement.rstrip(";")
            if not statement:
                continue

            # 检查SQL类型是否在白名单中
            sql_lower = statement.lower().strip()
            is_valid = False
            for allowed_type in sql_whitelist:
                if sql_lower.startswith(allowed_type):
                    is_valid = True
                    break

            if not is_valid:
                result = ReviewResult(
                    id=line,
                    errlevel=2,
                    stagestatus="Audit Failed",
                    errormessage=f"不支持的SQL类型，仅支持: {', '.join(sql_whitelist)}",
                    sql=statement,
                    affected_rows=0,
                    execute_time=0,
                )
                check_result.error_count += 1
            else:
                result = ReviewResult(
                    id=line,
                    errlevel=0,
                    stagestatus="Audit completed",
                    errormessage="通过审核",
                    sql=statement,
                    affected_rows=0,
                    execute_time=0,
                )

            check_result.rows.append(result)
            line += 1

        return check_result

    def execute(self, db_name=None, sql="", close_conn=True, **kwargs):
        """执行SQL语句，返回ReviewSet"""
        execute_result = ReviewSet(full_sql=sql)

        try:
            # 删除注释语句，切分SQL
            sql_formatted = sqlparse.format(sql, strip_comments=True)
            split_sql = sqlparse.split(sql_formatted)
            split_sql = [stmt.strip() for stmt in split_sql if stmt.strip()]
        except Exception as e:
            execute_result.error = f"SQL解析失败: {str(e)}"
            return execute_result

        if not split_sql:
            execute_result.error = "没有有效的SQL语句"
            return execute_result

        line = 1
        conn = None

        try:
            conn = self.get_connection(db_name=db_name)

            for statement in split_sql:
                statement = statement.rstrip(";")
                if not statement:
                    continue

                try:
                    with FuncTimer() as t:
                        # 执行SQL语句
                        if statement.lower().strip().startswith('select'):
                            # 对于查询语句，获取结果
                            instance = conn.execute_sql(statement)
                            reader = instance.open_reader()
                            affected_rows = len([row for row in reader])
                        else:
                            # 对于非查询语句，直接执行
                            instance = conn.execute_sql(statement)
                            # ODPS的execute_sql返回的instance对象，需要等待执行完成
                            instance.wait_for_completion()
                            affected_rows = 0  # ODPS暂不支持获取影响行数

                    execute_result.rows.append(
                        ReviewResult(
                            id=line,
                            errlevel=0,
                            stagestatus="Execute Successfully",
                            errormessage="执行成功",
                            sql=statement,
                            affected_rows=affected_rows,
                            execute_time=t.cost,
                        )
                    )

                except Exception as e:
                    logger.warning(
                        f"ODPS语句执行报错，语句：{statement}，错误信息：{traceback.format_exc()}"
                    )
                    # 追加当前报错语句信息到执行结果中
                    execute_result.error = str(e)
                    execute_result.rows.append(
                        ReviewResult(
                            id=line,
                            errlevel=2,
                            stagestatus="Execute Failed",
                            errormessage=f"执行失败：{str(e)}",
                            sql=statement,
                            affected_rows=0,
                            execute_time=0,
                        )
                    )
                    # 报错后停止执行后续语句
                    line += 1
                    # 将后续语句标记为未执行
                    for remaining_statement in split_sql[line-1:]:
                        if remaining_statement.strip():
                            execute_result.rows.append(
                                ReviewResult(
                                    id=line,
                                    errlevel=0,
                                    stagestatus="Audit completed",
                                    errormessage="前序语句失败，未执行",
                                    sql=remaining_statement.rstrip(";"),
                                    affected_rows=0,
                                    execute_time=0,
                                )
                            )
                            line += 1
                    break

                line += 1

        except Exception as e:
            logger.warning(f"ODPS连接或执行异常：{traceback.format_exc()}")
            execute_result.error = str(e)

        finally:
            if close_conn and conn:
                try:
                    # ODPS连接通常不需要显式关闭，但可以清理连接对象
                    self.conn = None
                except Exception:
                    pass

        return execute_result

    def execute_workflow(self, workflow):
        """执行上线单，返回Review set"""
        return self.execute(
            db_name=workflow.db_name,
            sql=workflow.sqlworkflowcontent.sql_content
        )
