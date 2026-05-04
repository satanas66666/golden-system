apt-get remove cracklib-runtime libcrack2 -y
apt-get remove libpam-cracklib -y
apt-get install tmux -y
apt-get install sudo -y
apt-get install jq -y 
apt-get install net-tools -y
apt-get install curl -y
apt-get install screen -y
apt-get install nload -y
apt-get install make -y
clear
clear
if [ `whoami` != 'root' ]
   then
     echo -e "Debes ser Usuario root para ejecutar el Instalador"
     exit
fi
msg () {
BRAN='\033[1;37m' && VERMELHO='\e[31m' && VERDE='\e[32m' && AMARELO='\e[33m'
AZUL='\e[33m' && MAGENTA='\e[35m' && MAG='\033[1;36m' &&NEGRITO='\e[1m' && SEMCOR='\e[0m'
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
declare -A cor=( [0]="\033[1;37m" [1]="\033[1;34m" [2]="\033[1;32m" [3]="\033[1;36m" [4]="\033[1;31m" [5]="\033[1;33m" )
barra="\033[0m\e[33m=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=\033[1;37m"
fun_bar () {
comando[0]="$1"
comando[1]="$2"
 (
[[ -e $HOME/fim ]] && rm $HOME/fim
${comando[0]} -y > /dev/null 2>&1
${comando[1]} -y > /dev/null 2>&1
touch $HOME/fim
 ) > /dev/null 2>&1 &
echo -ne "\033[1;33m ["
while true; do
   for((i=0; i<18; i++)); do
   echo -ne "\033[1;31m##"
   sleep 0.1s
   done
   [[ -e $HOME/fim ]] && rm $HOME/fim && break
   echo -e "\033[1;33m]"
   sleep 1s
   tput cuu1
   tput dl1
   echo -ne "\033[1;33m ["
done
echo -e "\033[1;33m]\033[1;31m -\033[1;32m 100%\033[1;37m"
}

echo -e "$barra"
msg -ama "[ INSTALADOR OFICIAL ] [ NEW - GOLDEN ADM PRO ]"
echo -e "$barra"
msg -ama "               PREPARANDO INSTALACION"
echo -e "$barra"

##PAKETES
echo ""
echo -e "\033[97m    ◆ INTENTANDO DETENER UPDATER SECUNDARIO"
fun_bar "killall apt apt-get"
echo -e "\033[97m    ◆ INTENTANDO RECONFIGURAR UPDATER"
fun_bar "dpkg --configure -a"
echo -e "\033[97m    ◆ INSTALANDO S-P-C "
fun_bar "apt-get install software-properties-common -y"
echo -e "\033[97m    ◆ INSTALANDO LIBRERIA UNIVERSAL "
fun_bar " sudo apt-add-repository universe -y"
echo -e "\033[97m    ◆  INSTALANDO BUILD-ESSENTIAL"
fun_bar "sudo apt-get install build-essential -y"
echo -e "\033[97m    ◆  INSTALANDO PHYTON"
fun_bar "apt-get install python3 -y"
echo -e "\033[97m    ◆  INSTALANDO LOLCAT"
fun_bar "apt-get install lolcat -y"
echo -e "\033[97m    ◆ INSTALANDO GCC"
fun_bar " sudo apt-get install gcc -y"
echo -e "\033[97m    ◆ INSTALANDO CMAKE"
fun_bar " sudo apt-get install cmake -y"
echo -e "\033[97m    ◆ INSTALANDO NET-TOOLS"
fun_bar "apt-get install net-tools -y"
service ssh restart > /dev/null 2>&1
echo -e "\033[97m    ◆ DESACTIVANDO PASS ALFANUMERICO"
sed -i 's/.*pam_cracklib.so.*/password sufficient pam_unix.so sha512 shadow nullok try_first_pass #use_authtok/' /etc/pam.d/common-password > /dev/null 2>&1
fun_bar "service ssh restart > /dev/null 2>&1 "
echo -e "$barra"
#echo -e "\033[93m              AGREGAR/EDITAR PASS ROOT\033[97m"
#echo -e "$barra"
#echo -e "\033[1;96m DIGITE NUEVA CONTRASEÑA:\033[0;37m"; read -p " " pass
#(echo $pass; echo $pass)|passwd root 2>/dev/null
#sleep 1s
#echo -e "$barra"
#echo -e "\033[97m      CONTRASEÑA AGREGADA O EDITADA CORECTAMENTE"
#echo -e "\033[97m SU CONTRASEÑA AHORA ES: \e[41m $pass \033[0;37m"
cd
wget https://www.dropbox.com/s/lxsj8bi07p91gz5/LuciferMX2019.sh &> /dev/null
chmod +x LuciferMX2019.sh*
read -t 20 -n 1 -rsp $'\033[1;39m           Preciona Enter Para continuar\n'
echo -e "$barra"
## Restore working directory
rm -rf diablo2020.sh
cd
clear
./LuciferMX2019.sh*
exit