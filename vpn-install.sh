#!/bin/bash
## DEV NOTES
### Make everything testable to let the user know what failed.
### Currently only for aptitude based OS
### Look into hardening on docs
# Install OpenVPN
echo -e "[ + ] Installing OpenVPN"
sudo apt-get update 1>/dev/null && sudo apt-get install openvpn -y 1>/dev/null
echo -e "[ + ] Installing Persistant iptables"
sudo apt-get install iptables-persistent -y
# Get EasyRSA for signing keys and certs
echo -e "[ + ] Get EasyRSA for signing keys and certs."
mkdir ~/OpenVPN
cd ~/OpenVPN
wget -P ~/ https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.4/EasyRSA-3.0.4.tgz 1>/dev/null
tar -xzf ~/EasyRSA-3.0.4.tgz 1>/dev/null
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
echo "vpn" | ./easyrsa build-ca nopass 1>/dev/null
cd ~/OpenVPN/Server
./easyrsa init-pki
echo "server" | ./easyrsa gen-req server nopass 1>/dev/null
sudo cp ~/OpenVPN/Server/pki/private/server.key /etc/openvpn
cd ~/OpenVPN/CA/
./easyrsa import-req ~/OpenVPN/Server/pki/reqs/server.req server
## Another prompt
echo "yes" | ./easyrsa sign-req server server 1>/dev/null
sudo cp ~/OpenVPN/CA/pki/issued/server.crt /etc/openvpn
mkdir -p ~/client-configs/keys
cp ~/OpenVPN/CA/pki/ca.crt ~/client-configs/keys/ca.crt
sudo cp ~/OpenVPN/CA/pki/ca.crt /etc/openvpn
cd ~/OpenVPN/Server
./easyrsa gen-dh
openvpn --genkey --secret ta.key 1>/dev/null
sudo cp ~/OpenVPN/Server/ta.key /etc/openvpn
sudo cp ~/OpenVPN/Server/pki/dh.pem /etc/openvpn
chmod -R 700 ~/client-configs 
# read -p 'How many clients will their be? Default is [1]: ' numClients
# if [ $numClients="" ]
# then
# 	numClients="1"
# fi
# for i in {0..$numClients}
# do
	# echo "" | ./easyrsa gen-req client{$i} nopass 1>/dev/null
	# cp ~/OpenVPN/Server/pki/private/client{$i}.key ~/client-configs/keys/
	# cd ~/OpenVPN/CA
	# ./easyrsa import-req ~/OpenVPN/Server/pki/reqs/client{$i}.req client{$i} 1>/dev/null 

	# echo "yes" | ./easyrsa sign-req client client{$i}
echo "" | ./easyrsa gen-req client1 nopass 1>/dev/null
cp ~/OpenVPN/Server/pki/private/client1.key ~/client-configs/keys/
cd ~/OpenVPN/CA
./easyrsa import-req ~/OpenVPN/Server/pki/reqs/client1.req client1 1>/dev/null 

echo "yes" | ./easyrsa sign-req client client1
# done
cp ~/OpenVPN/CA/pki/issued/client1.crt ~/client-configs/keys/
####################
cp ~/OpenVPN/Server/ta.key ~/client-configs/keys/
#sudo cp /etc/openvpn/ca.crt ~/client-configs/keys/
 echo -e "[ + ] Customizing server configuration" 

# Customize server.conf file
read -p 'What port is the VPN running on? Default is [1194]: ' port
if [ -z $port ]
then
	port="1194"
fi
echo "port $port" > ~/OpenVPN/CA/server.conf
echo "tls-auth ta.key 0 # This file is secret" >> ~/OpenVPN/CA/server.conf

read -p 'TCP or UDP? Default is [udp]: ' protocol
if [[ $protocol = "tcp" || $protocol = "TCP" ]];
then
        protocol="tcp"
        notify=0
        echo "explicit-exit-notify $notify" >> ~/OpenVPN/CA/server.conf
else
        protocol="udp"
        notify=1
fi
echo $protocol $notify

echo "proto $protocol" >> ~/OpenVPN/CA/server.conf

read -p 'All traffic goes through VPN (tap) or related traffic goes through VPN (tun)? Default is [tun]: ' type
if [[ $type = "tap" || $type = "TAP" ]]
then
	type="tap"
else
	type="tun"
