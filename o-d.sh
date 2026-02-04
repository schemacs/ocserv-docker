#!/bin/bash

function fetch() {
  curl --silent --show-error --fail "$@"
}

function set_hostname() {
  # These are URLs that return the client's apparent IP address.
  # We have more than one to try in case one starts failing
  # (e.g. https://github.com/Jigsaw-Code/outline-server/issues/776).
  local -ar urls=(
    'https://icanhazip.com/'
    'https://ipinfo.io/ip'
    'https://domains.google.com/checkip'
  )
  for url in "${urls[@]}"; do
    PUBLIC_HOSTNAME="$(fetch --ipv4 "${url}")" && return
  done
  echo "Failed to determine the server's IP address.  Try using --hostname <server IP>." >&2
  return 1
}

PUBLIC_PORT=8443
PUBLIC_HOSTNAME=""
CONTAINER_NAME='ocserv'
set_hostname
readonly PUBLIC_HOSTNAME
echo "Your Server Address: $PUBLIC_HOSTNAME:$PUBLIC_PORT"
echo
read -r -p "Your username: " -t 300 OCSERV_USER_NAME < /dev/tty
echo
read -r -s -p "Your password: " -t 300 OCSERV_PASSWORD < /dev/tty
echo
read -r -s -p "Confirm password: " -t 300 OCSERV_PASSWORD_CONFIRM < /dev/tty
echo > /dev/tty
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

sudo docker run --name "$CONTAINER_NAME" --privileged -p $PUBLIC_PORT:443 -p $PUBLIC_PORT:443/udp -d ocserv

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
echo "Connect with Anyconnect or Openconnect:"

echo -e "\033[1;32m"
echo Server Address: $PUBLIC_HOSTNAME:$PUBLIC_PORT
echo User name: $OCSERV_USER_NAME
echo Password: $OCSERV_PASSWORD
echo -e "\033[0m"
