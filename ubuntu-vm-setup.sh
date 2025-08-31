#!/usr/bin/env bash

set -euo pipefail

# Make sure the system is supported
if [ -r /etc/os-release ]; then
    source /etc/os-release
fi
if [[ "$ID" != "ubuntu" ]]; then
    echo "Error: Only Ubuntu Linux supported"
    exit 1
fi

# System variables
ARCH=$(dpkg --print-architecture)
PROJECT_DIR=$(realpath "$(dirname "$0")")
USER=$(id -u -n)
USER_ID=$(id -u)
GROUP=$(id -g -n)
GROUP_ID=$(id -g)

# Add current user into no-password sudoer list
NP_SUDOERS=/etc/sudoers.d/nopasswd
NP_ENTRY="$USER ALL=(ALL) NOPASSWD: ALL"
if [ ! -f "${NP_SUDOERS}" ]; then
    sudo touch "${NP_SUDOERS}" && sudo chmod 0400 "${NP_SUDOERS}"
fi
if ! sudo grep -qxF "${NP_ENTRY}" "${NP_SUDOERS}"; then
    echo "${NP_ENTRY}" | sudo tee -a "${NP_SUDOERS}" > /dev/null
fi

# Keep APT packages up-to-date
sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
if [ $? -ne 0 ]; then
    echo "Error: Package repositories could be temporarily unavailable. Pleast try again later."
    exit 1
fi

# Install latest Docker and Compose
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
APT_DOCKER_ASC=/etc/apt/keyrings/docker.asc
APT_DOCKER_LIST=/etc/apt/sources.list.d/docker.list
APT_DOCKER_URL=https://download.docker.com/linux/ubuntu
sudo curl -fsSL ${APT_DOCKER_URL}/gpg -o ${APT_DOCKER_ASC} && sudo chmod a+r ${APT_DOCKER_ASC}
if [ ! -f "${APT_DOCKER_LIST}" ]; then
    echo "deb [arch=$ARCH signed-by=${APT_DOCKER_ASC}] ${APT_DOCKER_URL} ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" | sudo tee ${APT_DOCKER_LIST} > /dev/null
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER

# Build and launch Hadoop ecosystem containers via Docker Compose
if [ -L /bridge ]; then
    sudo rm -f /bridge
fi
if [ -d /bridge ]; then
    sudo mv /bridge /bridge.$(date +"%Y%m%d_%H%M%S")
fi
sudo ln -s $HOME /bridge
sg docker -c "docker compose --project-directory ${PROJECT_DIR} up --build -d"
HOSTS_ENTRY="127.0.0.1 hadoop-master hadoop-worker1 hadoop-worker2 hadoop-worker3"
if ! grep -qxF "${HOSTS_ENTRY}" "/etc/hosts"; then
    echo | sudo tee -a "/etc/hosts" > /dev/null
    echo "${HOSTS_ENTRY}" | sudo tee -a "/etc/hosts" > /dev/null
fi

# Set up Java environment
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-11-jdk
JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
JAVA_HOME_ENTRY="export JAVA_HOME=${JAVA_HOME}"
if ! grep -qxF "${JAVA_HOME_ENTRY}" "$HOME/.bashrc"; then
    echo | tee -a "$HOME/.bashrc" > /dev/null
    echo "${JAVA_HOME_ENTRY}" | tee -a "$HOME/.bashrc" > /dev/null
fi

# Set up hadoop-client
if ! sg docker -c "docker exec hadoop-client getent passwd $USER" > /dev/null 2>&1; then
    for CONTAINER in "hadoop-master" "hadoop-worker1" "hadoop-worker2" "hadoop-worker3" "hadoop-client"; do
        sg docker -c "docker exec $CONTAINER groupadd -g ${GROUP_ID} $GROUP"
        sg docker -c "docker exec $CONTAINER useradd -u ${USER_ID} -g $GROUP -G supergroup -d /home/$USER -s /bin/bash $USER"
    done
    sg docker -c "docker exec hadoop-client cp /etc/group /etc/passwd /volumes/conf/"
    sg docker -c "dicker exec hadoop-client rm -f /home/$USER" > /dev/null 2>&1 || true
    sg docker -c "docker exec hadoop-client ln -s /bridge /home/$USER"
    TIMEOUT=180
    SLEEP_INTERVAL=3
    START_TIME=$(date +%s)
    CURRENT_TIME=${START_TIME}
    (( TIMEOUT_TIME = START_TIME + TIMEOUT ))
    while (( CURRENT_TIME <= TIMEOUT_TIME )); do
        if sg docker -c "docker exec hadoop-client gosu $USER:$GROUP hdfs dfs -mkdir -p /user/$USER" > /dev/null 2>&1; then
            break
        fi
        sleep ${SLEEP_INTERVAL}
        CURRENT_TIME=$(date +%s)
        (( ELAPSED = CURRENT_TIME - START_TIME ))
        echo "[$ELAPSED/$TIMEOUT] waiting for /user/$USER to be created on HDFS..."
    done
    if (( CURRENT_TIME > TIMEOUT_TIME )); then
        echo "Failed to create /user/$USER on HDFS!"
        exit 1
    fi
    echo "/user/$USER successdully created on HDFS."
fi
HADOOP_BIN="/opt/hadoop/bin"
HADOOP_CLIENT_ALIAS="alias hadoop-client='docker exec -it hadoop-client su - $USER'"
if ! grep -qxF "${HADOOP_CLIENT_ALIAS}" "$HOME/.bashrc"; then
    echo | tee -a "$HOME/.bashrc" > /dev/null
    printf "%s\n%s\n%s\n" \
        "if [[ \":\$PATH:\" != *\":${HADOOP_BIN}:\"* ]]; then" \
        "    export PATH=\"${HADOOP_BIN}:\$PATH\"" \
        "fi" | \
        tee -a "$HOME/.bashrc" > /dev/null
    echo | tee -a "$HOME/.bashrc" > /dev/null
    echo "${HADOOP_CLIENT_ALIAS}" | tee -a "$HOME/.bashrc" > /dev/null
fi

# Install commonly used tools (optional)
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y net-tools ssh tmux vim

# Done
echo "--------------------------------------------------------------------"
echo ">>> Reboot system to apply all changes!"
echo ">>> Afterwards, execute 'hadoop-client' to enter Hadoop client mode."
echo