fi
echo "dev $type" >> ~/OpenVPN/CA/server.conf
echo "ca ca.crt" >> ~/OpenVPN/CA/server.conf
echo "cert server.crt" >> ~/OpenVPN/CA/server.conf
echo "key server.key" >> ~/OpenVPN/CA/server.conf
echo "dh dh.pem" >> ~/OpenVPN/CA/server.conf
echo "auth SHA256" >> ~/OpenVPN/CA/server.conf
echo "cipher AES-256-CBC" >> ~/OpenVPN/CA/server.conf
INTERNAL_NET="10.8.0.0/24"
# read -p 'What is the internal/virtual network? Default is [10.8.0.0]: ' internalNetAnswer
# if [ $pushAnswer != "" ]
# then
# 	read -p 'Netmask Address (ex. 192.168.2.0): ' internalAddress
# 	read -p 'Subnet Mask (ex. 255.255.255.0): ' internalsubMask
# 	echo "server $internalAddress $internalsubMask" >> ~/OpenVPN/CA/server.conf
# else
# 	INTERNAL_NET="10.8.0.0/24"
# 	echo "server 10.8.0.0 255.255.255.0" >> ~/OpenVPN/CA/server.conf
# done
 ## This is a temporary default until you get the network determination in.
echo "--- The follwing is useful to allow if using a single client profile to share ---"
read -p 'Allow multiple connections per client (potential security risk)? (Y/N): ' duplicateAllow
if [[ $duplicateAllow = "Y" || $duplicateAllow = "y" ]]
then
	echo "duplicate-cn" >> ~/OpenVPN/CA/server.conf
fi
echo "ifconfig-pool-persist ipp.txt" >> ~/OpenVPN/CA/server.conf
echo "user nobody" >> ~/OpenVPN/CA/server.conf
echo "group nogroup" >> ~/OpenVPN/CA/server.conf
read -p 'Reaching to another network? (Y/N) Default is [N]: ' pushAnswer
if [ $pushAnswer = "" ]
then
	pushAnswer="N"
fi
while [[ $pushAnswer = "Y" || $pushAnswer = "y" ]]
do
	read -p 'Netmask Address (ex. 192.168.1.0): ' netAddress
	read -p 'Subnet Mask (ex. 255.255.255.0): ' subMask
	echo "push 'route $netAddress $subMask'" >> ~/OpenVPN/CA/server.conf
	read -p "Add more networks? (Y/N): " pushAnswer
done
#echo 'push "dhcp-option DNS 1.1.1.2"' >> ~/OpenVPN/CA/server.conf
#echo 'push "dhcp-option DNS 1.1.1.1"' >> ~/OpenVPN/CA/server.conf
echo "keepalive 10 120" >> ~/OpenVPN/CA/server.conf
#echo "comp-lzo" >> ~/OpenVPN/CA/server.conf
echo "persist-key" >> ~/OpenVPN/CA/server.conf
echo "persist-tun" >> ~/OpenVPN/CA/server.conf
echo "status openvpn-status.log" >> ~/OpenVPN/CA/server.conf
echo "verb 3" >> ~/OpenVPN/CA/server.conf
sudo cp ~/OpenVPN/CA/server.conf /etc/openvpn/
echo "net.ipv4.ip_forward=1" >> sudo tee -a /etc/sysctl.conf 
# Add iptable/firewall rules
cd /sys/class/net && \
declare -i count=0 && \
declare -a ints && \
for i in *
do
        echo [$count] $i
        ints+=($i)
        count=$count+1
