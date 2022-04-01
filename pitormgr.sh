#!/bin/bash
#
# PITOR MANAGER
# =============
#
# pitormgr is a bash script used to configure and manage a Raspberry PI
# that's been configured as a Tor Proxy aka pitor by forwarding any
# incoming traffic on ETH0 through the Tor network by another network
# interface connected to the internet.
#
#
#
# CONCEPT
# =======
#
# The idea of configuring a Raspberry PI as a pitor is to forward all
# network data coming from one or multiple clients connected to ETH0
# on the Raspberry PI through the Tor network. This prevents any
# accidental leakage and guarantees that any client connected to the
# Raspberry PI via the ETH0 port goes through the Tor network.
#
#
# SETUP
# =====
#
# The following diagram describes the ideal setup with a pitor:
#
#    __________                 __________                ____________
#    |        |                 |        |                |          |
#    | Client |[eth0] --> [eth0]|  pitor |[usb0/eth1] --> | Internet |
#    | Laptop |                 |        |                | provider |
#    |        |                 |        |                |          |
#    ----------                 ----------                ------------
#
# The secondary network interface controller in the pitor could be either
# a USB-to-ETH adapter which would be connected to a network connected
# to the internet or via USB tethering using a cellular phone.
#
#
# FEATURES
# ========
#
# pitormgr provides several command line options and arguments to help
# manage a pitor.
#
#
# CONFIGURE PITOR
# ---------------
#
# A Raspberry PI can be configured as a pitor by using the '-c' option.
# By default, the Tor exit country is set to 'US'. However, you can
# specify a country code after the '-c' option. See the example below:
#
#     # Configure a pitor to exit out of Canada
#     ./pitormgr.sh -c ca
#
#
# QUERY COUNTRY INFO
# ------------------
#
# Remembering two letter country codes is hard. So pitormgr makes it
# easier on you by providing a way to query for any country given by
# a keyword. It will print out any country that contains that keyword
# and hopefully the result will contain the desired output.
# 
# For example, I need the two letter country code for Bulgaria and I
# don't know how to spell Bulgaria but I know it starts with 'bul'.
# You can use pitormgr and search for 'bul' as such:
#
#     ./pitormgr.sh -q bul
#     [+] Searching for the following keyword(s): bul
#         [BG] Bulgaria
#     [+] Search complete!
#
# As you can see the result above, pitormgr found a match that contained
# the keyword 'bul'.
#
# 
# SET TOR EXIT COUNTRY
# --------------------
#
# pitormgr can be used to change the Tor exit country with the '-s' flag
# followed by the desired country code, as such:
#
#    # Change the Tor exit country to Brazil
#    ./pitormgr.sh -s br
#
#
# RESTART TOR SERVICE
# -------------------
#
# pitormgr allows you to restart the Tor service if necessary.
#
#    ./pitormgr.sh -r
#
#
# TEST CONNECTION
# ---------------
#
# pitormgr provides a way to test if you have an active connection
# to the Tor network. It is highly suggested that after changing the
# Tor exit country to verify that there is still an active connection.
# Not all countries contain active Tor exit relays, so it is possible
# that you may lose connection to the Tor network.
#
#    ./pitormgr.sh -t
#



# Proram information
NAME="pitormgr"
FILENAME="pitormgr.sh"
VERSION="1.0.0"
DATE="03/30/2022"
AUTHOR="eldiablo"
EMAIL="avsarria@gmail.com"


# Types of actions that require elevation of privileges
ACTION_CONFIG_PITOR=1
ACTION_SET_TOR_EXIT=2
ACTION_RESTART_TOR=3


#
# The following set of global variables contain non-configuration
# values:
#
DNSMASQ_CONFIG_FILE="/etc/dnsmasq.conf"
DHCP_CONFIG_FILE="/etc/dhcpcd.conf"
SYSCTL_CONFIG_FILE="/etc/sysctl.d/local.conf"
IPTABLES_RULES_V4_PATH="/etc/iptables/rules.v4"
IPTABLES_RULES_V6_PATH="/etc/iptables/rules.v6"

TOR_SERVICE_NAME="tor.service"
TORPROJECT_URL="https://check.torproject.org/api/ip"


#
# The following set of global variables contain values that
# can be configured within the script before running pitormgr.
# @TODO: Allow the possibility to consume a configuration file
#
DNS_SERVER="1.1.1.1"

