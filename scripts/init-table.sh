#!/bin/bash
# Initialize the demo table (user_accounts) on the Aurora cluster.
# Usage: ./init-table.sh <aurora-writer-endpoint>
#    or: DB_HOST=<aurora-writer-endpoint> ./init-table.sh
set -euo pipefail

DB_HOST="${1:-${DB_HOST:-}}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-test}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-password}"

if [[ -z "$DB_HOST" ]]; then
  echo "Usage: $0 <aurora-writer-endpoint>" >&2
  echo "   or: DB_HOST=<aurora-writer-endpoint> $0" >&2
  exit 1
fi

echo "Initializing table 'user_accounts' on ${DB_HOST}:${DB_PORT}/${DB_NAME} ..."

mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<'SQL'
CREATE TABLE IF NOT EXISTS user_accounts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(255) NOT NULL UNIQUE,
  nickname VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO user_accounts (username, nickname)
VALUES ('seiichi', 'seiichi')
ON DUPLICATE KEY UPDATE nickname = VALUES(nickname);

SELECT * FROM user_accounts;
SQL

echo "Done."