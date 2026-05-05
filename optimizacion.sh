#!/bin/bash

echo "🚀 OPTIMIZACION VPS MODO HACKER REAL (SAFE)"

# =========================
# VALIDAR ROOT
# =========================
if [ "$(whoami)" != "root" ]; then
  echo "❌ Ejecuta como root"
  exit 1
fi

# =========================
# DETECTAR SISTEMA
# =========================
CPU_CORES=$(nproc)
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
VIRT=$(systemd-detect-virt)

echo "🧠 CPU: $CPU_CORES cores"
echo "🧠 RAM: $RAM_TOTAL MB"
echo "🧠 Virtualización: $VIRT"

# =========================
# ACTUALIZAR
# =========================
apt-get update -y && apt-get upgrade -y

# =========================
# INSTALAR HERRAMIENTAS
# =========================
apt-get install -y curl wget nano htop net-tools dnsutils speedtest-cli vnstat

# =========================
# BBR (SEGURO)
# =========================
echo "⚡ Activando BBR..."

modprobe tcp_bbr 2>/dev/null
echo "tcp_bbr" > /etc/modules-load.d/bbr.conf

# =========================
# OPTIMIZACION DINAMICA
# =========================
echo "⚙️ Ajustando kernel inteligente..."

if [ "$RAM_TOTAL" -le 1024 ]; then
  # VPS pequeño
  RMEM=16777216
  WMEM=16777216
  BACKLOG=65536
else
  # VPS normal/grande
  RMEM=67108864
  WMEM=67108864
  BACKLOG=250000
fi

cat > /etc/sysctl.conf <<EOF
# === CORE ===
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# === BUFFER DINAMICO ===
net.core.rmem_max=$RMEM
net.core.wmem_max=$WMEM
net.ipv4.tcp_rmem=4096 87380 $RMEM
net.ipv4.tcp_wmem=4096 65536 $WMEM

# === TCP ===
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0

# === CONEXIONES ===
net.core.somaxconn=65535
net.core.netdev_max_backlog=$BACKLOG
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_max_syn_backlog=8192

# === LIMPIEZA CONEXIONES ===
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

# === SEGURIDAD BASICA ===
net.ipv4.tcp_syncookies=1
EOF

sysctl -p

# =========================
# LIMITES DINAMICOS
# =========================
echo "📈 Ajustando límites..."

if [ "$RAM_TOTAL" -le 1024 ]; then
  LIMIT=65535
else
  LIMIT=1048576
fi

cat > /etc/security/limits.conf <<EOF
* soft nofile $LIMIT
* hard nofile $LIMIT
root soft nofile $LIMIT
root hard nofile $LIMIT
EOF

ulimit -n $LIMIT

# =========================
# DNS INTELIGENTE
# =========================
echo "🌐 DNS optimizado..."

cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
EOF

# =========================
# DESACTIVAR SOLO LO SEGURO
# =========================
echo "🧹 Limpiando servicios innecesarios..."

for svc in apache2 ufw snapd; do
  systemctl stop $svc 2>/dev/null
  systemctl disable $svc 2>/dev/null
done

# =========================
# SSH OPTIMIZADO
# =========================
echo "🔐 Optimizando SSH..."

sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
sed -i 's/#TCPKeepAlive yes/TCPKeepAlive yes/g' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 60/g' /etc/ssh/sshd_config

systemctl restart ssh

# =========================
# SWAP CONTROLADO
# =========================
echo "🧠 Ajustando memoria..."

sysctl vm.swappiness=10
sysctl vm.vfs_cache_pressure=50

# =========================
# DISCO (SOLO SI EXISTE)
# =========================
DISK=$(lsblk -d -o NAME | tail -n1)

if [ -e /sys/block/$DISK/queue/scheduler ]; then
  echo "noop" > /sys/block/$DISK/queue/scheduler 2>/dev/null
fi

# =========================
# LIMPIEZA
# =========================
apt-get autoremove -y
apt-get autoclean -y

# =========================
# TEST FINAL
# =========================
echo "--------------------------------------"
echo "✅ OPTIMIZACION HACKER REAL COMPLETA"
echo "--------------------------------------"

echo "📡 BBR:"
sysctl net.ipv4.tcp_congestion_control

echo ""
echo "📊 Ping:"
ping -c 4 google.com

echo ""
echo "💻 Estado sistema:"
echo "CPU: $CPU_CORES | RAM: $RAM_TOTAL MB"

echo ""
echo "🔥 REINICIA EL VPS PARA MAXIMO RENDIMIENTO"
