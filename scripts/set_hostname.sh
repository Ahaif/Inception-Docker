#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <new-hostname>"
  exit 1
fi
NEWNAME=$1

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (use sudo inside the VM)."
  exit 2
fi

echo "$NEWNAME" > /etc/hostname
hostnamectl set-hostname "$NEWNAME" || true
sed -i "/127.0.1.1/d" /etc/hosts || true
echo "127.0.1.1 $NEWNAME" >> /etc/hosts

echo "Hostname set to $NEWNAME. Reboot the VM if necessary."
