#!/bin/bash

run_time=`date +%Y%m%d%H%M`
log_file="ap_setup_log.${run_time}"

cat /dev/null > ${log_file}

AP_CHANNEL=1

echo "Updating repositories..."
apt-get update
sudo apt-get install tor

read -p "Please provide your new SSID to be broadcasted by RPi (i.e. My_Raspi_AP): " AP_SSID
read -s -p "Please provide password for your new wireless network (8-63 characters): " AP_WPA_PASSPHRASE

echo ""

if [ `echo $AP_WPA_PASSPHRASE | wc -c` -lt 8 ] || [ `echo $AP_WPA_PASSPHRASE | wc -c` -gt 63 ]; then
	echo "Sorry, but the password is either to long or too short. Setup will now exit. Start again."
	exit 9
fi

echo ""

if [ `lsusb | grep "RTL8188CUS\|RTL8192CU" | wc -l` -ne 0 ]; then
        echo "Your WiFi is based on the chipset that requires special version of hostapd."                                          | tee -a ${log_file}
        echo "Setup will download it for you."                                                                                      | tee -a ${log_file}
        CHIPSET="yes"
else
        echo "Some of the WiFi chipset require special version of hostapd."                                                         | tee -a ${log_file}
        echo "Please answer yes if you want to have different version of hostapd downloaded."                                       | tee -a ${log_file}
        echo "(it is not recommended unless you had experienced issues with running regular hostapd - so type no)"                  | tee -a ${log_file}
        read ANSWER
        if [ ${ANSWER,,} = "yes" ]; then
                CHIPSET="yes"
        else
                CHIPSET="no"
        fi
fi

echo "Checking network interfaces..."                                                                                               | tee -a ${log_file}
NONIC=`netstat -i | grep ^wlan | cut -d ' ' -f 1 | wc -l`

if [ ${NONIC} -lt 1 ]; then
        echo "There are no wireless network interfaces... Exiting"                                                                  | tee -a ${log_file}
        exit 1
elif [ ${NONIC} -gt 1 ]; then
        echo "You have more than one wlan interface. Please select the interface to become AP: "                                    | tee -a ${log_file}
        select INTERFACE in `netstat -i | grep ^wlan | cut -d ' ' -f 1`
        do
                NIC=${INTERFACE}
		break
        done
        exit 1
else
        NIC=`netstat -i | grep ^wlan | cut -d ' ' -f 1`
fi

read -p "Please provide network interface that will be used as WAN connection (i.e. eth0): " WAN

DNS=`netstat -rn | grep ${WAN} | grep UG | tr -s " " "X" | cut -d "X" -f 2`
echo "DNS will be set to " ${DNS}                                                                                                   | tee -a ${log_file}
echo "You can change DNS addresses for the new network in /etc/dhcp/dhcpd.conf"                                                     | tee -a ${log_file}
echo ""
read -p "Please provide your new AP network (i.e. 192.168.10.X). Remember to put X at the end!!!  " NETWORK 

if [ `echo ${NETWORK} | grep X$ | wc -l` -eq 0 ]; then
	echo "Invalid AP network provided... No X was found at the end of you input. Setup will now exit."
	exit 4
fi

AP_ADDRESS=`echo ${NETWORK} | tr \"X\" \"1\"`
AP_UPPER_ADDR=`echo ${NETWORK} | tr \"X\" \"9\"`
AP_LOWER_ADDR=`echo ${NETWORK} | tr \"X\" \"2\"`
SUBNET=`echo ${NETWORK} | tr \"X\" \"0\"`

echo ""
echo ""
echo "+========================================================================"
echo "Your network settings will be:"                                                                                               | tee -a ${log_file}
echo "AP NIC address: ${AP_ADDRESS}  "                                                                                              | tee -a ${log_file}
echo "Subnet:  ${SUBNET} "                                                                                                          | tee -a ${log_file}
echo "Addresses assigned by DHCP will be from  ${AP_LOWER_ADDR} to ${AP_UPPER_ADDR}"                                                | tee -a ${log_file}
echo "Netmask: 255.255.255.0"                                                                                                       | tee -a ${log_file}
echo "WAN: ${WAN}"                                                                                                                  | tee -a ${log_file}

sudo sed "s|192.168.10.1|${AP_ADDRESS}|g"  /boot/torrc >/etc/tor/torrc

