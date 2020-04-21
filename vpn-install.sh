#!/bin/bash
## DEV NOTES
### Make everything testable to let the user know what failed.
### Currently only for aptitude based OS
### Consider nuking the replacements for server.conf and client.conf and just custom making a file.
### Look into hardening on docs
# Install OpenVPN
echo -e "[ + ] Installing OpenVPN"
sudo apt-get update && sudo apt-get install openvpn -y
echo -e "[ + ] Installing Persistant iptables"
sudo apt-get install iptables-persistent -y
# Get EasyRSA for signing keys and certs
echo -e "[ + ] Get EasyRSA for signing keys and certs."
mkdir ~/OpenVPN
cd ~/OpenVPN
wget -P ~/ https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.4/EasyRSA-3.0.4.tgz
tar -xzf ~/EasyRSA-3.0.4.tgz
# Creating simulated separate servers.
mv ~/OpenVPN/EasyRSA-3.0.4 ~/OpenVPN/CA
mkdir ~/OpenVPN/Server
cp -r ~/OpenVPN/CA/* ~/OpenVPN/Server/
cd ~/OpenVPN/CA
#cp ~/OpenVPN/CA/vars.example ~/OpenVPN/CA/vars


echo -e "[ + ] Generating Certificates & Keys"
read -p 'Country: ' reqCountry
read -p 'State/Province: ' reqState
read -p 'City: ' reqCity
read -p 'Organization: ' reqOrganization
read -p 'Email: ' reqEmail
read -p 'Department: ' reqUnit

## But an if-else loop here for confirming info.

echo "set_var EASYRSA_REQ_COUNTRY '$reqCountry'" >> ~/OpenVPN/CA/vars
echo "set_var EASYRSA_REQ_PROVINCE '$reqState'" >> ~/OpenVPN/CA/vars
echo "set_var EASYRSA_REQ_CITY '$reqCity'" >> ~/OpenVPN/CA/vars
echo "set_var EASYRSA_REQ_ORG '$reqOrganization'" >> ~/OpenVPN/CA/vars
echo "set_var EASYRSA_REQ_EMAIL '$reqEmail'" >> ~/OpenVPN/CA/vars
echo "set_var EASYRSA_REQ_OU '$reqUnit'" >> ~/OpenVPN/CA/vars
# Create certs and keys
./easyrsa init-pki
echo "vpn" | ./easyrsa build-ca nopass
cd ~/OpenVPN/Server
./easyrsa init-pki
echo "server" | ./easyrsa gen-req server nopass
sudo cp ~/OpenVPN/Server/pki/private/server.key /etc/openvpn
cd ~/OpenVPN/CA/
./easyrsa import-req ~/OpenVPN/Server/pki/reqs/server.req server
## Another prompt
echo "yes" | ./easyrsa sign-req server server
sudo cp ~/OpenVPN/CA/pki/issued/server.crt /etc/openvpn
sudo cp ~/OpenVPN/CA/pki/ca.crt /etc/openvpn
cd ~/OpenVPN/Server
./easyrsa gen-dh
openvpn --genkey --secret ta.key
sudo cp ~/OpenVPN/Server/ta.key /etc/openvpn
sudo cp ~/OpenVPN/Server/pki/dh.pem /etc/openvpn
mkdir -p ~/client-configs/keys
chmod -R 700 ~/client-configs ############ BE SURE TO WHEN THE SCRIPT IS DONE chmod 400 this.
## Prompt 'How many clients do you have?', then loop that many times. 
####################
echo "" | ./easyrsa gen-req client1 nopass
cp ~/OpenVPN/Server/pki/private/client1.key ~/client-configs/keys/
cd ~/OpenVPN/CA
./easyrsa import-req ~/OpenVPN/Server/pki/reqs/client1.req client1 ####
## Another prompt
echo "yes" | ./easyrsa sign-req client client1
cp ~/OpenVPN/CA/pki/issued/client1.crt ~/client-configs/keys/
####################
cp ~/OpenVPN/Server/ta.key ~/client-configs/keys/
sudo cp /etc/openvpn/ca.crt ~/client-configs/keys/
 echo -e "[ + ] Customizing server configuration" 



# Customize server.conf file
#sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
#sudo gzip -d /etc/openvpn/server.conf.gz
read -p 'What port is the VPN running on? Default is [1194]: ' port
if [ $port="" ]
then
	port="1194"
fi
echo "port $port" > ~/OpenVPN/CA/server.conf
echo "ls-auth ta.key 0 # This file is secret" >> ~/OpenVPN/CA/server.conf

read -p 'TCP or UDP? Default is [udp]: ' protocol
if [ $protocol="" ]
then
	protocol="udp"
elif [ $protocol="tcp" ||  $protocol="TCP" ] 
then
	echo "explicit-exit-notify 1" >> ~/OpenVPN/CA/server.conf
fi
echo "proto $protocol" >> ~/OpenVPN/CA/server.conf
## prompt; 
### TUN = only traffic, TAP = all traffic
read -p 'All traffic goes through VPN (tap) or related traffic goes through VPN (tun)? Default is [tun]: ' type
if [ $type="" ]
then
	type="tun"
fi
echo "dev $type" >> ~/OpenVPN/CA/server.conf
echo "ca ca.crt" >> ~/OpenVPN/CA/server.conf
echo "cert server.crt" >> ~/OpenVPN/CA/server.conf
echo "key server.key" >> ~/OpenVPN/CA/server.conf
echo "dh dh.pem" >> ~/OpenVPN/CA/server.conf
echo "auth SHA256" >> ~/OpenVPN/CA/server.conf
echo "server 10.8.0.0 255.255.255.0" >> ~/OpenVPN/CA/server.conf ## This is a temporary default until you get the network determination in.
## prompt for universal access via one configuration file (security risk)
# echo "duplicate-cn" >> server.conf
echo "ifconfig-pool-persist ipp.txt" >> ~/OpenVPN/CA/server.conf
echo "user nobody" >> ~/OpenVPN/CA/server.conf
echo "group nogroup" >> ~/OpenVPN/CA/server.conf
###############
read -p 'Reaching to another network? (Y/N): ' pushAnswer
while [ $pushAnswer="Y" -o $pushAnswer="y" ]] ##########################################
do
	read -p 'Netmask Address (ex. 192.168.1.0): ' netAddress
	read -p 'Subnet Mask (ex. 255.255.255.0): ' subMask
	echo 'push "route $netAddress $subMask"' >> ~/OpenVPN/CA/server.conf
	read -p "Add more networks? (Y/N): " pushAnswer
done
echo 'push "dhcp-option DNS 1.1.1.2"' >> ~/OpenVPN/CA/server.conf
echo 'push "dhcp-option DNS 1.1.1.1"' >> ~/OpenVPN/CA/server.conf
echo "keepalive 10 120" >> ~/OpenVPN/CA/server.conf
echo "comp-lzo" >> ~/OpenVPN/CA/server.conf
echo "persist-key" >> ~/OpenVPN/CA/server.conf
echo "persist-tun" >> ~/OpenVPN/CA/server.conf
echo "status openvpn-status.log" >> ~/OpenVPN/CA/server.conf
echo "verb 3" >> ~/OpenVPN/CA/server.conf
sudo cp ~/OpenVPN/CA/server.conf /etc/openvpn/
echo "net.ipv4.ip_forward=1" >> sudo tee -a /etc/sysctl.conf ############# NO PERMISSIONS
# Add iptable/firewall rules
INTERFACE="$( ip -o link show | awk '{print $2,$9}' | grep "UP" | cut -d: -f 1 | cut -d@ -f 1)"
sudo iptables -A INPUT -i $INTERFACE -m state --state NEW -p $proto --dport $port -j ACCEPT
sudo iptables -A INPUT -i $type+ -j ACCEPT
sudo iptables -A FORWARD -i $type+ -j 
sudo iptables -A FORWARD -i $type+ -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i $INTERFACE -o $type+ -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables-save > sudo tee -a /etc/iptables/rules.v4 ############# NO PERMISSIONS
# Start OpenVPN Service
echo -e "[ + ] Starting OpenVPN Server"
sudo systemctl stop openvpn@server && sudo systemctl start openvpn@server && sudo systemctl enable openvpn@server
echo -e "[ + ] OpenVPN Server Running!"
# Create Client Configuration
echo -e "[ + ] Create Client Configs"
# How many clients?
mkdir -p ~/client-configs/files
#cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/client-configs/base.conf
cd ~/client-configs/
read -p "Public Gateway IP: " ip
echo "client" > ~/client-configs/base.conf
echo "$dev $type" >> ~/client-configs/base.conf
echo "proto $protcol" >> ~/client-configs/base.conf
echo "remote $ip $port" >> ~/client-configs/base.conf
echo "resolv-retry-infinite" >> ~/client-configs/base.conf
echo "nobind" >> ~/client-configs/base.conf
echo "user nobody" >> ~/client-configs/base.conf
echo "group nogroup" >> ~/client-configs/base.conf
echo "persist-key" >> ~/client-configs/base.conf
echo "persist-tun" >> ~/client-configs/base.conf
echo "ca ca.crt" >> ~/client-configs/base.conf
echo "cert client.crt" >> ~/client-configs/base.conf
echo "cert client.key" >> ~/client-configs/base.conf
echo "tls-auth ta.key 1" >> ~/client-configs/base.conf
echo "auth SHA256" >> ~/client-configs/base.conf
echo "remote-cert-tls server" >> ~/client-configs/base.conf
echo "comp-lzo" >> ~/client-configs/base.conf
echo "verb 3" >> ~/client-configs/base.conf
echo "key-direction 1" >> ~/client-configs/base.conf
if [ $protocol="tcp" ] 
then
	echo "explicit-exit-notify 1" >> ~/client-configs/base.conf
fi
# if reading "Are there any linux clients that will be connected?". If yes, add the following lines.
# script-security 2
# up /etc/openvpn/update-resolv-conf
# down /etc/openvpn/update-resolv-conf
touch ~/client-configs/make_config.sh
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
read -p 'How many individuals will need their own unique connection file?: ' numClients
for i in {0..$numClients}
do
	./make_config.sh client$i
done
echo -e "[ * ] VPN client configs generated"
cp ~/client-configs/clients/client*.ovpn ~/Desktop/
echo -e "[ + ] Locking down VPN setup files"
# chattr too
sudo chmod -R 400 ~/client-configs ############ Added this line. Take out if problems copying.
sudo chmod -R 000 ~/OpenVPN/CA
sudo chmod -R 400 ~/OpenVPN/Server
cd ~/client-configs/clients/
echo -e "[ + ] FINISHED! VPN Setup complete!"    