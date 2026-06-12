#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
shopt -s extglob

REG="/etc/newadm/RegXray"
DIR="/etc/newadm/xray"
CFG="/usr/local/etc/xray/config.json"
BIN="/usr/local/bin/xray"
SERVICE="xray"

mkdir -p "$DIR" /etc/newadm /usr/local/etc/xray /etc/iptables

VERDE="\033[1;32m"
ROJO="\033[1;31m"
AMARILLO="\033[1;33m"
AZUL="\033[1;34m"
BLANCO="\033[1;37m"
RESET="\033[0m"

bar(){ echo -e "${AMARILLO}============================================================${RESET}"; }
ok(){ echo -e "${VERDE}$1${RESET}"; }
err(){ echo -e "${ROJO}$1${RESET}"; }
info(){ echo -e "${AZUL}$1${RESET}"; }
pause(){ echo -ne "${BLANCO}Enter para continuar: ${RESET}"; read -r enter; }

install_deps(){
apt update -y
apt install -y curl wget unzip zip jq uuid-runtime lsof screen iproute2 \
iptables iptables-persistent netfilter-persistent ca-certificates \
cron openssl socat chrony locales
locale-gen C.UTF-8 >/dev/null 2>&1
}

fix_time(){
systemctl enable chrony >/dev/null 2>&1
systemctl restart chrony >/dev/null 2>&1
timedatectl set-ntp true >/dev/null 2>&1
}

fix_performance(){
mkdir -p /etc/sysctl.d

cat >/etc/sysctl.d/99-xray-performance.conf <<'EOFSYS'
fs.file-max = 2097152
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 65535
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 500000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 1
net.netfilter.nf_conntrack_max = 262144
EOFSYS

cat >/etc/security/limits.d/99-xray.conf <<'EOFLIMIT'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOFLIMIT

sysctl --system >/dev/null 2>&1
ulimit -n 1048576 >/dev/null 2>&1
}

fix_service(){
mkdir -p /etc/systemd/system/xray.service.d

cat >/etc/systemd/system/xray.service <<'EOFSERVICE'
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=always
RestartSec=1
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TasksMax=infinity
CPUAccounting=no
MemoryAccounting=no

[Install]
WantedBy=multi-user.target
EOFSERVICE

systemctl daemon-reload >/dev/null 2>&1
}

open_port(){
local p="$1"
[[ -z "$p" ]] && return
iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport "$p" -j ACCEPT
iptables -C INPUT -p udp --dport "$p" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$p" -j ACCEPT
iptables-save > /etc/iptables/rules.v4 2>/dev/null
if command -v ufw >/dev/null 2>&1; then
ufw allow "$p"/tcp >/dev/null 2>&1
ufw allow "$p"/udp >/dev/null 2>&1
fi
}

close_port(){
local p="$1"
[[ -z "$p" ]] && return
while iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null; do
iptables -D INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null
done
while iptables -C INPUT -p udp --dport "$p" -j ACCEPT 2>/dev/null; do
iptables -D INPUT -p udp --dport "$p" -j ACCEPT 2>/dev/null
done
iptables-save > /etc/iptables/rules.v4 2>/dev/null
if command -v ufw >/dev/null 2>&1; then
ufw delete allow "$p"/tcp >/dev/null 2>&1
ufw delete allow "$p"/udp >/dev/null 2>&1
fi
}

restart_xray(){
fix_service
fix_time
fix_performance
systemctl enable xray >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
systemctl restart xray >/dev/null 2>&1
sleep 2
}

vps_ip(){
local ip
ip=$(curl -s4 --max-time 5 ifconfig.me 2>/dev/null)
[[ -z "$ip" ]] && ip=$(hostname -I | awk '{print $1}')
echo "$ip"
}

urlencode(){
jq -nr --arg v "$1" '$v|@uri'
}

normalize_path(){
local path="$1"
local def="$2"
[[ -z "$path" ]] && path="$def"
local first_char="${path:0:1}"
if [[ "$first_char" != "/" && "$first_char" != " " ]]; then
path="/$path"
fi
echo "$path"
}

random_short_id(){
openssl rand -hex 8
}

create_config(){
mkdir -p /usr/local/etc/xray
cat >"$CFG" <<'EOFJSON'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOFJSON
}

test_xray_config(){
if [[ ! -x "$BIN" || ! -e "$CFG" ]]; then
return 1
fi
$BIN run -test -config "$CFG" >/tmp/xray-test.log 2>&1 || $BIN test -c "$CFG" >/tmp/xray-test.log 2>&1
}

issue_tls_cert(){
local port="$1"
local domain="$2"
[[ -z "$port" || -z "$domain" ]] && return 1

install_deps
open_port 80
open_port "$port"
mkdir -p "/usr/local/etc/xray/cert/$port"

bar
info " Deteniendo Xray para liberar puerto 80 y generar certificado..."
bar
systemctl stop xray >/dev/null 2>&1
sleep 2

curl -s https://get.acme.sh | sh -s email=admin@"$domain"
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "$domain" --standalone --force --keylength ec-256

if [[ ! -f "/root/.acme.sh/${domain}_ecc/${domain}.key" ]]; then
err "NO SE GENERO EL CERTIFICADO. Verifica DNS del dominio y puerto 80 libre."
return 1
fi

~/.acme.sh/acme.sh --install-cert -d "$domain" --ecc \
--key-file "/usr/local/etc/xray/cert/$port/private.key" \
--fullchain-file "/usr/local/etc/xray/cert/$port/cert.crt"

if [[ ! -s "/usr/local/etc/xray/cert/$port/private.key" || ! -s "/usr/local/etc/xray/cert/$port/cert.crt" ]]; then
err "CERTIFICADO NO INSTALADO CORRECTAMENTE"
return 1
fi

ok "CERTIFICADO TLS GENERADO PARA $domain"
return 0
}

generate_reality_keys(){
local out private public
out=$($BIN x25519 2>/dev/null)
private=$(echo "$out" | awk -F': ' 'tolower($1) ~ /private/ {print $2; exit}')
public=$(echo "$out" | awk -F': ' 'tolower($1) ~ /public|password/ {print $2; exit}')

if [[ -z "$private" || -z "$public" ]]; then
err "No se pudieron generar claves REALITY con xray x25519"
return 1
fi

echo "$private|$public"
}

