#!/bin/bash
echo
read -r -p "Your user name: " -t 300 OCSERV_USER_NAME
echo
read -r -s -p "Your password: " -t 300 OCSERV_PASSWORD
echo
read -r -s -p "Confirm password: " -t 300 OCSERV_PASSWORD_CONFIRM
echo

if [[ "$OCSERV_PASSWORD" != "$OCSERV_PASSWORD_CONFIRM" ]]; then
    echo "Error: passwords do not match"
    exit 1
fi

### ===== 2. 生成 SHA-512 crypt hash（$6$）=====
SALT=$(openssl rand -hex 8)
PASSWORD_HASH=$(openssl passwd -6 -salt "$SALT" "$OCSERV_PASSWORD")


#sudo docker build -t ocserv https://github.com/iw4p/OpenConnect-Cisco-AnyConnect-VPN-Server-OneKey-ocserv.git
sudo docker build -t ocserv https://github.com/schemacs/ocserv-docker.git

sudo docker run --name ocserv --privileged -p 8443:443 -p 8443:443/udp -d ocserv

sudo ufw disable


sudo docker exec ocserv bash -c "
    set -e
    touch /etc/ocserv/ocpasswd
    chmod 600 /etc/ocserv/ocpasswd
    grep -v '^${OCSERV_USER_NAME}:' /etc/ocserv/ocpasswd > /etc/ocserv/ocpasswd.tmp || true
    echo '${OCSERV_USER_NAME}::${PASSWORD_HASH}' >> /etc/ocserv/ocpasswd.tmp
    mv /etc/ocserv/ocpasswd.tmp /etc/ocserv/ocpasswd
"

echo "User '$OCSERV_USER_NAME' added/updated successfully."
