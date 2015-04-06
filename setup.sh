#!/bin/bash
# Onion Pi, based on the Adafruit Learning Technologies Onion Pi project.
# For more info: http://learn.adafruit.com/onion-pi
#
# To do:
# * Options for setting up relay, exit, or bridge
# * More anonymization of Onion Pi box
# * Further testing

if (( $EUID != 0 )); then
  /bin/echo "This script must be run as root. Type in 'sudo $0' to run it as root."
  exit 1
fi

/bin/cat <<'Onion_Pi'
                            ~
                           /~
                     \  \ /**
                      \ ////
                      // //
                     // //
                   ///&//
                  / & /\ \
                /  & .,,  \
              /& %  :       \
            /&  %   :  ;     `\
           /&' &..%   !..    `.\
          /&' : &''" !  ``. : `.\
         /#' % :  "" * .   : : `.\
        I# :& :  !"  *  `.  : ::  I
        I &% : : !%.` '. . : : :  I
        I && :%: .&.   . . : :  : I
        I %&&&%%: WW. .%. : :     I
         \&&&##%%%`W! & '  :   ,'/
          \####ITO%% W &..'  #,'/
            \W&&##%%&&&&### %./
              \###j[\##//##}/
                 ++///~~\//_
                  \\ \ \ \  \_
                  /  /    \
Onion_Pi

/bin/echo "This script will auto-setup a Tor proxy for you. It is recommend that you
run this script on a fresh installation of Raspbian."
read -p "Press [Enter] key to begin.."

/bin/echo "Updating package index.."
/usr/bin/apt-get update -y

/bin/echo "Removing Wolfram Alpha Engine due to bug. More info:
http://www.raspberrypi.org/phpBB3/viewtopic.php?f=66&t=68263"
/usr/bin/apt-get remove -y wolfram-engine

/bin/echo "Updating out-of-date packages.."
/usr/bin/apt-get upgrade -y

/bin/echo "Downloading and installing various packages.."
/usr/bin/apt-get install -y ntp unattended-upgrades monit tor wget

/bin/echo "Downloading meek binary for RPi.."
/usr/bin/wget https://raw.githubusercontent.com/bbs4us/meek-client-pi/master/meek-client
/bin/chmod meek-client
mv meek-client /usr/local/bin/meek-client

/bin/echo "Configuring Tor.."
/bin/cat /dev/null > /etc/tor/torrc
/bin/echo "## Onion Pi Config v0.3
## More information: https://github.com/bbs4us/onion_pi/

# Transparent proxy port
TransPort 9040
# Explicit SOCKS port for applications.
SocksPort 9050

# Have Tor run in the background
RunAsDaemon 1

# Only ever run as a client. Do not run as a relay or an exit.
ClientOnly

# Ensure resolution of .onion and .exit domains happen through Tor.
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1

# Serve DNS responses
DNSPort 53

# meek bridges
UseBridges 1
# With tor 0.2.4 or earlier, you have to configure the url and front on the
# command line, and you can only use one url/front combination at a time:
Bridge meek 0.0.2.0:1
# Google is blocked in China
# ClientTransportPlugin meek exec ./meek-client --url=https://meek-reflect.appspot.com/ --front=www.google.com --log meek-client.log
ClientTransportPlugin meek exec /usr/local/bin/meek-client --url=https://d2zfqthxsdq309.cloudfront.net/ --front=a0.awsstatic.com --log /var/log/tor/meek-client.log

DataDirectory /var/lib/tor
PidFile /var/run/tor/tor.pid
User debian-tor

ControlSocket /var/run/tor/control
ControlSocketsGroupWritable 1

CookieAuthentication 1
CookieAuthFileGroupReadable 1
CookieAuthFile /var/run/tor/control.authcookie
Log notice file /var/log/tor/log" >> /etc/tor/torrc 


/bin/echo "Copying Tor config file.."
/bin/mkdir -p /usr/share/tor
/bin/cp /etc/tor/torrc /usr/share/tor/tor-service-defaults-torrc 

/bin/echo "Fixing firewall configuration.."
/sbin/iptables -F
/sbin/iptables -t nat -F
/sbin/iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j REDIRECT --to-ports 53 -m comment --comment "OnionPi: Redirect all DNS requests to Tor's DNSPort port."
/sbin/iptables -t nat -A PREROUTING -i wlan0 -p tcp --syn -j REDIRECT --to-ports 9040 -m comment --comment "OnionPi: Redirect all TCP packets to Tor's TransPort port."

/bin/sh -c "/sbin/iptables-save > /etc/iptables.ipv4.nat"

/bin/echo "Wiping various  files and directories.."
/usr/bin/shred -fvzu -n 3 /var/log/wtmp
/usr/bin/shred -fvzu -n 3 /var/log/lastlog
/usr/bin/shred -fvzu -n 3 /var/run/utmp
/usr/bin/shred -fvzu -n 3 /var/log/mail.*
/usr/bin/shred -fvzu -n 3 /var/log/syslog*
/usr/bin/shred -fvzu -n 3 /var/log/messages*
/usr/bin/shred -fvzu -n 3 /var/log/auth.log*

/bin/echo "Setting tor to start at boot.."
/usr/sbin/update-rc.d tor enable

/bin/echo "Setting up Monit to watch Tor process.."
/etc/monit/monitrc << 'tor_monit'
check process tor with pidfile /var/run/tor/tor.pid
group tor
start program = "/etc/init.d/tor start"
stop program = "/etc/init.d/tor stop"
if failed port 9050 type tcp
   with timeout 5 seconds
   then restart
if 3 restarts within 5 cycles then timeout
tor_monit

/bin/echo "Starting monit.."
/usr/bin/monit quit
/usr/bin/monit -c /etc/monit/monitrc

/bin/echo "Restarting tor.."
/usr/sbin/service tor restart

/usr/bin/clear
/bin/echo "Onion Pi setup complete!
To connect to your own Tor gateway, set your web browser or computer to connect to:
  Proxy type: SOCKSv5
  Port: 9050

  Transparent proxy port: 9040

Before doing anything, verify that you are using the Tor network by visiting:

  https://check.torproject.org/


Onion Pi
"

exit