DEFAULT_KEYBOARD_LAYOUT="us"

CLIENT_NIC="eth0"
CLIENT_NETWORK_SUBNET="192.168.2.0"
CLIENT_NETWORK_GATEWAY="192.168.2.1"
CLIENT_NETWORK_SUBNET_MASK="255.255.255.0"
CLIENT_NETWORK_SUBNET_CDIR="24"
CLIENT_NETWORK_DHCP_START="192.168.2.10"
CLIENT_NETWORK_DHCP_END="192.168.2.200"
CLIENT_NETWORK_DHCP_TIMEOUT="24h"

TOR_CONFIG_FILE="/etc/tor/torrc"
TOR_CONFIG_IP=$CLIENT_NETWORK_GATEWAY
TOR_CONFIG_DNSPORT="53"
TOR_CONFIG_TRANSPORT="9040"
TOR_CONFIG_DEFAULT_EXITNODE="us"
TOR_CONFIG_LOG="/var/log/tor/notices.log"


# POSIX Shell Colors
BLUE='\033[94m'
GREEN='\033[92m'
RED='\033[31m'
YELLOW='\033[93m'
FAIL='\033[91m'
BOLD='\033[1m'
WHITE='\033[37m'
BGRED='\033[41m'
ENDC='\033[0m'

