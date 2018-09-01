#!/usr/bin/env bash

## install wireguard from private repositories online
curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
yum install -y epel-release
yum install -y wireguard-dkms wireguard-tools

## add a wireguard network interface called wg0
## also give it a static IP in the 192.168.0.x cidr block
ip link add dev wg0 type wireguard
ip addr add 192.168.0.1/24 dev wg0

## generate our server's public and private keys for identity/auth/encryption
## need to make this more resilient (store/pull from s3 bucket?)
mkdir -p /etc/wireguard/keys/
wg genkey > /etc/wireguard/keys/privatekey && chmod 600 /etc/wireguard/keys/privatekey
wg pubkey < /etc/wireguard/keys/privatekey > /etc/wireguard/keys/pubkey
wg set wg0 private-key /etc/wireguard/keys/privatekey

## enable network forwarding and configure iptables
## to forward traffic from wg0 to eth0
sysctl net.ipv4.ip_forward=1
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

## configure wireguard interface
wg set wg0 listen-port 51820

## peer configuration, needs to be dynamically configured!
wg set wg0 peer 3OQOC1uEV0EEzcSgB64j6Q236oIt52mDU2BPUmVo9Ck= \
  allowed-ips 192.168.0.2/32 # only allows this peer to connect when its wireguard interface has this ip address

# enable our network device wg0
ip link set wg0 up

# client
#ip route add 10.0.0.0/16 dev wg0
#wg set wg0 peer PNxVoRiDWcFlxKDRCZhevH9I2eVYPimdej//f1Amai8= \
#  allowed-ips 192.168.0.1/32,10.0.0.0/16 \
#  endpoint 54.218.21.142:51820

