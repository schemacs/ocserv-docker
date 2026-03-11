#!/usr/bin/env bash

#cd /var/www/html
tmpdir=$(mktemp -d)
cd "$tmpdir" || exit

PUBLIC_HOSTNAME=127.0.0.1
function set_hostname() {
  local -ar urls=(
    'https://icanhazip.com/'
    'https://ipinfo.io/ip'
    'https://domains.google.com/checkip'
  )
  for url in "${urls[@]}"; do
    PUBLIC_HOSTNAME="$(curl --silent --show-error --fail --ipv4 "${url}")" && return
  done
  echo "Failed to determine the server's IP address.  Try using --hostname <server IP>." >&2
  return 1
}

download_url() {
  url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$1" || \
        curl -fsSL -r 0-0 -o /dev/null -w '%{url_effective}' "$1") || return 1

  if [ -n "$2" ]; then
    curl -fsSL --continue-at - -o "$2" "$url"
  else
    curl -fsSL --continue-at - -O "$url"
  fi
}

fdroid_download() {
    # curl -fsSL -O "https://f-droid.org/repo/${1}_$(curl -fsSL https://f-droid.org/api/v1/packages/$1 | jq -r .suggestedVersionCode).apk";
    pkg=$1
    ver=$(curl -fsSL --retry 3 --connect-timeout 10 "https://f-droid.org/api/v1/packages/$pkg" | jq -r .suggestedVersionCode) || return 1
    [ -n "$ver" ] || { echo "Failed to get version"; return 1; }
    curl --silent -fL --retry 5 --retry-delay 2 --retry-connrefused --continue-at - \
         --connect-timeout 15 --max-time 600 \
         -O "https://f-droid.org/repo/${pkg}_${ver}.apk"
}

github_download() {
    # curl -fsSL -O "$(curl -fsSL https://api.github.com/repos/$1/releases/latest | jq -r '.assets[] | select(.name|endswith(".apk")) | .browser_download_url' | head -n1)";
    repo=$1
    ext=${2:-apk}

    url=$(curl -fsSL --retry 3 --connect-timeout 10 \
        "https://api.github.com/repos/$repo/releases/latest" \
        | jq -r ".assets[] | select(.name|endswith(\".$ext\")) | .browser_download_url" \
        | head -n1) || return 1

    [ -n "$url" ] || { echo "No .$ext asset found"; return 1; }

    curl --silent -fL --retry 5 --retry-delay 2 --retry-connrefused --continue-at - \
         --connect-timeout 15 --max-time 600 \
         -O "$url"
}


gitlab_download(){
    repo=$1
    ext=${2:-apk}

    url=$(curl -fsSL --retry 3 --connect-timeout 10 \
        "https://gitlab.com/api/v4/projects/$(printf '%s' "$repo" | jq -sRr @uri)/releases" \
        | jq -r '.[0].assets.links[]?.url' \
        | grep -E "\.${ext}$" \
        | head -n1) || return 1

    [ -n "$url" ] || { echo "No .$ext asset found"; return 1; }

    curl --silent -fL --retry 5 --retry-delay 2 --retry-connrefused --continue-at - \
         --connect-timeout 15 --max-time 600 \
         -O "$url"
}

download_url https://s3.amazonaws.com/outline-releases/client/android/stable/Outline-Client.apk
download_url https://s3.amazonaws.com/outline-releases/client/windows/stable/Outline-Client.exe
download_url https://s3.amazonaws.com/outline-releases/manager/windows/stable/Outline-Manager.exe

download_url https://hide.me/download/android/apk

github_download shadowsocks/shadowsocks-android
github_download shadowsocks/shadowsocks-windows zip

fdroid_download net.openconnect_vpn.android
gitlab_download openconnect/openconnect-gui exe

set_hostname
port=$(python3 -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1]);s.close()')
echo '''iOS
 anyconnect: https://apps.apple.com/us/app/cisco-secure-client/id1135064690
    outline: https://apps.apple.com/us/app/outline-app/id1356177741
'''
echo "Download Android/Windows clients from http://$PUBLIC_HOSTNAME:$port"
python3 -m http.server "$port" --bind 0.0.0.0 | grep -v '^Serving HTTP on'