add_inbound(){
local port="$1"
local path="$2"
local mode="$3"
local domain="$4"
local reality_target="$5"
local reality_sni="$6"
local private_key="$7"
local short_id="$8"
local tmp

tmp=$(mktemp)

case "$mode" in
vmess-ws)
jq --arg p "$path" --argjson port "$port" '
.inbounds += [{
  "port": $port,
  "listen": "0.0.0.0",
  "protocol": "vmess",
  "settings": {"clients": [], "disableInsecureEncryption": false},
  "sniffing": {"enabled": false},
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "sockopt": {"tcpFastOpen": true, "tcpKeepAliveIdle": 30},
    "wsSettings": {"path": $p, "headers": {}}
  }
}]
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
vless-ws)
jq --arg p "$path" --argjson port "$port" '
.inbounds += [{
  "port": $port,
  "listen": "0.0.0.0",
  "protocol": "vless",
  "settings": {"clients": [], "decryption": "none"},
  "sniffing": {"enabled": false},
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "sockopt": {"tcpFastOpen": true, "tcpKeepAliveIdle": 30},
    "wsSettings": {"path": $p, "headers": {}}
  }
}]
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
trojan-ws)
jq --arg p "$path" --argjson port "$port" '
.inbounds += [{
  "port": $port,
  "listen": "0.0.0.0",
  "protocol": "trojan",
  "settings": {"clients": []},
  "sniffing": {"enabled": false},
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "sockopt": {"tcpFastOpen": true, "tcpKeepAliveIdle": 30},
    "wsSettings": {"path": $p, "headers": {}}
  }
}]
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
vless-tcp-xtls-tls)
jq --argjson port "$port" --arg d "$domain" --arg cert "/usr/local/etc/xray/cert/$port/cert.crt" --arg key "/usr/local/etc/xray/cert/$port/private.key" '
.inbounds += [{
  "port": $port,
  "listen": "0.0.0.0",
  "protocol": "vless",
  "settings": {"clients": [], "decryption": "none"},
  "sniffing": {"enabled": false},
  "streamSettings": {
    "network": "raw",
    "security": "tls",
    "sockopt": {"tcpFastOpen": true, "tcpKeepAliveIdle": 30},
    "tlsSettings": {
      "serverName": $d,
      "alpn": ["http/1.1"],
      "certificates": [{"certificateFile": $cert, "keyFile": $key}]
    }
  }
}]
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
vless-tcp-xtls-reality)
jq --argjson port "$port" --arg target "$reality_target" --arg sni "$reality_sni" --arg pk "$private_key" --arg sid "$short_id" '
.inbounds += [{
  "port": $port,
  "listen": "0.0.0.0",
  "protocol": "vless",
  "settings": {"clients": [], "decryption": "none"},
  "sniffing": {"enabled": false},
  "streamSettings": {
    "network": "raw",
    "security": "reality",
    "sockopt": {"tcpFastOpen": true, "tcpKeepAliveIdle": 30},
    "realitySettings": {
      "show": false,
      "target": $target,
      "xver": 0,
      "serverNames": [$sni],
      "privateKey": $pk,
      "shortIds": [$sid]
    }
  }
}]
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
vmess-tcp-tls)
jq --argjson port "$port" --arg d "$domain" --arg cert "/usr/local/etc/xray/cert/$port/cert.crt" --arg key "/usr/local/etc/xray/cert/$port/private.key" '
.inbounds += [{
  "port": $port,
  "listen": "0.0.0.0",
  "protocol": "vmess",
  "settings": {"clients": [], "disableInsecureEncryption": false},
  "sniffing": {"enabled": false},
  "streamSettings": {
    "network": "raw",
    "security": "tls",
    "sockopt": {"tcpFastOpen": true, "tcpKeepAliveIdle": 30},
    "tlsSettings": {
      "serverName": $d,
      "alpn": ["http/1.1"],
      "certificates": [{"certificateFile": $cert, "keyFile": $key}]
    }
  }
}]
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
vmess-xhttp-tls)
jq --arg p "$path" --argjson port "$port" --arg d "$domain" --arg cert "/usr/local/etc/xray/cert/$port/cert.crt" --arg key "/usr/local/etc/xray/cert/$port/private.key" '
.inbounds += [{
  "port": $port,
  "listen": "0.0.0.0",
  "protocol": "vmess",
  "settings": {"clients": [], "disableInsecureEncryption": false},
  "sniffing": {"enabled": false},
  "streamSettings": {
    "network": "xhttp",
    "security": "tls",
    "sockopt": {"tcpFastOpen": true, "tcpKeepAliveIdle": 30},
    "xhttpSettings": {"path": $p, "mode": "auto"},
    "tlsSettings": {
      "serverName": $d,
      "alpn": ["h2", "http/1.1"],
      "certificates": [{"certificateFile": $cert, "keyFile": $key}]
    }
  }
}]
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
vless-xhttp-tls)
jq --arg p "$path" --argjson port "$port" --arg d "$domain" --arg cert "/usr/local/etc/xray/cert/$port/cert.crt" --arg key "/usr/local/etc/xray/cert/$port/private.key" '
.inbounds += [{
  "port": $port,
  "listen": "0.0.0.0",
  "protocol": "vless",
  "settings": {"clients": [], "decryption": "none"},
  "sniffing": {"enabled": false},
  "streamSettings": {
    "network": "xhttp",
    "security": "tls",
    "sockopt": {"tcpFastOpen": true, "tcpKeepAliveIdle": 30},
    "xhttpSettings": {"path": $p, "mode": "auto"},
    "tlsSettings": {
      "serverName": $d,
      "alpn": ["h2", "http/1.1"],
      "certificates": [{"certificateFile": $cert, "keyFile": $key}]
    }
  }
}]
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
vless-xhttp-reality)
jq --arg p "$path" --argjson port "$port" --arg target "$reality_target" --arg sni "$reality_sni" --arg pk "$private_key" --arg sid "$short_id" '
.inbounds += [{
  "port": $port,
  "listen": "0.0.0.0",
  "protocol": "vless",
  "settings": {"clients": [], "decryption": "none"},
  "sniffing": {"enabled": false},
  "streamSettings": {
    "network": "xhttp",
    "security": "reality",
    "sockopt": {"tcpFastOpen": true, "tcpKeepAliveIdle": 30},
    "xhttpSettings": {"path": $p, "mode": "auto"},
    "realitySettings": {
      "show": false,
      "target": $target,
      "xver": 0,
      "serverNames": [$sni],
      "privateKey": $pk,
      "shortIds": [$sid]
    }
  }
}]
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
*)
rm -f "$tmp"
err "MODO NO SOPORTADO: $mode"
return 1
;;
esac
}

