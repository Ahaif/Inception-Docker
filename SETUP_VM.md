# VM Setup Guide — Inception (A to Z)

Complete walkthrough for spinning up a fresh virtual machine and running the full WordPress + MariaDB + NGINX stack with Docker secrets.

---

## Overview

```
Host machine
  └── push_to_vm.sh  →  VM: ~/inception/
                             ├── make secrets   (interactive password prompts)
                             ├── srcs/.env      (non-sensitive config)
                             └── make all       (build + start containers)
                                  ├── mariadb   (reads /run/secrets/*)
                                  ├── wordpress (reads /run/secrets/mysql_password)
                                  └── nginx     (TLS on port 443)
```

Sensitive values (passwords) never appear in environment variables, image layers, or `docker inspect` output. They live in `~/secrets/` on the VM host, mounted inside containers at `/run/secrets/<name>` via Docker's tmpfs mechanism.

---

## 1. Create the virtual machine

Use VirtualBox (or any hypervisor).

| Setting | Recommended value |
|---------|-------------------|
| OS | Debian 12 (netinstall ISO) |
| RAM | 4 GB |
| CPUs | 2 |
| Disk | 20 GB (dynamically allocated) |
| Network adapter 1 | NAT (internet during install) |
| Network adapter 2 | Host-only or Bridged (reachable from host) |

During the Debian installer select **no graphical environment** — only the base system and SSH server.

---

## 2. Boot the VM and get its IP

Log in as your normal user (not root).

```sh
ip addr show
# Note the IP on the second adapter (e.g. 192.168.56.10 for host-only)
```

From your host machine, verify SSH works:

```sh
ssh youruser@<vm-ip>
# or, if using VirtualBox NAT with port-forwarding (host 2222 → guest 22):
ssh -p 2222 youruser@127.0.0.1
```

---

## 3. Transfer the repository to the VM

Run this **on your host machine** from the repo root. It uses rsync over SSH — no git required on the VM.

```sh
# Standard SSH port 22
bash scripts/push_to_vm.sh youruser@<vm-ip>

# VirtualBox NAT with port-forwarding (host 2222 → guest 22)
bash scripts/push_to_vm.sh youruser@127.0.0.1 2222
```

The script copies the repo to `~/inception/` on the VM and uploads `vm_install.sh` to `~/` ready to run.

> **What is excluded from the transfer?**
> `.git/`, `*.log`, `srcs/.env`, and `secrets/` are never sent over the wire. Secrets are created directly on the VM in the next step.

---

## 4. Run vm_install.sh on the VM

SSH into the VM, then:

```sh
bash ~/vm_install.sh
```

This script performs all setup steps in one go:

| Step | What it does |
|------|-------------|
| 1 | `apt update && apt upgrade` |
| 2 | Installs `curl`, `make`, `openssl`, `rsync`, `gnupg` |
| 3 | Adds Docker's official apt repo and installs Docker Engine + Compose plugin |
| 4 | Adds your user to the `docker` group |
| 5 | Creates `~/data/db` and `~/data/www` (bind-mount targets for MariaDB and WordPress) |
| 6 | Creates `~/secrets/` (mode 700) and interactively prompts for two passwords |
| 7 | Verifies docker, docker compose, and make are all working |

When it reaches step 6 you will be asked:

```
--- Docker secrets ---
MariaDB root password: ****
Confirm MariaDB root password: ****
  -> Saved /home/youruser/secrets/mysql_root_password

MariaDB wp_user password: ****
Confirm MariaDB wp_user password: ****
  -> Saved /home/youruser/secrets/mysql_password
```

The files are stored with mode 600 (owner-read-only) and never leave the VM.

---

## 5. Activate the Docker group

The docker group change from step 4 requires a new login session to take effect:

```sh
# Option A — log out and SSH back in (cleanest)
exit
ssh youruser@<vm-ip>

# Option B — activate in the current shell only
newgrp docker
```

Verify:

```sh
docker run --rm hello-world
```

---

## 6. Configure the environment file

The `.env` file holds only non-sensitive settings. Passwords are handled by Docker secrets.

```sh
cp ~/inception/srcs/.env.example ~/inception/srcs/.env
nano ~/inception/srcs/.env
```

Edit every occurrence of `yourlogin` to your actual username:

```dotenv
LOGIN=abhaifou
DOMAIN_NAME=abhaifou.42.fr
HOST_DATA=/home/abhaifou/data

SECRETS_DIR=/home/abhaifou/secrets

MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
```

`SECRETS_DIR` must be the absolute path to the directory created by `vm_install.sh`. Docker Compose passes this to the `secrets:` block so the daemon can read the password files.

---

## 7. Add the domain to /etc/hosts

The stack listens on port 443 under `<LOGIN>.42.fr`. Both the VM itself and your host machine need to resolve this name.

