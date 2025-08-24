FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG HADOOP_VERSION=3.4.0
ENV HADOOP_HOME=/opt/hadoop
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

RUN mkdir -p ${HADOOP_HOME}/run ${HADOOP_HOME}/tmp /volumes/data /volumes/logs /bridge && \
    chgrp supergroup ${HADOOP_HOME}/run ${HADOOP_HOME}/tmp /volumes/data /volumes/logs && \
    chmod 775 ${HADOOP_HOME}/run ${HADOOP_HOME}/tmp /volumes/data /volumes/logs && \
    ln -s /volumes/data ${HADOOP_HOME}/tmp/dfs && \
    ln -s /volumes/logs ${HADOOP_HOME}/logs

COPY etc/hadoop/* ${HADOOP_HOME}/etc/hadoop/
COPY entrypoint/* /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint-*.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
