#!/bin/sh
set -e

WP_DIR=/var/www/html

if [ ! -f "$WP_DIR/wp-config.php" ]; then
  echo "Downloading WordPress..."
  wget -q https://wordpress.org/latest.zip -O /tmp/wp.zip
  unzip -q /tmp/wp.zip -d /tmp
  cp -a /tmp/wordpress/* $WP_DIR/
  chown -R www-data:www-data $WP_DIR

  cp $WP_DIR/wp-config-sample.php $WP_DIR/wp-config.php
  sed -i "s/database_name_here/${WORDPRESS_DB_NAME}/" $WP_DIR/wp-config.php
  sed -i "s/username_here/${WORDPRESS_DB_USER}/" $WP_DIR/wp-config.php
  sed -i "s/password_here/${WORDPRESS_DB_PASSWORD}/" $WP_DIR/wp-config.php
fi

exec "$@"
