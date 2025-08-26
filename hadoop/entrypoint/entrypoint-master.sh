#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/common.sh"

GLOBAL_CONF_DIR=/volumes/conf
if [ ! -d "${GLOBAL_CONF_DIR}/hadoop" ]; then
    mkdir -p ${GLOBAL_CONF_DIR}/hadoop
    for FILE in "hadoop-env.sh" "core-site.xml" "hdfs-site.xml" "mapred-site.xml" "yarn-site.xml"; do
        cp ${HADOOP_CONF_DIR}/$FILE ${GLOBAL_CONF_DIR}/hadoop/$FILE
    done
fi

for FPATH in "${GLOBAL_CONF_DIR}"/hadoop/*; do
    FILE=$(basename "$FPATH")
    rm -f ${HADOOP_CONF_DIR}/$FILE || true
    ln -s ${GLOBAL_CONF_DIR}/hadoop/$FILE ${HADOOP_CONF_DIR}/$FILE
done

if [ -f "${GLOBAL_CONF_DIR}/group" ] && [ -f "${GLOBAL_CONF_DIR}/passwd" ]; then
    restore_supergroup_users "${GLOBAL_CONF_DIR}/group" "${GLOBAL_CONF_DIR}/passwd"
fi

JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"

NEWFS=0
if [ ! -d "${HADOOP_VAR_DIR}/tmp/dfs/name/current" ]; then
  echo "Formatting NameNode..."
  gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs namenode -format -force -nonInteractive"
  NEWFS=1
fi

gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs --daemon start namenode"
wait_until_service_up "$MASTER" "9870" || exit 1

gosu yarn bash -lc "${HADOOP_HOME}/bin/yarn --daemon start resourcemanager"
wait_until_service_up "$MASTER" "8088" || exit 1

if [[ $NEWFS -eq 1 ]]; then
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs dfs -mkdir /tmp"
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs dfs -chmod 1777 /tmp"
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs dfs -mkdir /user"
fi

gosu mapred bash -lc "${HADOOP_HOME}/bin/mapred --daemon start historyserver"
wait_until_service_up "$MASTER" "19888" || exit 1

echo "Hadoop master services started: NameNode (hdfs), ResourceManager (yarn), HistoryServer (mapred)."

trap '
    echo "Stopping Hadoop master..."; \
    gosu mapred bash -lc "${HADOOP_HOME}/bin/mapred --daemon stop historyserver" || true; \
    gosu yarn bash -lc "${HADOOP_HOME}/bin/yarn --daemon stop resourcemanager" || true; \
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs --daemon stop namenode" || true; \
    exit 0 \
    ' SIGTERM SIGINT

tail -f /dev/null & wait $!
