#!/bin/bash

#sudo docker build -t ocserv https://github.com/iw4p/OpenConnect-Cisco-AnyConnect-VPN-Server-OneKey-ocserv.git
sudo docker build -t ocserv https://github.com/schemacs/ocserv-docker.git

sudo docker run --name ocserv --privileged -p 8443:443 -p 8443:443/udp -d ocserv

sudo ufw disable

#sudo docker exec -ti ocserv ocpasswd -c /etc/ocserv/ocpasswd YOUR-USER-NAME


