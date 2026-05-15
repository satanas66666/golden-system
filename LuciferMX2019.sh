cd $HOME

SCPdir="/etc/newadm"
SCPdir2="${SCPdir}/v2ray"
SCPinstal="$HOME/install"
SCPidioma="${SCPdir}/idioma"
SCPusr="${SCPdir}/ger-user"
SCPfrm3="/etc/adm-lite"
SCPfrm="/etc/ger-frm"
SCPinst="/etc/ger-inst"

declare -A cor=(
[0]="\033[1;37m"
[1]="\033[1;34m"
[2]="\033[1;32m"
[3]="\033[1;36m"
[4]="\033[1;31m"
[5]="\033[1;33m"
)

barra="\033[0m\e[33m=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=×=\033[1;37m"

mkdir -p /etc/B-ADMuser &>/dev/null

rm -rf /etc/localtime &>/dev/null
ln -s /usr/share/zoneinfo/America/Mexico_City /etc/localtime &>/dev/null

fun_bar () {
comando="$1"
(
[[ -e $HOME/fim ]] && rm $HOME/fim
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

[[ $(dpkg -l | grep -w gawk) ]] || apt-get install gawk -y &>/dev/null
[[ $(dpkg -l | grep -w mlocate) ]] || apt-get install mlocate -y &>/dev/null

rm $(pwd)/$0 &> /dev/null

msg () {
BRAN='\033[1;37m'
VERMELHO='\e[31m'
VERDE='\e[32m'
AMARELO='\e[33m'
AZUL='\e[33m'
MAGENTA='\e[35m'
MAG='\033[1;36m'
NEGRITO='\e[1m'
SEMCOR='\e[0m'

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

instalar_logo_login() {

cat >/etc/profile.d/newgolden-login.sh <<'EOF'
#!/bin/bash
[[ $- != *i* ]] && return 0

clear

cyan='\033[1;36m'
green='\033[1;32m'
yellow='\033[1;33m'
red='\033[1;31m'
white='\033[1;37m'
reset='\033[0m'

echo -e "${cyan}────────────────────────────────────────────────────────────${reset}"
echo
echo -e "   ${green} ██████╗  ██████╗ ██╗     ██████╗ ███████╗███╗   ██╗ ${reset}${red}███╗   ███╗██╗  ██╗${reset}"
echo -e "   ${green}██╔════╝ ██╔═══██╗██║     ██╔══██╗██╔════╝████╗  ██║ ${reset}${red}████╗ ████║╚██╗██╔╝${reset}"
echo -e "   ${yellow}██║  ███╗██║   ██║██║     ██║  ██║█████╗  ██╔██╗ ██║ ${reset}${red}██╔████╔██║ ╚███╔╝ ${reset}"
echo -e "   ${yellow}██║   ██║██║   ██║██║     ██║  ██║██╔══╝  ██║╚██╗██║ ${reset}${red}██║╚██╔╝██║ ██╔██╗ ${reset}"
echo -e "   ${red}╚██████╔╝╚██████╔╝███████╗██████╔╝███████╗██║ ╚████║ ${reset}${red}██║ ╚═╝ ██║██╔╝ ██╗${reset}"
echo -e "   ${red} ╚═════╝  ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═══╝ ${reset}${red}╚═╝     ╚═╝╚═╝  ╚═╝${reset}"
echo
echo -e "${cyan}────────────────────────────────────────────────────────────${reset}"
echo
echo -e "             ${white}Para ingresar al panel escriba:${reset}"
echo
echo -e "                         ${green}menu${reset}"
echo
echo -e "${cyan}────────────────────────────────────────────────────────────${reset}"
echo
EOF

chmod +x /etc/profile.d/newgolden-login.sh

cat >/etc/motd <<'EOF'
GOLDEN MX
Para ingresar al panel escriba: menu
EOF

}

clear
clear

echo -e "$barra"
msg -ama "\033[1;37mINSTALANDO COMPLEMENTOS FINALES POR FAVOR ESPERE....."
echo -e "$barra"
echo ""

fun_bar "apt-get install net-tools -y"
fun_bar "ufw disable"
fun_bar "apt-get --fix-broken install -y"
fun_bar "apt-get install lsof -y"
fun_bar "apt-get install figlet -y"
fun_bar "apt-get install bc -y"
fun_bar "apt-get install python3 -y"
fun_bar "apt-get install python3-pip -y"
fun_bar "apt-get install php -y"
fun_bar "apt-get update -y"
fun_bar "apt-get install nodejs -y"
fun_bar "apt-get install zip -y"
fun_bar "apt-get install unzip -y"

echo -e "$barra"

msg -ama "\033[1;37mCOMPLEMENTOS INSTALADOS CON EXITO"

fun_ip () {
MIP=$(hostname -I | awk '{print $1}')
MIP2=$(wget -qO- ipv4.icanhazip.com)

[[ "$MIP" != "$MIP2" ]] && IP="$MIP2" || IP="$MIP"
}

inst_components () {

[[ $(dpkg -l | grep -w nano) ]] || apt-get install nano -y &>/dev/null
[[ $(dpkg -l | grep -w bc) ]] || apt-get install bc -y &>/dev/null
[[ $(dpkg -l | grep -w screen) ]] || apt-get install screen -y &>/dev/null
[[ $(dpkg -l | grep -w python3) ]] || apt-get install python3 -y &>/dev/null

apt-get install python3-pip -y &>/dev/null

[[ $(dpkg -l | grep -w curl) ]] || apt-get install curl -y &>/dev/null
[[ $(dpkg -l | grep -w ufw) ]] || apt-get install ufw -y &>/dev/null
[[ $(dpkg -l | grep -w unzip) ]] || apt-get install unzip -y &>/dev/null
[[ $(dpkg -l | grep -w zip) ]] || apt-get install zip -y &>/dev/null
[[ $(dpkg -l | grep -w lsof) ]] || apt-get install lsof -y &>/dev/null

apt-get install apache2 -y &>/dev/null

sed -i "s;Listen 80;Listen 81;g" /etc/apache2/ports.conf > /dev/null 2>&1

systemctl restart apache2 2>/dev/null || service apache2 restart > /dev/null 2>&1

[[ $(dpkg -l | grep -w apache2) ]]
}

funcao_idioma () {
figlet "    GOLDEN MX" | lolcat
msg -bar2

pv="$(echo es)"

[[ ${#id} -gt 2 ]] && id="es" || id="$pv"

byinst="true"
}

install_fim () {

msg -ama "$(source trans -b es:${id} "Instalacion completa, utilize los Comandos"|sed -e 's/[^a-z -]//ig')"

msg bar2

echo -e " menu / adm"

msg -verm "$(source trans -b es:${id} "INICIE SESION CUANDO SE CIERRE ESTA TERMINAL"|sed -e 's/[^a-z -]//ig')"

mkdir /etc/nanotxz  > /dev/null 2>&1
mkdir /etc/rom  > /dev/null 2>&1
mkdir /etc/bin  > /dev/null 2>&1

msg -bar2

sleep 10s

sudo reboot
}

ofus () {

unset txtofus

number=$(expr length "$1")

for((i=1; i<$number+1; i++)); do

txt[$i]=$(echo "$1" | cut -b $i)

case ${txt[$i]} in
".")txt[$i]="+";;
"+")txt[$i]=".";;
"1")txt[$i]="@";;
"@")txt[$i]="1";;
"2")txt[$i]="?";;
"?")txt[$i]="2";;
"3")txt[$i]="%";;
"%")txt[$i]="3";;
"/")txt[$i]="K";;
"K")txt[$i]="/";;
esac

