#!/usr/bin/env bash
# Sets up OSX-KVM in WSL2 for local iOS testing.
# Run once from the repo root in WSL2.
# After this completes, boot the VM with local/boot_macos.sh and connect via
# VNC (localhost:5901) to complete the macOS installation manually.
set -euo pipefail

OSX_KVM_DIR="$HOME/OSX-KVM"
DISK_IMG="$HOME/mac_hdd.qcow2"
DISK_SIZE="128G"
MACOS_VERSION="sequoia"

echo "=== Installing QEMU and dependencies ==="
sudo apt-get update
sudo apt-get install -y \
  qemu-system-x86 qemu-utils \
  uml-utilities \
  wget python3 dmg2img \
  net-tools screen p7zip-full

echo "=== Configuring KVM ==="
sudo modprobe kvm
# Silence unknown MSR accesses (required for macOS guests).
echo 1 | sudo tee /sys/module/kvm/parameters/ignore_msrs

MARKER="# >>> pensine kvm msrs <<<"
if ! grep -q "$MARKER" /etc/modprobe.d/kvm.conf 2>/dev/null; then
  echo "$MARKER" | sudo tee -a /etc/modprobe.d/kvm.conf
  echo "options kvm ignore_msrs=Y" | sudo tee -a /etc/modprobe.d/kvm.conf
fi

if ! id -nG | grep -qw kvm; then
  sudo usermod -aG kvm "$USER"
  echo "Added $USER to kvm group — restart WSL (wsl --shutdown) and re-run."
  exit 1
fi

echo "=== Cloning OSX-KVM ==="
if [ ! -d "$OSX_KVM_DIR" ]; then
  git clone --depth 1 --recursive https://github.com/kholia/OSX-KVM.git "$OSX_KVM_DIR"
else
  echo "OSX-KVM already cloned, skipping"
fi

echo "=== Fetching macOS $MACOS_VERSION recovery image ==="
cd "$OSX_KVM_DIR"
if [ ! -f BaseSystem.dmg ]; then
  python3 fetch-macOS-v2.py --shortname "$MACOS_VERSION" --action download
else
  echo "BaseSystem.dmg already present, skipping"
fi

if [ ! -f BaseSystem.img ]; then
  echo "Converting DMG to IMG..."
  dmg2img -i BaseSystem.dmg BaseSystem.img
else
  echo "BaseSystem.img already present, skipping"
fi

echo "=== Creating virtual disk ($DISK_SIZE) ==="
if [ ! -f "$DISK_IMG" ]; then
  qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
else
  echo "Disk image already exists, skipping"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Run:  local/boot_macos.sh"
echo "  2. Connect via VNC to localhost:5901"
echo "  3. Install macOS (select disk, follow installer)"
echo "  4. After install: run local/setup_macos_dev.sh inside the VM via SSH"
echo "     SSH: ssh -p 2222 \$USER@localhost"