read -n 1 -p "Continue? (y/n):" GO
echo ""

if [ ${GO,,} = "y" ]; then
    sleep 1
else
    exit 2
fi

echo "Setting up  $NIC"                                                                                                             | tee -a ${log_file}
echo "Downloading and installing packages: hostapd isc-dhcp-server iptables."                                                       | tee -a ${log_file}
echo ""
apt-get -y install hostapd isc-dhcp-server iptables                                                                                 | tee -a ${log_file}
service hostapd stop                                                                                                                | tee -a ${log_file}  > /dev/null
service isc-dhcp-server stop                                                                                                        | tee -a ${log_file}  > /dev/null
echo ""                                                                                                                             | tee -a ${log_file}
echo "Backups:"                                                                                                                     | tee -a ${log_file}

if [ -f /etc/dhcp/dhcpd.conf ]; then
        cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak.${run_time}
        echo " /etc/dhcp/dhcpd.conf to /etc/dhcp/dhcpd.conf.bak.${run_time}"                                                        | tee -a ${log_file}
fi

if [ -f /etc/hostapd/hostapd.conf ]; then
        cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak.${run_time}
        echo "/etc/hostapd/hostapd.conf to /etc/hostapd/hostapd.conf.bak.${run_time}"                                               | tee -a ${log_file}
fi

if [ -f /etc/default/isc-dhcp-server ]; then
        cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak.${run_time}
        echo "/etc/default/isc-dhcp-server to /etc/default/isc-dhcp-server.bak.${run_time}"                                         | tee -a ${log_file}
fi

if [ -f /etc/sysctl.conf ]; then
        cp /etc/sysctl.conf /etc/sysctl.conf.bak.${run_time}
        echo "/etc/sysctl.conf /etc/sysctl.conf.bak.${run_time}"                                                                    | tee -a ${log_file}
fi

if [ -f /etc/network/interfaces ]; then
        cp /etc/network/interfaces /etc/network/interfaces.bak.${run_time}
        echo "/etc/network/interfaces to /etc/network/interfaces.bak.${run_time}"                                                   | tee -a ${log_file}
fi
 
echo "Setting up AP..."                                                                                                             | tee -a ${log_file}
echo "Configure: /etc/default/isc-dhcp-server"                                                                                      | tee -a ${log_file}
echo "DHCPD_CONF=\"/etc/dhcp/dhcpd.conf\""                                                                                          >  /etc/default/isc-dhcp-server
echo "INTERFACES=\"$NIC\""                                                                                                          >> /etc/default/isc-dhcp-server

echo "Configure: /etc/default/hostapd"                                                                                              | tee -a ${log_file}
echo "DAEMON_CONF=\"/etc/hostapd/hostapd.conf\""                                                                                    > /etc/default/hostapd

echo "Configure: /etc/dhcp/dhcpd.conf"                                                                                              | tee -a ${log_file}
echo "ddns-update-style none;"                                                                                                      >  /etc/dhcp/dhcpd.conf
echo "default-lease-time 86400;"                                                                                                    >> /etc/dhcp/dhcpd.conf
echo "max-lease-time 86400;"                                                                                                        >> /etc/dhcp/dhcpd.conf
echo "subnet ${SUBNET} netmask 255.255.255.0 {"                                                                                     >> /etc/dhcp/dhcpd.conf
echo "  range ${AP_LOWER_ADDR} ${AP_UPPER_ADDR}  ;"                                                                                 >> /etc/dhcp/dhcpd.conf
echo "  option domain-name-servers 8.8.8.8, 8.8.4.4  ;"                                                                             >> /etc/dhcp/dhcpd.conf
echo "  option domain-name \"home\";"                                                                                               >> /etc/dhcp/dhcpd.conf
echo "  option routers " ${AP_ADDRESS} " ;"                                                                                         >> /etc/dhcp/dhcpd.conf
echo "}"                                                                                                                            >> /etc/dhcp/dhcpd.conf

echo "Configure: /etc/hostapd/hostapd.conf"                                                                                         | tee -a ${log_file}

if [ ! -f /etc/hostapd/hostapd.conf ]; then
	touch /etc/hostapd/hostapd.conf
fi
	
