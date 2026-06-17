# Developer Documentation — Inception

## Prerequisites

- VirtualBox VM running Debian or Ubuntu (bookworm recommended)
- Run `bash ~/vm_install.sh` — installs Docker Engine, Compose plugin, make, creates data directories, and prompts for all secrets interactively
- Or install manually: `sudo apt-get install -y docker.io docker-compose-plugin make`

---

## Environment setup

```sh
# 1. Copy the example env file and fill in your login
cp srcs/.env.example srcs/.env
nano srcs/.env          # replace 'yourlogin' everywhere; set WP_ADMIN_USER (not 'admin')

# 2. Add your domain to /etc/hosts on the VM
echo "127.0.0.1  <LOGIN>.42.fr" | sudo tee -a /etc/hosts

# 3. Create secret files
make secrets            # prompts for all three passwords interactively
```

### `.env` variables

| Variable | Purpose |
|----------|---------|
| `LOGIN` | Your 42 username |
| `DOMAIN_NAME` | `<LOGIN>.42.fr` |
| `HOST_DATA` | Absolute path to data directories (e.g. `/home/<LOGIN>/data`) |
| `SECRETS_DIR` | Absolute path to secrets directory (e.g. `/home/<LOGIN>/secrets`) |
| `MYSQL_DATABASE` | Database name (e.g. `wordpress`) |
| `MYSQL_USER` | Database user for WordPress (e.g. `wp_user`) |
| `WP_ADMIN_USER` | WordPress admin username — **must not contain `admin` or `Admin`** |
| `WP_ADMIN_EMAIL` | WordPress admin email address |

Passwords are **not** in `.env`. They live in `SECRETS_DIR` as plain files, mounted into containers at `/run/secrets/<name>` via Docker secrets (tmpfs, not visible in `docker inspect`).

---

## Build and launch

```sh
make all      # docker compose build + up -d
make build    # build (or rebuild) all images
make up       # start containers (no rebuild)
make down     # stop and remove containers (data preserved)
make clean    # stop + remove containers, images, Docker volume metadata
make dirs     # create ~/data/db and ~/data/www; fix ownership if needed
make secrets  # create ~/secrets/ and prompt for all three passwords
```

---

## Container management

```sh
# Open a shell inside a container
docker exec -it mariadb bash
docker exec -it wordpress bash

# Connect to the database as root
docker exec -it mariadb mysql -uroot -p"$(cat ~/secrets/mysql_root_password)"

# Rebuild and restart a single service after a Dockerfile or config change
docker compose -f srcs/docker-compose.yml build --no-cache mariadb
docker compose -f srcs/docker-compose.yml up -d mariadb
```

---

## Data persistence

| Path on host | Mounted at in container | Contains |
|---|---|---|
| `~/data/db` | `/var/lib/mysql` (mariadb) | MariaDB database files (owned by `mysql` user = `syslog` UID on host) |
| `~/data/www` | `/var/www/html` (wordpress, nginx read-only) | WordPress core files, uploads, `wp-config.php` |

Both paths are exposed as Docker named volumes (`db_data`, `www_data`) using the `local` driver with `type: none, o: bind`. This makes them visible to `docker volume ls` and `docker volume inspect` while keeping data on the host filesystem.

Data survives `make down` and image rebuilds. `make clean` removes the Docker volume *objects* (metadata) but does **not** delete the actual files on disk.

### Full data reset

```sh
make down
sudo rm -rf ~/data/db ~/data/www    # sudo required: files owned by mysql UID
make dirs
make all
```

`sudo` is required because MariaDB writes database files as the `mysql` user inside the container. That UID maps to `syslog` on the Ubuntu/Debian host, so a plain `rm` as your own user will fail with "Permission denied".

---

## MariaDB initialization — how it works

On first boot (empty `~/data/db`):
1. The entrypoint detects no `mysql/` subdirectory and enters the init block
2. `mariadb-install-db` creates the system grant tables
3. `mariadbd --no-defaults --bootstrap` reads `/tmp/init.sql` from stdin — this sets the root password, creates the `wordpress` database, and creates `wp_user`
4. The temp SQL file is deleted, then `exec mysqld_safe` replaces the entrypoint as PID 1

**Why `rm -rf /var/lib/mysql/*` in the Dockerfile:** Debian's `mariadb-server` post-install scripts run `mariadb-install-db` during `apt-get install`, which populates `/var/lib/mysql` in the image layer. Docker copies image-layer content into empty named volumes on first container start — which would skip our init block on every fresh deploy. Wiping the directory in the same `RUN` step ensures the image carries no pre-initialized data.

**Why no `VOLUME` declaration:** A `VOLUME` instruction in the Dockerfile triggers the same image-to-volume copy behaviour. Since the volume mount is fully managed by `docker-compose.yml`, the Dockerfile declaration is unnecessary and harmful here.

---

## WordPress initialization — how it works

On first boot (empty `~/data/www`):
1. The entrypoint downloads WordPress and unpacks it to `/var/www/html`
2. `wp-config.php` is generated from `wp-config-sample.php` with the correct database credentials (read from Docker secrets and environment variables)
3. A wait loop tests the MariaDB connection via PHP `mysqli` until it succeeds
4. `wp core install` (WP-CLI) runs silently — no installation wizard is ever shown
5. `exec php-fpm -F` replaces the entrypoint as PID 1, listening on TCP port 9000

NGINX connects to WordPress via FastCGI (`fastcgi_pass wordpress:9000`) and mounts the same `www_data` volume read-only to serve static files directly without going through PHP.
