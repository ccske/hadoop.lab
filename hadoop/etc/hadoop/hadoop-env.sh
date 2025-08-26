export LANG=en_US.UTF-8
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
export HADOOP_OS_TYPE=${HADOOP_OS_TYPE:-$(uname -s)}
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/etc/hadoop
export HADOOP_LOG_DIR=/var/log/hadoop
export HADOOP_PID_DIR=/var/hadoop/pid
