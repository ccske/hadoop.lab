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

export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
export PATH=${HADOOP_HOME}/bin:$PATH

wait_for_up "$MASTER:8020" || exit 1

echo "Hadoop client started."

trap '
    echo "Stopping Hadoop client..."; \
    exit 0 \
    ' SIGTERM SIGINT

tail -f /dev/null & wait $!
