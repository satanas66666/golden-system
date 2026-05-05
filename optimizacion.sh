#!/bin/bash

echo "🚀 OPTIMIZANDO VPS PARA V2RAY..."

# Verificar root
if [ "$(whoami)" != "root" ]; then
  echo "❌ Ejecuta como root"
  exit 1
fi

# Actualizar sistema
echo "📦 Actualizando sistema..."
apt-get update -y && apt-get upgrade -y

# Instalar herramientas útiles
echo "🛠 Instalando herramientas..."
apt-get install -y curl wget sudo nano htop net-tools dnsutils speedtest-cli

# =========================
# ⚡ OPTIMIZACIÓN KERNEL (BBR)
# =========================
echo "⚡ Activando BBR..."

cat >> /etc/sysctl.conf <<EOF
# OPTIMIZACION V2RAY
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv4.ip_local_port_range=1024 65535
net.core.netdev_max_backlog=250000
EOF

sysctl -p

# =========================
# 🔥 LIMITES DEL SISTEMA
# =========================
echo "📈 Ajustando límites..."

cat >> /etc/security/limits.conf <<EOF
* soft nofile 51200
* hard nofile 51200
root soft nofile 51200
root hard nofile 51200
EOF

ulimit -n 51200

# =========================
# 🌐 DNS RAPIDO
# =========================
echo "🌐 Configurando DNS..."

cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# =========================
# 🚫 DESACTIVAR SERVICIOS INNECESARIOS
# =========================
echo "🧹 Limpiando servicios..."

systemctl stop apache2 2>/dev/null
systemctl disable apache2 2>/dev/null

systemctl stop ufw 2>/dev/null
systemctl disable ufw 2>/dev/null

# =========================
# ⚡ OPTIMIZACIÓN SSH
# =========================
echo "🔐 Optimizando SSH..."

sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
sed -i 's/#TCPKeepAlive yes/TCPKeepAlive yes/g' /etc/ssh/sshd_config

systemctl restart ssh

# =========================
# 🧠 LIMPIEZA GENERAL
# =========================
echo "🧼 Limpiando sistema..."

apt-get autoremove -y
apt-get autoclean -y

# =========================
# 🔍 INFO FINAL
# =========================
echo "--------------------------------------"
echo "✅ OPTIMIZACION COMPLETA FINALIZADA"
echo "--------------------------------------"

echo "🔎 Estado BBR:"
sysctl net.ipv4.tcp_congestion_control

echo ""
echo "📊 Test de red:"
ping -c 4 google.com

echo ""
echo "⚡ Speedtest:"
speedtest

echo ""
echo "🔥 REINICIA EL VPS PARA APLICAR TODO"
