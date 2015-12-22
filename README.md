Torkeroni - The Makeroni Onion router
=====================================

This is a bash script convert any kind of GNU/Linux distribution into a tor honeypot, the script creates a new WiFi Access Point that routes all traffic thru Tor router

Log in your Raspberry Pi and start the script:

````
git clone https://github.com/Makeroni/Torkeroni.git
chmod +x torkeroni_setup.sh
./torkeroni_setup.sh
````


Execute this script as root user. Follow all steps to create a new Tor router. 

The script creates a log file at the same path of torkeroni_setup.sh.

Wew are planning to release a full distribution ready to use for Raspberry Pi with a built-in honeypot, stay tuned!!!