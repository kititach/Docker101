#!/usr/bin/env bash
# Docker CE Installation Script
# Platform: Ubuntu 24.04 / Linux Mint 22.3 (Noble)
# Installs: docker-ce, docker-compose-plugin, docker-buildx-plugin

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo bash $0"

TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
[[ -z "$TARGET_USER" ]] && die "Cannot detect target user. Run with: sudo bash $0"

echo ""
echo "========================================"
echo "  Docker CE Installation"
echo "  Target user: $TARGET_USER"
echo "========================================"
echo ""

# ── Step 1: Remove old versions ──────────────────────────────────────────────
info "Step 1: Removing old Docker packages..."
for pkg in docker docker-engine docker.io containerd runc docker-compose; do
    apt-get remove -y "$pkg" 2>/dev/null && warn "Removed: $pkg" || true
done
success "Old packages cleaned"

# ── Step 2: Install prerequisites ────────────────────────────────────────────
info "Step 2: Installing prerequisites..."
apt-get update -y -q
apt-get install -y -q \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
success "Prerequisites installed"

# ── Step 3: Add Docker GPG key ───────────────────────────────────────────────
info "Step 3: Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
success "GPG key added"

# ── Step 4: Add Docker repository ────────────────────────────────────────────
info "Step 4: Adding Docker repository..."
# Linux Mint ใช้ ubuntu codename ไม่ใช่ mint codename
UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
${UBUNTU_CODENAME} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
success "Repository added (ubuntu/${UBUNTU_CODENAME})"

# ── Step 5: Install Docker CE ─────────────────────────────────────────────────
info "Step 5: Installing Docker CE..."
apt-get update -y -q
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
success "Docker CE installed"

# ── Step 6: Enable and start Docker service ───────────────────────────────────
info "Step 6: Starting Docker service..."
systemctl enable docker
systemctl start docker
success "Docker service started"

# ── Step 7: Add user to docker group ─────────────────────────────────────────
info "Step 7: Adding '$TARGET_USER' to docker group..."
usermod -aG docker "$TARGET_USER"
success "User '$TARGET_USER' added to docker group"

# ── Step 8: Verify installation ────────────────────────────────────────────────
info "Step 8: Verifying installation..."
echo ""
docker version
echo ""
docker compose version
echo ""
docker buildx version
echo ""

# ── Step 9: Run hello-world ────────────────────────────────────────────────────
info "Step 9: Running hello-world test..."
docker run --rm hello-world
echo ""

success "Docker CE installation complete!"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} Log out and back in (or run 'newgrp docker') to use Docker without sudo"
echo ""
echo "Quick test after re-login:"
echo "  docker run --rm alpine echo 'Docker is working!'"
echo ""
