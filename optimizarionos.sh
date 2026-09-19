#!/usr/bin/env bash
# GOLDEN VPS OPTIMIZER V2 - PERFIL MULTIPROTOCOLO
# Pensado para VPS con muchos clientes y trafico de tuneles/proxies de larga duracion.
# Optimiza el host sin cambiar puertos, payloads, certificados ni configuraciones
# propias de HAProxy/ProxyGo/BHTTP/HCR/H2/XHTTP/V2Ray/UDPGW.

set -u
set -o pipefail

C_RESET='\033[0m'
C_YELLOW='\033[0;33m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_CYAN='\033[0;36m'

line() { printf '%b\n' "${C_YELLOW}============================================================${C_RESET}"; }
info() { printf '%b\n' "${C_CYAN}[i]${C_RESET} $*"; }
ok()   { printf '%b\n' "${C_GREEN}[OK]${C_RESET} $*"; }
warn() { printf '%b\n' "${C_YELLOW}[!]${C_RESET} $*"; }
err()  { printf '%b\n' "${C_RED}[ERROR]${C_RESET} $*" >&2; }

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    err "Ejecuta este script como root."
    exit 1
fi

for cmd in awk grep sed sysctl nproc free cp mv mkdir date; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        err "Falta el comando requerido: $cmd"
        exit 1
    fi
done

CPU=$(nproc 2>/dev/null || echo 1)
RAM_MB=$(awk '/MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)
[[ -n "$RAM_MB" && "$RAM_MB" -gt 0 ]] || RAM_MB=$(free -m | awk '/Mem:/ {print $2}')

# Perfil automatico conservador: capacidad alta sin colas absurdamente grandes.
if (( RAM_MB <= 2048 )); then
    SWAP_GB=2
    CONNTRACK=262144
    NETDEV_BACKLOG=32768
    BUF_MAX=16777216       # 16 MiB
    FILE_MAX=2097152
    SSH_MAXSTARTUPS='100:30:500'
elif (( RAM_MB <= 4096 )); then
    SWAP_GB=2
    CONNTRACK=524288
    NETDEV_BACKLOG=65536
    BUF_MAX=33554432       # 32 MiB
    FILE_MAX=2097152
    SSH_MAXSTARTUPS='200:30:800'
elif (( RAM_MB <= 8192 )); then
    SWAP_GB=4
    CONNTRACK=1048576
    NETDEV_BACKLOG=65536
    BUF_MAX=67108864       # 64 MiB
    FILE_MAX=4194304
    SSH_MAXSTARTUPS='300:30:1200'
elif (( RAM_MB <= 16384 )); then
    SWAP_GB=4
    CONNTRACK=2097152
    NETDEV_BACKLOG=131072
    BUF_MAX=67108864       # 64 MiB
    FILE_MAX=4194304
    SSH_MAXSTARTUPS='500:30:2000'
elif (( RAM_MB <= 32768 )); then
    SWAP_GB=4
    CONNTRACK=2097152
    NETDEV_BACKLOG=131072
    BUF_MAX=67108864       # 64 MiB
    FILE_MAX=4194304
    SSH_MAXSTARTUPS='800:30:3000'
else
    SWAP_GB=4
    CONNTRACK=4194304
    NETDEV_BACKLOG=131072
    BUF_MAX=67108864       # 64 MiB
    FILE_MAX=8388608
    SSH_MAXSTARTUPS='1000:30:4000'
fi

STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/golden-vps-optimizer/$STAMP"
mkdir -p "$BACKUP_DIR"

backup_file() {
    local f="$1"
    if [[ -e "$f" ]]; then
        local safe
        safe=$(printf '%s' "$f" | sed 's#^/##; s#/#__#g')
        cp -a "$f" "$BACKUP_DIR/$safe" 2>/dev/null || true
    fi
}

line
echo "        GOLDEN VPS OPTIMIZER V2 - MULTIPROTOCOLO"
line
echo "CPU              : $CPU vCPU"
echo "RAM              : ${RAM_MB} MB"
echo "Conntrack max    : $CONNTRACK"
echo "Backlog NIC      : $NETDEV_BACKLOG"
echo "Buffer TCP max   : $((BUF_MAX / 1024 / 1024)) MiB"
echo "File handles     : $FILE_MAX"
echo "Swap emergencia  : ${SWAP_GB}G (solo si no existe swap)"
echo "Backup            : $BACKUP_DIR"
line

# -----------------------------------------------------------------------------
# 1) SWAP: nunca hace swapoff -a ni destruye swap existente.
# -----------------------------------------------------------------------------
info "Verificando SWAP sin interrumpir la VPS..."
SWAP_MB=$(awk '/SwapTotal:/ {printf "%d", $2/1024}' /proc/meminfo)
if (( SWAP_MB > 0 )); then
    ok "Ya existe SWAP (${SWAP_MB} MB). Se conserva sin cambios."
elif [[ -e /swapfile ]]; then
    warn "/swapfile existe pero no esta activo. No se sobrescribe por seguridad."
    warn "Revisalo manualmente antes de modificarlo."
else
    backup_file /etc/fstab
    info "No hay SWAP. Creando /swapfile de ${SWAP_GB}G como proteccion contra picos de memoria..."
    if command -v fallocate >/dev/null 2>&1 && fallocate -l "${SWAP_GB}G" /swapfile 2>/dev/null; then
        :
    else
        dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_GB * 1024)) status=none || {
            err "No se pudo crear /swapfile. Se continua sin tocar el resto."
            rm -f /swapfile
        }
    fi

    if [[ -f /swapfile ]]; then
        chmod 600 /swapfile
        if mkswap /swapfile >/dev/null 2>&1 && swapon /swapfile 2>/dev/null; then
            grep -Eq '^[[:space:]]*/swapfile[[:space:]]' /etc/fstab || \
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
            ok "SWAP creada y activada."
        else
            warn "No fue posible activar /swapfile. Se deja sin registrar en fstab."
        fi
    fi