txtofus+="${txt[$i]}"

done

echo "$txtofus" | rev
}

verificar_arq () {

[[ ! -d ${SCPdir} ]] && mkdir ${SCPdir}
[[ ! -d ${SCPdir2} ]] && mkdir ${SCPdir2}
[[ ! -d ${SCPusr} ]] && mkdir ${SCPusr}
[[ ! -d ${SCPfrm} ]] && mkdir ${SCPfrm}
[[ ! -d ${SCPinst} ]] && mkdir ${SCPinst}

[[ $(find /etc/newadm/ger-user -name tiemlim.log 2>/dev/null) ]] || wget -q -O /etc/newadm/ger-user/tiemlim.log https://www.dropbox.com/s/sew455tgb0v79wm/tiemlim.log

[[ $(find /etc/newadm/ger-user -name IDT.log 2>/dev/null) ]] || wget -q -O /etc/newadm/ger-user/IDT.log https://www.dropbox.com/s/norz9mhypyto4e2/IDT.log

case $1 in
"menu"|"message.txt")ARQ="${SCPdir}/";;
"usercodes")ARQ="${SCPusr}/";;
"openssh.sh"|"squid.sh"|"dropbear.sh"|"openvpn.sh"|"ssl.sh"|"shadowsocksLive.sh"|"shadown.sh"|"budp.sh"|"shadowsock.sh"|"ssrrmu.sh"|"shadowsocks.sh"|"v2ray.sh"|"sockspy.sh"|"PDirect.py"|"PPub.py"|"PPriv.py"|"POpen.py"|"PGet.py") ARQ="${SCPinst}/";;
*)ARQ="${SCPfrm}/";;
esac