mode_label(){
case "$1" in
vmess-ws) echo "VMess + WebSocket" ;;
vmess-tcp-tls) echo "VMess + TCP + TLS" ;;
vmess-xhttp-tls) echo "VMess + xHTTP + TLS" ;;
vless-ws) echo "VLESS + WebSocket" ;;
trojan-ws) echo "Trojan + WebSocket" ;;
vless-tcp-xtls-tls) echo "VLESS + TCP + TLS + XTLS Vision" ;;
vless-tcp-xtls-reality) echo "VLESS + TCP + REALITY + XTLS Vision" ;;
vless-xhttp-tls) echo "VLESS + xHTTP + TLS" ;;
vless-xhttp-reality) echo "VLESS + xHTTP + REALITY" ;;
*) echo "$1" ;;
esac
}

select_mode(){
{
bar
echo -e "${VERDE}[1]${RESET} VMess + WebSocket"
echo -e "${VERDE}[2]${RESET} VLESS + WebSocket"
echo -e "${VERDE}[3]${RESET} Trojan + WebSocket"
bar
echo -e "${VERDE}[4]${RESET} VLESS + TCP + TLS + XTLS Vision"
echo -e "${VERDE}[5]${RESET} VLESS + TCP + REALITY + XTLS Vision"
bar
echo -e "${VERDE}[6]${RESET} VLESS + xHTTP + TLS"
echo -e "${VERDE}[7]${RESET} VLESS + xHTTP + REALITY"
bar
echo -e "${VERDE}[8]${RESET} VMess + TCP + TLS"
echo -e "${VERDE}[9]${RESET} VMess + xHTTP + TLS"
bar
echo -ne "Seleccione modo: "
} >&2
read -r mode_op
case "$mode_op" in
1) echo "vmess-ws" ;;
2) echo "vless-ws" ;;
3) echo "trojan-ws" ;;
4) echo "vless-tcp-xtls-tls" ;;
5) echo "vless-tcp-xtls-reality" ;;
6) echo "vless-xhttp-tls" ;;
7) echo "vless-xhttp-reality" ;;
8) echo "vmess-tcp-tls" ;;
9) echo "vmess-xhttp-tls" ;;
*) echo "vmess-ws" ;;
esac
}

inbound_path(){
local port="$1"
jq -r --arg p "$port" '
.inbounds[]? | select((.port|tostring)==$p) |
if (.streamSettings.network // "") == "xhttp" then (.streamSettings.xhttpSettings.path // "-")
elif (.streamSettings.network // "") == "ws" or (.streamSettings.network // "") == "websocket" then (.streamSettings.wsSettings.path // "-")
else "-" end
' "$CFG"
}

inbound_sni(){
local port="$1"
jq -r --arg p "$port" '
.inbounds[]? | select((.port|tostring)==$p) |
.streamSettings.tlsSettings.serverName // .streamSettings.realitySettings.serverNames[0] // ""
' "$CFG"
}

inbound_security(){
local port="$1"
jq -r --arg p "$port" '.inbounds[]? | select((.port|tostring)==$p) | .streamSettings.security // "none"' "$CFG"
}

inbound_network(){
local port="$1"
jq -r --arg p "$port" '.inbounds[]? | select((.port|tostring)==$p) | .streamSettings.network // "ws"' "$CFG"
}

inbound_proto(){
local port="$1"
jq -r --arg p "$port" '.inbounds[]? | select((.port|tostring)==$p) | .protocol // "vmess"' "$CFG"
}

show_ports(){
[[ ! -e "$CFG" ]] && {
err "No existe configuración Xray"
return
}

jq -r '
.inbounds[]? |
"Puerto: \(.port) | Protocolo: \(.protocol // "-") | Red: \(.streamSettings.network // "-") | Seguridad: \(.streamSettings.security // "none") | Path: [\(if (.streamSettings.network // "") == "xhttp" then (.streamSettings.xhttpSettings.path // "-") elif (.streamSettings.network // "") == "ws" or (.streamSettings.network // "") == "websocket" then (.streamSettings.wsSettings.path // "-") else "-" end)] | Usuarios: \((.settings.clients // [])|length)"
' "$CFG"
}

import_legacy_v2ray(){
local old_cfg="/usr/local/etc/v2ray/config.json"
local old_reg="/etc/newadm/RegV2ray"

if [[ -s "$old_cfg" ]] && jq empty "$old_cfg" >/dev/null 2>&1; then
  if [[ ! -s "$CFG" ]] || [[ "$(jq -r '(.inbounds // []) | length' "$CFG" 2>/dev/null)" == "0" ]]; then
    cp -f "$old_cfg" "$CFG"
    ok "Configuración VMess antigua importada a Xray"
  fi
fi

[[ ! -s "$old_reg" ]] && return 0
touch "$REG"

while IFS='|' read -r cred user expire port hostcustom; do
  [[ -z "$cred" || -z "$user" || -z "$port" ]] && continue
  grep -Fq "$cred|" "$REG" 2>/dev/null && continue

  local proto network security path sni mode flow public_key short_id spiderx
  proto=$(inbound_proto "$port")
  network=$(inbound_network "$port")
  security=$(inbound_security "$port")
  path=$(inbound_path "$port")
  sni=$(inbound_sni "$port")
  flow=""
  public_key=""
  short_id=""
  spiderx="/"

  if [[ "$proto" == "vless" && "$network" == "raw" && ( "$security" == "tls" || "$security" == "reality" ) ]]; then
    flow="xtls-rprx-vision"
    if [[ "$security" == "tls" ]]; then mode="vless-tcp-xtls-tls"; else mode="vless-tcp-xtls-reality"; fi
  elif [[ "$proto" == "vless" && "$network" == "xhttp" && "$security" == "tls" ]]; then
    mode="vless-xhttp-tls"
  elif [[ "$proto" == "vless" && "$network" == "xhttp" && "$security" == "reality" ]]; then
    mode="vless-xhttp-reality"
  elif [[ "$proto" == "vless" ]]; then
    mode="vless-ws"
  elif [[ "$proto" == "trojan" ]]; then
    mode="trojan-ws"
  else
    mode="vmess-ws"
  fi

  echo "$cred|$user|$expire|$port|$hostcustom|$mode|$network|$security|$flow|$path|$sni|$public_key|$short_id|$spiderx" >> "$REG"
done < "$old_reg"

ok "Registro antiguo RegV2ray importado a RegXray"
}

install_xray(){
clear
bar
info " INSTALANDO XRAY-CORE MODERNO"
bar

install_deps
fix_performance

systemctl stop v2ray >/dev/null 2>&1
systemctl disable v2ray >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)"

ln -sf /usr/local/bin/xray /usr/bin/xray
mkdir -p /usr/local/etc/xray
create_config
import_legacy_v2ray

if [[ "$(jq -r '(.inbounds // []) | length' "$CFG" 2>/dev/null)" == "0" ]]; then
  add_inbound 80 "/vmess" "vmess-ws" "" "" "" "" ""
fi

touch "$REG"
for p in $(jq -r '.inbounds[]?.port' "$CFG" 2>/dev/null); do
  open_port "$p"
done
restart_xray

bar
test_xray_config
cat /tmp/xray-test.log 2>/dev/null
bar

if ss -lntp | grep -q ':80'; then
ok " XRAY INSTALADO Y ESCUCHANDO EN PUERTO 80"
else
err " XRAY INSTALADO, PERO NO ESTA ESCUCHANDO"
fi

bar
info "Ahora puedes agregar VLESS + XTLS, REALITY o xHTTP desde la opción [2]."
bar
pause
menu
}

agregar_puerto(){
clear
bar
info " AGREGAR PUERTO / PROTOCOLO XRAY"
bar

[[ ! -e "$CFG" ]] && {
err "Primero instala Xray"
pause
menu
}

mode=$(select_mode)
bar
info "Modo seleccionado: $(mode_label "$mode")"
bar

echo -ne "Puerto nuevo: "
read -r port

if [[ -z "$port" || "$port" != +([0-9]) || "$port" -lt 1 || "$port" -gt 65535 ]]; then
err "PUERTO INVALIDO"
pause
menu
fi

if jq -e --arg p "$port" '.inbounds[]? | select((.port|tostring)==$p)' "$CFG" >/dev/null; then
err "Ese puerto ya existe"
pause
menu
fi

path=""
domain=""
reality_target=""
reality_sni=""
private_key=""
public_key=""
short_id=""

case "$mode" in
vmess-ws|vless-ws|trojan-ws)
printf "Path WebSocket EXACTO con espacios/emojis: "
IFS= read -r path
path=$(normalize_path "$path" "/${mode%%-*}")
;;
vless-tcp-xtls-tls|vmess-tcp-tls)
echo -ne "Dominio apuntado a la VPS para TLS: "
read -r domain
[[ -z "$domain" ]] && { err "DOMINIO INVALIDO"; pause; menu; }
issue_tls_cert "$port" "$domain" || { restart_xray; pause; menu; }
;;
vless-tcp-xtls-reality)
echo -ne "Target REALITY, ejemplo www.microsoft.com:443: "
read -r reality_target
[[ -z "$reality_target" ]] && reality_target="www.microsoft.com:443"
echo -ne "SNI REALITY, ejemplo www.microsoft.com: "
read -r reality_sni
[[ -z "$reality_sni" ]] && reality_sni="${reality_target%%:*}"
keys=$(generate_reality_keys) || { pause; menu; }
private_key="${keys%%|*}"
public_key="${keys##*|}"
short_id=$(random_short_id)
;;
vless-xhttp-tls|vmess-xhttp-tls)
printf "Path xHTTP EXACTO con espacios/emojis: "
IFS= read -r path
path=$(normalize_path "$path" "/xhttp")
echo -ne "Dominio apuntado a la VPS para TLS: "
read -r domain
[[ -z "$domain" ]] && { err "DOMINIO INVALIDO"; pause; menu; }
issue_tls_cert "$port" "$domain" || { restart_xray; pause; menu; }
;;
vless-xhttp-reality)
printf "Path xHTTP EXACTO: "
IFS= read -r path
path=$(normalize_path "$path" "/xhttp")
echo -ne "Target REALITY, ejemplo www.microsoft.com:443: "
read -r reality_target
[[ -z "$reality_target" ]] && reality_target="www.microsoft.com:443"
echo -ne "SNI REALITY, ejemplo www.microsoft.com: "
read -r reality_sni
[[ -z "$reality_sni" ]] && reality_sni="${reality_target%%:*}"
keys=$(generate_reality_keys) || { pause; menu; }
private_key="${keys%%|*}"
public_key="${keys##*|}"
short_id=$(random_short_id)
;;
esac

