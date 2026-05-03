#!/usr/bin/env bash
# 等待 mssql 就緒後執行 schema.sql + seed.sql
set -euo pipefail

CONTAINER="${CONTAINER:-shift-mssql}"
PASSWORD="${MSSQL_SA_PASSWORD:-Shift@Pass2026}"
SQLCMD="/opt/mssql-tools18/bin/sqlcmd"

echo "==> 等待 SQL Server 啟動..."
for i in {1..40}; do
  if docker exec -e PW="$PASSWORD" "$CONTAINER" \
        bash -c "$SQLCMD -S localhost -U sa -P \"\$PW\" -No -Q 'SELECT 1' >/dev/null 2>&1"; then
    echo "==> SQL Server 就緒"
    break
  fi
  sleep 2
  if [[ $i -eq 40 ]]; then
    echo "!! SQL Server 未就緒，超時退出" >&2
    exit 1
  fi
done

echo "==> 執行 schema.sql"
docker exec -e PW="$PASSWORD" "$CONTAINER" \
  bash -c "$SQLCMD -S localhost -U sa -P \"\$PW\" -No -b -i /db/schema.sql"

echo "==> 執行 seed.sql"
docker exec -e PW="$PASSWORD" "$CONTAINER" \
  bash -c "$SQLCMD -S localhost -U sa -P \"\$PW\" -No -b -i /db/seed.sql"

echo "==> 完成"