**Inside the VM** (needed for WP-CLI and server-side requests):

```sh
echo "127.0.0.1  abhaifou.42.fr" | sudo tee -a /etc/hosts
```

**On your host machine** (needed to open the browser):

If using a bridged/host-only adapter with its own IP:

```sh
# On the host — /etc/hosts
echo "192.168.56.10  abhaifou.42.fr" | sudo tee -a /etc/hosts
```

If using VirtualBox NAT with port-forwarding (host 443 → guest 443):

```sh
# On the host — /etc/hosts
echo "127.0.0.1  abhaifou.42.fr" | sudo tee -a /etc/hosts
```

Then add a VirtualBox port-forwarding rule: Protocol TCP, Host port 443, Guest port 443.

---

## 8. Verify secrets are in place

Before building, confirm all required secret files exist and are non-empty:

```sh
ls -la ~/secrets/
# Expected:
# -rw------- 1 youruser youruser  N mysql_password
# -rw------- 1 youruser youruser  N mysql_root_password

cat ~/secrets/mysql_root_password | wc -c   # should print > 0
cat ~/secrets/mysql_password      | wc -c   # should print > 0
```

If a file is missing, re-run:

```sh
cd ~/inception && make secrets
```

---

## 9. Build and start the stack

```sh
cd ~/inception
make all
```

This runs `docker compose build` followed by `docker compose up -d`.

Watch the containers come up:

```sh
docker compose -f srcs/docker-compose.yml ps
```

Expected output once healthy:

```
NAME        IMAGE       STATUS       PORTS
mariadb     mariadb     Up           3306/tcp
wordpress   wordpress   Up           80/tcp
nginx       nginx       Up           0.0.0.0:443->443/tcp
```

Follow logs if anything looks stuck:

```sh
docker compose -f srcs/docker-compose.yml logs -f
# Ctrl-C to stop following
```

---

## 10. Open the site in the browser

Navigate to:

```
https://abhaifou.42.fr
```

The NGINX container uses a **self-signed TLS certificate**, so the browser shows a security warning on the first visit. This is expected for a local setup.

- **Firefox**: click *Advanced* → *Accept the Risk and Continue*
- **Chrome/Chromium**: type `thisisunsafe` anywhere on the warning page

You should reach the WordPress installation screen (or the site homepage if WP-CLI already configured it during container startup).

---

## 11. Useful commands

```sh
# Check running containers
docker compose -f srcs/docker-compose.yml ps

# Follow all logs
docker compose -f srcs/docker-compose.yml logs -f

# Follow logs for one service
docker compose -f srcs/docker-compose.yml logs -f wordpress

# Rebuild a single service after changing its Dockerfile
docker compose -f srcs/docker-compose.yml build nginx
docker compose -f srcs/docker-compose.yml up -d nginx

# Open a shell inside a running container
docker exec -it wordpress bash
docker exec -it mariadb bash

# Connect to MariaDB directly (enter root password when prompted)
docker exec -it mariadb mysql -uroot -p

# Stop all services (data volumes preserved)
make down

# Destroy everything including volumes — ALL DB DATA WILL BE LOST
make clean

# Inspect the TLS certificate
echo | openssl s_client -connect abhaifou.42.fr:443 2>/dev/null | openssl x509 -noout -text

# Re-create secrets (if you need to change a password)
make secrets        # skips files that already exist
# To force a new password, delete the old file first:
rm ~/secrets/mysql_password && make secrets
```

---

## 12. Re-syncing the repo after local changes

When you edit files on your host and want to push the updates:

```sh
# On the host
bash scripts/push_to_vm.sh youruser@<vm-ip>

# On the VM — rebuild affected images and restart
cd ~/inception
make down && make all
```

---

## 13. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `docker: permission denied` | Not in docker group / group not active | `newgrp docker` or re-login |
| `secret not found` or `no such file` | Secret file missing or wrong SECRETS_DIR | `ls ~/secrets/`; check SECRETS_DIR in .env |
| MariaDB crashes on first start | Secret file is empty | `cat ~/secrets/mysql_root_password` — re-run `make secrets` |
| `Error establishing database connection` | MariaDB not ready or wrong credentials | `docker logs mariadb`; verify secret files match between mariadb and wordpress |
| Browser says "connection refused" on port 443 | NGINX not running or port not forwarded | `docker compose ps`; check VirtualBox port-forwarding rules |
| Browser shows TLS error (not just untrusted) | Wrong cert path in nginx.conf | `docker exec nginx nginx -t` |
| Permission denied on volume mount | Data dirs owned by root | `sudo chown -R $USER:$USER ~/data` |
| `make: docker-compose: command not found` | Using Compose v2 (plugin) | The Makefile already uses `docker compose` — check you haven't modified it |
