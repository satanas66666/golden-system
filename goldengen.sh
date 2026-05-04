#!/bin/bash
# GENERADOR GOLDEN ADM PRO (GITHUB VERSION)

set -e

CREATE_DIR="mkdir -p /tmp/golden"
DIR="/tmp/golden"
CLEAN="rm -rf /tmp/golden"
HOME_DIR="$HOME"
DIR_SCRIPT="/etc/SCRIPT"

REPO="https://raw.githubusercontent.com/satanas66666/golden-system/main"

echo "🔧 Instalando Golden System PRO..."

# limpiar y preparar
$CLEAN
$CREATE_DIR
cd $DIR

# actualizar sistema
apt-get update -y
apt-get upgrade -y

# 🔥 paquetes completos (esto evita TODOS los errores)
apt-get install -y \
bc screen nano zip unzip curl wget \
netcat netcat-traditional \
apache2 lsof

# 🔥 asegurar compatibilidad netcat
update-alternatives --set nc /bin/nc.traditional 2>/dev/null || true

# apache puerto 81 (tu lógica intacta)
sed -i "s;Listen 80;Listen 81;g" /etc/apache2/ports.conf
systemctl restart apache2 >/dev/null 2>&1

# crear estructura
rm -rf $DIR_SCRIPT
mkdir -p $DIR_SCRIPT

# 🔥 descargar desde GitHub
echo "📥 Descargando archivos desde GitHub..."

wget -q "$REPO/golden.zip"
unzip -o golden.zip >/dev/null 2>&1

# copiar scripts
cp -r golden/SCRIPT/* $DIR_SCRIPT/
chmod 777 $DIR_SCRIPT/*

# instalar generador
cp golden/gerar.sh /bin/gerar
chmod +x /bin/gerar

cp golden/gerar.sh /usr/bin/gerar.sh
chmod +x /usr/bin/gerar.sh

# instalar servidor corregido
wget -q "$REPO/http-server.sh" -O /bin/http-server.sh
chmod +x /bin/http-server.sh

# 🔥 asegurar permisos globales
chmod 777 /bin/http-server.sh
chmod 777 /bin/gerar
chmod 777 /usr/bin/gerar.sh

# limpiar
rm -rf golden*
cd $HOME_DIR
$CLEAN

echo -e "\033[1;36m--------------------------------------------------------------------\033[0m"
echo -e "\033[1;32m INSTALACION COMPLETA ✔\033[0m"
echo -e "\033[1;33m Use el comando: \033[1;31m gerar \033[1;33m para generar keys\033[0m"
echo -e "\033[1;36m--------------------------------------------------------------------\033[0m"

exit 0