add_inbound "$port" "$path" "$mode" "$domain" "$reality_target" "$reality_sni" "$private_key" "$short_id" || { pause; menu; }
open_port "$port"
restart_xray

bar
if ss -lntp | grep -q ":$port"; then
ok " PUERTO $port AGREGADO Y ACTIVO"
else
err " PUERTO AGREGADO, PERO NO ESCUCHA"
fi
echo " Modo: $(mode_label "$mode")"
[[ -n "$path" ]] && echo " Path: [$path]"
[[ -n "$domain" ]] && echo " TLS/SNI: $domain"
if [[ -n "$public_key" ]]; then
echo " REALITY SNI: $reality_sni"
echo " REALITY TARGET: $reality_target"
echo " REALITY PUBLIC KEY: $public_key"
echo " REALITY SHORT ID: $short_id"
fi
bar
pause
menu
}

eliminar_puerto(){
clear
bar
info " ELIMINAR PUERTO"
bar
show_ports
bar

echo -ne "Puerto a eliminar: "
read -r port

if [[ -z "$port" || "$port" != +([0-9]) ]]; then
err "PUERTO INVALIDO"
pause
menu
fi

tmp=$(mktemp)
jq --arg p "$port" '.inbounds |= map(select((.port|tostring)!=$p))' "$CFG" > "$tmp" && mv "$tmp" "$CFG"

grep -v "|$port|" "$REG" > "$REG.tmp" 2>/dev/null
mv "$REG.tmp" "$REG" 2>/dev/null

close_port "$port"
restart_xray

bar
ok "PUERTO $port ELIMINADO Y CERRADO DEL FIREWALL"
bar
pause
menu
}

