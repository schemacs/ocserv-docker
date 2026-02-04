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

gen_username() {
    local words1=(blue fast happy quiet smart lucky)
    local words2=(fox cat panda tiger eagle cloud)
    echo "${words1[RANDOM % ${#words1[@]}]}-${words2[RANDOM % ${#words2[@]}]}$((RANDOM % 100))"
}

gen_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 8
}


PUBLIC_PORT=8443
PUBLIC_HOSTNAME=""
CONTAINER_NAME='ocserv'
set_hostname
readonly PUBLIC_HOSTNAME

if [ -t 0 ] && [ -e /dev/tty ]; then
  echo "   Server Address: $PUBLIC_HOSTNAME:$PUBLIC_PORT"
  if ! read -r -p "Your new username: " -t 300 OCSERV_USER_NAME < /dev/tty; then
      OCSERV_USER_NAME="$(gen_username)"
      echo
      echo "⏰ Timeout. Auto-generated username: $OCSERV_USER_NAME"
  fi
  
  if ! read -r -s -p "Your new password: " -t 300 OCSERV_PASSWORD < /dev/tty; then
      OCSERV_PASSWORD="$(gen_password)"
      OCSERV_PASSWORD_CONFIRM="$OCSERV_PASSWORD"
      echo
      echo "⏰ Timeout. Auto-generated password: $OCSERV_PASSWORD"
  else
      echo
      if ! read -r -s -p " Confirm password: " -t 300 OCSERV_PASSWORD_CONFIRM < /dev/tty; then
          echo
          echo "❌ Password confirmation timeout"
          exit 1
      fi
      echo
  fi
  echo > /dev/tty
else
    OCSERV_USER_NAME="$(gen_username)"
    OCSERV_PASSWORD="$(gen_password)"
    OCSERV_PASSWORD_CONFIRM="$OCSERV_PASSWORD"
fi

if [[ "$OCSERV_PASSWORD" != "$OCSERV_PASSWORD_CONFIRM" ]]; then
    echo "❌ Passwords do not match"
    exit 1
fi

if [[ "$OCSERV_PASSWORD" != "$OCSERV_PASSWORD_CONFIRM" ]]; then
    echo "Error: passwords do not match"
    exit 1
fi

SALT=$(openssl rand -hex 8)
PASSWORD_HASH=$(openssl passwd -6 -salt "$SALT" "$OCSERV_PASSWORD")

command -v docker &> /dev/null || (
    # Change umask so that /usr/share/keyrings/docker-archive-keyring.gpg has the right permissions.
    # See https://github.com/Jigsaw-Code/outline-server/issues/951.
    # We do this in a subprocess so the umask for the calling process is unaffected.
    umask 0022
    fetch https://get.docker.com/ | sh
) >&2


#sudo docker build -t ocserv https://github.com/iw4p/OpenConnect-Cisco-AnyConnect-VPN-Server-OneKey-ocserv.git
sudo docker build -t ocserv https://github.com/schemacs/ocserv-docker.git

sudo docker run --name "$CONTAINER_NAME" --privileged -p $PUBLIC_PORT:443 -p $PUBLIC_PORT:443/udp -d ocserv

sudo ufw disable

sudo docker exec ocserv sh -c "
    set -e
    touch /etc/ocserv/ocpasswd
    chmod 600 /etc/ocserv/ocpasswd
    grep -v '^${OCSERV_USER_NAME}:' /etc/ocserv/ocpasswd > /etc/ocserv/ocpasswd.tmp || true
    echo '${OCSERV_USER_NAME}::${PASSWORD_HASH}' >> /etc/ocserv/ocpasswd.tmp
    mv /etc/ocserv/ocpasswd.tmp /etc/ocserv/ocpasswd
"


#echo "User '$OCSERV_USER_NAME' added/updated successfully."
echo "Connect with Anyconnect or Openconnect:"

echo -e "\033[1;32m"
echo "Server Address: $PUBLIC_HOSTNAME:$PUBLIC_PORT"
echo "      Username: $OCSERV_USER_NAME"
echo "      Password: $OCSERV_PASSWORD"
echo -e "\033[0m"
