# 使用官方的Archery基础镜像
ARG BASE_IMAGE="hhyo/archery-base:sha-d8159f4"
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-c"]

# 复制当前代码到容器中（包含我们的ODPS审核功能改造）
COPY . /opt/archery/

WORKDIR /opt/

# 创建nginx用户
RUN useradd nginx

# 安装依赖和配置
RUN apt-get update \
    && apt-get install -yq --no-install-recommends nginx mariadb-client \
    && source venv4archery/bin/activate \
    && pip install -r /opt/archery/requirements.txt \
    && pip install "redis>=4.1.0" \
    && pip install "pyodps>=0.11.0" \
    && cp -f /opt/archery/src/docker/nginx.conf /etc/nginx/ \
    && cp -f /opt/archery/src/docker/supervisord.conf /etc/ \
    && mv /opt/sqladvisor /opt/archery/src/plugins/ \
    && mv /opt/soar /opt/archery/src/plugins/ \
    && mv /opt/my2sql /opt/archery/src/plugins/ \
    && apt-get -yq remove gcc curl \
    && apt-get clean \
    && rm -rf /var/cache/apt/* \
    && rm -rf /root/.cache

# 暴露端口
EXPOSE 9123

# 启动服务
ENTRYPOINT ["bash", "/opt/archery/src/docker/startup.sh"]