activar_tls(){
clear
bar
info " ACTIVAR TLS EN PUERTO"
bar
show_ports
bar

echo -ne "Puerto donde activar TLS: "
read -r port

if ! jq -e --arg p "$port" '.inbounds[]? | select((.port|tostring)==$p)' "$CFG" >/dev/null; then
err "PUERTO NO EXISTE"
pause
menu
fi

security=$(inbound_security "$port")
if [[ "$security" == "reality" ]]; then
err "Este puerto usa REALITY. No se debe convertir a TLS desde aquí."
pause
menu
fi

echo -ne "Dominio apuntado a la VPS: "
read -r domain
[[ -z "$domain" ]] && { err "DOMINIO INVALIDO"; pause; menu; }

issue_tls_cert "$port" "$domain" || { restart_xray; pause; menu; }

tmp=$(mktemp)
jq --arg p "$port" --arg d "$domain" --arg cert "/usr/local/etc/xray/cert/$port/cert.crt" --arg key "/usr/local/etc/xray/cert/$port/private.key" '
.inbounds |= map(
if (.port|tostring)==$p then
.streamSettings.security = "tls" |
.streamSettings.tlsSettings = {
  "serverName": $d,
  "alpn": ["h2", "http/1.1"],
  "certificates": [{"certificateFile": $cert, "keyFile": $key}]
}
else . end
)
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"

restart_xray
bar
ok " TLS ACTIVADO CORRECTAMENTE EN PUERTO $port"
ok " DOMINIO: $domain"
bar
pause
menu
}

desactivar_tls(){
clear
bar
info " DESACTIVAR TLS EN PUERTO"
bar
show_ports
bar

echo -ne "Puerto: "
read -r port

security=$(inbound_security "$port")
if [[ "$security" == "reality" ]]; then
err "Este puerto usa REALITY. No se puede desactivar como si fuera TLS."
pause
menu
fi

tmp=$(mktemp)
jq --arg p "$port" '
.inbounds |= map(
if (.port|tostring)==$p then
.streamSettings.security = "none" |
del(.streamSettings.tlsSettings)
else . end
)
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"

restart_xray
bar
ok "TLS DESACTIVADO EN PUERTO $port"
bar
pause
menu
}

