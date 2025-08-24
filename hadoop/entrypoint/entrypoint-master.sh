#!/usr/bin/env bash

set -euo pipefail

function wait_for_up() {
    local HOST_PORT=$1
    local HOST=${HOST_PORT%%:*}
    local PORT=${HOST_PORT#*:}
    local MAX_RETRIES=60
    local SLEEP_INTERVAL=3
    let i=1

    while (( $i <= ${MAX_RETRIES} )); do
        echo "[$i/${MAX_RETRIES}] waiting for $HOST:$PORT up..."
        nc -z $HOST $PORT
        if [[ $? -eq 0 ]]; then
            break
        fi
        sleep ${SLEEP_INTERVAL}
        i=$((i + 1))
    done

    if (( $i > ${MAX_RETRIES} )); then
        echo "$HOST:$PORT is still not available!"
        return 1
    fi

    echo "$HOST:$PORT is up."
    return 0
}

function restore_supergroup() {
    local ETC_GROUP=$1
    local ETC_PASSWD=$2

    members=$(grep '^supergroup:' ${ETC_GROUP} | cut -d: -f4 | tr ',' '\n')
    while IFS=: read -r user passwd uid gid gecos home shell; do
        if echo "$members" | grep -qx "$user" && [ "$uid" -ge 1000 ] && ! getent passwd $user > /dev/null 2>&1; then
            group=$(awk -F: -v gid="$gid" '$3 == gid {print $1}' ${ETC_GROUP})
            groupadd -g $gid $group && useradd -u $uid -g $group -G supergroup -d /home/$user -s /bin/bash $user
        fi
    done < ${ETC_PASSWD}
}

export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"

NEWFS=0
if [ ! -d "${HADOOP_HOME}/tmp/dfs/name/current" ]; then
  echo "Formatting NameNode..."
  gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs namenode -format -force -nonInteractive"
  NEWFS=1
fi

gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs --daemon start namenode"
wait_for_up "$MASTER:9870" || exit 1

gosu yarn bash -lc "${HADOOP_HOME}/bin/yarn --daemon start resourcemanager"
wait_for_up "$MASTER:8088" || exit 1

if [[ $NEWFS -eq 1 ]]; then
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs dfs -mkdir /tmp"
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs dfs -chmod 1777 /tmp"
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs dfs -mkdir /user"
fi

gosu mapred bash -lc "${HADOOP_HOME}/bin/mapred --daemon start historyserver"
wait_for_up "$MASTER:19888" || exit 1

if [ -f "/volumes/client/etc/group" ] && [ -f "/volumes/client/etc/passwd" ]; then
    restore_supergroup "/volumes/client/etc/group" "/volumes/client/etc/passwd"
fi

echo "Hadoop master services started: NameNode (hdfs), ResourceManager (yarn), HistoryServer (mapred)."

trap '
    echo "Stopping Hadoop master..."; \
    gosu mapred bash -lc "${HADOOP_HOME}/bin/mapred --daemon stop historyserver" || true; \
    gosu yarn bash -lc "${HADOOP_HOME}/bin/yarn --daemon stop resourcemanager" || true; \
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs --daemon stop namenode" || true; \
    exit 0 \
    ' SIGTERM SIGINT

tail -f /dev/null & wait $!
