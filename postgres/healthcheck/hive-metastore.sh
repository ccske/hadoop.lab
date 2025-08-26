#!/usr/bin/env sh

set -euo pipefail

PGHOST="localhost"
PGPORT="5432"
PGUSER="hive"
PGDATABASE="metastore"

pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -q -t 3
