#!/bin/bash

IVAR="/etc/http-instas"

install_fun () {
    apt-get install -y netcat-openbsd
}

fun_ip () {
    MIP=$(hostname -I | awk '{print $1}')
    MIP2=$(curl -s ipv4.icanhazip.com)
    [[ "$MIP" != "$MIP2" ]] && IP="$MIP2" || IP="$MIP"
}

# 🔥 LISTEN (ARREGLADO SIN -e)
listen_fun () {
    PORTA="8888"
    echo "🌐 HTTP-SERVER activo en puerto $PORTA"

    while true; do
        { server_fun; } | nc -l -p "$PORTA" -q 1
    done
}

# 🔥 SERVER
server_fun () {

DIR="/etc/http-shell"
mkdir -p "$DIR"

read REQUEST

# 🔥 obtener ruta
URL=$(echo "$REQUEST" | cut -d ' ' -f2)

KEY=$(echo "$URL" | cut -d '/' -f2)
ARQ=$(echo "$URL" | cut -d '/' -f3)
USRIP=$(echo "$URL" | cut -d '/' -f4)

[[ -z "$KEY" ]] && KEY="ERRO"
[[ -z "$ARQ" ]] && ARQ="ERRO"
[[ -z "$USRIP" ]] && USRIP="ERRO"

FILE2="${DIR}/${KEY}"
FILE="${FILE2}/${ARQ}"

# 🔥 VALIDACIÓN
if [[ -f "$FILE" ]]; then
    STATUS_NUMBER="200"
    STATUS_NAME="OK"
    ENV_ARQ="True"

    if [[ -f "${FILE2}/FERRAMENTA" ]]; then
        if [[ "$USRIP" != "ERRO" ]]; then
            FILE="${DIR}/ERROR-KEY"
            echo "FERRAMENTA KEY!" > "$FILE"
            ENV_ARQ="False"
        fi
    else
        if [[ "$USRIP" = "ERRO" ]]; then
            FILE="${DIR}/ERROR-KEY"
            echo "KEY DE INSTALACION!" > "$FILE"
            ENV_ARQ="False"
        fi
    fi

else
    FILE="${DIR}/ERROR-KEY"
    echo "KEY INVALIDA!" > "$FILE"
    STATUS_NUMBER="200"
    STATUS_NAME="ERROR"
    ENV_ARQ="False"
fi

# 🔥 RESPUESTA HTTP
echo -e "HTTP/1.1 $STATUS_NUMBER $STATUS_NAME"
echo -e "Content-Type: text/plain"
echo -e "Connection: close"
echo ""
cat "$FILE"

# 🔥 EJECUCIÓN SI ES VÁLIDO
if [[ "$ENV_ARQ" = "True" ]]; then
(
    mkdir -p /var/www/html/$KEY
    mkdir -p /var/www/$KEY

    TIME=10

    for arqs in $(cat "$FILE"); do
        cp "${FILE2}/$arqs" /var/www/html/$KEY/ 2>/dev/null
        cp "${FILE2}/$arqs" /var/www/$KEY/ 2>/dev/null
        TIME=$((TIME + 1))
    done

    sleep $TIME

    rm -rf /var/www/html/$KEY
    rm -rf /var/www/$KEY

    if [[ -d "$FILE2" ]]; then

        PERM="${FILE2}/keyfixa"

        if [[ -f "$PERM" ]]; then
            if [[ "$(cat "$PERM")" != "$USRIP" ]]; then
                log="/etc/gerar-sh-log"
                echo "USUARIO: $(cat ${FILE2}.name 2>/dev/null) IP FIXO: $(cat $PERM) USO IP: $USRIP" >> $log
                echo "KEY BLOQUEADA" >> $log
                echo "------------------------------" >> $log
                rm -rf "$FILE2"
                rm -f "${FILE2}.name"
            fi
        else
            rm -rf "$FILE2"
            rm -f "${FILE2}.name"
        fi

        num=$(cat $IVAR 2>/dev/null)
        [[ -z "$num" ]] && num=0
        num=$((num + 1))
        echo $num > $IVAR
    fi

) > /dev/null 2>&1 &
fi
}

# 🔥 COMANDOS
case "$1" in
    -start|-s|-iniciar)
        listen_fun
    ;;
    -install|-i|-instalar)
        install_fun
    ;;
    *)
        server_fun
    ;;
esac