fi

# -----------------------------------------------------------------------------
# 2) MODULOS Y BBR: se activa solo si el kernel realmente lo soporta.
# -----------------------------------------------------------------------------
info "Comprobando nf_conntrack y BBR..."
if command -v modprobe >/dev/null 2>&1; then
    modprobe nf_conntrack 2>/dev/null || true
    modprobe tcp_bbr 2>/dev/null || true
fi

if [[ -d /etc/modules-load.d ]]; then
    if [[ -e /proc/sys/net/netfilter/nf_conntrack_max ]]; then
        echo 'nf_conntrack' > /etc/modules-load.d/99-golden-nf_conntrack.conf
    fi
    if sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
        echo 'tcp_bbr' > /etc/modules-load.d/99-golden-tcp-bbr.conf
    fi
fi

# -----------------------------------------------------------------------------
# 3) SYSCTL: aplica solo parametros que existen y que el VPS permite escribir.
#    Esto evita dejar sysctl --system lleno de errores en kernels restringidos.
# -----------------------------------------------------------------------------
SYSCTL_FILE='/etc/sysctl.d/99-golden-auto.conf'
SYSCTL_TMP="${SYSCTL_FILE}.tmp.$$"
backup_file "$SYSCTL_FILE"
: > "$SYSCTL_TMP"
cat >> "$SYSCTL_TMP" <<'HDR'
# GOLDEN VPS OPTIMIZER V2 - generado automaticamente
# No editar mientras el optimizador siga siendo la fuente de autoridad.
HDR

apply_sysctl() {
    local key="$1"
    local value="$2"
    if sysctl -n "$key" >/dev/null 2>&1; then
        if sysctl -w "$key=$value" >/dev/null 2>&1; then
            printf '%s=%s\n' "$key" "$value" >> "$SYSCTL_TMP"
            return 0
        fi
        warn "Kernel/VPS rechazo: $key=$value (se omite)."
    fi
    return 1
}

info "Aplicando perfil de red para tuneles y proxies de larga duracion..."

# Archivos / memoria
apply_sysctl fs.file-max "$FILE_MAX" || true
apply_sysctl fs.nr_open 2097152 || true
apply_sysctl vm.swappiness 10 || true
apply_sysctl vm.vfs_cache_pressure 75 || true
apply_sysctl vm.dirty_ratio 10 || true
apply_sysctl vm.dirty_background_ratio 5 || true