echo "interface=$NIC"                                                                                                               >  /etc/hostapd/hostapd.conf
echo "ssid=${AP_SSID}"                                                                                                              >> /etc/hostapd/hostapd.conf
echo "channel=${AP_CHANNEL}"                                                                                                        >> /etc/hostapd/hostapd.conf
echo "# WPA and WPA2 configuration"                                                                                                 >> /etc/hostapd/hostapd.conf
echo "macaddr_acl=0"                                                                                                                >> /etc/hostapd/hostapd.conf
echo "auth_algs=1"                                                                                                                  >> /etc/hostapd/hostapd.conf
echo "ignore_broadcast_ssid=0"                                                                                                      >> /etc/hostapd/hostapd.conf
echo "wpa=2"                                                                                                                        >> /etc/hostapd/hostapd.conf
echo "wpa_passphrase=${AP_WPA_PASSPHRASE}"                                                                                          >> /etc/hostapd/hostapd.conf
echo "wpa_key_mgmt=WPA-PSK"                                                                                                         >> /etc/hostapd/hostapd.conf
echo "wpa_pairwise=TKIP"                                                                                                            >> /etc/hostapd/hostapd.conf
echo "rsn_pairwise=CCMP"                                                                                                            >> /etc/hostapd/hostapd.conf
echo "# Hardware configuration"                                                                                                     >> /etc/hostapd/hostapd.conf

if [ ${CHIPSET} = "yes" ]; then
	echo "driver=rtl871xdrv"                                                                                                        >> /etc/hostapd/hostapd.conf
	echo "ieee80211n=1"                                                                                                             >> /etc/hostapd/hostapd.conf
    echo "device_name=RTL8192CU"                                                                                                    >> /etc/hostapd/hostapd.conf
    echo "manufacturer=Realtek"                                                                                                     >> /etc/hostapd/hostapd.conf
else
	echo "driver=nl80211"                                                                                                           >> /etc/hostapd/hostapd.conf
fi

echo "hw_mode=g"                                                                                                                    >> /etc/hostapd/hostapd.conf

echo "Configure: /etc/sysctl.conf"                                                                                                  | tee -a ${log_file}
echo "net.ipv4.ip_forward=1"                                                                                                        >> /etc/sysctl.conf

echo "Configure: iptables"                                                                                                          | tee -a ${log_file}
iptables -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE
iptables -A FORWARD -i ${WAN} -o ${NIC} -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ${NIC} -o ${WAN} -j ACCEPT
sh -c "iptables-save > /etc/iptables.ipv4.nat"

echo "Configure: /etc/network/interfaces"                                                                                           | tee -a ${log_file}
echo "auto ${NIC}"                                                                                                                  >>  /etc/network/interfaces

if [ ${CHIPSET,,} = "yes" ]; then 
		echo "#allow-hotplug ${NIC}"                                                                                                >> /etc/network/interfaces
else
		echo "allow-hotplug ${NIC}"                                                                                                 >> /etc/network/interfaces
fi

echo "iface ${NIC} inet static"                                                                                                     >> /etc/network/interfaces
echo "        address ${AP_ADDRESS}"                                                                                                >> /etc/network/interfaces
echo "        netmask 255.255.255.0"                                                                                                >> /etc/network/interfaces
echo "up iptables-restore < /etc/iptables.ipv4.nat"                                                                                 >> /etc/network/interfaces

if [ ${CHIPSET,,} = "yes" ]; then 
	echo "Install: special hostapd version"                                                                                         | tee -a ${log_file}
    tar -xzvf RTL8188-hostapd-2.0.tar.gz                                                                                            | tee -a ${log_file}
    cd RTL8188-hostapd-2.0 && sudo make

    if [ -f /usr/sbin/hostapd ]; then
        mv /usr/sbin/hostapd /usr/sbin/hostapd.bk.${run_time}
    fi

    cp hostapd /usr/sbin/
    chmod 755 /usr/sbin/hostapd
fi

ifdown ${NIC}                                                                                                                       | tee -a ${log_file}
ifup ${NIC}                                                                                                                         | tee -a ${log_file}
service hostapd start                                                                                                               | tee -a ${log_file}
service isc-dhcp-server start                                                                                                       | tee -a ${log_file}

echo "Setting hostname..."
echo "torkeroni"                                                                                                                    > /etc/hostname
sudo hostname -F /etc/hostname
echo ""                                                                                                                             >>  /etc/hosts
echo "127.0.1.1    torkeroni"                                                                                                       >>  /etc/hosts
sudo /etc/init.d/hostname.sh

