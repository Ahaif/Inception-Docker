FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# php-fpm        : FastCGI process manager — executes PHP code for NGINX
# php-mysql      : PHP MySQLi/PDO driver for MariaDB connectivity
# wget / unzip   : download and extract the WordPress archive at runtime
# ca-certificates: trusted TLS roots so wget can verify HTTPS downloads
# procps         : ps/kill for process management
RUN apt-get update && apt-get install -y \
    php-fpm php-mysql wget unzip ca-certificates procps \
    && rm -rf /var/lib/apt/lists/*

# Replace the default pool config to listen on TCP 9000 instead of a Unix socket.
# NGINX runs in a separate container and cannot share a Unix socket.
RUN find /etc/php -name 'www.conf' -type f | xargs rm -f
COPY www.conf /tmp/www.conf
RUN find /etc/php -type d -name 'fpm' | head -1 | xargs -I{} cp /tmp/www.conf {}/pool.d/www.conf \
    && rm /tmp/www.conf

# Create a stable symlink so the CMD below works regardless of the PHP version.
RUN find /usr/sbin -name 'php-fpm*' -type f | head -1 | xargs -I{} ln -sf {} /usr/local/bin/php-fpm

# WP-CLI — auto-installs and configures WordPress on first boot so the
# browser never shows the installation wizard.
RUN wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    -O /usr/local/bin/wp && chmod +x /usr/local/bin/wp

WORKDIR /var/www/html

COPY wp-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wp-entrypoint.sh

# PHP-FPM listens on TCP 9000; NGINX forwards FastCGI requests here.
EXPOSE 9000

VOLUME ["/var/www/html"]

ENTRYPOINT ["/usr/local/bin/wp-entrypoint.sh"]
# -F : run in foreground (no daemonize) so the container stays alive
CMD ["php-fpm", "-F"]
