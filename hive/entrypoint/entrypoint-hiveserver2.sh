#!/usr/bin/env bash

set -euo pipefail

echo "Starting HiveServer2 with Tez..."

exec /opt/hive/bin/hive --service hiveserver2 \
  --hiveconf hive.root.logger=INFO,console

