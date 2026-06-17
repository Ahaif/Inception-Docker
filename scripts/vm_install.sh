#!/bin/bash
# =============================================================================
# vm_install.sh — Install all required services on the VM
# =============================================================================
# WHERE TO RUN : on the VM, after SSHing in from your host
# WHO runs it  : your normal user (NOT root — the script calls sudo itself)
#
# WHAT it does, in order:
#   1. Updates the system package list and upgrades existing packages
#   2. Installs essential base tools (curl, make, openssl, etc.)
#   3. Adds Docker's official apt repository and installs Docker Engine
#      + the Compose plugin (so "docker compose" works without a separate binary)
#   4. Adds your user to the "docker" group so you can run docker without sudo
#   5. Creates ~/data/db and ~/data/www — the folders Docker will bind-mount
#      for MariaDB and WordPress persistent data
#   6. Creates ~/secrets and stores the DB passwords as secret files
#   7. Verifies every tool is reachable and prints next steps
#
# USAGE:
#   bash ~/vm_install.sh
# =============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
die()     { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}--- $* ---${NC}"; }

[[ "$(id -u)" -eq 0 ]] && die "Do not run as root. Run as your normal user — sudo will be invoked where needed."

# =============================================================================
# STEP 0 — Clock sync
# =============================================================================
section "Clock sync"

# VirtualBox VMs frequently drift or wake from a snapshot with a stale clock.
# apt rejects release files whose timestamps are in the future relative to
# the system clock, causing "not valid yet" errors. Syncing first prevents that.
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd 2>/dev/null || true

# Wait up to 10 seconds for the first successful sync.
for i in $(seq 1 10); do
    timedatectl status | grep -q "synchronized: yes" && break
    sleep 1
done

info "System time: $(date)"

# =============================================================================
# STEP 1 — System update
# =============================================================================
section "System update"

sudo apt-get update -qq
sudo apt-get upgrade -y -qq
info "System up to date."

# =============================================================================
# STEP 2 — Base tools
# =============================================================================
section "Base tools"

sudo apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    make \
    rsync \
    openssl
info "Base tools installed."

# =============================================================================
# STEP 3 — Docker Engine
# =============================================================================
section "Docker Engine"

# Read OS ID and codename from the standard os-release file.
# ID will be "debian" or "ubuntu" (or similar); VERSION_CODENAME is e.g. "bookworm"
# or "noble". The Docker repo URL uses the same ID, so this works for both distros.
. /etc/os-release
OS_ID="${ID}"
OS_CODENAME="${VERSION_CODENAME}"
info "Detected OS: ${OS_ID} (${OS_CODENAME})"

if command -v docker &>/dev/null; then
    warn "Docker already installed: $(docker --version). Skipping."
else
    sudo install -m 0755 -d /etc/apt/keyrings

    # Fetch Docker's signing key for this distro (debian or ubuntu).
    curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the Docker apt repository for this distro and codename.
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/${OS_ID} \
        ${OS_CODENAME} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -qq

    sudo apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    info "Docker installed: $(docker --version)"
fi

# =============================================================================
# STEP 4 — Docker group
# =============================================================================
section "Docker group"

if groups "$USER" | grep -qw docker; then
    warn "User '$USER' is already in the docker group."
else
    sudo usermod -aG docker "$USER"
    warn "Added '$USER' to the docker group."
    warn "You must log out and back in (or run: newgrp docker) for this to take effect."
fi

# =============================================================================
# STEP 5 — Data directories
# =============================================================================
section "Data directories"

# Create as the current (non-root) user so the host always owns them.
# Never use sudo here — if root owns these directories Docker's bind-mount
# delivers a root-owned path into the container, and mysqld (which drops to
# the mysql user internally) gets EACCES before the entrypoint chown can run.
mkdir -p ~/data/db ~/data/www

# Repair ownership in case a previous run left them owned by root.
# This is the one place we allow sudo — to fix, not to create.
if [ "$(stat -c '%U' ~/data/db)" != "$USER" ]; then
    warn "~/data/db is not owned by $USER — fixing ownership..."
    sudo chown -R "$USER:$USER" ~/data/db ~/data/www
fi

info "Data directories ready (owner: $USER)"

# =============================================================================
# STEP 6 — Docker secrets
# =============================================================================
section "Docker secrets"

# Docker secrets are stored as plain files on the host but are mounted
# inside containers at /run/secrets/<name> via tmpfs — they never appear
# in environment variables, image layers, or docker inspect output.
mkdir -p ~/secrets
chmod 700 ~/secrets

prompt_secret() {
    local file="$1"
    local label="$2"
    if [ -f "$file" ]; then
        warn "Secret '$(basename "$file")' already exists at $file — skipping."
    else
        while true; do
            printf "${BOLD}%s: ${NC}" "$label"
            read -rs value
            echo
            if [ -z "$value" ]; then
                echo -e "${RED}Password cannot be empty. Try again.${NC}"
                continue
            fi
            printf "${BOLD}Confirm %s: ${NC}" "$label"
            read -rs confirm
            echo
            if [ "$value" = "$confirm" ]; then
                printf '%s' "$value" > "$file"
                chmod 600 "$file"
                info "Saved $file"
                break
            else
                echo -e "${RED}Passwords do not match. Try again.${NC}"
            fi
        done
    fi
}

prompt_secret ~/secrets/mysql_root_password "MariaDB root password"
prompt_secret ~/secrets/mysql_password      "MariaDB wp_user password"
prompt_secret ~/secrets/wp_admin_password   "WordPress admin password"

info "Secrets directory: ~/secrets (mode 700, files mode 600)"

# =============================================================================
# STEP 7 — Verify
# =============================================================================
section "Verify"

docker version           && info "docker         OK"
docker compose version   && info "docker compose OK"
make --version | head -1 && info "make           OK"

# ── Final instructions ────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}All done.${NC}"
echo "Next steps:"
echo "  1. Run 'newgrp docker' or log out/in so the docker group takes effect."
echo "  2. Edit ~/inception/srcs/.env — replace 'yourlogin' with your actual username."
echo "  3. Add your domain to /etc/hosts:"
echo "       echo \"127.0.0.1  yourlogin.42.fr\" | sudo tee -a /etc/hosts"
echo "  4. Run 'cd ~/inception && make all' to build and start the stack."
