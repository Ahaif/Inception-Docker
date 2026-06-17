FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# mariadb-server : the database engine
# procps         : provides ps/kill, required by mysqld_safe to manage child processes
# After install, Debian's post-install scripts run mariadb-install-db and populate
# /var/lib/mysql inside the image layer. Docker copies that content into any empty
# named volume on first container start — which would make our entrypoint's init
# check always false. Wiping the directory here ensures the image layer is empty so
# Docker has nothing to copy; our entrypoint owns all initialization.
RUN apt-get update && apt-get install -y mariadb-server procps \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql/*

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