crear_usuario(){
clear
bar
info " CREAR USUARIO XRAY"
bar

[[ ! -e "$CFG" ]] && { err "Primero instala Xray"; pause; menu; }

show_ports
bar

while true; do
echo -ne "Puerto: "
read -r port
if [[ -z "$port" || "$port" != +([0-9]) ]]; then
err "PUERTO INVALIDO"
continue
fi
if ! jq -e --arg p "$port" '.inbounds[] | select((.port|tostring)==$p)' "$CFG" >/dev/null; then
err "PUERTO NO EXISTE"
continue
fi
break
done

proto=$(inbound_proto "$port")
network=$(inbound_network "$port")
security=$(inbound_security "$port")
sni=$(inbound_sni "$port")
path=$(inbound_path "$port")
flow=""
mode="$proto-$network-$security"

if [[ "$proto" == "vless" && "$network" == "raw" && ( "$security" == "tls" || "$security" == "reality" ) ]]; then
flow="xtls-rprx-vision"
if [[ "$security" == "tls" ]]; then mode="vless-tcp-xtls-tls"; else mode="vless-tcp-xtls-reality"; fi
elif [[ "$proto" == "vless" && "$network" == "xhttp" && "$security" == "tls" ]]; then
mode="vless-xhttp-tls"
elif [[ "$proto" == "vless" && "$network" == "xhttp" && "$security" == "reality" ]]; then
mode="vless-xhttp-reality"
elif [[ "$proto" == "vless" && ( "$network" == "ws" || "$network" == "websocket" ) ]]; then
mode="vless-ws"
elif [[ "$proto" == "vmess" && "$network" == "raw" && "$security" == "tls" ]]; then
mode="vmess-tcp-tls"
elif [[ "$proto" == "vmess" && "$network" == "xhttp" && "$security" == "tls" ]]; then
mode="vmess-xhttp-tls"
elif [[ "$proto" == "vmess" ]]; then
mode="vmess-ws"
elif [[ "$proto" == "trojan" ]]; then
mode="trojan-ws"
fi

echo -ne "Usuario: "
read -r user
user="$(echo "$user" | sed 's/[^a-zA-Z0-9_-]//g')"
if [[ ${#user} -lt 2 || ${#user} -gt 20 ]]; then
err "USUARIO INVALIDO"
pause
menu
fi

echo -ne "Dias: "
read -r dias
if [[ -z "$dias" || "$dias" != +([0-9]) || "$dias" -lt 1 || "$dias" -gt 365 ]]; then
err "DIAS INVALIDOS"
pause
menu
fi

if [[ "$network" == "ws" || "$network" == "websocket" ]]; then
echo -ne "Host funcional para HTTP Custom / SNI ENTER para automático: "
IFS= read -r hostcustom
[[ -z "$hostcustom" ]] && hostcustom="$sni"
printf "Path EXACTO ENTER para usar el del puerto: "
IFS= read -r pathcustom
if [[ -n "$pathcustom" ]]; then
pathcustom=$(normalize_path "$pathcustom" "$path")
tmp_path=$(mktemp)
jq --arg p "$port" --arg path "$pathcustom" '
.inbounds |= map(if (.port|tostring)==$p then .streamSettings.wsSettings.path=$path else . end)
' "$CFG" > "$tmp_path" && mv "$tmp_path" "$CFG"
path="$pathcustom"
fi
elif [[ "$network" == "xhttp" ]]; then
echo -ne "SNI/Host para link ENTER para usar [$sni]: "
IFS= read -r hostcustom
[[ -z "$hostcustom" ]] && hostcustom="$sni"
printf "Path xHTTP ENTER para usar el del puerto: "
IFS= read -r pathcustom
if [[ -n "$pathcustom" ]]; then
pathcustom=$(normalize_path "$pathcustom" "$path")
tmp_path=$(mktemp)
jq --arg p "$port" --arg path "$pathcustom" '
.inbounds |= map(if (.port|tostring)==$p then .streamSettings.xhttpSettings.path=$path else . end)
' "$CFG" > "$tmp_path" && mv "$tmp_path" "$CFG"
path="$pathcustom"
fi
else
echo -ne "SNI/Host para link ENTER para usar [$sni]: "
IFS= read -r hostcustom
[[ -z "$hostcustom" ]] && hostcustom="$sni"
fi

if [[ "$proto" == "trojan" ]]; then
echo -ne "Password personalizado ENTER para automático: "
IFS= read -r credcustom
if [[ -z "$credcustom" ]]; then cred=$(openssl rand -hex 12); else cred="$credcustom"; fi
else
echo -ne "UUID personalizado ENTER para automático: "
IFS= read -r credcustom
if [[ -z "$credcustom" ]]; then cred=$(uuidgen); else cred="$credcustom"; fi
if ! [[ "$cred" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
err "UUID INVALIDO. Usa formato UUID correcto o deja vacío para automático."
pause
menu
fi
fi

expire=$(date '+%F' -d "+$dias days")
email="$user@golden"
tmp=$(mktemp)

case "$proto" in
vmess)
jq --arg p "$port" --arg id "$cred" --arg email "$email" '
.inbounds |= map(if (.port|tostring)==$p then .settings.clients += [{"id":$id,"alterId":0,"security":"auto","level":0,"email":$email}] else . end)
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
vless)
jq --arg p "$port" --arg id "$cred" --arg email "$email" --arg flow "$flow" '
.inbounds |= map(if (.port|tostring)==$p then .settings.clients += [({"id":$id,"level":0,"email":$email} + (if $flow != "" then {"flow":$flow} else {} end))] else . end)
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
trojan)
jq --arg p "$port" --arg pass "$cred" --arg email "$email" '
.inbounds |= map(if (.port|tostring)==$p then .settings.clients += [{"password":$pass,"level":0,"email":$email}] else . end)
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
*)
err "PROTOCOLO NO SOPORTADO PARA USUARIOS: $proto"
rm -f "$tmp"
pause
menu
;;
esac

public_key=""
short_id=""
spiderx="/"
if [[ "$security" == "reality" ]]; then
private_key=$(jq -r --arg p "$port" '.inbounds[] | select((.port|tostring)==$p) | .streamSettings.realitySettings.privateKey // ""' "$CFG")
short_id=$(jq -r --arg p "$port" '.inbounds[] | select((.port|tostring)==$p) | .streamSettings.realitySettings.shortIds[0] // ""' "$CFG")
if [[ -n "$private_key" ]]; then
public_key=$($BIN x25519 -i "$private_key" 2>/dev/null | awk -F': ' 'tolower($1) ~ /public|password/ {print $2; exit}')
fi
fi

echo "$cred|$user|$expire|$port|$hostcustom|$mode|$network|$security|$flow|$path|$sni|$public_key|$short_id|$spiderx" >> "$REG"

restart_xray
bar
ok " USUARIO CREADO"
echo "Usuario: $user"
echo "Modo: $(mode_label "$mode")"
if [[ "$proto" == "trojan" ]]; then echo "Password: $cred"; else echo "UUID: $cred"; fi
echo "Puerto: $port"
echo "Expira: $expire"
[[ -n "$hostcustom" ]] && echo "Host/SNI: $hostcustom"
[[ "$path" != "-" ]] && echo "Path: $path"
bar
generar_link "$cred" "$user" "$port" "$hostcustom" "$mode" "$network" "$security" "$flow" "$path" "$sni" "$public_key" "$short_id" "$spiderx"
bar
pause
menu
}

generar_link(){
local cred="$1"
local user="$2"
local port="$3"
local hostcustom="$4"
local mode="$5"
local network="$6"
local security="$7"
local flow="$8"
local path="$9"
local sni="${10}"
local public_key="${11}"
local short_id="${12}"
local spiderx="${13:-/}"

local ip encpath encuser enchost encsni enccred encspx link_network link_security tlsfield hostfield
ip=$(vps_ip)
[[ -z "$path" || "$path" == "null" ]] && path=$(inbound_path "$port")
[[ -z "$network" || "$network" == "null" ]] && network=$(inbound_network "$port")
[[ -z "$security" || "$security" == "null" ]] && security=$(inbound_security "$port")
[[ -z "$sni" || "$sni" == "null" ]] && sni=$(inbound_sni "$port")
[[ -z "$hostcustom" || "$hostcustom" == "null" ]] && hostcustom="$sni"

encpath=$(urlencode "$path")
encuser=$(urlencode "$user")
enchost=$(urlencode "$hostcustom")
encsni=$(urlencode "$sni")
encspx=$(urlencode "$spiderx")

case "$mode" in
vmess-ws)
tlsfield="$security"
[[ "$tlsfield" == "none" ]] && tlsfield=""
json=$(jq -n \
--arg v "2" --arg ps "$user" --arg add "$ip" --arg port "$port" --arg id "$cred" \
--arg aid "0" --arg scy "auto" --arg net "ws" --arg type "none" --arg host "$hostcustom" \
--arg path "$path" --arg tls "$tlsfield" \
'{"v":$v,"ps":$ps,"add":$add,"port":$port,"id":$id,"aid":$aid,"scy":$scy,"net":$net,"type":$type,"host":$host,"path":$path,"tls":$tls}')
echo "vmess://$(printf '%s' "$json" | base64 -w0)"
;;
vmess-tcp-tls)
tlsfield="tls"
json=$(jq -n --arg v "2" --arg ps "$user" --arg add "$ip" --arg port "$port" --arg id "$cred" --arg aid "0" --arg scy "auto" --arg net "tcp" --arg type "none" --arg host "$hostcustom" --arg path "" --arg tls "$tlsfield" --arg sni "$sni" --arg fp "chrome" '{"v":$v,"ps":$ps,"add":$add,"port":$port,"id":$id,"aid":$aid,"scy":$scy,"net":$net,"type":$type,"host":$host,"path":$path,"tls":$tls,"sni":$sni,"fp":$fp}')
echo "vmess://$(printf '%s' "$json" | base64 -w0)"
;;
vmess-xhttp-tls)
tlsfield="tls"
json=$(jq -n --arg v "2" --arg ps "$user" --arg add "$ip" --arg port "$port" --arg id "$cred" --arg aid "0" --arg scy "auto" --arg net "xhttp" --arg type "auto" --arg host "$hostcustom" --arg path "$path" --arg tls "$tlsfield" --arg sni "$sni" --arg fp "chrome" --arg alpn "h2" '{"v":$v,"ps":$ps,"add":$add,"port":$port,"id":$id,"aid":$aid,"scy":$scy,"net":$net,"type":$type,"host":$host,"path":$path,"tls":$tls,"sni":$sni,"fp":$fp,"alpn":$alpn}')
echo "vmess://$(printf '%s' "$json" | base64 -w0)"
;;
trojan-ws)
enccred=$(urlencode "$cred")
link_security="none"
[[ "$security" == "tls" ]] && link_security="tls"
echo "trojan://${enccred}@${ip}:${port}?type=ws&security=${link_security}&path=${encpath}&host=${enchost}&sni=${encsni}#${encuser}"
;;
vless-ws)
link_security="none"
[[ "$security" == "tls" ]] && link_security="tls"
echo "vless://${cred}@${ip}:${port}?type=ws&security=${link_security}&path=${encpath}&host=${enchost}&sni=${encsni}#${encuser}"
;;
vless-tcp-xtls-tls)
echo "vless://${cred}@${ip}:${port}?type=tcp&security=tls&sni=${encsni}&fp=chrome&flow=xtls-rprx-vision#${encuser}"
;;
vless-tcp-xtls-reality)
[[ -z "$public_key" ]] && public_key="PUBLIC_KEY_NO_ENCONTRADA"
[[ -z "$short_id" ]] && short_id=""
echo "vless://${cred}@${ip}:${port}?type=tcp&security=reality&sni=${encsni}&fp=chrome&pbk=${public_key}&sid=${short_id}&spx=${encspx}&flow=xtls-rprx-vision#${encuser}"
;;
vless-xhttp-tls)
echo "vless://${cred}@${ip}:${port}?type=xhttp&security=tls&sni=${encsni}&fp=chrome&path=${encpath}&mode=auto&alpn=h2#${encuser}"
;;
vless-xhttp-reality)
[[ -z "$public_key" ]] && public_key="PUBLIC_KEY_NO_ENCONTRADA"
[[ -z "$short_id" ]] && short_id=""
echo "vless://${cred}@${ip}:${port}?type=xhttp&security=reality&sni=${encsni}&fp=chrome&pbk=${public_key}&sid=${short_id}&spx=${encspx}&path=${encpath}&mode=auto#${encuser}"
;;
*)
# Compatibilidad con registros antiguos
proto=$(inbound_proto "$port")
if [[ "$proto" == "trojan" ]]; then
mode="trojan-ws"
elif [[ "$proto" == "vless" ]]; then
mode="vless-ws"
elif [[ "$proto" == "vmess" && "$network" == "raw" && "$security" == "tls" ]]; then
mode="vmess-tcp-tls"
elif [[ "$proto" == "vmess" && "$network" == "xhttp" && "$security" == "tls" ]]; then
mode="vmess-xhttp-tls"
else
mode="vmess-ws"
fi
generar_link "$cred" "$user" "$port" "$hostcustom" "$mode" "$network" "$security" "$flow" "$path" "$sni" "$public_key" "$short_id" "$spiderx"
;;
esac
}