mv -f ${SCPinstal}/$1 ${ARQ}/$1

chmod +x ${ARQ}/$1
}

fun_ip

wget -q -O /usr/bin/trans https://www.dropbox.com/s/dzknghcgew54pc6/trans
wget -q -O /usr/bin/limv2ray https://www.dropbox.com/s/k4tosjnio1scyvd/limv2ray

chmod +x /usr/bin/limv2ray

wget -q -O /bin/Desbloqueo.sh https://www.dropbox.com/s/9z6wclbzghi8k8u/Desbloqueo.sh

chmod +x /bin/Desbloqueo.sh

msg -bar2
msg -ama "[ INSTALADOR OFICIAL ] [ NEW - GOLDEN ADM PRO ]"
msg -bar2
msg -ama "\033[1;37mESTE ESCRIPT SOLO FUNCIONA EN EL IDIOMA ESPAÑOL"
msg -ama "\033[1;37mINGRESE SU KEY DE INSTALACION SI NO TIENES PONTE EN CONTACTO"
msg -bar2
msg -ama "\033[1;34mTELEGRAM: @ELDIABLOLUCIFER2020"
msg -ama "\033[1;34mWHATSAPP: +52 2292453056"
msg -bar2

[[ $1 = "" ]] && funcao_idioma || {
[[ ${#1} -gt 2 ]] && funcao_idioma || id="$1"
}

error_fun () {

msg -bar2 && msg -verm "$(source trans -b es:${id} "Esta clave era de otro servidor, por lo tanto fue excluida"|sed -e 's/[^a-z -]//ig') "

msg -bar2

[[ -d ${SCPinstal} ]] && rm -rf ${SCPinstal}

rm -rf diablo2020.sh
rm -rf LuciferMX2019.sh

exit 1
}

invalid_key () {

echo -e "$barra"

msg -verm "Key Failed! "

msg -bar2

[[ -e $HOME/lista-arq ]] && rm $HOME/lista-arq

exit 1
}

while [[ ! $Key ]]; do
msg -ne "Script Key: "
read Key
tput cuu1 2>/dev/null
tput dl1 2>/dev/null
done

msg -ne "Key: "

cd $HOME

wget -q -O $HOME/lista-arq $(ofus "$Key")/$IP && echo -e "\033[1;32m Verificando" || {
echo -e "\033[1;32m Verificado"
invalid_key
exit
}

IP=$(ofus "$Key" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

echo "$IP" > /usr/bin/vendor_code

sleep 1s

updatedb 2>/dev/null

if [[ -e $HOME/lista-arq ]] && [[ ! $(cat $HOME/lista-arq | grep "KEY INVALIDA!") ]]; then

echo -e "$barra"

msg -ama "$(source trans -b es:${id} "BIENVENIDO, GRACIAS POR UTILIZAR"|sed -e 's/[^a-z -]//ig'): \033[1;31m[ NEW-GOLDEN ADM PRO ]"

REQUEST=$(ofus "$Key" | cut -d'/' -f2)

[[ ! -d ${SCPinstal} ]] && mkdir ${SCPinstal}

pontos="."

stopping="$(source trans -b es:${id} "Verificando Actualizaciones"|sed -e 's/[^a-z -]//ig')"

for arqx in $(cat $HOME/lista-arq); do

msg -verm "${stopping}${pontos}"

wget -q -O ${SCPinstal}/${arqx} ${IP}:81/${REQUEST}/${arqx} && verificar_arq "${arqx}" || error_fun

tput cuu1 2>/dev/null
tput dl1 2>/dev/null

pontos+="."

done

sleep 1s

msg -bar2

listaarqs="$(locate lista-arq 2>/dev/null | head -1)"

[[ -e ${listaarqs} ]] && rm $listaarqs

cat /etc/bash.bashrc | grep -v '[[ $UID != 0 ]] && TMOUT=15 && export TMOUT' > /etc/bash.bashrc.2

echo '[[ $UID != 0 ]] && TMOUT=15 && export TMOUT' >> /etc/bash.bashrc.2

mv -f /etc/bash.bashrc.2 /etc/bash.bashrc

echo "${SCPdir}/menu" > /usr/bin/menu
chmod +x /usr/bin/menu

echo "${SCPdir}/menu" > /usr/bin/adm
chmod +x /usr/bin/adm

instalar_logo_login

inst_components

echo "$Key" > ${SCPdir}/key.txt

[[ -d ${SCPinstal} ]] && rm -rf ${SCPinstal}

[[ ${#id} -gt 2 ]] && echo "pt" > ${SCPidioma} || echo "${id}" > ${SCPidioma}

[[ ${byinst} = "true" ]] && install_fim

else

invalid_key

fi
