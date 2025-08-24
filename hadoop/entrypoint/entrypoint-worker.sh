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

wait_for_up "$MASTER:9870" || exit 1
gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs --daemon start datanode"
wait_for_up "localhost:9864" || exit 1

wait_for_up "$MASTER:8088" || exit 1
gosu yarn bash -lc "${HADOOP_HOME}/bin/yarn --daemon start nodemanager"
wait_for_up "localhost:8042" || exit 1

if [ -f "/volumes/client/etc/group" ] && [ -f "/volumes/client/etc/passwd" ]; then
    restore_supergroup "/volumes/client/etc/group" "/volumes/client/etc/passwd"
fi

echo "Hadoop worker services started: DataNode (hdfs), NodeManager (yarn)."

trap '
    echo "Stopping Hadoop worker..."; \
    gosu yarn bash -lc "${HADOOP_HOME}/bin/yarn --daemon stop nodemanager" || true; \
    gosu hdfs bash -lc "${HADOOP_HOME}/bin/hdfs --daemon stop datanode" || true; \
    exit 0 \
    ' SIGTERM SIGINT

tail -f /dev/null & wait $!
