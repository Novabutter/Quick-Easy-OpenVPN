#!/bin/sh
## DEV NOTES
### Make everything testable to let the user know what failed.
### Currently only for aptitude based OS
# Install OpenVPN
echo -e "[ + ] Installing OpenVPN"
apt-get update && apt-get install openvpn -y
echo -e "[ + ] Installing Persistant iptables"
apt-get install iptables-persistent -y
# Get EasyRSA for signing keys and certs
echo -e "[ + ] Get EasyRSA for signing keys and certs."
mkdir ~/OpenVPN
cd ~/OpenVPN
wget -P ~/ https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.4/EasyRSA-3.0.4.tgz
tar -xzvf EasyRSA-3.0.4.tgz ~/OpenVPN/
# Creating simulated separate servers.
mv ~/OpenVPN/EasyRSA-3.0.4 CA
cp -r ~/OpenVPN/CA ~/OpenVPN/Server
cd ~/OpenVPN/CA
cp ~/OpenVPN/CA/vars.example ~/OpenVPN/CA/vars
echo -e "[ + ] Generating Certificates & Keys"
read -p '\n\nCountry: ' reqCountry
read -p '\nState/Province: ' reqState
read -p '\nCity: ' reqCity
read -p '\nOrganization: ' reqOrganization
read -p '\nEmail: ' reqEmail
read -p '\nDepartment: ' reqUnit
# sed -i 's/old-text/new-text/g' input.txt
## But an if-else loop here for confirming info.
sed -i "s/'#set_var EASYRSA_REQ_COUNTRY*'/'set_var EASYRSA_REQ_COUNTRY\t$reqCountry'/g" vars
sed -i "s/'#set_var EASYRSA_REQ_PROVINCE*'/'set_var EASYRSA_REQ_PROVINCE\t$reqState'/g" vars
sed -i "s/'#set_var EASYRSA_REQ_CITY*'/'set_var EASYRSA_REQ_CITY\t$reqCity'/g" vars
sed -i "s/'#set_var EASYRSA_REQ_ORG*'/'set_var EASYRSA_REQ_ORG\t$reqOrganization'/g" vars
sed -i "s/'#set_var EASYRSA_REQ_EMAIL*'/'set_var EASYRSA_REQ_EMAIL\t$reqEmail'/g" vars
sed -i "s/'#set_var EASYRSA_REQ_OU*'/'set_var EASYRSA_REQ_OU\t$reqUnit'/g" vars
# Create certs and keys
.~/OpenVPN/CA/easyrsa init-pki
## Experementing with piping the expected prompt of a common name
## Another way to do it if this fails: echo "Y Y N N Y N Y Y N" | ./your_script
.~/OpenVPN/CA/easyrsa build-ca nopass | vpn
cd ~/OpenVPN/Server
.~/OpenVPN/Server/easyrsa init-pki
.~/OpenVPN/Server/easyrsa gen-req server nopass
cp ~/OpenVPN/Server/pki/private/server.key /etc/openvpn
cd ~/OpenVPN/CA/
.~/OpenVPN/CA/easyrsa import-req ~/OpenVPN/Server/pki/reqs/server.req server
## Another prompt
.~/OpenVPN/CA/easyrsa sign-req server server | yes
cp ~/OpenVPN/CA/pki/issued/server.crt /etc/openvpn
cp ~/OpenVPN/CA/pki/ca.crt /etc/openvpn
cd ~/OpenVPN/Server
.~/OpenVPN/Server/easyrsa gen-dh
openvpn --genkey --secret ta.key
cp ~/OpenVPN/Server/ta.key /etc/openvpn
cp ~/OpenVPN/Server/pki/dh.pem /etc/openvpn
mkdir -p ~/client-configs/keys
chmod -R 700 ~/client-configs ############ BE SURE TO WHEN THE SCRIPT IS DONE chmod 400 this.
## Prompt 'How many clients do you have?', then loop that many times.
####################
.~/OpenVPN/Server/easyrsa gen-req client1 nopass
cp ~/OpenVPN/Server/pki/private/client1.key ~/client-configs/keys/
cd ~/OpenVPN/CA
.~/OpenVPN/CA/easyrsa import-req pki/reqs/client1.req client1
## Another prompt
.~/OpenVPN/CA/easyrsa sign-req client client1 | yes
cp ~/OpenVPN/CA/pki/issued/client1.crt ~/client-configs/keys/
####################
cp ~/OpenVPN/Server/ta.key ~/client-configs/keys/
cp /etc/openvpn ~/client-configs/keys/
echo -e "[ + ] Customizing server configuration"
# Customize server.conf file
cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
gzip -d /etc/openvpn/server.conf.gz
sed -i "s/'*tls-auth ta.key 0 # This file is secret'/'tls-auth ta.key 0 # This file is secret'/g" server.conf
## prompt; if port != 1194, then set sed replace port
## prompt tap or tun; if != tun, sed -i "s/*'dev tun'/';dev tun'/g" server.conf sed -i "s/*';dev tap'/'dev tap'/g" server.conf type=tap else type=tun
## prompt tcp or udp; if != udp, sed -i "s/*'proto udp'/';proto udp'/g" server.conf sed -i"s/*';proto tcp'/'proto tcp'/g" server.conf sed -i "s/*'explicit-exit-notify 0'/'explicit-exit-notify 1'/g" server.conf proto=tcp else proto=udp
echo "auth SHA256" >> /etc/openvpn/server.conf
sed -i "^.*dh*/s/*dh*/'dh dh.pem'/g"
sed -i "s/*user*/'user nobody'/g"
sed -i "s/*group*/'group nogroup'/g"
## prompt force all traffic through secure VPN? if yes sed -i "s/*'push "redirect-gateway def1 bypass-dhcp"'/'push "redirect-gateway def1 bypass-dhcp"'/g" server.conf
### echo 'push "dhcp-option DNS 208.67.222.222"' >> /etc/openvpn/server.conf
###echo 'push "dhcp-option DNS 208.67.220.220"' >> /etc/openvpn/server.conf
## prompt for adding other push networks.
### Need mechanism for determining netmask
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
# Add iptable/firewall rules
INTERFACE="$( ip -o link show | awk '{print $2,$9}' | grep "UP" | cut -d: -f 1 | cut -d@ -f 1)"
iptables -A INPUT -i $INTERFACE -m state --state NEW -p $proto --dport $port -j ACCEPT
iptables -A INPUT -i $type+ -j ACCEPT
iptables -A FORWARD -i $type+ -j 
iptables -A FORWARD -i $type+ -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $INTERFACE -o $type+ -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables-save > /etc/iptables/rules.v4
# Start OpenVPN Service
echo -e "[ + ] Starting OpenVPN Server"
systemctl start openvpn@server && systemctl enable openvpn@server
echo -e "[ + ] OpenVPN Server Running!"
# Create Client Configuration
echo -e "[ + ] Create Client Configs"
# How many clients?
mkdir -p ~/client-configs/files
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/client-configs/base.conf
cd ~/client-configs/base.conf
read -p "\nPublic Gateway IP: " ip
sed -i "s/my-server-1*/$ip\t$port/g" ~/client-configs/base.conf
# if != udp, sed -i "s/*'proto udp'/';proto udp'/g" server.conf sed -i"s/*';proto tcp'/'proto tcp'/g" server.conf sed -i "s/*'explicit-exit-notify 0'/'explicit-exit-notify 1'/g" server.conf
sed -i "s/*user*/'user nobody'/g"
sed -i "s/*group*/'group nogroup'/g"
sed -i "s/*'ca ca.crt'*/'#ca ca.crt'"
sed -i "s/*'key client.key'*/'#key client.key'"
sed -i "s/*'cert client.crt'*/'#cert client.crt'"
sed -i "s/*'tls-auth ta.key 1'*/'#tls-auth ta.key 1'"
echo "auth SHA256" >> ~/client-configs/base.conf
key-direction 1
# if reading "Are there any linux clients that will be connected?". If yes, add the following lines.
# script-security 2
# up /etc/openvpn/update-resolv-conf
# down /etc/openvpn/update-resolv-conf
mkdir -p ~/client-configs/make_config.sh
mkdir -p ~/client-configs/clients
cd ~/client-configs
echo "#!/bin/bash" > ~/client-configs/make_config.sh
echo "KEY_DIR=~/client-configs/keys" >> ~/client-configs/make_config.sh
echo "OUTPUT_DIR=~/client-configs/clients" >> ~/client-configs/make_config.sh
echo "BASE_CONFIG=~/client-configs/base.conf" >> ~/client-configs/make_config.sh
echo "cat ${BASE_CONFIG} \ " >> ~/client-configs/make_config.sh
echo "<(echo -e '<ca>') \ " >> ~/client-configs/make_config.sh
echo "${KEY_DIR}/ca.crt \ " >> ~/client-configs/make_config.sh
echo "<(echo -e '</ca>\n<cert>') \ " >> ~/client-configs/make_config.sh
echo "${KEY_DIR}/${1}.crt \ " >> ~/client-configs/make_config.sh
echo "<(echo -e '</cert>\n<key>') \ " >> ~/client-configs/make_config.sh
echo "${KEY_DIR}/${1}.key \ " >> ~/client-configs/make_config.sh
echo "<(echo -e '</key>\n<tls-auth>') \ " >> ~/client-configs/make_config.sh
echo "${KEY_DIR}/ta.key \ " >> ~/client-configs/make_config.sh
echo "<(echo -e '</tls-auth>') \ " >> ~/client-configs/make_config.sh
echo "> ${OUTPUT_DIR}/${1}.ovpn " >> ~/client-configs/make_config.sh
chmod 700 ~/client-configs/make_config.sh
cd ~/client-configs
# for i amount of times to generate clients, generate client[i]
./make_config.sh client1
echo -e "[ * ] VPN client configs generated"
echo -e "[ + ] Locking down VPN setup files"
chmod -R 400 ~/client-configs ############ Added this line. Take out if problems copying.
chmod -R 000 ~/OpenVPN/CA
chmod -R 400 ~/OpenVPN/Server
cd ~/client-configs/clients
echo -e "[ + ] FINISHED! VPN Setup complete!"

    
    
    
    
    
    
    
    
    