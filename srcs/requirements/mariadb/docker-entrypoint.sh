#!/bin/sh
set -e

DATADIR=/var/lib/mysql

# Read passwords from Docker secrets (files mounted at /run/secrets/).
# Passwords are never passed as environment variables to avoid leaking them
# through docker inspect, /proc/<pid>/environ, or log output.
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/mysql_root_password)
MYSQL_PASSWORD=$(cat /run/secrets/mysql_password)

# Ensure the datadir and socket directory exist and are owned by the mysql user.
# The bind-mounted host directory starts as root-owned; mysqld refuses to start
# unless the datadir belongs to the user it runs as.
mkdir -p "$DATADIR" /var/run/mysqld
chown -R mysql:mysql "$DATADIR" /var/run/mysqld

# MariaDB 11.x writes ddl_recovery.log in the CWD. If CWD is '/' the mysql user
# cannot write it (permission denied). Switch to the datadir which we just chowned.
cd "$DATADIR"

# Only initialize on a truly fresh datadir. The Dockerfile wipes /var/lib/mysql/*
# from the image layer so Docker cannot pre-populate this directory; the mysql/
# subdirectory only appears after mariadb-install-db runs below.
if [ ! -d "$DATADIR/mysql" ]; then
  echo "[init] Creating system tables..."

  # mariadb-install-db creates the system grant tables (mysql schema).
  # --skip-test-db omits the sample 'test' database (eval requirement: no extra DBs).
  mariadb-install-db --user=mysql --datadir="$DATADIR" --skip-test-db

  # Write SQL to a temp file so the shell expands ${variables} before piping
  # into the bootstrap process. Heredoc quoting (SQLEOF unquoted) enables expansion.
  cat > /tmp/init.sql << SQLEOF
USE mysql;
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQLEOF

  # --bootstrap reads SQL from stdin, applies it synchronously, then exits.
  # This avoids starting a background daemon and eliminates socket/timing races.
  # --no-defaults skips /etc/mysql config files which may reference paths or
  # plugins that don't exist yet at this stage.
  mariadbd --no-defaults --bootstrap --user=mysql --datadir="$DATADIR" < /tmp/init.sql
  rm -f /tmp/init.sql
  echo "[init] Done. DB='${MYSQL_DATABASE}' USER='${MYSQL_USER}'"
fi

# Replace the entrypoint process with mysqld_safe (PID 1).
# --bind-address=0.0.0.0 allows connections from other containers on the Docker
# bridge network (the default 127.0.0.1 would block all cross-container traffic).
exec mysqld_safe --datadir="$DATADIR" --user=mysql --bind-address=0.0.0.0
