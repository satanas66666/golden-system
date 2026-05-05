#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Evitar errores por locks
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock &>/dev/null
dpkg --configure -a &>/dev/null

apt-get update -y
apt-get remove cracklib-runtime libcrack2 -y &>/dev/null
apt-get remove libpam-cracklib -y &>/dev/null

apt-get install -y tmux sudo jq net-tools curl screen nload make &>/dev/null

clear
clear

if [ "$(whoami)" != 'root' ]; then
  echo -e "Debes ser Usuario root para ejecutar el Instalador"
  exit 1
fi

msg () {
BRAN='\033[1;37m' && VERMELHO='\e[31m' && VERDE='\e[32m' && AMARELO='\e[33m'
AZUL='\e[33m' && MAGENTA='\e[35m' && MAG='\033[1;36m' && NEGRITO='\e[1m' && SEMCOR='\e[0m'
 case $1 in
  -ne)cor="${VERMELHO}${NEGRITO}" && echo -ne "${cor}${2}${SEMCOR}";;
  -ama)cor="${AMARELO}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}";;
  -verm)cor="${AMARELO}${NEGRITO}[!] ${VERMELHO}" && echo -e "${cor}${2}${SEMCOR}";;
  -azu)cor="${MAG}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}";;
  -verd)cor="${VERDE}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}";;
  -bra)cor="${BRAN}${NEGRITO}" && echo -ne "${cor}${2}${SEMCOR}";;
 "-bar2"|"-bar")cor="${AZUL}=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=" && echo -e "${cor}${SEMCOR}";;
 esac
}

barra="\033[0m\e[33m=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=\033[1;37m"

fun_bar () {
comando="$1"
(
  rm -f $HOME/fim
  bash -c "$comando" > /dev/null 2>&1
  touch $HOME/fim
) &

echo -ne "\033[1;33m ["
while true; do
   for((i=0; i<18; i++)); do
      echo -ne "\033[1;31m##"
      sleep 0.1
   done
   [[ -e $HOME/fim ]] && rm $HOME/fim && break
   echo -e "\033[1;33m]"
   sleep 1
   tput cuu1 2>/dev/null
   tput dl1 2>/dev/null
   echo -ne "\033[1;33m ["
done

echo -e "\033[1;33m]\033[1;31m -\033[1;32m 100%\033[1;37m"
}

echo -e "$barra"
msg -ama "[ INSTALADOR OFICIAL ] [ NEW - GOLDEN ADM PRO ]"
echo -e "$barra"
msg -ama "               PREPARANDO INSTALACION"
echo -e "$barra"

echo ""
echo -e "\033[97m    ◆ INTENTANDO DETENER BLOQUEOS DE APT"
fun_bar "rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock"

echo -e "\033[97m    ◆ RECONFIGURANDO DPKG"
fun_bar "dpkg --configure -a"

echo -e "\033[97m    ◆ ACTUALIZANDO REPOSITORIOS"
fun_bar "apt-get update -y"

echo -e "\033[97m    ◆ INSTALANDO S-P-C"
fun_bar "apt-get install -y software-properties-common"

echo -e "\033[97m    ◆ HABILITANDO REPOSITORIO UNIVERSE"
fun_bar "add-apt-repository -y universe"

echo -e "\033[97m    ◆ INSTALANDO BUILD-ESSENTIAL"
fun_bar "apt-get install -y build-essential"

echo -e "\033[97m    ◆ INSTALANDO PYTHON"
fun_bar "apt-get install -y python3 python-is-python3"

echo -e "\033[97m    ◆ INSTALANDO LOLCAT"
fun_bar "apt-get install -y lolcat"

echo -e "\033[97m    ◆ INSTALANDO GCC"
fun_bar "apt-get install -y gcc"

echo -e "\033[97m    ◆ INSTALANDO CMAKE"
fun_bar "apt-get install -y cmake"

echo -e "\033[97m    ◆ INSTALANDO NET-TOOLS"
fun_bar "apt-get install -y net-tools"

service ssh restart > /dev/null 2>&1

echo -e "\033[97m    ◆ DESACTIVANDO PASS ALFANUMERICO"
sed -i 's/.*pam_cracklib.so.*/password sufficient pam_unix.so sha512 shadow nullok try_first_pass/' /etc/pam.d/common-password

fun_bar "service ssh restart"

echo -e "$barra"

cd
wget -q https://raw.githubusercontent.com/satanas66666/golden-system/main/LuciferMX2019.sh -O LuciferMX2019.sh
chmod +x LuciferMX2019.sh

read -t 10 -n 1 -rsp $'\033[1;39m           Presiona Enter Para continuar\n'

echo -e "$barra"

rm -rf diablo2020.sh
cd
clear

./LuciferMX2019.sh

exit