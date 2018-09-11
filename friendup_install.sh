#!/bin/bash
# This file is licensed under MIT license.
# See LICENSE file for details
# Copyright 2018 Inseo Oh(YeonJi) all rights reserved.
function infoMessage {
  echo -e "\e[97;1m*** INFO: "$1"\e[0m"
}

function errorMessage {
  echo -e "\e[31;1m*** ERROR: "$1"\e[0m"
}

function try {
  $@
  ERROR=$?
  if [ $ERROR -ne 0 ]; then
    errorMessage "Command "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" failed(returned code "$ERROR")"
    exit 1
  fi
}

infoMessage "Gather information from user..."
echo -e "\e[93mEnter MySQL/MariaDB root password you want to use.\e[0m"
echo -e "\e[93mYou will need this password later during installation.\e[0m"
MYSQLROOTPW=""
while true; do
  echo -ne "Enter new MySQL/MariaDB root password: "
  read -s PASSWORD1
  echo ""
  echo -ne "Retype new MySQL/MariaDB root password: "
  read -s PASSWORD2
  echo ""
  if [ "$PASSWORD1" == "$PASSWORD2" ]; then
    MYSQLROOTPW=$PASSWORD1
    break
  fi
  echo -e "\e[97;21mPassword does not match!\e[0m"
done

echo -e "\e[93mEnter MySQL/MariaDB database password you want to use.\e[0m"
MYSQLDBPW=""
while true; do
  echo -ne "Enter new MySQL/MariaDB database password: "
  read -s PASSWORD1
echo ""
  echo -ne "Retype new MySQL/MariaDB database password: "
  read -s PASSWORD2
  echo ""
  if [ "$PASSWORD1" == "$PASSWORD2" ]; then
    MYSQLDBPW=$PASSWORD1
    break
  fi
  echo -e "\e[97;21mPassword does not match!\e[0m"
done

echo -e "\e[93mEnter domain name you want to use. There should be no space in domain name!\e[0m"
echo -ne "Domain name(Leave blank if you want to use 'localhost'): "
read DOMAINNAME
if [ "$DOMAINNAME" == "" ]; then
  DOMAINNAME="localhost"
fi

echo -e "\e[93mSSL/TLS configuration\e[0m"
echo -ne "Do you want to use TLS?(y/n): "
TLS=""
while true; do
  read ANSWER
  if [ "$ANSWER" == "y" ]; then
    TLS="1"
    break
  elif [ "$ANSWER" == "n" ]; then
    TLS="0"
    break
  fi
  echo -e "\e[97;21mBad answer!\e[0m"
done

echo -e "\e[93mThank you. Installation will now begin...\e[0m"


infoMessage "Updating packages..."
try sudo apt update


infoMessage "Upgrading packages..."
try sudo apt upgrade -y


infoMessage "Installing required packages"
try sudo apt install -y bash gcc git sed mysql-server


infoMessage "Setting up MySQL/MariaDB..."
infoMessage " -> Create MySQL/MariaDB query file to update root password..."
QUERYFILE=$(mktemp)
ERROR=$?
if [ $ERROR -ne 0 ]; then
  errorMessage "Cannot create temporary file(mktemp returned code "$ERROR")"
  exit 1
fi
try sudo chmod 0666 $QUERYFILE
echo "use mysql;" > $QUERYFILE
echo "update user set password=PASSWORD(\""$MYSQLROOTPW"\") where User='root';" >> $QUERYFILE
echo "flush privileges;" >> $QUERYFILE
ERROR=$?
if [ $ERROR -ne 0 ]; then
  errorMessage "Cannot write to query file(error code "$ERROR")"
  exit 1
fi
infoMessage " -> Run query file"
try sudo mysql -u root < $QUERYFILE

infoMessage " -> Remove query file"
try sudo rm -rf $QUERYFILE

infoMessage " -> Restart MySQL/MariaDB"
try sudo systemctl restart mysqld


infoMessage "Downloading FriendUP..."
if [ ! -d friendup ]; then
  try git clone https://github.com/FriendSoftwareLabs/friendup
else
  infoMessage " -> FriendUP directory already exists. Skipping..."
fi

infoMessage "Patching FriendUP installer..."
try sed -i -e 's/libmysqlclient-dev/libmariadbclient-dev/g' friendup/install.sh
try sed -i -e 's/phpmyadmin//g' friendup/install.sh


infoMessage "Creating directories..."
try mkdir -p friendup/build/cfg/crt


infoMessage "Creating configuration file..."
CFGFILE=friendup/build/cfg/cfg.ini