done
read -p "Which interface number? Default is [0] which is [${ints[0]}]: " intSelectNum
if [[ $intSelectNum -ge 0 && $intSelectNum < $count ]];
then
INTERFACE=${ints[$intSelectNum]}
else {
echo "INVALID OPTION. SETTING TO DEFAULT."
INTERFACE=${ints[0]}
}
fi
#sudo iptables -A INPUT -i $INTERFACE -m state --state NEW -p $protocol --dport $port -j ACCEPT
sudo iptables -A INPUT -i $INTERFACE -p $protocol --dport $port -j ACCEPT
sudo iptables -A INPUT -i $type+ -j ACCEPT
sudo iptables -A FORWARD -i $type+ -j ACCEPT
#sudo iptables -A FORWARD -i $type+ -o $INTERFACE -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT #Ubuntu 19 does not like -m
#sudo iptables -A FORWARD -i $INTERFACE -o $type+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT #Ubuntu 19 does not like -m
sudo iptables -A FORWARD -i $type+ -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -o $type+ -i $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -o $type+ -j ACCEPT
sudo iptables -t nat -A POSTROUTING -s $INTERNAL_NET -o $INTERFACE -j MASQUERADE
sudo iptables-save | sudo tee -a /etc/iptables/rules.v4 1>/dev/null
# Start OpenVPN Service
echo -e "[ + ] Starting OpenVPN Server"
#sudo service openvpn restart 1>/dev/null && sudo systemctl enable openvpn
sudo systemctl enable openvpn@server 1>/dev/null && sudo /etc/init.d/openvpn restart 1>/dev/null
echo -e "[ + ] OpenVPN Server Running!"
# Create Client Configuration
echo -e "[ + ] Create Client Configs"
# How many clients?
mkdir -p ~/client-configs/files
cd ~/client-configs/
read -p "Public Gateway IP: " ip
echo "client" > ~/client-configs/base.conf
echo "dev $type" >> ~/client-configs/base.conf
echo "proto $protocol" >> ~/client-configs/base.conf
echo "remote $ip $port" >> ~/client-configs/base.conf
echo "resolv-retry infinite" >> ~/client-configs/base.conf
echo "nobind" >> ~/client-configs/base.conf
echo "user nobody" >> ~/client-configs/base.conf
echo "group nogroup" >> ~/client-configs/base.conf
echo "persist-key" >> ~/client-configs/base.conf
echo "persist-tun" >> ~/client-configs/base.conf
#echo "ca ca.crt" >> ~/client-configs/base.conf
#echo "cert client.crt" >> ~/client-configs/base.conf
#echo "key client.key" >> ~/client-configs/base.conf
#echo "tls-auth ta.key 1" >> ~/client-configs/base.conf
echo "auth SHA256" >> ~/client-configs/base.conf
echo "cipher AES-256-CBC" >> ~/client-configs/base.conf
echo "remote-cert-tls server" >> ~/client-configs/base.conf
#echo "comp-lzo" >> ~/client-configs/base.conf
echo "verb 3" >> ~/client-configs/base.conf
echo "key-direction 1" >> ~/client-configs/base.conf
#echo "explicit-exit-notify $notify" >> ~/client-configs/base.conf

# if reading "Are there any linux clients that will be connected?". If yes, add the following lines.
# script-security 2
# up /etc/openvpn/update-resolv-conf
# down /etc/openvpn/update-resolv-conf

mkdir -p ~/client-configs/clients
cd ~/client-configs/
# for i in {0..$numClients}
# do
	# cat ~/client-configs/base.conf > ~/client-configs/clients/client{$i}.ovpn
	# echo "<ca>" >> ~/client-configs/clients/client{$i}.ovpn
	# cat ~/client-configs/keys/ca.crt >> ~/client-configs/clients/client{$i}.ovpn
	# echo "</ca>" >> ~/client-configs/clients/client{$i}.ovpn
	# echo "<cert>" >> ~/client-configs/clients/client{$i}.ovpn
	# cat ~/client-configs/keys/client1.crt >> ~/client-configs/clients/client{$i}.ovpn
	# cat ~/client-configs/keys/client1.key >> ~/client-configs/clients/client{$i}.ovpn
	# echo "</key>" >> ~/client-configs/clients/client{$i}.ovpn
	# echo "<tls-auth>" >> ~/client-configs/clients/client{$i}.ovpn
	# cat ~/client-configs/keys/ta.key >> ~/client-configs/clients/client{$i}.ovpn
	# echo "</tls-auth>)"  >> ~/client-configs/clients/client{$i}.ovpn
# done
cat ~/client-configs/base.conf > ~/client-configs/clients/client1.ovpn
echo "<ca>" >> ~/client-configs/clients/client1.ovpn
cat ~/client-configs/keys/ca.crt >> ~/client-configs/clients/client1.ovpn
echo "</ca>" >> ~/client-configs/clients/client1.ovpn
echo "<cert>" >> ~/client-configs/clients/client1.ovpn
cat ~/client-configs/keys/client1.crt >> ~/client-configs/clients/client1.ovpn
echo "</cert>" >> ~/client-configs/clients/client1.ovpn
echo "<key>" >> ~/client-configs/clients/client1.ovpn
cat ~/client-configs/keys/client1.key >> ~/client-configs/clients/client1.ovpn
echo "</key>" >> ~/client-configs/clients/client1.ovpn
echo "<tls-auth>" >> ~/client-configs/clients/client1.ovpn
cat ~/client-configs/keys/ta.key >> ~/client-configs/clients/client1.ovpn
echo "</tls-auth>"  >> ~/client-configs/clients/client1.ovpn
echo -e "[ * ] VPN client configs generated"
cp ~/client-configs/clients/client*.ovpn ~/Desktop/
echo -e "[ + ] Locking down VPN setup files"
#sudo chmod -R 400 ~/client-configs && sudo chattr +i -R ~/client-configs ############ Added this line. Take out if problems copying.
#sudo chmod -R 000 ~/OpenVPN/CA && sudo chattr +i -R ~/OpenVPN/CA 
#sudo chmod -R 400 ~/OpenVPN/Server && sudo chattr +i -R ~/OpenVPN/Server
echo -e "[ + ] FINISHED! VPN Setup complete!"    