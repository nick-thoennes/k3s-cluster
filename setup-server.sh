#!/bin/bash

#setup network
cat > /etc/netplan/99_config.yaml << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0:
      addresses:
        - 192.168.3.2/24
      routes:
        - to: default
          via: 192.168.3.1
      nameservers:
          search: [cluster]
          addresses: [192.168.3.1, 1.1.1.1]
EOF
netplan apply
echo "setup-server>> network has been updated"

#update apt
apt update -y > /dev/null
apt upgrade -y > /dev/null
echo "setup-server>> apt has been updated and upgraded"

#install isc-dhcp-server
apt install isc-dhcp-server -y > /dev/null
sed -i 's/^INTERFACESv4=.*$/INTERFACESv4="enp3s0"/' /etc/default/isc-dhcp-server
cat > /etc/dhcp/dhcpd.conf << 'EOF'
# dhcpd.conf
#
# Sample configuration file for ISC dhcpd
#
# Attention: If /etc/ltsp/dhcpd.conf exists, that will be used as
# configuration file instead of this file.
#

# option definitions common to all supported networks...
option domain-name "cluster.lab";
option domain-name-servers 192.168.3.1, 1.1.1.1;

default-lease-time 600;
max-lease-time 7200;

# The ddns-updates-style parameter controls whether or not the server will
# attempt to do a DNS update when a lease is confirmed. We default to the
# behavior of the version 2 packages ('none', since DHCP v2 didn't
# have support for DDNS.)
ddns-update-style none;

# If this DHCP server is the official DHCP server for the local
# network, the authoritative directive should be uncommented.
authoritative;

# Use this to send dhcp log messages to a different log file (you also
# have to hack syslog.conf to complete the redirection).
#log-facility local7;

# No service will be given on this subnet, but declaring it helps the
# DHCP server to understand the network topology.

#subnet 10.152.187.0 netmask 255.255.255.0 {
#}

# This is a very basic subnet declaration.

#subnet 10.254.239.0 netmask 255.255.255.224 {
#  range 10.254.239.10 10.254.239.20;
#  option routers rtr-239-0-1.example.org, rtr-239-0-2.example.org;
#}

# This declaration allows BOOTP clients to get dynamic addresses,
# which we don't really recommend.

#subnet 10.254.239.32 netmask 255.255.255.224 {
#  range dynamic-bootp 10.254.239.40 10.254.239.60;
#  option broadcast-address 10.254.239.31;
#  option routers rtr-239-32-1.example.org;
#}

# A slightly different configuration for an internal subnet.
#subnet 10.5.5.0 netmask 255.255.255.224 {
#  range 10.5.5.26 10.5.5.30;
#  option domain-name-servers ns1.internal.example.org;
#  option domain-name "internal.example.org";
#  option subnet-mask 255.255.255.224;
#  option routers 10.5.5.1;
#  option broadcast-address 10.5.5.31;
#  default-lease-time 600;
#  max-lease-time 7200;
#}

# Hosts which require special configuration options can be listed in
# host statements.   If no address is specified, the address will be
# allocated dynamically (if possible), but the host-specific information
# will still come from the host declaration.

#host passacaglia {
#  hardware ethernet 0:0:c0:5d:bd:95;
#  filename "vmunix.passacaglia";
#  server-name "toccata.example.com";
#}

# Fixed IP addresses can also be specified for hosts.   These addresses
# should not also be listed as being available for dynamic assignment.
# Hosts for which fixed IP addresses have been specified can boot using
# BOOTP or DHCP.   Hosts for which no fixed address is specified can only
# be booted with DHCP, unless there is an address range on the subnet
# to which a BOOTP client is connected which has the dynamic-bootp flag
# set.
#host fantasia {
#  hardware ethernet 08:00:07:26:c0:a5;
#  fixed-address fantasia.example.com;
#}

# You can declare a class of clients and then do address allocation
# based on that.   The example below shows a case where all clients
# in a certain class get addresses on the 10.17.224/24 subnet, and all
# other clients get addresses on the 10.0.29/24 subnet.

#class "foo" {
#  match if substring (option vendor-class-identifier, 0, 4) = "SUNW";
#}

