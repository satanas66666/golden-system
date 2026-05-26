#!/bin/bash

echo "========================================="
echo "       OPTIMIZANDO VPS IONOS"
echo "========================================="

# ==================================================
# SWAP 8GB
# ==================================================

echo
echo "[+] Configurando SWAP..."

swapoff -a 2>/dev/null
rm -f /swapfile

fallocate -l 8G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=8192

chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

grep -q "/swapfile" /etc/fstab || \
echo "/swapfile none swap sw 0 0" >> /etc/fstab

# ==================================================
# CONNTRACK
# ==================================================

echo
echo "[+] Activando nf_conntrack..."

modprobe nf_conntrack

echo "nf_conntrack" > /etc/modules-load.d/nf_conntrack.conf

# ==================================================
# SYSCTL
# ==================================================

echo
echo "[+] Aplicando optimizaciones TCP..."

cat >/etc/sysctl.d/99-ionos-performance.conf <<EOF

# FILES
fs.file-max=2097152

# MEMORIA
vm.swappiness=15
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5

# RED
net.core.somaxconn=65535
net.core.netdev_max_backlog=250000

net.core.rmem_max=67108864
net.core.wmem_max=67108864

# TCP
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1

net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_keepalive_time=180

net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.tcp_max_tw_buckets=2000000

net.ipv4.tcp_tw_reuse=1

net.ipv4.ip_local_port_range=1024 65000

# CONNTRACK
net.netfilter.nf_conntrack_max=262144

net.netfilter.nf_conntrack_tcp_timeout_established=600
net.netfilter.nf_conntrack_tcp_timeout_time_wait=15
net.netfilter.nf_conntrack_tcp_timeout_fin_wait=15
net.netfilter.nf_conntrack_tcp_timeout_close_wait=15

# BBR
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

EOF

sysctl --system

# ==================================================
# SSH
# ==================================================

echo
echo "[+] Optimizando SSH..."

sed -i 's/^#*UseDNS.*/UseDNS no/' /etc/ssh/sshd_config

grep -q "^ClientAliveInterval" /etc/ssh/sshd_config \
&& sed -i 's/^ClientAliveInterval.*/ClientAliveInterval 120/' /etc/ssh/sshd_config \
|| echo "ClientAliveInterval 120" >> /etc/ssh/sshd_config

grep -q "^MaxStartups" /etc/ssh/sshd_config \
&& sed -i 's/^MaxStartups.*/MaxStartups 500:30:1000/' /etc/ssh/sshd_config \
|| echo "MaxStartups 500:30:1000" >> /etc/ssh/sshd_config

grep -q "^MaxSessions" /etc/ssh/sshd_config \
&& sed -i 's/^MaxSessions.*/MaxSessions 500/' /etc/ssh/sshd_config \
|| echo "MaxSessions 500" >> /etc/ssh/sshd_config

systemctl restart ssh

# ==================================================
# BADVPN
# ==================================================

echo
echo "[+] Reiniciando BADVPN..."

pkill badvpn-udpgw

nohup /usr/local/bin/badvpn-udpgw \
--listen-addr 0.0.0.0:7200 \
--max-clients 5000 \
--max-connections-for-client 20 \
>/dev/null 2>&1 &

nohup /usr/local/bin/badvpn-udpgw \
--listen-addr 0.0.0.0:7300 \
--max-clients 5000 \
--max-connections-for-client 20 \
>/dev/null 2>&1 &

nohup /usr/local/bin/badvpn-udpgw \
--listen-addr 0.0.0.0:7400 \
--max-clients 5000 \
--max-connections-for-client 20 \
>/dev/null 2>&1 &

# ==================================================
# LIMITS
# ==================================================

echo
echo "[+] Configurando limites del sistema..."

cat >/etc/security/limits.d/99-performance.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

# ==================================================
# FINAL
# ==================================================

echo
echo "========================================="
echo "     OPTIMIZACION COMPLETADA"
echo "========================================="
echo
echo "REINICIA LA VPS PARA APLICAR TODO"
echo
