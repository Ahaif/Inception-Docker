#!/bin/bash
# =============================================================================
# push_to_vm.sh — Transfer the repo from your host to the VM over SSH
# =============================================================================
# WHERE TO RUN : on your HOST machine (the one you SSH *from*)
# REQUIRES     : rsync and ssh installed on the host (standard on Linux/macOS)
# NO GIT NEEDED on the VM — files are copied directly over the SSH connection.
#
# WHAT it does:
#   1. Validates arguments and checks that rsync is available on the host
#   2. Uses rsync to copy the entire repo to ~/inception on the VM,
#      skipping files the VM doesn't need (.git history, logs, .env secrets)
#   3. Uses scp to also drop vm_install.sh into ~ on the VM so you can
#      run it immediately after this script finishes
#
# USAGE:
#   bash scripts/push_to_vm.sh <user@vm-ip>              # standard SSH port 22
#   bash scripts/push_to_vm.sh <user@vm-ip> <ssh-port>   # custom port
#
# EXAMPLES:
#   bash scripts/push_to_vm.sh abhaifou@192.168.56.10        # bridged adapter
#   bash scripts/push_to_vm.sh abhaifou@127.0.0.1 2222       # VirtualBox NAT
# =============================================================================

# ── Shell safety flags ────────────────────────────────────────────────────────
# -e  : stop immediately on any error
# -u  : error on undefined variables
# -o pipefail : a failed command inside a pipe marks the whole pipe as failed
set -euo pipefail

# ── Colour codes ──────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# ── Helper functions ──────────────────────────────────────────────────────────
info() { echo -e "${GREEN}[+]${NC} $*"; }
die()  { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

# =============================================================================
# STEP 1 — Argument handling
# =============================================================================

# $# is the number of arguments passed to the script.
# We need at least one (the SSH target). If none given, print usage and exit.
[[ $# -lt 1 ]] && die "Usage: $0 <user@vm-ip> [ssh-port]"

TARGET="$1"           # e.g. "abhaifou@192.168.56.10"
PORT="${2:-22}"       # use $2 if supplied, otherwise default to 22
DEST="~/inception"    # destination folder on the VM

# -- Locate the repo root relative to this script's own location --------------
# BASH_SOURCE[0] is the path to this script file itself.
# dirname gives the directory containing the script (scripts/).
# cd + pwd resolves it to an absolute path (handles symlinks, relative invocation).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go one level up from scripts/ to reach the repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# -- Check rsync is installed on the host ------------------------------------
# "command -v" returns 0 if the command exists, non-zero if not.
# We pipe to /dev/null to suppress the output (we only care about the exit code).
command -v rsync &>/dev/null || die "rsync not found. Install it with: sudo apt install rsync"

info "Source : $REPO_ROOT"
info "Target : $TARGET:$DEST  (SSH port $PORT)"

# =============================================================================
# STEP 2 — rsync the repo to the VM
# =============================================================================

# rsync flags explained:
#   -a  : archive mode — preserves permissions, timestamps, symlinks, etc.
#         Equivalent to -rlptgoD (recursive + preserve everything)
#   -v  : verbose — prints each file as it is transferred
#   -z  : compress data during transfer (saves bandwidth on slow links)
#   --progress        : show a per-file progress bar
#   -e "ssh -p $PORT" : use SSH as the transport, on the specified port
#
# Excluded paths (the VM doesn't need these):
#   .git/     — git history and objects; the VM only needs the working files
#   *.log     — any log files that may exist locally
#   srcs/.env — contains plain-text passwords; you will create this on the VM
#               manually so secrets are never sent over the wire in a file sync
#
# Note the trailing slash on $REPO_ROOT/ — this tells rsync to copy the
# *contents* of the directory into $DEST, not the directory itself.
rsync -avz --progress \
    -e "ssh -p $PORT" \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='srcs/.env' \
    --exclude='secrets/' \
    "$REPO_ROOT/" \
    "$TARGET:$DEST/"

info "Repo pushed to $TARGET:$DEST"

# =============================================================================
# STEP 3 — Upload vm_install.sh so it's ready to run on the VM
# =============================================================================

# scp (secure copy) copies a single file over SSH.
# -P $PORT : connect on the given port (note: scp uses -P, ssh uses -p)
# We place it in ~ (home directory) so the user can run it as: bash ~/vm_install.sh
info "Uploading vm_install.sh to ~ on the VM ..."
scp -P "$PORT" "$SCRIPT_DIR/vm_install.sh" "$TARGET:~/vm_install.sh"

# Make the script executable on the VM via a remote SSH command
ssh -p "$PORT" "$TARGET" "chmod +x ~/vm_install.sh"

# =============================================================================
# Done — print next steps
# =============================================================================
echo -e "\n${BOLD}${GREEN}Transfer complete.${NC}"
echo "Now SSH into the VM and run:"
echo ""
echo "  bash ~/vm_install.sh"
echo ""
echo "  That script installs Docker, creates data dirs, and prompts you"
echo "  to set the database passwords as Docker secrets."
echo ""
echo "Then finish configuration:"
echo "  nano ~/inception/srcs/.env        # replace 'yourlogin' with your username"
echo "  echo \"127.0.0.1  yourlogin.42.fr\" | sudo tee -a /etc/hosts"
echo ""
echo "Then build and start the stack:"
echo "  cd ~/inception && make all"
