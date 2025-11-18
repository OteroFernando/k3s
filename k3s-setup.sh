#!/usr/bin/env bash
set -e

ROLE=$1
MASTER_IP=$2
TOKEN=$3

if [[ -z "$ROLE" ]]; then
  echo "Uso:"
  echo "  $0 master"
  echo "  $0 worker <IP_MASTER> <TOKEN>"
  exit 1
fi

echo "==============================================="
echo " 🚀 Raspberry Pi Kubernetes (k3s) Installer"
echo "==============================================="
echo "Rol seleccionado: $ROLE"
echo

############################################
# 1) Actualizar sistema
############################################
echo "[1/6] Actualizando sistema..."
sudo apt update && sudo apt upgrade -y


############################################
# 2) Deshabilitar swap
############################################
echo "[2/6] Deshabilitando swap..."
sudo dphys-swapfile swapoff || true
sudo dphys-swapfile uninstall || true
sudo systemctl disable dphys-swapfile || true


############################################
# 3) Habilitar cgroups para Kubernetes
############################################
echo "[3/6] Configurando cgroups en /boot/cmdline.txt..."

if ! grep -q "cgroup_enable=memory" /boot/cmdline.txt; then
  sudo sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/cmdline.txt
  NEED_REBOOT=true
fi


############################################
# 4) Reboot si es necesario
############################################
if [[ "$NEED_REBOOT" = true ]]; then
  echo "[4/6] Reinicio necesario para aplicar cgroups."
  echo "Reiniciando en 5 segundos..."
  sleep 5
  sudo reboot
fi


############################################
# 5) Instalación de k3s según el rol
############################################
echo "[5/6] Instalando k3s..."

if [[ "$ROLE" == "master" ]]; then

  echo "Instalando nodo MASTER..."
  curl -sfL https://get.k3s.io | sudo INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

  echo
  echo "==============================================="
  echo " ✔ Master instalado correctamente"
  echo "Token del cluster:"
  sudo cat /var/lib/rancher/k3s/server/node-token
  echo
  echo "Archivo kubeconfig:"
  echo "  /etc/rancher/k3s/k3s.yaml"
  echo "==============================================="

elif [[ "$ROLE" == "worker" ]]; then

  if [[ -z "$MASTER_IP" || -z "$TOKEN" ]]; then
    echo "Error: Para worker necesitás: worker <IP_MASTER> <TOKEN>"
    exit 1
  fi

  echo "Instalando nodo WORKER..."
  curl -sfL https://get.k3s.io | \
    sudo K3S_URL="https://${MASTER_IP}:6443" \
    K3S_TOKEN="${TOKEN}" sh -

  echo
  echo "==============================================="
  echo " ✔ Worker unido correctamente al master ${MASTER_IP}"
  echo "==============================================="

else
  echo "Error: Rol inválido. Usá: master | worker"
  exit 1
fi


############################################
# 6) Fin
############################################
echo "[6/6] Instalación completada."
echo "Listo! 🚀"
