#!/bin/bash

set -e

# ============================
# CONFIGURAÇÕES
# ============================

VMID=9000
NAME="ubuntu-24-template"

STORAGE="local-lvm"
BRIDGE="vmbr0"

MEMORY=2048
CORES=2

IMAGE_DIR="/var/lib/vz/template/iso"
IMAGE="$IMAGE_DIR/$1"

# ============================
# VALIDAÇÕES
# ============================

if [ -z "$1" ]; then
    echo "Uso:"
    echo "  $0 nome-da-imagem.img"
    echo
    echo "Exemplo:"
    echo "  $0 noble-server-cloudimg-amd64.img"
    exit 1
fi

if [ ! -f "$IMAGE" ]; then
    echo "ERRO: Imagem não encontrada:"
    echo "$IMAGE"
    exit 1
fi

if qm status "$VMID" &>/dev/null; then
    echo "ERRO: VMID $VMID já existe."
    exit 1
fi

echo "========================================"
echo " Criando template Proxmox"
echo "========================================"
echo "VMID:    $VMID"
echo "Nome:    $NAME"
echo "Imagem:  $IMAGE"
echo "Storage: $STORAGE"
echo

# ============================
# CRIAR VM
# ============================

echo "[1/7] Criando VM..."

qm create "$VMID" \
    --name "$NAME" \
    --memory "$MEMORY" \
    --cores "$CORES" \
    --cpu host \
    --net0 virtio,bridge="$BRIDGE"

# ============================
# IMPORTAR DISCO
# ============================

echo "[2/7] Importando disco..."

qm disk import "$VMID" "$IMAGE" "$STORAGE"

# ============================
# CONFIGURAR DISCO
# ============================

echo "[3/7] Configurando disco..."

qm set "$VMID" \
    --scsihw virtio-scsi-pci \
    --scsi0 "$STORAGE:vm-$VMID-disk-0"

# ============================
# CLOUD INIT
# ============================

echo "[4/7] Adicionando Cloud-Init..."

qm set "$VMID" \
    --ide2 "$STORAGE:cloudinit"

# ============================
# BOOT
# ============================

echo "[5/7] Configurando boot..."

qm set "$VMID" \
    --boot order=scsi0

qm set "$VMID" \
    --serial0 socket \
    --vga serial0

# ============================
# CLOUD INIT DEFAULT
# ============================

echo "[6/7] Configurando Cloud-Init..."

qm set "$VMID" \
    --ipconfig0 ip=dhcp

qm set "$VMID" \
    --agent enabled=1

# ============================
# TEMPLATE
# ============================

echo "[7/7] Convertendo para template..."

qm template "$VMID"

echo
echo "========================================"
echo " TEMPLATE CRIADO COM SUCESSO"
echo "========================================"
echo
echo "VMID: $VMID"
echo "Nome: $NAME"
echo
echo "Para criar uma VM:"
echo
echo "qm clone $VMID 101 --name vm-teste --full"
echo
echo "qm set 101 --ipconfig0 ip=dhcp"
echo "qm start 101"
echo
