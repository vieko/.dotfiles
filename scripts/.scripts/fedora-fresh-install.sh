#!/bin/bash
# fedora-fresh-install.sh — repos + package set for a fresh Fedora Workstation install
# Idempotent: safe to re-run. Last verified on Fedora 44 (2026-07).
# Run with: sudo bash fedora-fresh-install.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

FEDORA_VER=$(rpm -E %fedora)

echo "==> RPM Fusion (free + nonfree)"
dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
  2>/dev/null || echo "    (already installed)"

echo "==> COPRs"
dnf copr enable -y lionheartp/Hyprland
dnf copr enable -y scottames/ghostty
dnf copr enable -y atim/lazygit
dnf copr enable -y atim/starship   # starship isn't packaged in Fedora proper

echo "==> Third-party repos + signing keys"
if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
  curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
fi
if [ ! -f /etc/yum.repos.d/tailscale.repo ]; then
  curl -fsSL "https://pkgs.tailscale.com/stable/fedora/tailscale.repo" -o /etc/yum.repos.d/tailscale.repo
fi
if [ ! -f /etc/yum.repos.d/nextdns.repo ]; then
  curl -fsSL https://repo.nextdns.io/nextdns.repo -o /etc/yum.repos.d/nextdns.repo
fi
if [ ! -f /etc/yum.repos.d/google-cloud-sdk.repo ]; then
  cat > /etc/yum.repos.d/google-cloud-sdk.repo <<'EOF'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
fi
rpm --import https://pkgs.tailscale.com/stable/fedora/repo.gpg
rpm --import https://repo.nextdns.io/nextdns-armored.gpg

echo "==> Snapshots (btrfs + snapper, incl. auto pre/post-dnf snapshots)"
dnf install -y snapper btrfs-assistant python3-dnf-plugin-snapper
snapper list-configs | grep -q '^root' || snapper -c root create-config /
snapper list-configs | grep -q '^home' || snapper -c home create-config /home

echo "==> Packages"
dnf install -y \
  hyprland hyprlock hypridle hyprpaper hyprpicker hyprshot uwsm hyprland-uwsm \
  xdg-desktop-portal-hyprland waybar mako rofi-wayland wofi grim slurp \
  wlr-randr brightnessctl playerctl nwg-panel wev wtype \
  ghostty kitty \
  btop htop eza fd-find fzf ripgrep zoxide git-delta gh stow neovim \
  xclip xsel httpie cloc inotify-tools socat p7zip p7zip-plugins unison \
  restic speedtest-cli tree-sitter-cli wmctrl xdotool iotop-c \
  gcc gcc-c++ clang cmake make meson ninja-build golang zig luarocks \
  awscli2 nodejs-npm \
  tailscale nextdns syncthing \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  keepassxc easyeffects input-remapper lazygit google-cloud-cli \
  akmods akmod-v4l2loopback v4l-utils radeontop

echo "==> Multimedia (RPM Fusion)"
rpm -q ffmpeg >/dev/null 2>&1 || dnf swap -y ffmpeg-free ffmpeg --allowerasing
# fresh installs ship no mesa-va-drivers, so install (not swap) the freeworld VA-API driver
rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1 || dnf install -y mesa-va-drivers-freeworld

echo "==> Done. Post-steps (as user):"
echo "    gh auth login && gh repo clone <you>/.dotfiles -- --recurse-submodules"
echo "    npm i -g n && n lts"
echo "    sudo systemctl enable --now tailscaled docker"
