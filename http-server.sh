#!/bin/bash

# 🔥 NECESARIO PARA @( )
shopt -s extglob

IVAR="/etc/http-instas"

# evitar error si no existe
[[ ! -f $IVAR ]] && echo "0" > $IVAR

install_fun () {
apt-get install -y netcat curl bc > /dev/null 2>&1
}

fun_ip () {
MIP=$(ip addr 2>/dev/null | grep 'inet ' | grep -v inet6 | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1 | head -n1)
MIP2=$(curl -s ipv4.icanhazip.com 2>/dev/null)
[[ "$MIP" != "$MIP2" && -n "$MIP2" ]] && IP="$MIP2" || IP="$MIP"
}

# LISTEN
listen_fun () {
PORTA="8888"
PROGRAMA="/bin/http-server.sh"

while true; do

  if command -v nc.traditional >/dev/null 2>&1; then
    nc.traditional -l -p "$PORTA" -e "$PROGRAMA"

  elif nc -h 2>&1 | grep -q -- "-e"; then
    nc -l -p "$PORTA" -e "$PROGRAMA"

  else
    # 🔥 fallback sin -e (Ubuntu nuevos)
    while true; do
      { 
        read line
        echo "$line" | "$PROGRAMA"
      } | nc -l -p "$PORTA"
    done

  fi

done
}

# SERVER
server_fun () {

DIR="/etc/http-shell"
unset ENV_ARQ

[[ ! -d $DIR ]] && mkdir -p $DIR

# leer request
read URL || exit

KEYZ=($(echo "$URL" | cut -d ' ' -f2 | awk -F "/" '{print $2, $3, $4, $5, $6, $7}'))

KEY="${KEYZ[0]}"
[[ -z $KEY ]] && KEY="ERRO"

ARQ="${KEYZ[1]}"
[[ -z $ARQ ]] && ARQ="ERRO"

USRIP="${KEYZ[2]}"
[[ -z $USRIP ]] && USRIP="ERRO"

FILE2="${DIR}/${KEY}"
FILE="${DIR}/${KEY}/$ARQ"

if [[ -e ${FILE} ]]; then

STATUS_NUMBER="200"
STATUS_NAME="Found"
ENV_ARQ="True"

 if [[ -e ${FILE2}/FERRAMENTA ]]; then
   if [[ ${USRIP} != "ERRO" ]]; then
    FILE="${DIR}/ERROR-KEY"
    echo "FERRAMENTA KEY!" > ${FILE}
    ENV_ARQ="False"
   fi
 else
   if [[ ${USRIP} = "ERRO" ]]; then
    FILE="${DIR}/ERROR-KEY"
    echo "KEY DE INSTALACAO!" > ${FILE}
    ENV_ARQ="False"
   fi
 fi

else

FILE="${DIR}/ERROR-KEY"
echo "KEY INVALIDA!" > ${FILE}

STATUS_NUMBER="200"
STATUS_NAME="Found"
ENV_ARQ="False"

fi

SIZE=$(wc -c < "$FILE" 2>/dev/null)

cat << EOF
HTTP/1.1 $STATUS_NUMBER - $STATUS_NAME
Date: $(date)
Server: ShellHTTP
Content-Length: $SIZE
Connection: close
Content-Type: text/html; charset=utf-8

$(cat "$FILE")
EOF

if [[ $ENV_ARQ = "True" ]]; then
(
mkdir -p /var/www/html/$KEY
mkdir -p /var/www/$KEY

TIME="10+"

for arqs in $(cat "$FILE"); do
  cp ${FILE2}/$arqs /var/www/html/$KEY/ 2>/dev/null
  cp ${FILE2}/$arqs /var/www/$KEY/ 2>/dev/null
  TIME+="1+"
done

TIME=$(echo "${TIME}0" | bc 2>/dev/null)
sleep ${TIME:-10}s

rm -rf /var/www/html/$KEY
rm -rf /var/www/$KEY

if [[ -d $FILE2 ]]; then

PERM="${DIR}/${KEY}/keyfixa"

# 🔐 VALIDACIÓN CORREGIDA (NO BORRA KEYS NORMALES)
if [[ -e $PERM ]]; then

  if [[ $(cat $PERM) != "$USRIP" ]]; then

    log="/etc/gerar-sh-log"

    echo "USUARIO: $(cat ${FILE2}.name 2>/dev/null) IP FIXO: $(cat $PERM) USOU IP: $USRIP" >> $log
    echo "IP DIFERENTE - ACCESO BLOQUEADO" >> $log
    echo "--------------------------------------------------------------------" >> $log

    # ❌ YA NO ELIMINA LA KEY
    exit 0
  fi

fi

# 🔓 KEY NORMAL = MULTI VPS (NO SE BORRA)

num=$(cat ${IVAR} 2>/dev/null)
[[ -z $num ]] && num=0

let num++
echo $num > $IVAR

fi

) &> /dev/null &
fi

}

[[ $1 = @(-[Ss]tart|-[Ss]|-[Ii]niciar) ]] && listen_fun && exit
[[ $1 = @(-[Ii]stall|-[Ii]|-[Ii]stalar) ]] && listen_fun && exit

server_fun