#shared-network 224-29 {
#  subnet 10.17.224.0 netmask 255.255.255.0 {
#    option routers rtr-224.example.org;
#  }
#  subnet 10.0.29.0 netmask 255.255.255.0 {
#    option routers rtr-29.example.org;
#  }
#  pool {
#    allow members of "foo";
#    range 10.17.224.10 10.17.224.250;
#  }
#  pool {
#    deny members of "foo";
#    range 10.0.29.10 10.0.29.230;
#  }
#}
#
# in this example, we serve DHCP requests from 192.168.0.(3 to 253)
# and we have a router at 192.168.0.1
subnet 192.168.3.0 netmask 255.255.255.0 {
  range 192.168.3.15 192.168.3.253;
  option broadcast-address 192.168.3.255;
  option routers 192.168.3.1;             # our router
  option domain-name-servers 192.168.3.1; # our router has DNS functionality
  next-server 192.168.3.2;
  filename "bootx64.efi";
}
EOF
systemctl start isc-dhcp-server > /dev/null
systemctl enable isc-dhcp-server > /dev/null
echo "setup-server>> dhcp has been installed and set up"

#install tftp-hpa
apt install tftp > /dev/null
apt install tftpd-hpa > /dev/null
sed -i 's/^TFTP_ADDRESS=":69".*$/TFTP_ADDRESS="0.0.0.0:69"/' /etc/default/tftpd-hpa
mkdir /srv/tftp/
chmod 777 -R /srv/*
echo "setup-server>> tftp has been installed and set up"

#install python3
apt install python3 > /dev/null
echo "setup-server>> python3 has been installed and set up"

#setup tftp and grub
cd /srv/tftp/
wget https://mirror.math.princeton.edu/pub/ubuntu-iso/22.04.3/ubuntu-22.04.3-live-server-amd64.iso
mv ubuntu-22.04.3-live-server-amd64.iso jammy.iso
mount jammy.iso /mnt/
cp -r /mnt/* .
umount /mnt/
touch user-data
touch meta-data
cp /usr/lib/grub/x86_64-efi-signed/grubnetx64.efi.signed .
mv grubnetx64.efi.signed bootx64.efi
rm -r grub/
mkdir grub/
touch grub/grub.cfg
cat > grub/grub.cfg << 'EOF'
set gfxpayload=keep
linux   vmlinuz ip=dhcp cloud-config-url=/dev/null url=http://192.168.3.2:3003/jammy.iso autoinstall ds="nocloud-net;s=http://192.168.3.2:3003/" ---
initrd  initrd
boot
EOF
cp casper/initrd .
cp casper/vmlinuz .
echo "setup-server>> grub and install files have been set up"

#setup user-data and start an HTTP server in jammy
cat > user-data << 'EOF'
#cloud-config
autoinstall:
  apt:
    disable_components: []
    fallback: abort
    geoip: true
    mirror-selection:
      primary:
      - country-mirror
      - arches:
        - amd64
        - i386
        uri: http://archive.ubuntu.com/ubuntu
      - arches:
        - s390x
        - arm64
        - armhf
        - powerpc
        - ppc64el
        - riscv64
        uri: http://ports.ubuntu.com/ubuntu-ports
    preserve_sources_list: false
  codecs:
    install: false
  drivers:
    install: false
  identity:
    hostname: new_host
    password: "$6$exDY1mhS4KUYCE/2$zmn9ToZwTKLhCw.b4/b.ZRTIZM30JZ4QrOQ2aOXJ8yk96xpcCof0kxKwuX1kqLG/ygbJ1f8wxED22bTL4F46P0"
    username: ubuntu
  kernel:
    package: linux-generic
  keyboard:
    layout: us
    toggle: null
    variant: ''
  locale: en_US.UTF-8
  network:
    ethernets:
      enp1s0:
        dhcp4: true
    version: 2
  source:
    id: ubuntu-server
    search_drivers: false
  ssh:
    allow-pw: true
    authorized-keys: []
    install-server: true
  storage:
    layout:
      name: lvm
  updates: security
  version: 1
EOF
chmod 777 -R /tft/*
systemctl restart tftpd-hpa
systemctl restart isc-dhcp-server
python3 -m http.server 3003