#!/bin/bash
# https://github.com/Jigsaw-Code/outline-server/blob/master/src/server_manager/install_scripts/install_server.sh
# https://github.com/Jigsaw-Code/outline-server/tree/master/src/shadowbox#access-keys-management-api
# https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/shadowbox/server/api.yml
# TODO: apt install qrencode

ACCESS_CONFIG=/opt/outline/access.txt
apiUrl=$(sudo grep "apiUrl" $ACCESS_CONFIG | sed "s/^apiUrl://")
certSha256=$(sudo grep "apiUrl" $ACCESS_CONFIG | sed "s/^certSha256://")
pinnedPubkey=$(sudo grep "apiUrl" $ACCESS_CONFIG | sed "s/^pinnedPubkey://")
# https://curl.haxx.se/libcurl/c/CURLOPT_PINNEDPUBLICKEY.html
SB_CERTIFICATE_FILE=/opt/outline/persisted-state/shadowbox-selfsigned.crt
pinnedPubkey=$(sudo openssl x509 -in "${SB_CERTIFICATE_FILE}" -pubkey -noout | openssl asn1parse -noout -inform pem -out - | openssl dgst -sha256 -binary | openssl base64)


#apiUrl="$(get_field_value apiUrl)"
#pinnedPubkey="$(get_field_value pinnedPubkey)"
#pinnedPubkey=$(openssl x509 -in "${SB_CERTIFICATE_FILE}" -pubkey -noout | openssl asn1parse -noout -inform pem -out - | openssl dgst -sha256 -binary | openssl base64)

echo
echo "To connect to your Outline Server, please copy one of the following access keys"
echo "into the Outline/Shadowsocks Client:"
echo -e "\033[1;32m"
# https://api.qrserver.com/v1/create-qr-code?data=
#curl --max-time 5 --cacert "${SB_CERTIFICATE_FILE}" -s "${PUBLIC_API_URL}/access-keys"
curl --silent --insecure --pinnedpubkey "sha256//$pinnedPubkey" "${apiUrl}/access-keys" | jq -r '.[] | map(.accessUrl) | .[]'
echo -e "\033[0m"

curl --silent --insecure --pinnedpubkey "sha256//$pinnedPubkey" "${apiUrl}/access-keys" | jq -r '.[] | map(.accessUrl) | .[]' | xargs printf 'echo -n "%s" | qrencode -t UTF8\n'| head -n 1 | bash -

echo
echo "Add more users, run:"
echo -e "\033[1;32m"
echo "export apiUrl=\"${apiUrl}\" pinnedPubkey=\"${pinnedPubkey}\""
echo "curl --silent --insecure --pinnedpubkey \"sha256//$pinnedPubkey\" \"$apiUrl/access-keys/\" -X POST | jq -r .accessUrl"
echo -e "\033[0m"
echo "For more info, visit https://getoutline.org"


cat <<END_OF_SERVER_OUTPUT
To manage your Outline server, please copy the following line (including curly
brackets) into Step 2 of the Outline Manager interface:

$(echo -e "\033[1;32m{\"apiUrl\":\"${apiUrl}\",\"certSha256\":\"${certSha256}\"}\033[0m")
END_OF_SERVER_OUTPUT

# curl --silent --insecure "${apiUrl}/metrics/transfer" | jq .
# curl -X PUT -d '{limit: {bytes: 1024000000}}' --silent --insecure "${apiUrl}/access-keys/{id}/data-limit" | jq .
# curl -X DELETE --silent --insecure "${apiUrl}/access-keys/{id}/data-limit" | jq .
# docker restart $(docker ps --filter "name=shadowbox" --quiet)
