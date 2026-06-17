#!/bin/sh
set -e

WP_DIR=/var/www/html

# Read secrets — never stored as environment variables.
WORDPRESS_DB_PASSWORD=$(cat /run/secrets/mysql_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)

# ── Download and configure WordPress (first boot only) ────────────────────────
if [ ! -f "$WP_DIR/wp-config.php" ]; then
  echo "[wp] Downloading WordPress..."
  rm -rf /tmp/wp.zip /tmp/wordpress
  wget -q https://wordpress.org/latest.zip -O /tmp/wp.zip
  unzip -q -o /tmp/wp.zip -d /tmp
  cp -a /tmp/wordpress/. "$WP_DIR/"
  chown -R www-data:www-data "$WP_DIR"

  cp "$WP_DIR/wp-config-sample.php" "$WP_DIR/wp-config.php"

  # Use | as delimiter — passwords containing / would break sed with default delimiter.
  sed -i "s|database_name_here|${WORDPRESS_DB_NAME}|"  "$WP_DIR/wp-config.php"
  sed -i "s|username_here|${WORDPRESS_DB_USER}|"        "$WP_DIR/wp-config.php"
  sed -i "s|password_here|${WORDPRESS_DB_PASSWORD}|"    "$WP_DIR/wp-config.php"
  sed -i "s|define( 'DB_HOST', 'localhost' )|define( 'DB_HOST', 'mariadb' )|" \
    "$WP_DIR/wp-config.php"
  echo "[wp] wp-config.php written."
fi

# ── Wait for MariaDB ──────────────────────────────────────────────────────────
echo "[wp] Waiting for MariaDB..."
until php -r "
  \$c = new mysqli('${WORDPRESS_DB_HOST}', '${WORDPRESS_DB_USER}',
                   '${WORDPRESS_DB_PASSWORD}', '${WORDPRESS_DB_NAME}');
  exit(\$c->connect_error ? 1 : 0);
" 2>/dev/null; do
  sleep 2
done
echo "[wp] MariaDB is ready."

# ── Run WP-CLI install (first boot only) ─────────────────────────────────────
if ! wp --path="$WP_DIR" --allow-root core is-installed 2>/dev/null; then
  echo "[wp] Installing WordPress..."
  wp --path="$WP_DIR" --allow-root core install \
    --url="https://${DOMAIN_NAME}" \
    --title="Inception" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email
  echo "[wp] Done. Site: https://${DOMAIN_NAME}"
fi

# exec makes php-fpm PID 1 so Docker's SIGTERM reaches it for clean shutdown.
exec "$@"