# Colas y buffers. Los maximos permiten BDP alto, pero el autotuning evita
# reservar ese valor para cada socket desde el inicio.
apply_sysctl net.core.somaxconn 65535 || true
apply_sysctl net.core.netdev_max_backlog "$NETDEV_BACKLOG" || true
apply_sysctl net.core.rmem_max "$BUF_MAX" || true
apply_sysctl net.core.wmem_max "$BUF_MAX" || true
apply_sysctl net.core.rmem_default 262144 || true
apply_sysctl net.core.wmem_default 262144 || true
apply_sysctl net.core.optmem_max 65536 || true
apply_sysctl net.ipv4.tcp_rmem "4096 262144 $BUF_MAX" || true
apply_sysctl net.ipv4.tcp_wmem "4096 262144 $BUF_MAX" || true
apply_sysctl net.ipv4.tcp_moderate_rcvbuf 1 || true

# Red TCP. Evita timeouts demasiado cortos para SSH/SSL/H2/XHTTP/BHTTP.
apply_sysctl net.ipv4.ip_forward 1 || true
apply_sysctl net.ipv4.tcp_syncookies 1 || true
apply_sysctl net.ipv4.tcp_fastopen 3 || true
apply_sysctl net.ipv4.tcp_mtu_probing 1 || true
apply_sysctl net.ipv4.tcp_fin_timeout 20 || true
apply_sysctl net.ipv4.tcp_keepalive_time 300 || true
apply_sysctl net.ipv4.tcp_keepalive_intvl 30 || true
apply_sysctl net.ipv4.tcp_keepalive_probes 5 || true
apply_sysctl net.ipv4.tcp_max_syn_backlog 65535 || true
apply_sysctl net.ipv4.tcp_tw_reuse 1 || true
apply_sysctl net.ipv4.ip_local_port_range "1024 65535" || true
apply_sysctl net.ipv4.tcp_slow_start_after_idle 0 || true

# Presupuesto de recepcion: solo en kernels que lo exponen y con >=4 vCPU.
if (( CPU >= 4 )); then
    apply_sysctl net.core.netdev_budget 600 || true
    apply_sysctl net.core.netdev_budget_usecs 8000 || true
fi

# Conntrack: capacidad alta sin destruir sesiones legitimas que esten ociosas
# durante varios minutos. El V1 usaba 600s para ESTABLISHED; aqui se conserva
# 24h de inactividad para tuneles largos.
if [[ -e /proc/sys/net/netfilter/nf_conntrack_max ]]; then
    apply_sysctl net.netfilter.nf_conntrack_max "$CONNTRACK" || true
    apply_sysctl net.netfilter.nf_conntrack_tcp_timeout_established 86400 || true
    apply_sysctl net.netfilter.nf_conntrack_tcp_timeout_time_wait 30 || true
    apply_sysctl net.netfilter.nf_conntrack_tcp_timeout_fin_wait 60 || true
    apply_sysctl net.netfilter.nf_conntrack_tcp_timeout_close_wait 60 || true
    apply_sysctl net.netfilter.nf_conntrack_udp_timeout 60 || true
    apply_sysctl net.netfilter.nf_conntrack_udp_timeout_stream 180 || true
fi

# BBR + fq solo cuando BBR aparece entre los algoritmos disponibles.
AVAILABLE_CC=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)
if grep -qw bbr <<<"$AVAILABLE_CC"; then
    apply_sysctl net.core.default_qdisc fq || true
    if apply_sysctl net.ipv4.tcp_congestion_control bbr; then
        ok "BBR activado correctamente."
    fi
else
    CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo desconocido)
    warn "BBR no esta disponible en este kernel. Se conserva: $CURRENT_CC"
fi

mv -f "$SYSCTL_TMP" "$SYSCTL_FILE"
ok "SYSCTL aplicado y guardado en $SYSCTL_FILE"

# -----------------------------------------------------------------------------
# 4) LIMITES: limits.d + systemd. El V1 solo ajustaba PAM/limits.d; muchos
#    demonios (HAProxy, Xray, ProxyGo, etc.) arrancan por systemd.
# -----------------------------------------------------------------------------
info "Configurando limites de archivos para servicios y sesiones..."
LIMITS_FILE='/etc/security/limits.d/99-golden-auto.conf'
backup_file "$LIMITS_FILE"
mkdir -p /etc/security/limits.d
cat > "$LIMITS_FILE" <<'EOF_LIMITS'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF_LIMITS

SYSTEMD_LIMITS='/etc/systemd/system.conf.d/99-golden-vpn-limits.conf'
mkdir -p /etc/systemd/system.conf.d
backup_file "$SYSTEMD_LIMITS"
cat > "$SYSTEMD_LIMITS" <<'EOF_SYSTEMD'
[Manager]
DefaultLimitNOFILE=1048576
EOF_SYSTEMD

