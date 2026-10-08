#!/usr/bin/env bash
# Aplica a modelagem inteira em um MySQL já no ar, na ordem numérica.
#
#   ./scripts/bootstrap.sh                       # localhost:3306, root sem senha
#   MYSQL_PWD=root ./scripts/bootstrap.sh        # com senha
#   MYSQL_HOST=127.0.0.1 MYSQL_PORT=3307 ./scripts/bootstrap.sh
set -euo pipefail

HOST="${MYSQL_HOST:-127.0.0.1}"
PORT="${MYSQL_PORT:-3306}"
USER="${MYSQL_USER:-root}"

cd "$(dirname "$0")/.."

for arquivo in sql_implementation/[0-9][0-9]_*.sql; do
  printf '%-44s' "$arquivo"
  mysql -h "$HOST" -P "$PORT" -u "$USER" --default-character-set=utf8mb4 < "$arquivo" > /dev/null
  echo 'OK'
done

echo
echo 'Modelagem aplicada. Para medir o efeito dos índices:'
echo "  python scripts/benchmark.py --host $HOST --porta $PORT --usuario $USER"