mostrar_usuarios(){
clear
bar
info " USUARIOS REGISTRADOS"
bar

[[ ! -e "$REG" ]] && touch "$REG"

if [[ ! -s "$REG" ]]; then
err "NO HAY USUARIOS"
bar
pause
menu
fi

while IFS='|' read -r cred user expire port hostcustom mode network security flow path sni public_key short_id spiderx; do
[[ -z "$cred" ]] && continue
[[ -z "$mode" ]] && mode="vmess-ws"
[[ -z "$network" ]] && network=$(inbound_network "$port")
[[ -z "$security" ]] && security=$(inbound_security "$port")
[[ -z "$path" ]] && path=$(inbound_path "$port")
[[ -z "$sni" ]] && sni=$(inbound_sni "$port")

echo -e "${VERDE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${VERDE}USUARIO :${RESET} $user"
echo -e "${VERDE}MODO    :${RESET} $(mode_label "$mode")"
if [[ "$mode" == trojan* ]]; then echo -e "${VERDE}PASS    :${RESET} $cred"; else echo -e "${VERDE}UUID    :${RESET} $cred"; fi
echo -e "${VERDE}PUERTO  :${RESET} $port"
echo -e "${VERDE}EXPIRA  :${RESET} $expire"
[[ -n "$hostcustom" ]] && echo -e "${VERDE}HOST    :${RESET} $hostcustom"
[[ -n "$sni" ]] && echo -e "${VERDE}SNI     :${RESET} $sni"
[[ "$path" != "-" ]] && echo -e "${VERDE}PATH    :${RESET} $path"
[[ -n "$public_key" ]] && echo -e "${VERDE}PBK     :${RESET} $public_key"
[[ -n "$short_id" ]] && echo -e "${VERDE}SID     :${RESET} $short_id"
echo ""
generar_link "$cred" "$user" "$port" "$hostcustom" "$mode" "$network" "$security" "$flow" "$path" "$sni" "$public_key" "$short_id" "$spiderx"
echo ""
done < "$REG"

echo -e "${VERDE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
pause
menu
}

eliminar_usuario(){
clear
bar
info " ELIMINAR USUARIO"
bar

[[ ! -e "$REG" ]] && touch "$REG"

if [[ ! -s "$REG" ]]; then
err "NO HAY USUARIOS"
bar
pause
menu
fi

awk -F'|' '
NF && $1 != "" {
  mode=$6
  if(mode=="") mode="vmess-ws"
  printf "%d) %s | %s | Modo:%s | Puerto:%s | Expira:%s\n", ++i, $2, $1, mode, $4, $3
}
' "$REG"
bar

echo -ne "Numero de usuario a eliminar o UUID/PASSWORD: "
read -r seleccion

if [[ -z "$seleccion" ]]; then
err "SELECCION INVALIDA"
pause
menu
fi

line=""

# Permite eliminar por numero, segun la lista mostrada: 1, 2, 3...
if [[ "$seleccion" == +([0-9]) ]]; then
line=$(awk -F'|' -v n="$seleccion" 'NF && $1 != "" { if(++i==n){ print; exit } }' "$REG")
else
# Compatibilidad: tambien permite eliminar pegando UUID o password.
line=$(grep -F "$seleccion" "$REG" | head -1)
fi

cred=$(echo "$line" | cut -d'|' -f1)
user=$(echo "$line" | cut -d'|' -f2)
port=$(echo "$line" | cut -d'|' -f4)
mode=$(echo "$line" | cut -d'|' -f6)
proto=$(inbound_proto "$port")

if [[ -z "$cred" || -z "$port" ]]; then
err "USUARIO NO ENCONTRADO"
pause
menu
fi

bar
info "ELIMINANDO: $user | Puerto: $port | Modo: ${mode:-vmess-ws}"
bar

tmp=$(mktemp)
case "$proto" in
trojan)
jq --arg p "$port" --arg pass "$cred" '
.inbounds |= map(if (.port|tostring)==$p then .settings.clients |= map(select(.password != $pass)) else . end)
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
*)
jq --arg p "$port" --arg id "$cred" '
.inbounds |= map(if (.port|tostring)==$p then .settings.clients |= map(select(.id != $id)) else . end)
' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
esac

# Quita del registro solo la cuenta seleccionada.
awk -F'|' -v c="$cred" 'BEGIN{OFS=FS} !($1==c)' "$REG" > "$REG.tmp"
mv "$REG.tmp" "$REG"

