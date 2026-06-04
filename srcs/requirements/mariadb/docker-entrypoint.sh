#!/bin/sh
set -e

DATADIR=/var/lib/mysql

if [ ! -d "$DATADIR/mysql" ]; then
  echo "Initializing MariaDB data directory"
  mysqld --initialize-insecure --datadir=$DATADIR
fi

# Start mariadb in background to run initialization SQL
mysqld_safe --datadir=$DATADIR &
PID=$!

sleep 3

if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
  mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
fi

if [ -n "$MYSQL_DATABASE" ]; then
  mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \\`${MYSQL_DATABASE}\\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
fi

if [ -n "$MYSQL_USER" -a -n "$MYSQL_PASSWORD" ]; then
  mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}'; GRANT ALL PRIVILEGES ON \\`${MYSQL_DATABASE}\\`.* TO '${MYSQL_USER}'@'%'; FLUSH PRIVILEGES;"
fi

wait $PID
