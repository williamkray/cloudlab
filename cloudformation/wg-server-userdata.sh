#!/usr/bin/env bash

## installs and configures wireguard to be used as a vpn
## this has been tested on amazon-linux-2 only!

set -e

## set some variables we can use throughout this script
wg_scripts_prefix="/etc/wireguard/scripts"
wg_interface_name="wg0"
wg_server_address="192.168.100.1/24"
wg_server_port="51820"

## install wireguard from private repositories online
curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
#yum install -y epel-release
yum install -y wireguard-dkms wireguard-tools

## generate scripts to run when bringing the interface up/down
mkdir -p $wg_scripts_prefix

cat << EOF > ${wg_scripts_prefix}/postup.sh
#!/usr/bin/env bash

## set private key for this interface
wg set $wg_interface_name private-key /etc/wireguard/keys/privatekey

## update peer configuration
${wg_scripts_prefix}/update_peers.sh

## enable network forwarding and configure iptables
## to forward traffic from $wg_interface_name to eth0
sysctl net.ipv4.ip_forward=1
iptables -A FORWARD -i $wg_interface_name -j ACCEPT
iptables -A FORWARD -o $wg_interface_name -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
EOF

cat << EOF > ${wg_scripts_prefix}/postdown.sh
#!/usr/bin/env bash
## drop extra routing rules
iptables -D FORWARD -i $wg_interface_name -j ACCEPT
iptables -D FORWARD -o $wg_interface_name -j ACCEPT
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

cat << EOF > ${wg_scripts_prefix}/update_peers.sh
#!/usr/bin/env bash
## drop any peers that may have been added but no longer exist as configs
added_peers="\$(wg show ${wg_interface_name} | grep 'peer:' | awk '{print \$2}')"
for peer in \$added_peers; do
  if [[ -z "\$(grep \$peer /etc/wireguard/peers/*)" ]]; then
    wg set $wg_interface_name \$peer remove
  fi
done

## add any peer files that might exist
## need to populate these files somehow
for peer in \$(ls /etc/wireguard/peers/); do
  wg addconf $wg_interface_name /etc/wireguard/peers/\$peer
done
EOF

chmod +x ${wg_scripts_prefix}/*.sh

## add a directory to keep track of all peer config files
mkdir -p /etc/wireguard/peers

## add a systemd override that uses our update script above
## whenever systemctl reload wg-quick@interface is run
mkdir -p /etc/systemd/system/wg-quick@.service.d
if ! [[ -f /etc/systemd/system/wg-quick@.service.d/override.conf ]]; then
  cat << EOF > /etc/systemd/system/wg-quick@.service.d/override.conf
[Service]
ExecReload=${wg_scripts_prefix}/update_peers.sh
EOF
fi
systemctl daemon-reload

## generate a config file for this server so we can use wg-quick
## we don't need a fancy prefix for the config file itself
## because this is a software default path
## however, we do resolve the pre/post scripts prefix
cat << EOF > /etc/wireguard/$wg_interface_name.conf
[Interface]
Address = $wg_server_address
ListenPort = $wg_server_port
PostUp = ${wg_scripts_prefix}/postup.sh
PostDown = ${wg_scripts_prefix}/postdown.sh
EOF

chmod 600 /etc/wireguard/$wg_interface_name.conf

## generate our server's public and private keys for identity/auth/encryption
## we don't do this ahead of time so we can store the private key more securely
## need to make this more resilient (store/pull from s3 bucket?)
mkdir -p /etc/wireguard/keys/
if ! [[ -f /etc/wireguard/keys/privatekey ]]; then
  wg genkey > /etc/wireguard/keys/privatekey && chmod 600 /etc/wireguard/keys/privatekey
  wg pubkey < /etc/wireguard/keys/privatekey > /etc/wireguard/keys/pubkey
fi

## start the wireguard interface
systemctl enable wg-quick@${wg_interface_name}
systemctl start wg-quick@${wg_interface_name}

## from here on down, this doesn't have anything to do with the server itself,
## this is just to make it easier to connect clients to the server.

## generate a peer config file that clients can use to connect to this instance
## to-do: make this an action that can be triggered externally, and push the config
## somewhere that the client/user can download it securely to use it
server_pubkey="$(cat /etc/wireguard/keys/pubkey)"
server_hostname="$(hostname)"
server_endpoint="$(curl -s whatismyip.akamai.com):${wg_server_port}"
## include additional routes that this server should be used for...
## this includes the CIDR of the VPC it's in, or for _all_ traffic
## to be sent from clients through this VPN, use 0.0.0.0/0,::/0
#routes="0.0.0.0/0,::/0"
routes="10.0.0.0/16"

cat << EOF > /etc/wireguard/self-peer-file.conf
### $server_hostname

[Peer]
PublicKey = $server_pubkey
AllowedIPs = ${wg_server_address},${routes}
Endpoint = $server_endpoint

###
EOF

