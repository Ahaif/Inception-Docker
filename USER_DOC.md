# User Documentation — Inception

## Services

| Service | Role |
|---------|------|
| **NGINX** | HTTPS reverse proxy — the only public entry point (port 443, TLS 1.2/1.3 only) |
| **WordPress** | CMS application server, runs PHP-FPM on an internal port |
| **MariaDB** | Database backend, reachable only by WordPress (not exposed outside the VM) |

---

## Start / Stop

```sh
cd ~/inception

make all      # build images and start all three containers
make down     # stop containers (all data is preserved on disk)
make clean    # stop and delete containers, images, and Docker volumes
```

After `make clean`, data in `~/data/db` and `~/data/www` is **not** deleted — you keep your WordPress content. Only the Docker objects (containers, images, volume metadata) are removed.

---

## Access the site

| URL | Description |
|-----|-------------|
| `https://<LOGIN>.42.fr` | WordPress frontend |
| `https://<LOGIN>.42.fr/wp-admin` | WordPress admin dashboard |

The site uses a **self-signed TLS certificate** generated at build time — accept the browser security warning on first visit. HTTP (port 80) is not served; plain HTTP connections are refused.

---

## Credentials

Passwords are stored as plain text files in `~/secrets/` on the VM (never committed to the repo):

```
~/secrets/mysql_root_password   — MariaDB root password
~/secrets/mysql_password        — WordPress database user password
~/secrets/wp_admin_password     — WordPress admin account password
```

The WordPress admin username is set via `WP_ADMIN_USER` in `srcs/.env` (default: `webmaster`). WordPress is installed automatically on first boot via WP-CLI — there is no installation wizard. Log in directly at `https://<LOGIN>.42.fr/wp-admin`.

---

## Check services are running

```sh
# Show status of all three containers
docker compose -f srcs/docker-compose.yml ps

# Follow live logs (all services)
docker compose -f srcs/docker-compose.yml logs -f

# Logs for a specific service
docker logs mariadb
docker logs wordpress
docker logs nginx
```

All three containers should show `Up` status. On first boot, `docker logs mariadb` will show `[init] Creating system tables...` followed by `[init] Done.` — this confirms the database and WordPress user were created successfully.

---

## Resetting data (full wipe)

If you need to start completely fresh (e.g., to change passwords):

```sh
make down
sudo rm -rf ~/data/db ~/data/www
make dirs
make secrets   # re-enter passwords if they changed
make all
```

`sudo` is required because MariaDB writes the database files as the `mysql` system user inside the container, so those files are owned by a different UID on the host.
