#!/bin/bash
#

set -e

BASE_DIR=$(cd "$(dirname "$0")";pwd)
PROJECT_DIR=${BASE_DIR}

if [ ! "$(rpm -qa | grep openvpn)" ]; then
  yum install -y openvpn
  systemctl enable openvpn@server
fi
if [ ! "$(rpm -qa | grep easy-rsa)" ]; then
  yum install -y easy-rsa
fi

if [ ! -d "/etc/openvpn/easy-rsa/3" ]; then
  cp -R /usr/share/easy-rsa /etc/openvpn/
fi

cd /etc/openvpn/easy-rsa/3

if [ ! -f "/etc/openvpn/easy-rsa/3/vars" ]; then
  find / -type f -name "vars.example" | xargs -i cp {} . && mv vars.example vars
fi

if [ ! -d "/etc/openvpn/easy-rsa/3/pki" ]; then
  ./easyrsa init-pki && sleep 1s
fi

if [ ! -f "/etc/openvpn/easy-rsa/3/pki/ca.crt" ]; then
  echo | ./easyrsa build-ca nopass && sleep 1s
fi

if [ ! -f "/etc/openvpn/easy-rsa/3/pki/reqs/server.req" ]; then
  echo | ./easyrsa gen-req server nopass && sleep 1s
fi

if [ ! -f "/etc/openvpn/easy-rsa/3/pki/issued/server.crt" ]; then
  echo "yes" | ./easyrsa sign server server && sleep 1s
fi

if [ ! -f "/etc/openvpn/easy-rsa/3/pki/dh.pem" ]; then
  ./easyrsa gen-dh && sleep 1s
fi

if [ ! -d "/etc/openvpn/client/easy-rsa" ]; then
  mkdir -p /etc/openvpn/client/easy-rsa
fi

if [ ! -d "/etc/openvpn/client/easy-rsa/3" ]; then
  cp -R /usr/share/easy-rsa /etc/openvpn/client
fi

cd /etc/openvpn/client/easy-rsa/3

if [ ! -f "/etc/openvpn/client/easy-rsa/3/vars" ]; then
  find /usr/share/doc/ -type f -name "vars.example" | xargs -i cp {} . && mv vars.example vars
fi

if [ ! -d "/etc/openvpn/client/easy-rsa/3/pki" ]; then
 ./easyrsa init-pki && sleep 1s
fi

if [ ! -f "/etc/openvpn/client/3/pki/reqs/client.req" ]; then
  echo | ./easyrsa gen-req client nopass && sleep 1s
fi

cd /etc/openvpn/easy-rsa/3
./easyrsa import-req /etc/openvpn/client/easy-rsa/3/pki/reqs/client.req client && echo "yes" | ./easyrsa sign client client && sleep 1s

if [ ! -d "/etc/openvpn/certs" ]; then
  mkdir /etc/openvpn/certs
fi

if [ ! -f "/etc/openvpn/certs/dh.pem" ]; then
  cp /etc/openvpn/easy-rsa/3/pki/dh.pem /etc/openvpn/certs/
fi

if [ ! -f "/etc/openvpn/certs/ca.crt" ]; then
  cp /etc/openvpn/easy-rsa/3/pki/ca.crt /etc/openvpn/certs/
fi

if [ ! -f "/etc/openvpn/certs/server.crt" ]; then
  cp /etc/openvpn/easy-rsa/3/pki/issued/server.crt /etc/openvpn/certs/
fi

if [ ! -f "/etc/openvpn/certs/server.key" ]; then
  cp /etc/openvpn/easy-rsa/3/pki/private/server.key /etc/openvpn/certs/
fi

if [ ! -f "/etc/openvpn/client/ca.crt" ]; then
  cp /etc/openvpn/easy-rsa/3/pki/ca.crt /etc/openvpn/client/
fi

if [ ! -f "/etc/openvpn/client/client.crt" ]; then
  cp /etc/openvpn/easy-rsa/3/pki/issued/client.crt /etc/openvpn/client/
fi

if [ ! -f "/etc/openvpn/client/client.key" ]; then
  cp /etc/openvpn/client/easy-rsa/3/pki/private/client.key /etc/openvpn/client/
fi

if [ "$(firewall-cmd --state)" == "running" ]; then
  if [ ! "$(firewall-cmd --list-services | grep openvpn)" ]; then
    firewall-cmd --permanent --add-masquerade
    firewall-cmd --permanent --zone=public --add-service=openvpn
    firewalld_flag=1
  fi
  if [ "$firewalld_flag" ]; then
    firewall-cmd --reload
  fi
else
  if [ ! "$(iptables -L -n -t nat | grep 10.8.0.0/24)" ]; then
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE
  fi
fi

if ! grep -q "net.ipv4.ip_forward" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  sysctl_flag=1
fi
if [ "$sysctl_flag" ]; then
  sysctl -p
fi

if [ ! -f "/etc/openvpn/server.conf" ]; then
  cat > /etc/openvpn/server.conf << "EOF"
local 0.0.0.0
port 1194
;proto tcp
proto udp
;dev tap
dev tun
;dev-node MyTap
ca /etc/openvpn/certs/ca.crt
cert /etc/openvpn/certs/server.crt
key /etc/openvpn/certs/server.key  # This file should be kept secret
dh /etc/openvpn/certs/dh.pem

;topology subnet

server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /etc/openvpn/ipp.txt

;server-bridge 10.8.0.4 255.255.255.0 10.8.0.50 10.8.0.100
;server-bridge
;push "route 192.168.10.0 255.255.255.0"
;push "route 192.168.20.0 255.255.255.0"
;client-config-dir ccd
;route 192.168.40.128 255.255.255.248
;client-config-dir ccd
;route 10.9.0.0 255.255.255.252
;learn-address ./script

push "redirect-gateway def1 bypass-dhcp"

;push "dhcp-option DNS 208.67.222.222"
;push "dhcp-option DNS 208.67.220.220"

push "dhcp-option DNS 192.168.100.1"
client-to-client

;duplicate-cn

keepalive 10 120
cipher AES-256-CBC

;compress lz4-v2
;push "compress lz4-v2"

comp-lzo

;max-clients 100
;user nobody
;group nobody

persist-key
persist-tun
status openvpn-status.log

;log         openvpn.log

log-append  openvpn.log
verb 3
mute 20
explicit-exit-notify 1
EOF
fi

if [ ! -f "/etc/openvpn/client/client.ovpn" ]; then
  cat > /etc/openvpn/client/client.ovpn << "EOF"
client
dev tun
proto udp
remote <server> 1194
ca /etc/openvpn/client/ca.crt
cert /etc/openvpn/client/client.crt
key /etc/openvpn/client/client.key

resolv-retry infinite
nobind
mute-replay-warnings

keepalive 20 120
comp-lzo

persist-key
persist-tun
status openvpn-status.log
log-append openvpn.log
verb 3
mute 20
EOF
fi

if [ ! "$(systemctl status openvpn@server | grep Active | grep running)" ]; then
  systemctl start openvpn@server
fi

exit 0