echo "Setting MOTD..."
echo "                                                                                                                                                      " > /etc/motd.tail
echo "                                                                                                                                                      " >> /etc/motd.tail
echo "                                                                                                                                                      " >> /etc/motd.tail
echo " _____          _                        _                                                                                                            " >> /etc/motd.tail
echo "|_   _|        | |                      (_)                                                                                                           " >> /etc/motd.tail
echo "  | | ___  _ __| | _____ _ __ ___  _ __  _                                                                                                            " >> /etc/motd.tail
echo "  | |/ _ \| '__| |/ / _ \ '__/ _ \| '_ \| |                                                                                                           " >> /etc/motd.tail
echo "  | | (_) | |  |   <  __/ | | (_) | | | | |                                                                                                           " >> /etc/motd.tail
echo "  \_/\___/|_|  |_|\_\___|_|  \___/|_| |_|_|                                                                                                           " >> /etc/motd.tail
echo "                                                                                                                                                      " >> /etc/motd.tail
echo "                                                                                                                                                      " >> /etc/motd.tail
echo " ____  _   _  ____    __  __    __    _  _  ____  ____  _____  _  _  ____    _____  _  _  ____  _____  _  _    ____  _____  __  __  ____  ____  ____  " >> /etc/motd.tail
echo "(_  _)( )_( )( ___)  (  \/  )  /__\  ( )/ )( ___)(  _ \(  _  )( \( )(_  _)  (  _  )( \( )(_  _)(  _  )( \( )  (  _ \(  _  )(  )(  )(_  _)( ___)(  _ \ " >> /etc/motd.tail
echo "  )(   ) _ (  )__)    )    (  /(__)\  )  (  )__)  )   / )(_)(  )  (  _)(_    )(_)(  )  (  _)(_  )(_)(  )  (    )   / )(_)(  )(__)(   )(   )__)  )   / " >> /etc/motd.tail
echo " (__) (_) (_)(____)  (_/\/\_)(__)(__)(_)\_)(____)(_)\_)(_____)(_)\_)(____)  (_____)(_)\_)(____)(_____)(_)\_)  (_)\_)(_____)(______) (__) (____)(_)\_) " >> /etc/motd.tail
echo "                                                                                                                                                      " >> /etc/motd.tail
echo "

read -n 1 -p "Would you like to start AP on boot? (y/n): " startup_answer
echo ""

if [ ${startup_answer,,} = "y" ]; then
        echo "Configure: startup"                                                                                                   | tee -a ${log_file}
        update-rc.d hostapd enable                                                                                                  | tee -a ${log_file}
        update-rc.d isc-dhcp-server enable                                                                                          | tee -a ${log_file}
else
        echo "In case you change your mind, please run below commands if you want AP to start on boot:"                             | tee -a ${log_file}
        echo "update-rc.d hostapd enable"                                                                                           | tee -a ${log_file}
        echo "update-rc.d isc-dhcp-server enable"                                                                                   | tee -a ${log_file}
fi

sudo cp /etc/default/ifplugd /etc/default/ifplugd.old                                                                               | tee -a ${log_file}
sudo sed "s|auto|eth0|g" /etc/default/ifplugd.old >/etc/default/ifplugd                                                             | tee -a ${log_file}
sudo sed "s|all|eth0|g" /etc/default/ifplugd.old >/etc/default/ifplugd                                                              | tee -a ${log_file}

echo ""                                                                                                                             | tee -a ${log_file}
echo "Do not worry if you see something like: [FAIL] Starting ISC DHCP server above... this is normal :)"                           | tee -a ${log_file}
echo ""                                                                                                                             | tee -a ${log_file}
echo "REMEMBER TO RESTART YOUR COMPUTER!!!"                                                                                         | tee -a ${log_file}
echo ""                                                                                                                             | tee -a ${log_file}
echo "Enjoy"                                                                                                                        | tee -a ${log_file}

sudo iptables -F
sudo iptables -t nat -F

sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 22 -j REDIRECT --to-ports 22
sudo iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j REDIRECT --to-ports 53
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --syn -j REDIRECT --to-ports 9040
sudo iptables -t nat -L
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

sudo touch /var/log/tor/notices.log
sudo chown debian-tor /var/log/tor/notices.log
sudo chmod 644 /var/log/tor/notices.log

sudo service tor start
sudo service tor status

sudo update-rc.d tor enable

exit 0