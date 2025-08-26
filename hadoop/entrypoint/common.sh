# shellcheck shell=bash

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    echo "This file is a library and must be sourced, not executed." >&2
    exit 1
fi

if [ -n "${_COMMON_SH_INCLUDED:-}" ]; then
    return 0
fi
readonly _COMMON_SH_INCLUDED=1

function wait_until_service_up() {
    local host=$1
    local port=$2
    local timeout=180
    local sleep_interval=3
    local start_time=$(date +%s)
    local current_time=${start_time}

    (( timeout_time = start_time + timeout ))
    while (( current_time <= timeout_time )); do
        nc -z $host $port
        if [[ $? -eq 0 ]]; then
            break
        fi
        sleep ${sleep_interval}
        current_time=$(date +%s)
        (( elapsed = current_time - start_time ))
        echo "[$elapsed/$timeout] waiting for $host:$port..."
    done

    if (( current_time > timeout_time )); then
        echo "$host:$port is still down!"
        return 1
    fi

    echo "$host:$port is up."
    return 0
}

function wait_until_file_created() {
    local file=$1
    local timeout=60
    local sleep_interval=1
    local start_time=$(date +%s)
    local current_time=${start_time}

    (( timeout_time = start_time + timeout ))
    while (( current_time <= timeout_time )); do
        if [ -e "$file" ]; then
            break
        fi
        sleep ${sleep_interval}
        current_time=$(date +%s)
        (( elapsed = current_time - start_time ))
        echo "[$elapsed/$timeout] waiting for $file..."
    done

    if (( current_time > timeout_time )); then
        echo "$file is still unavailable!"
        return 1
    fi

    echo "$file is available."
    return 0
}

function restore_supergroup_users() {
    local group_file=$1
    local passwd_file=$2
    local members=$(grep '^supergroup:' ${group_file} | cut -d: -f4 | tr ',' '\n')

    while IFS=: read -r user passwd uid gid gecos home shell; do
        if echo "$members" | grep -qx "$user" && [ "$uid" -ge 1000 ] && ! getent passwd $user > /dev/null 2>&1; then
            group=$(awk -F: -v gid="$gid" '$3 == gid {print $1}' ${group_file})
            if ! getent group $group > /dev/null 2>&1; then
                groupadd -g $gid $group
            fi
            useradd -u $uid -g $group -G supergroup -d /home/$user -s /bin/bash $user
        fi
    done < $passwd_file
}
