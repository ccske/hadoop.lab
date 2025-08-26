FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl netcat-openbsd openjdk-11-jdk-headless procps gosu tini && \
    rm -rf /var/lib/apt/lists/*

ENV HIVE_VERSION=4.1.0
ENV HIVE_HOME=/opt/hive
RUN curl -fSL "https://downloads.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz" | tar -xz -C /opt && \
    ln -s /opt/apache-hive-${HIVE_VERSION}-bin ${HIVE_HOME} && \
    curl -fSL "https://jdbc.postgresql.org/download/postgresql-42.7.7.jar" -o ${HIVE_HOME}/lib/postgresql-42.7.7.jar

ENV TEZ_VERSION=0.10.5
ENV TEZ_HOME=/opt/tez
RUN curl -fSL "https://downloads.apache.org/tez/${TEZ_VERSION}/apache-tez-${TEZ_VERSION}-bin.tar.gz" | tar -xz -C /opt && \
    ln -s /opt/apache-tez-${TEZ_VERSION}-bin ${TEZ_HOME} && \
    cd ${TEZ_HOME} && tar -czf tez.tar.gz share/

ENV HADOOP_VERSION=3.4.0
ENV HADOOP_HOME=/opt/hadoop
RUN set -eux && \
    case "${TARGETARCH:-unknown}" in \
      amd64)  HADOOP_TGZ="hadoop-${HADOOP_VERSION}.tar.gz" ;; \
      arm64)  HADOOP_TGZ="hadoop-${HADOOP_VERSION}-aarch64.tar.gz" ;; \
      *)      echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    curl -fSL "https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_TGZ}" | tar -xz -C /opt && \
    cp -r /opt/hadoop-${HADOOP_VERSION}/share/hadoop/{common,hdfs,yarn,mapreduce} ${HADOOP_HOME}/ && \
    rm -rf /opt/hadoop-${HADOOP_VERSION}

ENV PATH=$HIVE_HOME/bin:$HADOOP_HOME/bin:$PATH

COPY conf/* $HIVE_HOME/conf/
COPY entrypoint/* /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint-*.sh

WORKDIR ${HIVE_HOME}

ENTRYPOINT ["/usr/bin/tini", "--"]
