#!/bin/bash

echo "========================================="
echo "   OPTIMIZADOR AUTOMATICO GOLDEN VPS"
echo "========================================="

CPU=$(nproc)
RAM_MB=$(free -m | awk '/Mem:/ {print $2}')

echo "CPU detectados : $CPU"
echo "RAM detectada  : ${RAM_MB}MB"

# =========================
# CALCULO AUTOMATICO
# =========================

if [[ "$RAM_MB" -le 2048 ]]; then
    SWAP_SIZE="4G"
    CONNTRACK=131072
    SOMAX=32768
    BACKLOG=65535
    MAX_CLIENTS=2000
    MAX_CONN_CLIENT=10
elif [[ "$RAM_MB" -le 4096 ]]; then
    SWAP_SIZE="6G"
    CONNTRACK=262144
    SOMAX=65535
    BACKLOG=131072
    MAX_CLIENTS=4000
    MAX_CONN_CLIENT=15
elif [[ "$RAM_MB" -le 8192 ]]; then
    SWAP_SIZE="8G"
    CONNTRACK=524288
    SOMAX=65535
    BACKLOG=250000
    MAX_CLIENTS=8000
    MAX_CONN_CLIENT=20
elif [[ "$RAM_MB" -le 16384 ]]; then
    SWAP_SIZE="12G"
    CONNTRACK=1048576
    SOMAX=65535
    BACKLOG=300000
    MAX_CLIENTS=15000
    MAX_CONN_CLIENT=25
else
    SWAP_SIZE="16G"
    CONNTRACK=2097152
    SOMAX=65535
    BACKLOG=500000
    MAX_CLIENTS=25000
    MAX_CONN_CLIENT=30
fi

# Ajuste extra por CPU
if [[ "$CPU" -ge 8 ]]; then
    MAX_CLIENTS=$((MAX_CLIENTS + 5000))
fi

if [[ "$CPU" -ge 12 ]]; then
    MAX_CLIENTS=$((MAX_CLIENTS + 10000))
fi

echo "SWAP        : $SWAP_SIZE"
echo "CONNTRACK   : $CONNTRACK"
echo "BACKLOG     : $BACKLOG"
echo "MAX CLIENTS : $MAX_CLIENTS"

# =========================
# SWAP
# =========================

echo
echo "[+] Configurando SWAP..."

swapoff -a 2>/dev/null
rm -f /swapfile

fallocate -l "$SWAP_SIZE" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=$(( ${SWAP_SIZE%G} * 1024 ))

chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

grep -q "/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab

# =========================
# CONNTRACK
# =========================

echo
echo "[+] Activando nf_conntrack..."

modprobe nf_conntrack 2>/dev/null
echo "nf_conntrack" > /etc/modules-load.d/nf_conntrack.conf

# =========================
# SYSCTL
# =========================

echo
echo "[+] Aplicando optimizaciones..."

cat >/etc/sysctl.d/99-golden-auto.conf <<EOF
fs.file-max=2097152

vm.swappiness=15
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5

net.core.somaxconn=$SOMAX
net.core.netdev_max_backlog=$BACKLOG
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.core.rmem_default=262144
net.core.wmem_default=262144

net.ipv4.ip_forward=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_keepalive_time=180
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_max_syn_backlog=$SOMAX
net.ipv4.tcp_max_tw_buckets=2000000
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65000

net.netfilter.nf_conntrack_max=$CONNTRACK
net.netfilter.nf_conntrack_tcp_timeout_established=600
net.netfilter.nf_conntrack_tcp_timeout_time_wait=15
net.netfilter.nf_conntrack_tcp_timeout_fin_wait=15
net.netfilter.nf_conntrack_tcp_timeout_close_wait=15

net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

sysctl --system

# =========================
# LIMITS
# =========================

cat >/etc/security/limits.d/99-golden-auto.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

# =========================
# SSH
# =========================

if [[ -e /etc/ssh/sshd_config ]]; then
    sed -i 's/^#*UseDNS.*/UseDNS no/' /etc/ssh/sshd_config

    grep -q "^ClientAliveInterval" /etc/ssh/sshd_config \
    && sed -i 's/^ClientAliveInterval.*/ClientAliveInterval 120/' /etc/ssh/sshd_config \
    || echo "ClientAliveInterval 120" >> /etc/ssh/sshd_config

    grep -q "^ClientAliveCountMax" /etc/ssh/sshd_config \
    && sed -i 's/^ClientAliveCountMax.*/ClientAliveCountMax 2/' /etc/ssh/sshd_config \
    || echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config

    grep -q "^MaxStartups" /etc/ssh/sshd_config \
    && sed -i "s/^MaxStartups.*/MaxStartups 500:30:1000/" /etc/ssh/sshd_config \
    || echo "MaxStartups 500:30:1000" >> /etc/ssh/sshd_config

    grep -q "^MaxSessions" /etc/ssh/sshd_config \
    && sed -i "s/^MaxSessions.*/MaxSessions 500/" /etc/ssh/sshd_config \
    || echo "MaxSessions 500" >> /etc/ssh/sshd_config

    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
fi

# =========================
# BADVPN AUTO
# =========================

if [[ -x /usr/local/bin/badvpn-udpgw ]]; then
    echo
    echo "[+] Reiniciando BADVPN con perfil automatico..."

    pkill badvpn-udpgw 2>/dev/null

    for PORT in 7200 7300 7400; do
        nohup /usr/local/bin/badvpn-udpgw \
        --listen-addr 0.0.0.0:$PORT \
        --max-clients "$MAX_CLIENTS" \
        --max-connections-for-client "$MAX_CONN_CLIENT" \
        >/dev/null 2>&1 &
    done
fi

# =========================
# FINAL
# =========================

echo
echo "========================================="
echo " OPTIMIZACION AUTOMATICA COMPLETADA"
echo "========================================="
echo "CPU          : $CPU"
echo "RAM          : ${RAM_MB}MB"
echo "SWAP         : $SWAP_SIZE"
echo "CONNTRACK    : $CONNTRACK"
echo "MAX CLIENTES : $MAX_CLIENTS"
echo
echo "REINICIA LA VPS:"
echo "reboot"
echo
