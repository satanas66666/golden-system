#!/bin/bash

SCPdir="/etc/newadm"
SCPdir2="/etc/ger-frm"
SCPusr="${SCPdir}/ger-user"
MyPID="${SCPusr}/pid-adm"
MyTIME="${SCPusr}/time-adm"
USRdatabase="/etc/ADMuser"

[[ -e ${MyPID} ]] && source ${MyPID} || touch ${MyPID}
[[ -e ${MyTIME} ]] && source ${MyTIME} || touch ${MyTIME}
[[ ! -e ${USRdatabase} ]] && touch ${USRdatabase}

sort ${USRdatabase} | uniq > ${USRdatabase}.tmp
mv -f ${USRdatabase}.tmp ${USRdatabase}

unlockall3 () {
    for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd | grep -v "rick" | grep -vi "nobody" | grep -vi "polkitd" | grep -vi "systemd-"); do
        usermod -U "$user" &>/dev/null
    done
}

mostrar_usuarios () {
    awk -F: '$3 >= 1000 && $1!="nobody" && $1!="polkitd" && $1!~/systemd-/ {print $1}' /etc/passwd
}

rm_user () {
    local user="$1"

    [[ -z "$user" ]] && return 1
    [[ "$user" = "root" ]] && return 1

    # Cerrar conexiones activas del usuario
    pkill -KILL -u "$user" 2>/dev/null
    pkill -KILL -f "$user" 2>/dev/null

    ps -ef | grep -w "$user" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null

    sleep 1

    # Eliminar usuario a fuerza
    userdel -f "$user" &>/dev/null || return 1

    # Limpiar base de datos
    if [[ -e "$USRdatabase" ]]; then
        grep -w -v "$user" "$USRdatabase" > "${USRdatabase}.tmp"
        mv -f "${USRdatabase}.tmp" "$USRdatabase"
    fi

    return 0
}

rm_vencidos () {
    local DataVPS
    DataVPS=$(date +%s)

    while read user; do
        [[ -z "$user" ]] && continue

        DataUser=$(chage -l "$user" 2>/dev/null | grep -i "Account expires" | awk -F ":" '{print $2}' | xargs)

        usr="$user"
        while [[ ${#usr} -lt 20 ]]; do
            usr="${usr} "
        done

        [[ -z "$DataUser" ]] && continue

        if [[ "$DataUser" = "never" ]]; then
            continue
        fi

        DataSEC=$(date -d "$DataUser" +%s 2>/dev/null)
        [[ -z "$DataSEC" ]] && continue

        if [[ "$DataSEC" -lt "$DataVPS" ]]; then
            rm_user "$user"
        fi

    done <<< "$(mostrar_usuarios)"

    rm -rf /etc/newadm-userlock
    rm -rf /etc/newadm/ger-user/Limiter.log
}

unlockall3 &>/dev/null
rm_vencidos &>/dev/null

exit