restart_xray
bar
ok " USUARIO ELIMINADO"
bar
pause
menu
}

limpiar_expirados(){
clear
bar
info " LIMPIAR EXPIRADOS"
bar

[[ ! -e "$REG" ]] && touch "$REG"
now=$(date +%s)
tmpreg=$(mktemp)

while IFS='|' read -r cred user expire port hostcustom mode network security flow path sni public_key short_id spiderx; do
[[ -z "$cred" ]] && continue
expsec=$(date +%s -d "$expire" 2>/dev/null)
if [[ -n "$expsec" && "$now" -gt "$expsec" ]]; then
proto=$(inbound_proto "$port")
tmp=$(mktemp)
case "$proto" in
trojan)
jq --arg p "$port" --arg pass "$cred" '.inbounds |= map(if (.port|tostring)==$p then .settings.clients |= map(select(.password != $pass)) else . end)' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
*)
jq --arg p "$port" --arg id "$cred" '.inbounds |= map(if (.port|tostring)==$p then .settings.clients |= map(select(.id != $id)) else . end)' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
;;
esac
echo "Eliminado: $user"
else
echo "$cred|$user|$expire|$port|$hostcustom|$mode|$network|$security|$flow|$path|$sni|$public_key|$short_id|$spiderx" >> "$tmpreg"
fi
done < "$REG"

mv "$tmpreg" "$REG"
restart_xray
bar
ok " LIMPIEZA COMPLETADA"
bar
pause
menu
}

estado_panel(){
clear
bar
info " ESTADO GENERAL"
bar

if [[ -x "$BIN" ]]; then
ok "XRAY INSTALADO"
$BIN version | head -1
else
err "XRAY NO INSTALADO"
fi

if systemctl is-active --quiet xray; then
ok "SERVICIO ACTIVO"
else
err "SERVICIO INACTIVO"
fi

bar
info "PUERTOS CONFIGURADOS"
show_ports
bar
info "PUERTOS ESCUCHANDO"
ss -lntp | grep xray || err "NO HAY PUERTOS ESCUCHANDO"
bar
pause
menu
}

test_config(){
clear
bar
info " TEST CONFIG XRAY"
bar
if [[ -x "$BIN" && -e "$CFG" ]]; then
test_xray_config
cat /tmp/xray-test.log 2>/dev/null
else
err "Xray no instalado o config no existe"
fi
bar
pause
menu
}

reparar_servicio(){
clear
bar
info " REPARANDO SERVICIO XRAY"
bar
fix_service
fix_time
fix_performance
for p in $(jq -r '.inbounds[]?.port' "$CFG" 2>/dev/null); do
open_port "$p"
done
restart_xray
systemctl status xray --no-pager -l
bar
ss -lntp | grep xray || err "NO ESTA ESCUCHANDO"
bar
pause
menu
}

unistallxray_completo(){
clear
bar
info " DESINSTALANDO XRAY COMPLETAMENTE"
bar
PORTS="$(jq -r '.inbounds[]?.port' "$CFG" 2>/dev/null)"
read -p " Confirmar desinstalación completa [s/n]: " resp
[[ "$resp" != "s" ]] && menu

systemctl stop xray >/dev/null 2>&1
sleep 1
systemctl disable xray >/dev/null 2>&1
pkill -9 -x xray >/dev/null 2>&1

for p in $PORTS 80 443; do
close_port "$p"
done

rm -f /etc/systemd/system/xray.service
rm -rf /etc/systemd/system/xray.service.d
systemctl daemon-reload >/dev/null 2>&1

rm -f /usr/local/bin/xray
rm -f /usr/bin/xray
rm -rf /etc/xray
rm -rf /usr/local/etc/xray
rm -rf /usr/local/share/xray
rm -rf /var/log/xray
rm -rf ~/.acme.sh
rm -rf /etc/newadm/xray
rm -f /etc/newadm/RegXray
screen -wipe >/dev/null 2>&1
iptables-save > /etc/iptables/rules.v4 2>/dev/null
apt autoremove -y >/dev/null 2>&1
bar
ok " XRAY ELIMINADO COMPLETAMENTE"
ok " PUERTOS DEL PANEL CERRADOS DEL FIREWALL"
bar
pause
menu
}

menu(){
clear
bar
echo -e "${AZUL} PANEL XRAY PROFESIONAL ${ROJO}[ GOLDEN MX / XTLS + xHTTP ]${RESET}"
bar

if [[ -x "$BIN" ]]; then ok "XRAY: INSTALADO"; else err "XRAY: NO INSTALADO"; fi
if systemctl is-active --quiet xray; then ok "SERVICIO: ACTIVO"; else err "SERVICIO: INACTIVO"; fi
bar
info "PUERTOS CONFIGURADOS"
show_ports
bar
echo -e "${VERDE}[1]${RESET} INSTALAR XRAY-CORE"
echo -e "${VERDE}[2]${RESET} AGREGAR PUERTO / PROTOCOLO"
echo -e "${VERDE}[3]${RESET} ELIMINAR PUERTO"
echo -e "${VERDE}[4]${RESET} ACTIVAR TLS EN PUERTO"
echo -e "${VERDE}[5]${RESET} DESACTIVAR TLS EN PUERTO"
bar
echo -e "${VERDE}[6]${RESET} CREAR USUARIO"
echo -e "${VERDE}[7]${RESET} ELIMINAR USUARIO"
echo -e "${VERDE}[8]${RESET} MOSTRAR USUARIOS + LINKS"
echo -e "${VERDE}[9]${RESET} LIMPIAR EXPIRADOS"
bar
echo -e "${VERDE}[10]${RESET} ESTADO GENERAL"
echo -e "${VERDE}[11]${RESET} TEST CONFIG"
echo -e "${VERDE}[12]${RESET} REPARAR SERVICIO"
echo -e "${VERDE}[13]${RESET} DESINSTALAR COMPLETO"
echo -e "${VERDE}[0]${RESET} SALIR"
bar

echo -ne "Seleccione: "
read -r op
case "$op" in
1) install_xray ;;
2) agregar_puerto ;;
3) eliminar_puerto ;;
4) activar_tls ;;
5) desactivar_tls ;;
6) crear_usuario ;;
7) eliminar_usuario ;;
8) mostrar_usuarios ;;
9) limpiar_expirados ;;
10) estado_panel ;;
11) test_config ;;
12) reparar_servicio ;;
13) unistallxray_completo ;;
0) exit ;;
*) menu ;;
esac
}

menu