#
# Source: https://www.iban.com/country-codes
# Removed (the)
#
COUNTRY_LIST="[AF] Afghanistan
[AL] Albania
[DZ] Algeria
[AS] American Samoa
[AD] Andorra
[AO] Angola
[AI] Anguilla
[AQ] Antarctica
[AG] Antigua and Barbuda
[AR] Argentina
[AM] Armenia
[AW] Aruba
[AU] Australia
[AT] Austria
[AZ] Azerbaijan
[BS] Bahamas
[BH] Bahrain
[BD] Bangladesh
[BB] Barbados
[BY] Belarus
[BE] Belgium
[BZ] Belize
[BJ] Benin
[BM] Bermuda
[BT] Bhutan
[BO] Bolivia (Plurinational State of)
[BQ] Bonaire, Sint Eustatius and Saba
[BA] Bosnia and Herzegovina
[BW] Botswana
[BV] Bouvet Island
[BR] Brazil
[IO] British Indian Ocean Territory
[BN] Brunei Darussalam
[BG] Bulgaria
[BF] Burkina Faso
[BI] Burundi
[CV] Cabo Verde
[KH] Cambodia
[CM] Cameroon
[CA] Canada
[KY] Cayman Islands
[CF] Central African Republic
[TD] Chad
[CL] Chile
[CN] China
[CX] Christmas Island
[CC] Cocos (Keeling) Islands
[CO] Colombia
[KM] Comoros
[CG] Congo
[CD] Congo, Democratic Republic of the
[CK] Cook Islands
[CR] Costa Rica
[CI] Côte d'Ivoire
[HR] Croatia
[CU] Cuba
[CW] Curaçao
[CY] Cyprus
[CZ] Czechia
[DK] Denmark
[DJ] Djibouti
[DM] Dominica
[DO] Dominican Republic
[EC] Ecuador
[EG] Egypt
[SV] El Salvador
[GQ] Equatorial Guinea
[ER] Eritrea
[EE] Estonia
[SZ] Eswatini
[ET] Ethiopia
[FK] Falkland Islands (Malvinas)
[FO] Faroe Islands
[FJ] Fiji
[FI] Finland
[FR] France
[GF] French Guiana
[PF] French Polynesia
[TF] French Southern Territories
[GA] Gabon
[GM] Gambia
[GE] Georgia
[DE] Germany
[GH] Ghana
[GI] Gibraltar
[GR] Greece
[GL] Greenland
[GD] Grenada
[GP] Guadeloupe
[GU] Guam
[GT] Guatemala
[GG] Guernsey
[GN] Guinea
[GW] Guinea-Bissau
[GY] Guyana
[HT] Haiti
[HM] Heard Island and McDonald Islands
[VA] Holy See
[HN] Honduras
[HK] Hong Kong
[HU] Hungary
[IS] Iceland
[IN] India
[ID] Indonesia
[IR] Iran (Islamic Republic of)
[IQ] Iraq
[IE] Ireland
[IM] Isle of Man
[IL] Israel
[IT] Italy
[JM] Jamaica
[JP] Japan
[JE] Jersey
[JO] Jordan
[KZ] Kazakhstan
[KE] Kenya
[KI] Kiribati
[KP] Korea (Democratic People's Republic of)
[KR] Korea, Republic of
[KW] Kuwait
[KG] Kyrgyzstan
[LA] Lao People's Democratic Republic
[LV] Latvia
[LB] Lebanon
[LS] Lesotho
[LR] Liberia
[LY] Libya
[LI] Liechtenstein
[LT] Lithuania
[LU] Luxembourg
[MO] Macao
[MG] Madagascar
[MW] Malawi
[MY] Malaysia
[MV] Maldives
[ML] Mali
[MT] Malta
[MH] Marshall Islands
[MQ] Martinique
[MR] Mauritania
[MU] Mauritius
[YT] Mayotte
[MX] Mexico
[FM] Micronesia (Federated States of)
[MD] Moldova, Republic of
[MC] Monaco
[MN] Mongolia
[ME] Montenegro
[MS] Montserrat
[MA] Morocco
[MZ] Mozambique
[MM] Myanmar
[NA] Namibia
[NR] Nauru
[NP] Nepal
[NL] Netherlands
[NC] New Caledonia
[NZ] New Zealand
[NI] Nicaragua
[NE] Niger
[NG] Nigeria
[NU] Niue
[NF] Norfolk Island
[MK] North Macedonia
[MP] Northern Mariana Islands
[NO] Norway
[OM] Oman
[PK] Pakistan
[PW] Palau
[PS] Palestine, State of
[PA] Panama
[PG] Papua New Guinea
[PY] Paraguay
[PE] Peru
[PH] Philippines
[PN] Pitcairn
[PL] Poland
[PT] Portugal
[PR] Puerto Rico
[QA] Qatar
[RE] Réunion
[RO] Romania
[RU] Russian Federation
[RW] Rwanda
[BL] Saint Barthélemy
[SH] Saint Helena, Ascension and Tristan da Cunha
[KN] Saint Kitts and Nevis
[LC] Saint Lucia
[MF] Saint Martin (French part)
[PM] Saint Pierre and Miquelon
[VC] Saint Vincent and the Grenadines
[WS] Samoa
[SM] San Marino
[ST] Sao Tome and Principe
[SA] Saudi Arabia
[SN] Senegal
[RS] Serbia
[SC] Seychelles
[SL] Sierra Leone
[SG] Singapore
[SX] Sint Maarten (Dutch part)
[SK] Slovakia
[SI] Slovenia
[SB] Solomon Islands
[SO] Somalia
[ZA] South Africa
[GS] South Georgia and the South Sandwich Islands
[SS] South Sudan
[ES] Spain
[LK] Sri Lanka
[SD] Sudan
[SR] Suriname
[SJ] Svalbard and Jan Mayen
[SE] Sweden
[CH] Switzerland
[SY] Syrian Arab Republic
[TW] Taiwan, Province of China
[TJ] Tajikistan
[TZ] Tanzania, United Republic of
[TH] Thailand
[TL] Timor-Leste
[TG] Togo
[TK] Tokelau
[TO] Tonga
[TT] Trinidad and Tobago
[TN] Tunisia
[TR] Turkey
[TM] Turkmenistan
[TC] Turks and Caicos Islands
[TV] Tuvalu
[UG] Uganda
[UA] Ukraine
[AE] United Arab Emirates
[GB] United Kingdom of Great Britain and Northern Ireland
[UM] United States Minor Outlying Islands
[US] United States of America
[UY] Uruguay
[UZ] Uzbekistan
[VU] Vanuatu
[VE] Venezuela (Bolivarian Republic of)
[VN] Viet Nam
[VG] Virgin Islands (British)
[VI] Virgin Islands (U.S.)
[WF] Wallis and Futuna
[EH] Western Sahara
[YE] Yemen
[ZM] Zambia
[ZW] Zimbabwe
[AX] Åland Islands"


LOGI()
{
    printf "$GREEN[+]$ENDC %s\n" "$1"
}

LOGW()
{
    printf "$YELLOW[!]$ENDC %s\n" "$1"
}

LOGE()
{
    printf "$RED[-] %s $ENDC\n" "$1"
}

disable_kernel_modules()
{
    echo "" > /etc/modprobe.d/raspi-blacklist.conf
    echo "blacklist brcmfmac" >> /etc/modprobe.d/raspi-blacklist.conf
    echo "blacklist brcmutil" >> /etc/modprobe.d/raspi-blacklist.conf
    echo "blacklist btbcm" >> /etc/modprobe.d/raspi-blacklist.conf
    echo "blacklist hci_uart" >> /etc/modprobe.d/raspi-blacklist.conf
}

disable_services()
{
    local services="wifi-country.service,
                    wpa_supplicant.service,
                    bluetooth.service,
                    hciuart.service,
                    avahi-daemon.service,
                    rpi-display-backlight.service,
                    triggerhappy.service,
                    triggerhappy.socket"
    local ret="0"

    for service in $(printf "$services" | sed "s/,/ /g"); do
        LOGI "Disabling $service"
        ret=$(systemctl disable $service &> /dev/null; echo $?)
        if [ "$ret" != "0" ]; then
            LOGW "Failed to disable $service"
        fi
    done
}

configure_tor()
{
    local country="$1"

    printf "" > $TOR_CONFIG_FILE
    printf "%s\n" "Log notice file $TOR_CONFIG_LOG" >> $TOR_CONFIG_FILE
    printf "%s\n" "VirtualAddrNetwork 10.192.0.0/10" >> $TOR_CONFIG_FILE
    printf "%s\n" "AutomapHostsOnResolve 1" >> $TOR_CONFIG_FILE
    printf "%s\n" "TransPort $TOR_CONFIG_IP:$TOR_CONFIG_TRANSPORT" >> $TOR_CONFIG_FILE
    printf "%s\n" "DNSPort $TOR_CONFIG_IP:$TOR_CONFIG_DNSPORT" >> $TOR_CONFIG_FILE
    printf "%s\n" "ExitNodes {$country}" >> $TOR_CONFIG_FILE
    printf "%s\n" "StrictNodes 1" >> $TOR_CONFIG_FILE

    touch $TOR_CONFIG_LOG
    chown debian-tor:debian-tor $TOR_CONFIG_LOG
    chmod 644 $TOR_CONFIG_LOG
}

configure_iptables()
{
    local internet_nic="$1"
    local client_nic="$2"

    printf "" > $IPTABLES_RULES_V4_PATH
    printf "%s\n" "*nat" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" ":PREROUTING ACCEPT [0:0]" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" ":INPUT ACCEPT [0:0]" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" ":OUTPUT ACCEPT [0:0]" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" ":POSTROUTING ACCEPT [0:0]" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" "-A PREROUTING -i $client_nic -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports $TOR_CONFIG_TRANSPORT" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" "-A POSTROUTING -o $internet_nic -j MASQUERADE" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" "COMMIT" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" "*filter" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" ":INPUT ACCEPT [0:0]" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" ":FORWARD ACCEPT [0:0]" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" ":OUTPUT ACCEPT [0:0]" >> $IPTABLES_RULES_V4_PATH
    printf "%s\n" "COMMIT" >> $IPTABLES_RULES_V4_PATH

    printf "" > $IPTABLES_RULES_V6_PATH
    printf "%s\n" "*filter" >> $IPTABLES_RULES_V6_PATH
    printf "%s\n" ":INPUT DROP [0:0]" >> $IPTABLES_RULES_V6_PATH
    printf "%s\n" ":FORWARD DROP [0:0]" >> $IPTABLES_RULES_V6_PATH
    printf "%s\n" ":OUTPUT DROP [0:0]" >> $IPTABLES_RULES_V6_PATH
    printf "%s\n" "COMMIT" >> $IPTABLES_RULES_V6_PATH
}

configure_dnsmasq()
{
    local client_nic="$1"

    printf "" > $DNSMASQ_CONFIG_FILE
    printf "%s\n" "interface=$client_nic" >> $DNSMASQ_CONFIG_FILE
    printf "%s\n" "    dhcp-range=$CLIENT_NETWORK_DHCP_START,$CLIENT_NETWORK_DHCP_END,$CLIENT_NETWORK_SUBNET_MASK,$CLIENT_NETWORK_DHCP_TIMEOUT" >> $DNSMASQ_CONFIG_FILE
    printf "%s\n" "dhcp-authoritative" >> $DNSMASQ_CONFIG_FILE
}

configure_dhcpd()
{
    local internet_nic="$1"
    local client_nic="$2"

    printf "" > $DHCP_CONFIG_FILE
    printf "%s\n" "interface $client_nic" >> $DHCP_CONFIG_FILE
    printf "%s\n" "static ip_address=$CLIENT_NETWORK_GATEWAY/$CLIENT_NETWORK_SUBNET_CDIR" >> $DHCP_CONFIG_FILE
    printf "%s\n" "static domain_name_servers=$CLIENT_NETWORK_GATEWAY $DNS_SERVER" >> $DHCP_CONFIG_FILE
    printf "%s\n" "denyinterfaces $client_nic" >> $DHCP_CONFIG_FILE
    printf "%s\n" "denyinterfaces $internet_nic" >> $DHCP_CONFIG_FILE
}

configure_ip_forwarding()
{
    echo "" > $SYSCTL_CONFIG_FILE
    echo "net.ipv4.ip_forward=1" >> $SYSCTL_CONFIG_FILE
    echo "net.ipv6.conf.all.disable_ipv6=1" >> $SYSCTL_CONFIG_FILE
    echo "net.ipv6.conf.default.disable_ipv6=1" >> $SYSCTL_CONFIG_FILE
    echo "net.ipv6.conf.lo.disable_ipv6=1" >> $SYSCTL_CONFIG_FILE
}

get_internet_nic()
{
    local nic=""

    nic=$(ip route list default | cut -f 5 -d ' ')

    printf "$nic"
}

get_country_details()
{
    local keywords="$1"
    local ret=""

    LOGI "Searching for the following keyword(s): $keywords"
    while read -r line; do
        ret=$(printf "$line" | grep -i "$keywords")
        if [ "$ret" ]; then
            printf "    $ret\n"
        fi
    done <<< "$COUNTRY_LIST"
    LOGI "Search complete!"
}

is_valid_country_code()
{
    local country="$1"
    local ret=""
    local status=0

    while read -r line; do
        ret=$(printf $line | grep -i "\[$country\]" &> /dev/null; echo $?)
        if [ "$ret" = "0" ]; then
            status=1
            break
        fi
    done <<< "$COUNTRY_LIST"

    printf $status
}

test_tor_connection()
{
    local required_tools="torsocks, curl"
    local query_ret=""
    local tor_ip=""
    local ret=""

    LOGI "Testing Tor connection. This could take a while..."

    for tool in $(printf "$required_tools" | sed "s/,[[:space:]]/ /g"); do
        ret=$(which $tool &> /dev/null; echo $?)
        if [ "$ret" != "0" ]; then
            LOGE "$tool is not available"
            exit 1
        fi
    done

    query_ret=$(torsocks -q curl $TORPROJECT_URL -s)
    ret=$(echo $?)
    if [ "$ret" == "0" ]; then
        # Not the prettiest way, but it gets the job done!
        tor_ip=$(printf $query_ret | sed -e 's/["{}]//g' -e 's/.*IP://g')
        LOGI "Successful connection. Tor IP is $tor_ip"
    else
        LOGE "Failed to connect to the Tor network"
        LOGW "It's possible Tor isn't running or there aren't active Tor exit relays"
    fi
}

restart_tor_service()
{
    LOGI "Restarting $TOR_SERVICE_NAME"

    ret=$(systemctl restart $TOR_SERVICE_NAME &> /dev/null; echo $?)
    if [ "$ret" == "3" ]; then
        LOGW "Can't restart '$TOR_SERVICE_NAME'. Service is not running or active"
    elif [ "$ret" == "5" ]; then
        LOGE "Can't restart '$TOR_SERVICE_NAME'. Service is not installed"
    elif [ "$ret" != "0" ]; then
        LOGE "Failed to restart '$TOR_SERVICE_NAME'"
        LOGW "Run 'journalctl -e -u $TOR_SERVICE_NAME' to review logs"
    else
        LOGI "Successfully restarted $TOR_SERVICE_NAME"
    fi
}

change_tor_exit_country()
{
    local country="$1"
    local ret=""

    LOGI "Setting tor exit relay country to '$country'"

    ret=$(is_valid_country_code "$country")
    if [ "$ret" != "1" ]; then
        LOGE "Invalid country code: $country"
        exit 1
    fi

    if [ ! -f "$TOR_CONFIG_FILE" ]; then
        LOGE "The Tor configuration file '$TOR_CONFIG_FILE' does not exist"
        LOGW "Run $FILENAME with '-c' and desired country code to configure as pitor first"
        exit 1
    fi

    # Do not check for return values when using sed
    sed -i "s/ExitNodes {.*}/ExitNodes {$country}/" $TOR_CONFIG_FILE &> /dev/null

    # Verify using grep that the change did ocurred!
    ret=$(grep "{$country}" $TOR_CONFIG_FILE &> /dev/null; echo $?)
    if [ "$ret" != 0 ]; then
        LOGE "Failed to set tor exit relay country to '$country'"
        exit 1
    fi

    LOGI "Restarting $TOR_SERVICE_NAME"
    ret=$(systemctl restart $TOR_SERVICE_NAME &> /dev/null; echo $?)
    if [ "$ret" != "0" ]; then
        LOGE "Failed to restart '$TOR_SERVICE_NAME'"
        LOGW "Run 'journalctl -e -u $TOR_SERVICE_NAME' to review logs"
        exit 1
    fi

    LOGI "Successfully updated Tor exit relay country!"
}

configure_pitor()
{
    local country="$1"
    local internet_nic=""
    local req_packages="tor, dnsmasq, iptables-persistent, curl"
    local services="tor, dnsmasq"
    local ret=""


    LOGI "Configuring Raspberry PI as a pitor"

    if [ -z "$country" ]; then
        LOGE "Must enter a valid two letter country code for the tor exit relay"
        exit 1
    fi


    internet_nic=$(get_internet_nic)
    if [ -z "$internet_nic" ]; then
        LOGE "Failed to find a network interface connected to the internet"
        exit 1
    fi
    LOGI "Detected network interface connected to the internet: $internet_nic"


    ret=$(cat /sys/class/net/$CLIENT_NIC/operstate)
    if [ "$ret" = "down" ]; then
        LOGE "PI is not connected to a client"
        exit 1
    fi
    LOGI "Detected client connection on '$CLIENT_NIC'"


    LOGI "Modifying keyboard layout"
    sed -i -e "s/gb/$DEFAULT_KEYBOARD_LAYOUT/g" /etc/default/keyboard


    export DEBIAN_FRONTEND=noninteractive
    LOGI "Updating the package sources list"
    apt-get update &> /dev/null
    LOGI "Upgrading system to the latest version. This could take a while..."
    apt-get upgrade -y &> /dev/null


    for package in $(printf "$req_packages" | sed "s/,[[:space:]]/ /g"); do
        LOGI "Installing $package"
        ret=$(apt-get install -y $package &> /dev/null; echo $?)
        if [ "$ret" != "0" ]; then
            LOGW "Failed to install $package"
        fi
    done


    for service in $(printf "$services" | sed "s/,[[:space:]]/ /g"); do
        LOGI "Stopping $service service"
        ret=$(systemctl stop $service &> /dev/null; echo $?)
        if [ "$ret" != "0" ]; then
            LOGW "Failed to stop $service service"
        fi
    done


    LOGI "Enable IPv4 Forwarding and disable IPv6"
    configure_ip_forwarding


    LOGI "Configure dhcp service for $CLIENT_NIC"
    configure_dhcpd "$internet_nic" "$CLIENT_NIC"


    LOGI "Configure dnsmasq service for $CLIENT_NIC"
    configure_dnsmasq "$CLIENT_NIC"


    LOGI "Configure iptables"
    configure_iptables "$internet_nic" "$CLIENT_NIC"


    LOGI "Configure tor service. Setting tor exit relay country to '$country'"
    configure_tor "$country"


    LOGI "Enabling newly installed services: dnsmasq, tor"
    for service in $(printf "$services" | sed "s/,[[:space:]]/ /g"); do
        LOGI "Enabling and starting $service service"
        ret=$(systemctl enable $service &> /dev/null; echo $?)
        if [ "$ret" != "0" ]; then
            LOGW "Failed to enable $service service"
        fi
        ret=$(systemctl start $service &> /dev/null; echo $?)
        if [ "$ret" != "0" ]; then
            LOGW "Failed to start $service service"
        fi
    done


    LOGI "Disable unused services"
    disable_services


    LOGI "Disable unused kernel modules"
    disable_kernel_modules


    LOGI "Setup complete! Raspberry PI is now a Tor Proxy aka pitor"
    LOGW "Must reboot pitor in order to apply changes!"
    printf "Press ENTER to reboot \n"
    read _
    systemctl reboot
}

show_version()
{
    printf "%s\n" "pitormgr v$VERSION by $AUTHOR"
    printf "\n"
}

usage()
{
    printf "%s\n" "Usage: $FILENAME [-h] [-r] [-t] [-v] (-c | -s | -q [...])"   1>&2
    printf "\n"                                                                 1>&2
    printf "%s\n" "optional arguments:"                                         1>&2
    printf "%s\n" "  -h    show this help message and exit"                     1>&2
    printf "%s\n" "  -c    configure Raspberry PI as an Onion PI with"          1>&2
    printf "%s\n" "        a given two letter country code [default: us]"       1>&2
    printf "%s\n" "  -q    query for country information given a keyword"       1>&2
    printf "%s\n" "  -r    restarts tor service"                                1>&2
    printf "%s\n" "  -s    changes the tor exit relay country location"         1>&2
    printf "%s\n" "        with a given two letter country code"                1>&2
    printf "%s\n" "  -t    test tor connection"                                 1>&2
    printf "%s\n" "  -v    show program's version number and exit"              1>&2
    printf "\n"                                                                 1>&2
}

main()
{
    local OPTS
    local OPTIND
    local default_country="us"
    local country=""
    local keywords=""
    local ret=""
    local status=0

    #
    # REF:
    # The following link gives an example of handling an option with optional arguments:
    #   https://stackoverflow.com/a/21709328
    #
    while getopts ':c:q:s:rtvh' OPTS
    do
        case $OPTS in
            c)
                country="${OPTARG:=$default_country}"
                if [ -z "$country" ]; then
                    country=$default_country
                fi

                show_version

                if [ $(id -u) -ne 0 ]; then
                    LOGW "Must be root to perform this action"
                    exec sudo "$0" $ACTION_CONFIG_PITOR "$country"
                    return
                fi

                configure_pitor "$country"
                return
                ;;
            q)
                keywords="${OPTARG}"
                if [ -z "$keywords" ]; then
                    usage
                    return
                fi

                show_version
                get_country_details "$keywords"
                return
                ;;
            r)
                show_version

                if [ $(id -u) -ne 0 ]; then
                    LOGW "Must be root to perform this action"
                    exec sudo "$0" $ACTION_RESTART_TOR "$country"
                    return
                fi

                restart_tor_service
                return
                ;;
            s)
                country="${OPTARG}"
                if [ -z "$country" ]; then
                    usage
                    return
                fi

                show_version

                if [ $(id -u) -ne 0 ]; then
                    LOGW "Must be root to perform this action"
                    exec sudo "$0" $ACTION_SET_TOR_EXIT "$country"
                    return
                fi

                change_tor_exit_country "$country"
                return
                ;;
            t)
                show_version
                test_tor_connection
                return
                ;;
            v)
                show_version
                return
                ;;
            h)
                usage
                return
                ;;
            :)
                if [[ "$OPTARG" = "c" ]]; then
                    show_version

                    if [ $(id -u) -ne 0 ]; then
                        LOGW "Must be root to perform this action"
                        exec sudo "$0" $ACTION_CONFIG_PITOR "$default_country"
                        return
                    fi

                    configure_pitor "$default_country"
                else
                    usage
                    return
                fi
                ;;
            *)
                usage
                return
                ;;
        esac
    done

    # If we got here, then no valid parameter was passed!
    usage
}


#
# FLOW OF EXECUTION
#
# Get the first parameter passed to see if there is an ACTION set.
# If an ACTION is set, then the script should be running at a higher
# privilege level. Otherwise, if no ACTION is set, then run the script
# as normal.
#

# This is the beginning of the script
ACTION=$1
ret=""

if [ "$ACTION_CONFIG_PITOR" == "$ACTION" ]; then
    # We should be root, but never trust
    if [ $(id -u) -ne 0 ]; then
        LOGW "Failed to configure pitor. Requires elevation of privileges!"
        exit 1
    fi

    configure_pitor "$2"

elif [ "$ACTION_SET_TOR_EXIT" == "$ACTION" ]; then
    # We should be root, but never trust
    if [ $(id -u) -ne 0 ]; then
        LOGW "Failed to set Tor exit country. Requires elevation of privileges!"
        exit 1
    fi

    change_tor_exit_country "$2"

elif [ "$ACTION_RESTART_TOR" == "$ACTION" ]; then
    # We should be root, but never trust
    if [ $(id -u) -ne 0 ]; then
        LOGW "Failed to restart service. Requires elevation of privileges!"
        exit 1
    fi

    restart_tor_service
else
    main "$@"
fi
