#!/usr/bin/env bash
# Boots the macOS VM via QEMU with VNC on localhost:5901.
# First boot: connect via VNC to complete macOS installation.
# Subsequent boots: SSH in on localhost:2222 to run tests.
set -euo pipefail

OSX_KVM_DIR="$HOME/OSX-KVM"
DISK_IMG="$HOME/mac_hdd.qcow2"
RAM_MB=8192
CPUS=4

if [ ! -f "$DISK_IMG" ]; then
  echo "ERROR: $DISK_IMG not found. Run local/IOS/setup_osx_kvm.sh first."
  exit 1
fi

echo "Booting macOS VM (VNC on localhost:5901, SSH on localhost:2222)..."

qemu-system-x86_64 \
  -enable-kvm \
  -m "$RAM_MB" \
  -smp "$CPUS",cores="$CPUS" \
  -cpu Penryn,kvm=on,vendor=GenuineIntel,+kvm_pv_unhalt,+kvm_pv_eoi,\
+hypervisor,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,\
+aes,+xsave,+xsaveopt,check \
  -machine q35 \
  -device usb-ehci,id=ehci \
  -device usb-xhci,id=xhci \
  -device nec-usb-xhci,id=usb-bus \
  -global nec-usb-xhci.msi=off \
  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
  -drive if=pflash,format=raw,readonly=on,file="$OSX_KVM_DIR/OVMF_CODE.fd" \
  -drive if=pflash,format=raw,file="$OSX_KVM_DIR/OVMF_VARS-1024x768.fd" \
  -smbios type=2 \
  -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$OSX_KVM_DIR/OpenCore/OpenCore.qcow2" \
  -device ide-hd,bus=ide.2,drive=OpenCoreBoot \
  -drive id=MacHDD,if=none,file="$DISK_IMG",format=qcow2 \
  -device ide-hd,bus=ide.3,drive=MacHDD \
  -drive id=InstallMedia,if=none,file="$OSX_KVM_DIR/BaseSystem.img",format=raw \
  -device ide-hd,bus=ide.0,drive=InstallMedia \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device vmxnet3,netdev=net0,id=net0 \
  -vga vmware \
  -display vnc=127.0.0.1:1 \
  -usb \
  -device usb-tablet \
  -device usb-kbd \
  &

echo "VM booting in background (PID $!)."
echo "Connect via VNC: localhost:5901"
echo "SSH (after macOS is installed): ssh -p 2222 \$USER@localhost"
