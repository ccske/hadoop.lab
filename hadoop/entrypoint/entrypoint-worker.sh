#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/common.sh"

GLOBAL_CONF_DIR=/volumes/conf
if wait_until_file_created "${GLOBAL_CONF_DIR}/hadoop" && [ -d "${GLOBAL_CONF_DIR}/hadoop" ]; then
    for FPATH in "${GLOBAL_CONF_DIR}"/hadoop/*; do
        FILE=$(basename "$FPATH")
        rm -f ${HADOOP_CONF_DIR}/$FILE || true
        ln -s ${GLOBAL_CONF_DIR}/hadoop/$FILE ${HADOOP_CONF_DIR}/$FILE
    done
else
    echo "WARNING: Global conf not found! Apply default settings."
fi

if [ -f "${GLOBAL_CONF_DIR}/group" ] && [ -f "${GLOBAL_CONF_DIR}/passwd" ]; then
    restore_supergroup_users "${GLOBAL_CONF_DIR}/group" "${GLOBAL_CONF_DIR}/passwd"
fi

JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"

wait_until_service_up "$MASTER" "9870" || exit 1
gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs --daemon start datanode"
wait_until_service_up "localhost" "9864" || exit 1

wait_until_service_up "$MASTER" "8088" || exit 1
gosu yarn bash -lc "${HADOOP_HOME}/bin/yarn --daemon start nodemanager"
wait_until_service_up "localhost" "8042" || exit 1

echo "Hadoop worker services started: DataNode (hdfs), NodeManager (yarn)."

trap '
    echo "Stopping Hadoop worker..."; \
    gosu yarn bash -lc "${HADOOP_HOME}/bin/yarn --daemon stop nodemanager" || true; \
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs --daemon stop datanode" || true; \
    exit 0 \
    ' SIGTERM SIGINT

tail -f /dev/null & wait $!
