FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG HADOOP_VERSION=3.4.0
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV HADOOP_LOG_DIR=/var/log/hadoop
ENV HADOOP_VAR_DIR=/var/hadoop
ENV HADOOP_PID_DIR=${HADOOP_VAR_DIR}/pid
ENV HADOOP_TMP_DIR=${HADOOP_VAR_DIR}/tmp
ENV PATH=${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:$PATH

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends ca-certificates curl netcat-openbsd openjdk-11-jdk-headless procps gosu tini && \
    rm -rf /var/lib/apt/lists/*

RUN set -eux && \
    case "${TARGETARCH:-unknown}" in \
      amd64)  HADOOP_TGZ="hadoop-${HADOOP_VERSION}.tar.gz" ;; \
      arm64)  HADOOP_TGZ="hadoop-${HADOOP_VERSION}-aarch64.tar.gz" ;; \
      *)      echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -fSL "https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_TGZ}" -o /tmp/hadoop.tgz && \
    tar -xzf /tmp/hadoop.tgz -C /opt && \
    ln -s hadoop-${HADOOP_VERSION} ${HADOOP_HOME} && \
    rm -f /tmp/hadoop.tgz

RUN userdel -f -r ubuntu && \
    groupadd -r supergroup && \
    useradd -G supergroup -r -M hdfs && \
    useradd -G supergroup -r -M yarn && \
    useradd -G supergroup -r -M mapred

RUN mkdir -p ${HADOOP_PID_DIR} ${HADOOP_TMP_DIR} /volumes/conf /volumes/data /volumes/logs && \
    chgrp supergroup ${HADOOP_PID_DIR} ${HADOOP_TMP_DIR} /volumes/data /volumes/logs && \
    chmod -R 755 /volumes/conf && \
    chmod -R 775 ${HADOOP_PID_DIR} ${HADOOP_TMP_DIR} /volumes/data /volumes/logs && \
    ln -s /volumes/data ${HADOOP_TMP_DIR}/dfs && \
    ln -s /volumes/logs ${HADOOP_LOG_DIR} && \
    ln -s ${HADOOP_HOME}/etc/hadoop ${HADOOP_CONF_DIR}

COPY etc/hadoop/* ${HADOOP_HOME}/etc/hadoop/
COPY entrypoint/* /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint-*.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
