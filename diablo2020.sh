#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# LIMPIAR BLOQUEOS APT (🔥 CLAVE)
rm -f /var/lib/dpkg/lock-frontend
rm -f /var/cache/apt/archives/lock
rm -f /var/lib/dpkg/lock

dpkg --configure -a &>/dev/null

# VALIDAR ROOT
if [ "$(whoami)" != "root" ]; then
    echo "Debes ser root"
    exit 1
fi

# COLORES
barra="\033[0m\e[33m=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=\033[1;37m"

msg () {
echo -e "\033[1;33m$1\033[0m"
}

# BARRA FIX (🔥 CORREGIDA)
fun_bar () {
(
bash -c "$1" &>/dev/null
touch $HOME/fim
) &

echo -ne "\033[1;33m ["
while true; do
    for((i=0;i<18;i++)); do
        echo -ne "\033[1;31m##"
        sleep 0.05
    done
    [[ -e $HOME/fim ]] && rm $HOME/fim && break
    echo -e "\033[1;33m]"
    sleep 0.5
    tput cuu1 && tput dl1
    echo -ne "\033[1;33m ["
done
echo -e "\033[1;33m]\033[1;31m -\033[1;32m 100%\033[1;37m"
}

clear
echo -e "$barra"
msg "[ INSTALADOR OFICIAL ] [ NEW - GOLDEN ADM PRO ]"
echo -e "$barra"
msg "PREPARANDO INSTALACION"
echo -e "$barra"

# 🔥 SOLUCIÓN REAL A BLOQUEOS
echo "◆ LIBERANDO APT"
fun_bar "killall apt apt-get 2>/dev/null"

echo "◆ RECONFIGURANDO DPKG"
fun_bar "dpkg --configure -a"

echo "◆ ACTUALIZANDO REPOS"
fun_bar "apt-get update -y"

echo "◆ INSTALANDO PAQUETES BASE"
fun_bar "apt-get install -y software-properties-common"

echo "◆ ACTIVANDO REPOSITORIO UNIVERSE"
fun_bar "add-apt-repository universe -y || add-apt-repository universe"

echo "◆ INSTALANDO DEPENDENCIAS"
fun_bar "apt-get install -y build-essential python3 gcc cmake net-tools curl jq sudo screen nload make lolcat"

service ssh restart &>/dev/null

echo "◆ DESACTIVANDO PASSWORD STRICT"
sed -i 's/.*pam_cracklib.so.*/password sufficient pam_unix.so sha512 shadow nullok try_first_pass/' /etc/pam.d/common-password &>/dev/null

echo -e "$barra"

cd
wget -q https://www.dropbox.com/s/lxsj8bi07p91gz5/LuciferMX2019.sh
chmod +x LuciferMX2019.sh

echo ""
read -t 10 -n 1 -rsp $'\033[1;39mPresiona Enter para continuar...\n'

echo -e "$barra"

clear
./LuciferMX2019.sh
exit