if [[ "$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ')" == 'systemd' ]]; then
    systemctl daemon-reexec >/dev/null 2>&1 || warn "systemd no pudo hacer daemon-reexec; se aplicara tras reiniciar."
fi
ulimit -n 1048576 2>/dev/null || true
ok "Limites configurados. Los servicios existentes toman el nuevo limite al reiniciarse."

# -----------------------------------------------------------------------------
# 5) SSH: ajuste seguro y validado. No cambia auth, usuarios, claves ni puertos.
# -----------------------------------------------------------------------------
configure_ssh() {
    local main='/etc/ssh/sshd_config'
    local dir='/etc/ssh/sshd_config.d'
    local drop="$dir/00-golden-vpn.conf"

    [[ -f "$main" ]] || return 0
    command -v sshd >/dev/null 2>&1 || return 0

    # Usamos drop-in solo si el sshd_config principal realmente lo incluye.
    if ! grep -Eiq '^[[:space:]]*Include[[:space:]]+.*sshd_config\.d/\*\.conf' "$main"; then
        warn "sshd_config no incluye sshd_config.d/*.conf; por seguridad no se reescribe SSH."
        return 0
    fi

    mkdir -p "$dir"
    backup_file "$drop"
    cat > "$drop" <<EOF_SSH
# GOLDEN VPS OPTIMIZER V2
UseDNS no
TCPKeepAlive yes
ClientAliveInterval 120
ClientAliveCountMax 3
MaxStartups $SSH_MAXSTARTUPS
MaxSessions 100
EOF_SSH

    if sshd -t -f "$main" >/dev/null 2>&1; then
        if systemctl reload ssh >/dev/null 2>&1 || systemctl reload sshd >/dev/null 2>&1; then
            ok "OpenSSH validado y recargado sin cortar sesiones activas."
        else
            warn "Configuracion SSH valida, pero no se pudo recargar automaticamente."
        fi
    else
        err "La validacion de SSH fallo. Se revierte el drop-in nuevo."
        rm -f "$drop"
        local safe='etc__ssh__sshd_config.d__00-golden-vpn.conf'
        if [[ -f "$BACKUP_DIR/$safe" ]]; then
            cp -a "$BACKUP_DIR/$safe" "$drop"
        fi
        return 1
    fi
}

info "Ajustando OpenSSH para picos de reconexion..."
configure_ssh || true

# -----------------------------------------------------------------------------
# 6) SERVICIOS DE PROTOCOLO: NO se matan ni se relanzan.
#    El optimizador anterior hacia pkill badvpn-udpgw y lo levantaba en 3 puertos.
#    Aqui se preserva la topologia instalada por el panel.
# -----------------------------------------------------------------------------
if pgrep -x badvpn-udpgw >/dev/null 2>&1; then
    ok "UDPGW/BADVNP detectado: se conserva el proceso y sus puertos actuales."
elif [[ -x /usr/local/bin/badvpn-udpgw ]]; then
    info "badvpn-udpgw esta instalado pero no activo; no se inicia automaticamente."
fi

# Resumen rapido de componentes comunes; solo informativo.
ACTIVE=()
for proc in haproxy sshd xray v2ray stunnel dropbear; do
    if pgrep -x "$proc" >/dev/null 2>&1; then
        ACTIVE+=("$proc")
    fi
done

line
echo " OPTIMIZACION V2 COMPLETADA"
line
echo "CPU               : $CPU"
echo "RAM               : ${RAM_MB} MB"
echo "CONNTRACK MAX     : $CONNTRACK"
echo "NETDEV BACKLOG    : $NETDEV_BACKLOG"
echo "BUFFER TCP MAX    : $((BUF_MAX / 1024 / 1024)) MiB"
echo "NOFILE            : 1048576"
echo "SSH MaxStartups   : $SSH_MAXSTARTUPS"
if ((${#ACTIVE[@]} > 0)); then
    echo "Procesos detectados: ${ACTIVE[*]}"
fi
echo "Backup             : $BACKUP_DIR"
line
printf '%b\n' "${C_GREEN}Recomendado: reinicia UNA vez la VPS para que todos los servicios hereden los limites systemd.${C_RESET}"
echo "Comando: reboot"
