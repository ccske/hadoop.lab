#!/usr/bin/env bash

set -euo pipefail

echo "Starting Hive Metastore..."

schematool -dbType postgres \
  -driver org.postgresql.Driver \
  -url jdbc:postgresql://postgres:5432/metastore \
  -user hive \
  -passWord hive \
  -initSchema || true

exec /opt/hive/bin/hive --service metastore

