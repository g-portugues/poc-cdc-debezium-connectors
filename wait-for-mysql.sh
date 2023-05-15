#!/usr/bin/env sh
set -eu

command="$@"

echo "Waiting for mysql in host '$DB_SERVER'"
until mysql --port $DB_PORT -h $DB_SERVER -u $DB_USER -p$DB_PASSWORD -e "exit" >&2
do
  echo "MySQL is unavailable - sleeping"
  sleep 1
done

echo "MySQL is up - executing command"

exec $command