echo ";" >> $CFGFILE
echo "; Friend Core configuration file" >> $CFGFILE
echo "; ------------------------------" >> $CFGFILE
echo "; This file was generated by YeonJi FriendUP installer!" >> $CFGFILE
echo "; Please respect both spaces and breaks between lines if you change this file manually" >> $CFGFILE
echo ";" >> $CFGFILE
# DatabaseUser
echo "[DatabaseUser]" >> $CFGFILE
echo "login = friendup" >> $CFGFILE
echo "password = "$MYSQLDBPW >> $CFGFILE
echo "host = localhost" >> $CFGFILE
echo "dbname = friendup" >> $CFGFILE
echo "port = 3306" >> $CFGFILE
echo " " >> $CFGFILE
# FriendCore
echo "[FriendCore]" >> $CFGFILE
echo "fchost = \"$DOMAINNAME\"" >> $CFGFILE
echo "port = 6502" >> $CFGFILE
echo "fcupload = storage/" >> $CFGFILE
echo " " >> $CFGFILE
# Core
echo "[Core]" >> $CFGFILE
echo "port = 6502" >> $CFGFILE
echo "SSLEnable = "$TLS >> $CFGFILE
echo " " >> $CFGFILE
# FriendNetwork
echo "[FriendNetwork]" >> $CFGFILE
echo "enabled = 0" >> $CFGFILE
echo " " >> $CFGFILE
# FriendChat
echo "[FriendChat]" >> $CFGFILE
echo "enabled = 0" >> $CFGFILE
echo " " >> $CFGFILE
ERROR=$?
if [ $ERROR -ne 0 ]; then
  errorMessage "Cannot write to config file(error code "$ERROR")"
  exit 1
fi

if [ "$TLS" == "1" ]; then
  infoMessage "Creating dummy key files for activating TLS..."
  sudo touch friendup/build/cfg/crt/key.pem
  sudo touch friendup/build/cfg/crt/certificate.pem
fi

infoMessage "Starting FriendUP installer..."
cd friendup/
sudo ./install.sh

infoMessage "Kill Friend services..."
sudo friendup/killFriend.sh

infoMessage "Configure Apache..."
echo "ServerName "$DOMAINNAME | sudo tee -a /etc/apache2/apache2.conf

infoMessage "Stop Apache..."
apachectl -k stop

if [ "$TLS" == "1" ]; then
  infoMessage "Begin HTTPS setup..."
  infoMessage "-> Ask user whether user wants to run ACMEv2 setup or not"
  echo -ne "Do you want to configure HTTPS with Let's Encrypt ACMEv2?(y/n): "
  ACME=""
  while true; do
    read ANSWER
    if [ "$ANSWER" == "y" ]; then
      ACME="1"
      break
    elif [ "$ANSWER" == "n" ]; then
      ACME="0"
      break
    fi
    echo -e "\e[97;21mBad answer!\e[0m"
  done

  if [ "$ACME" == "1" ]; then
    infoMessage "-> Install Certbot for HTTPS setup with ACMEv2..."
    try sudo apt install -y certbot
    infoMessage "-> Run Certbot..."
    try sudo certbot certonly --standalone -d $DOMAINNAME
    infoMessage "-> Remove old cert files..."
    try sudo rm -rf build/cfg/crt/key.pem build/cfg/crt/certificate.pem
    infoMessage "-> Link new cert files..."
    try sudo ln -s /etc/letsencrypt/live/$DOMAINNAME/privkey.pem $(pwd)/build/cfg/crt/key.pem
    try sudo ln -s /etc/letsencrypt/live/$DOMAINNAME/cert.pem $(pwd)/build/cfg/crt/certificate.pem
  else
    infoMessage "-> Skip HTTPS setup"
    echo "You have to symlink or copy cert files(and rename to proper name) to friendup/build/cfg/crt"
    echo "Private key file -> friendup/build/cfg/crt/key.pem"
    echo "Certificate file -> friendup/build/cfg/crt/certificate.pem"
  fi

  infoMessage "Finishing HTTPS setup..."
fi

infoMessage "Install as systemd service..."
try sudo ./install_systemd.sh

infoMessage "Configuring&Starting friendcore service..."
try sudo systemctl enable friendcore
try sudo systemctl start friendcore

infoMessage "Thank you! Everything is complete."
infoMessage "Open your browser and go to:"
if [ "$TLS" == "1" ]; then
  infoMessage "https://"$DOMAINNAME":6502/webclient/index.html"
else
  infoMessage "http://"$DOMAINNAME":6502/webclient/index.html"
fi

cd ..
