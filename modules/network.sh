#!/usr/bin/env bash

network_menu() {
    while true; do
        local choice=$(d --clear --title "Network Management" \
            --menu "\nSelect network operation:" $HEIGHT $WIDTH $MENU_HEIGHT \
            1 "List Network Interfaces" \
            2 "Interface Details" \
            3 "Enable/Disable Interface" \
            4 "Configure Static IP" \
            5 "Configure DHCP" \
            6 "DNS Management" \
            7 "Routing Table" \
            8 "Add/Remove Route" \
            9 "Active Connections" \
            10 "Ping Test" \
            11 "Traceroute" \
            12 "Network Statistics" \
            13 "Bandwidth Monitor" \
            14 "WiFi Management" \
            15 "VPN Management" \
            16 "Port Forwarding" \
            17 "Network Scan" \
            18 "Speed Test" \
            0 "Main Menu" \
            3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$choice" == "0" ]] && break
        
        case "$choice" in
            1) network_list_interfaces ;;
            2) network_interface_details ;;
            3) network_enable_disable ;;
            4) network_configure_static ;;
            5) network_configure_dhcp ;;
            6) network_dns_management ;;
            7) network_routing_table ;;
            8) network_add_route ;;
            9) network_active_connections ;;
            10) network_ping ;;
            11) network_traceroute ;;
            12) network_statistics ;;
            13) network_bandwidth_monitor ;;
            14) network_wifi_manager ;;
            15) network_vpn_manager ;;
            16) network_port_forwarding ;;
            17) network_scan ;;
            18) network_speed_test ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

network_list_interfaces() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                  NETWORK INTERFACES"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "ALL INTERFACES (ip):"
        echo "────────────────────────────────────────────────────────────────────────"
        ip -c a 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
        echo ""
        echo "INTERFACE SUMMARY:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total interfaces: $(ip -o link show | wc -l)"
        echo "   Up interfaces: $(ip -o link show | grep -c "state UP")"
        echo "   Down interfaces: $(ip -o link show | grep -c "state DOWN")"
        echo ""
        echo "PHYSICAL INTERFACES:"
        echo "────────────────────────────────────────────────────────────────────────"
        for iface in $(ls /sys/class/net/); do
            if [[ -d "/sys/class/net/$iface/device" ]]; then
                echo "   $iface: $(cat /sys/class/net/$iface/operstate 2>/dev/null)"
            fi
        done
        echo ""
        echo "WIRELESS INTERFACES:"
        echo "────────────────────────────────────────────────────────────────────────"
        iwconfig 2>/dev/null | grep -E "^[a-z]" | awk '{print $1}'
        echo ""
        echo "BRIDGE INTERFACES:"
        echo "────────────────────────────────────────────────────────────────────────"
        brctl show 2>/dev/null || echo "bridge-utils not installed"
        echo ""
        echo "BONDING INTERFACES:"
        echo "────────────────────────────────────────────────────────────────────────"
        cat /proc/net/bonding/* 2>/dev/null | head -20 || echo "No bonding interfaces"
        echo ""
        echo "MAC ADDRESSES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ip -o link show | awk '{print $2, $17}'
    } > "$TMP_FILE"
    show_text "Network Interfaces" "$TMP_FILE"
    log "Listed network interfaces"
}

network_interface_details() {
    local iface=$(get_input "Interface Details" "Enter interface name:" "eth0")
    [[ -z "$iface" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              INTERFACE DETAILS - $iface"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "BASIC INFO:"
        echo "────────────────────────────────────────────────────────────────────────"
        ip addr show "$iface" 2>/dev/null
        echo ""
        echo "STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        ip -s link show "$iface" 2>/dev/null
        echo ""
        echo "DRIVER INFO:"
        echo "────────────────────────────────────────────────────────────────────────"
        ethtool -i "$iface" 2>/dev/null || echo "ethtool not available"
        echo ""
        echo "SPEED & DUPLEX:"
        echo "────────────────────────────────────────────────────────────────────────"
        ethtool "$iface" 2>/dev/null | grep -E "Speed|Duplex|Auto-negotiation" || echo "ethtool not available"
        echo ""
        echo "WIRELESS INFO:"
        echo "────────────────────────────────────────────────────────────────────────"
        iwconfig "$iface" 2>/dev/null
        echo ""
        echo "MTU:"
        echo "────────────────────────────────────────────────────────────────────────"
        cat "/sys/class/net/$iface/mtu" 2>/dev/null
        echo ""
        echo "QUEUE LENGTH:"
        echo "────────────────────────────────────────────────────────────────────────"
        cat "/sys/class/net/$iface/tx_queue_len" 2>/dev/null
        echo ""
        echo "FLAGS:"
        echo "────────────────────────────────────────────────────────────────────────"
        cat "/sys/class/net/$iface/flags" 2>/dev/null
        echo ""
        echo "ADDRESS FAMILIES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ip addr show "$iface" | grep -E "inet|inet6"
    } > "$TMP_FILE"
    show_text "Interface Details" "$TMP_FILE"
    log "Viewed details for interface $iface"
}

network_enable_disable() {
    local iface=$(get_input "Enable/Disable" "Enter interface name:" "eth0")
    [[ -z "$iface" ]] && return
    
    local action=$(d --title "Interface Action" --menu "\nSelect action:" 12 60 2 \
        "up" "Enable Interface" \
        "down" "Disable Interface" \
        3>&1 1>&2 2>&3)
    [[ -z "$action" ]] && return
    
    if ask_yesno "$action interface $iface?"; then
        {
            sudo ip link set "$iface" "$action" 2>&1
            echo "Interface $iface set to $action"
            echo ""
            echo "Current status:"
            ip link show "$iface"
        } > "$TMP_FILE" 2>&1
        show_text "Interface Action Result" "$TMP_FILE"
        log "Set interface $iface to $action"
    fi
}

network_configure_static() {
    local iface=$(get_input "Configure Static IP" "Enter interface name:" "eth0")
    [[ -z "$iface" ]] && return
    
    local ip_addr=$(get_input "Configure Static IP" "Enter IP address with CIDR (e.g., 192.168.1.100/24):" "192.168.1.100/24")
    [[ -z "$ip_addr" ]] && return
    
    local gateway=$(get_input "Configure Static IP" "Enter gateway (e.g., 192.168.1.1):" "192.168.1.1")
    [[ -z "$gateway" ]] && return
    
    local dns=$(get_input "Configure Static IP" "Enter DNS servers (space separated):" "8.8.8.8 1.1.1.1")
    [[ -z "$dns" ]] && return
    
    if ask_yesno "Configure $iface with:\n\nIP: $ip_addr\nGateway: $gateway\nDNS: $dns"; then
        {
            echo "Configuring static IP on $iface..."
            sudo ip addr flush dev "$iface" 2>&1
            sudo ip addr add "$ip_addr" dev "$iface" 2>&1
            sudo ip link set "$iface" up 2>&1
            sudo ip route add default via "$gateway" dev "$iface" 2>&1
            
            echo "Setting DNS..."
            echo "nameserver $dns" | sudo tee /etc/resolv.conf > /dev/null
            
            echo ""
            echo "Configuration applied successfully!"
            echo ""
            echo "Current configuration:"
            ip addr show "$iface"
            echo ""
            echo "Gateway:"
            ip route show default
            echo ""
            echo "DNS:"
            cat /etc/resolv.conf
        } > "$TMP_FILE" 2>&1
        show_text "Static IP Configuration" "$TMP_FILE"
        log "Configured static IP on $iface: $ip_addr"
    fi
}

network_configure_dhcp() {
    local iface=$(get_input "Configure DHCP" "Enter interface name:" "eth0")
    [[ -z "$iface" ]] && return
    
    if ask_yesno "Configure $iface to use DHCP?"; then
        {
            echo "Configuring DHCP on $iface..."
            sudo ip addr flush dev "$iface" 2>&1
            sudo ip link set "$iface" up 2>&1
            
            if command -v dhclient &>/dev/null; then
                sudo dhclient -v "$iface" 2>&1
            elif command -v dhcpcd &>/dev/null; then
                sudo dhcpcd "$iface" 2>&1
            elif command -v nmcli &>/dev/null; then
                sudo nmcli device reapply "$iface" 2>&1
            else
                echo "DHCP client not found. Manual configuration required."
            fi
            
            echo ""
            echo "DHCP configuration applied!"
            echo ""
            echo "IP Address:"
            ip addr show "$iface" | grep inet
        } > "$TMP_FILE" 2>&1
        show_text "DHCP Configuration" "$TMP_FILE"
        log "Configured DHCP on $iface"
    fi
}

network_dns_management() {
    local choice=$(d --title "DNS Management" --menu "\nSelect DNS operation:" 14 60 5 \
        "show" "Show DNS Configuration" \
        "set" "Set DNS Server" \
        "add" "Add DNS Server" \
        "remove" "Remove DNS Server" \
        "flush" "Flush DNS Cache" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        show)
            {
                echo "DNS CONFIGURATION:"
                echo "────────────────────────────────────────────────────────────────────────"
                echo "Current /etc/resolv.conf:"
                cat /etc/resolv.conf 2>/dev/null
                echo ""
                echo "Systemd-resolved status:"
                resolvectl status 2>/dev/null || echo "systemd-resolved not active"
                echo ""
                echo "Hosts file:"
                cat /etc/hosts 2>/dev/null | head -20
                echo ""
                echo "DNS Cache (nscd):"
                nscd -g 2>/dev/null | grep -A 5 "hosts" || echo "nscd not running"
            } > "$TMP_FILE"
            show_text "DNS Configuration" "$TMP_FILE"
            ;;
        set)
            local dns1=$(get_input "Set DNS" "Enter primary DNS:" "8.8.8.8")
            [[ -z "$dns1" ]] && return
            local dns2=$(get_input "Set DNS" "Enter secondary DNS:" "1.1.1.1")
            [[ -z "$dns2" ]] && return
            
            {
                echo "Setting DNS servers..."
                sudo bash -c "echo 'nameserver $dns1' > /etc/resolv.conf"
                sudo bash -c "echo 'nameserver $dns2' >> /etc/resolv.conf"
                echo "DNS configured successfully!"
                echo ""
                cat /etc/resolv.conf
            } > "$TMP_FILE" 2>&1
            show_text "DNS Configuration" "$TMP_FILE"
            log "Set DNS servers: $dns1, $dns2"
            ;;
        add)
            local dns=$(get_input "Add DNS" "Enter DNS server IP:" "8.8.8.8")
            [[ -z "$dns" ]] && return
            
            {
                echo "Adding DNS server $dns..."
                sudo bash -c "echo 'nameserver $dns' >> /etc/resolv.conf"
                echo "DNS server added!"
                echo ""
                cat /etc/resolv.conf
            } > "$TMP_FILE" 2>&1
            show_text "Add DNS" "$TMP_FILE"
            log "Added DNS server: $dns"
            ;;
        remove)
            local dns=$(get_input "Remove DNS" "Enter DNS server IP to remove:" "8.8.8.8")
            [[ -z "$dns" ]] && return
            
            {
                sudo sed -i "/nameserver $dns/d" /etc/resolv.conf 2>&1
                echo "DNS server removed!"
                echo ""
                cat /etc/resolv.conf
            } > "$TMP_FILE" 2>&1
            show_text "Remove DNS" "$TMP_FILE"
            log "Removed DNS server: $dns"
            ;;
        flush)
            {
                echo "Flushing DNS cache..."
                if command -v systemctl &>/dev/null; then
                    sudo systemctl restart systemd-resolved 2>&1
                elif command -v nscd &>/dev/null; then
                    sudo nscd -i hosts 2>&1
                elif command -v dnsmasq &>/dev/null; then
                    sudo systemctl restart dnsmasq 2>&1
                fi
                echo "DNS cache flushed successfully!"
            } > "$TMP_FILE" 2>&1
            show_text "DNS Flush" "$TMP_FILE"
            log "Flushed DNS cache"
            ;;
    esac
}

network_routing_table() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                  ROUTING TABLE"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "IPv4 ROUTES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ip route show
        echo ""
        echo "IPv6 ROUTES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ip -6 route show 2>/dev/null
        echo ""
        echo "ROUTE STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total routes: $(ip route show | wc -l)"
        echo "   Default route: $(ip route show default 2>/dev/null)"
        echo "   Kernel IP routing table:"
        route -n 2>/dev/null
        echo ""
        echo "ARP TABLE:"
        echo "────────────────────────────────────────────────────────────────────────"
        ip neigh show 2>/dev/null
        echo ""
        echo "ROUTE CACHE:"
        echo "────────────────────────────────────────────────────────────────────────"
        ip route show cache 2>/dev/null
    } > "$TMP_FILE"
    show_text "Routing Table" "$TMP_FILE"
    log "Viewed routing table"
}

network_add_route() {
    local choice=$(d --title "Route Operation" --menu "\nSelect operation:" 12 60 2 \
        "add" "Add Route" \
        "delete" "Delete Route" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    if [[ "$choice" == "add" ]]; then
        local network=$(get_input "Add Route" "Enter network (e.g., 192.168.2.0/24):" "192.168.2.0/24")
        [[ -z "$network" ]] && return
        local gateway=$(get_input "Add Route" "Enter gateway:" "192.168.1.1")
        [[ -z "$gateway" ]] && return
        local iface=$(get_input "Add Route" "Enter interface:" "eth0")
        [[ -z "$iface" ]] && return
        
        if ask_yesno "Add route: $network via $gateway dev $iface"; then
            {
                sudo ip route add "$network" via "$gateway" dev "$iface" 2>&1
                echo "Route added successfully!"
                echo ""
                ip route show "$network"
            } > "$TMP_FILE" 2>&1
            show_text "Add Route" "$TMP_FILE"
            log "Added route: $network via $gateway"
        fi
    else
        local network=$(get_input "Delete Route" "Enter network to delete:" "192.168.2.0/24")
        [[ -z "$network" ]] && return
        
        if ask_yesno "Delete route to $network?"; then
            {
                sudo ip route del "$network" 2>&1
                echo "Route deleted successfully!"
                echo ""
                ip route show
            } > "$TMP_FILE" 2>&1
            show_text "Delete Route" "$TMP_FILE"
            log "Deleted route to $network"
        fi
    fi
}

network_active_connections() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                  ACTIVE NETWORK CONNECTIONS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "ALL SOCKETS (ss):"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo ss -tulpn 2>/dev/null
        echo ""
        echo "ESTABLISHED CONNECTIONS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo ss -tunp 2>/dev/null | grep ESTAB
        echo ""
        echo "LISTENING PORTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo ss -tlnp 2>/dev/null
        echo ""
        echo "UDP CONNECTIONS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo ss -ulnp 2>/dev/null
        echo ""
        echo "UNIX SOCKETS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo ss -xlp 2>/dev/null | head -30
        echo ""
        echo "CONNECTION STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total TCP: $(ss -tun | grep -c tcp)"
        echo "   Total UDP: $(ss -tun | grep -c udp)"
        echo "   ESTABLISHED: $(ss -tun | grep -c ESTAB)"
        echo "   LISTENING: $(ss -tun | grep -c LISTEN)"
        echo "   TIME_WAIT: $(ss -tun | grep -c TIME_WAIT)"
    } > "$TMP_FILE"
    show_text "Active Connections" "$TMP_FILE"
    log "Viewed active connections"
}

network_ping() {
    local target=$(get_input "Ping Test" "Enter host/IP to ping:" "8.8.8.8")
    [[ -z "$target" ]] && return
    
    local count=$(get_input "Ping Test" "Number of pings:" "4")
    [[ -z "$count" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              PING TEST - $target"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        ping -c "$count" "$target" 2>&1
        echo ""
        echo "PING STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        ping -c "$count" "$target" 2>&1 | grep -E "packets transmitted|rtt"
    } > "$TMP_FILE"
    show_text "Ping Test" "$TMP_FILE"
    log "Pinged $target"
}

network_traceroute() {
    local target=$(get_input "Traceroute" "Enter host/IP:" "8.8.8.8")
    [[ -z "$target" ]] && return
    
    local method=$(d --title "Traceroute Method" --menu "\nSelect method:" 12 60 2 \
        "traceroute" "Standard traceroute" \
        "mtr" "MTR (real-time)" \
        3>&1 1>&2 2>&3)
    [[ -z "$method" ]] && return
    
    if [[ "$method" == "traceroute" ]]; then
        {
            echo "TRACEROUTE to $target"
            echo "────────────────────────────────────────────────────────────────────────"
            if command -v traceroute &>/dev/null; then
                traceroute -n "$target" 2>&1
            else
                echo "traceroute not installed. Install: sudo apt install traceroute"
            fi
        } > "$TMP_FILE"
    else
        {
            echo "MTR to $target (real-time tracing)"
            echo "────────────────────────────────────────────────────────────────────────"
            if command -v mtr &>/dev/null; then
                mtr -n "$target" 2>&1
            else
                echo "mtr not installed. Install: sudo apt install mtr-tiny"
            fi
        } > "$TMP_FILE"
    fi
    show_text "Traceroute" "$TMP_FILE"
    log "Traced route to $target"
}

network_statistics() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                  NETWORK STATISTICS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "INTERFACE STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        netstat -i 2>/dev/null
        echo ""
        echo "PROTOCOL STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        netstat -s 2>/dev/null | head -50
        echo ""
        echo "IP STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        netstat -s 2>/dev/null | grep -A 10 "Ip:"
        echo ""
        echo "TCP STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        netstat -s 2>/dev/null | grep -A 10 "Tcp:"
        echo ""
        echo "UDP STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        netstat -s 2>/dev/null | grep -A 5 "Udp:"
        echo ""
        echo "PACKET DROPS:"
        echo "────────────────────────────────────────────────────────────────────────"
        ip -s link show | grep -E "RX|TX|errors|dropped" | head -20
    } > "$TMP_FILE"
    show_text "Network Statistics" "$TMP_FILE"
    log "Viewed network statistics"
}

network_bandwidth_monitor() {
    local iface=$(get_input "Bandwidth Monitor" "Enter interface (or 'all'):" "all")
    [[ -z "$iface" ]] && return
    
    local duration=$(get_input "Bandwidth Monitor" "Monitor duration (seconds):" "10")
    [[ -z "$duration" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              BANDWIDTH MONITOR - $iface"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "Current bandwidth usage:"
        echo "────────────────────────────────────────────────────────────────────────"
        
        if command -v ifstat &>/dev/null; then
            if [[ "$iface" == "all" ]]; then
                ifstat -t "$duration" 1 2>&1
            else
                ifstat -i "$iface" -t "$duration" 1 2>&1
            fi
        elif command -v nload &>/dev/null; then
            echo "nload installed. For better monitoring, run: nload $iface"
        elif command -v iptraf &>/dev/null; then
            echo "iptraf installed. For better monitoring, run: iptraf"
        else
            echo "Bandwidth monitoring tools not found."
            echo ""
            echo "Available options:"
            echo "  sudo apt install ifstat nload iptraf-ng"
            echo ""
            echo "Basic bandwidth estimation:"
            if [[ "$iface" != "all" ]]; then
                echo ""
                echo "RX/TX bytes for $iface:"
                cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null
                cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null
            fi
        fi
    } > "$TMP_FILE"
    show_text "Bandwidth Monitor" "$TMP_FILE"
    log "Monitored bandwidth on $iface"
}

network_wifi_manager() {
    if ! command -v nmcli &>/dev/null; then
        show_msg "Error" "nmcli (NetworkManager) not installed.\n\nInstall: sudo apt install network-manager"
        return
    fi
    
    local choice=$(d --title "WiFi Management" --menu "\nSelect WiFi operation:" 14 60 5 \
        "scan" "Scan WiFi Networks" \
        "connect" "Connect to WiFi" \
        "disconnect" "Disconnect from WiFi" \
        "status" "Show WiFi Status" \
        "hotspot" "Create WiFi Hotspot" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        scan)
            {
                echo "SCANNING WiFi NETWORKS..."
                echo "────────────────────────────────────────────────────────────────────────"
                nmcli device wifi list 2>&1
                echo ""
                echo "WiFi Devices:"
                nmcli device status 2>&1 | grep wifi
            } > "$TMP_FILE"
            show_text "WiFi Scan" "$TMP_FILE"
            log "Scanned WiFi networks"
            ;;
        connect)
            local ssid=$(get_input "WiFi Connect" "Enter SSID:")
            [[ -z "$ssid" ]] && return
            local password=$(get_password "WiFi Connect" "Enter password:")
            [[ -z "$password" ]] && return
            
            {
                nmcli device wifi connect "$ssid" password "$password" 2>&1
                echo ""
                echo "Connection status:"
                nmcli device status
            } > "$TMP_FILE" 2>&1
            show_text "WiFi Connect" "$TMP_FILE"
            log "Connected to WiFi: $ssid"
            ;;
        disconnect)
            {
                nmcli device disconnect 2>&1
                echo "Disconnected from WiFi"
                nmcli device status
            } > "$TMP_FILE" 2>&1
            show_text "WiFi Disconnect" "$TMP_FILE"
            log "Disconnected from WiFi"
            ;;
        status)
            {
                echo "WiFi STATUS:"
                echo "────────────────────────────────────────────────────────────────────────"
                nmcli device status
                echo ""
                echo "Active Connections:"
                nmcli connection show --active
                echo ""
                echo "Current WiFi Details:"
                nmcli device wifi list | grep "*"
            } > "$TMP_FILE"
            show_text "WiFi Status" "$TMP_FILE"
            log "Viewed WiFi status"
            ;;
        hotspot)
            local ssid=$(get_input "WiFi Hotspot" "Enter hotspot SSID:" "Linux-Hotspot")
            [[ -z "$ssid" ]] && return
            local password=$(get_password "WiFi Hotspot" "Enter hotspot password (min 8 chars):")
            [[ -z "$password" ]] && return
            
            {
                nmcli device wifi hotspot ifname wlan0 ssid "$ssid" password "$password" 2>&1
                echo ""
                echo "Hotspot created successfully!"
                echo "SSID: $ssid"
                echo "Password: $password"
                echo ""
                nmcli device status
            } > "$TMP_FILE" 2>&1
            show_text "WiFi Hotspot" "$TMP_FILE"
            log "Created WiFi hotspot: $ssid"
            ;;
    esac
}

network_vpn_manager() {
    local choice=$(d --title "VPN Management" --menu "\nSelect VPN operation:" 12 60 3 \
        "openvpn" "OpenVPN Management" \
        "wireguard" "WireGuard Management" \
        "status" "VPN Status" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        openvpn)
            {
                echo "OPENVPN STATUS:"
                echo "────────────────────────────────────────────────────────────────────────"
                if systemctl is-active --quiet openvpn 2>/dev/null; then
                    systemctl status openvpn --no-pager
                else
                    echo "OpenVPN not running"
                fi
                echo ""
                echo "OpenVPN Configs:"
                ls -la /etc/openvpn/*.conf 2>/dev/null || echo "No OpenVPN configs found"
            } > "$TMP_FILE"
            show_text "OpenVPN" "$TMP_FILE"
            log "Viewed OpenVPN status"
            ;;
        wireguard)
            {
                echo "WIREGUARD STATUS:"
                echo "────────────────────────────────────────────────────────────────────────"
                if command -v wg &>/dev/null; then
                    wg show 2>/dev/null
                    echo ""
                    echo "WireGuard Interfaces:"
                    ls -la /etc/wireguard/*.conf 2>/dev/null || echo "No WireGuard configs found"
                else
                    echo "WireGuard not installed. Install: sudo apt install wireguard"
                fi
            } > "$TMP_FILE"
            show_text "WireGuard" "$TMP_FILE"
            log "Viewed WireGuard status"
            ;;
        status)
            {
                echo "VPN STATUS"
                echo "────────────────────────────────────────────────────────────────────────"
                echo "OpenVPN:"
                systemctl status openvpn --no-pager 2>/dev/null | head -10 || echo "OpenVPN not installed"
                echo ""
                echo "WireGuard:"
                wg show 2>/dev/null || echo "WireGuard not installed/running"
                echo ""
                echo "Tunnel Interfaces:"
                ip link show | grep -E "tun|tap" 2>/dev/null
            } > "$TMP_FILE"
            show_text "VPN Status" "$TMP_FILE"
            log "Viewed VPN status"
            ;;
    esac
}

network_port_forwarding() {
    local choice=$(d --title "Port Forwarding" --menu "\nSelect operation:" 12 60 3 \
        "add" "Add Port Forward" \
        "delete" "Delete Port Forward" \
        "list" "List Port Forwards" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        add)
            local src_port=$(get_input "Port Forward" "Enter source port:" "8080")
            [[ -z "$src_port" ]] && return
            local dest_ip=$(get_input "Port Forward" "Enter destination IP:" "192.168.1.100")
            [[ -z "$dest_ip" ]] && return
            local dest_port=$(get_input "Port Forward" "Enter destination port:" "80")
            [[ -z "$dest_port" ]] && return
            local proto=$(d --title "Protocol" --menu "\nSelect protocol:" 12 60 2 \
                "tcp" "TCP" \
                "udp" "UDP" \
                3>&1 1>&2 2>&3)
            [[ -z "$proto" ]] && return
            
            if ask_yesno "Forward port $src_port/$proto to $dest_ip:$dest_port"; then
                {
                    echo "Adding port forward..."
                    if command -v nft &>/dev/null; then
                        sudo nft add table ip nat 2>/dev/null
                        sudo nft add chain ip nat prerouting { type nat hook prerouting priority 0 \; } 2>/dev/null
                        sudo nft add rule ip nat prerouting tcp dport "$src_port" dnat to "$dest_ip:$dest_port" 2>&1
                    else
                        sudo iptables -t nat -A PREROUTING -p "$proto" --dport "$src_port" -j DNAT --to-destination "$dest_ip:$dest_port" 2>&1
                        sudo iptables -A FORWARD -p "$proto" -d "$dest_ip" --dport "$dest_port" -j ACCEPT 2>&1
                    fi
                    echo "Port forward added successfully!"
                } > "$TMP_FILE" 2>&1
                show_text "Port Forward" "$TMP_FILE"
                log "Added port forward: $src_port->$dest_ip:$dest_port"
            fi
            ;;
        delete)
            local src_port=$(get_input "Port Forward Delete" "Enter source port to delete:" "8080")
            [[ -z "$src_port" ]] && return
            
            if ask_yesno "Delete port forward for $src_port?"; then
                {
                    echo "Deleting port forward..."
                    if command -v nft &>/dev/null; then
                        sudo nft delete rule ip nat prerouting tcp dport "$src_port" dnat 2>&1
                    else
                        sudo iptables -t nat -D PREROUTING -p tcp --dport "$src_port" -j DNAT 2>&1
                    fi
                    echo "Port forward deleted!"
                } > "$TMP_FILE" 2>&1
                show_text "Delete Port Forward" "$TMP_FILE"
                log "Deleted port forward for $src_port"
            fi
            ;;
        list)
            {
                echo "CURRENT PORT FORWARDS:"
                echo "────────────────────────────────────────────────────────────────────────"
                if command -v nft &>/dev/null; then
                    nft list ruleset | grep -A 5 "dnat"
                else
                    sudo iptables -t nat -L PREROUTING -v -n 2>/dev/null
                    echo ""
                    echo "FORWARD RULES:"
                    sudo iptables -L FORWARD -v -n 2>/dev/null
                fi
            } > "$TMP_FILE"
            show_text "Port Forwards" "$TMP_FILE"
            log "Listed port forwards"
            ;;
    esac
}

network_scan() {
    local target=$(get_input "Network Scan" "Enter target network (e.g., 192.168.1.0/24):" "192.168.1.0/24")
    [[ -z "$target" ]] && return
    
    local scan_type=$(d --title "Scan Type" --menu "\nSelect scan type:" 14 60 4 \
        "ping" "Ping Sweep" \
        "ports" "Port Scan" \
        "services" "Service Detection" \
        "os" "OS Detection" \
        3>&1 1>&2 2>&3)
    [[ -z "$scan_type" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              NETWORK SCAN - $target"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if command -v nmap &>/dev/null; then
            case "$scan_type" in
                ping)
                    sudo nmap -sn "$target" 2>&1
                    ;;
                ports)
                    local ports=$(get_input "Port Scan" "Enter ports (e.g., 22,80,443 or 1-1000):" "1-1000")
                    [[ -z "$ports" ]] && return
                    sudo nmap -p "$ports" "$target" 2>&1
                    ;;
                services)
                    sudo nmap -sV "$target" 2>&1
                    ;;
                os)
                    sudo nmap -O "$target" 2>&1
                    ;;
            esac
        else
            echo "nmap not installed. Install: sudo apt install nmap"
            echo ""
            echo "Basic ping sweep:"
            local network=$(echo "$target" | cut -d/ -f1 | cut -d. -f1-3)
            for i in {1..254}; do
                ping -c 1 -W 1 "$network.$i" 2>/dev/null | grep "64 bytes" &
            done
            wait
        fi
    } > "$TMP_FILE"
    show_text "Network Scan" "$TMP_FILE"
    log "Scanned network: $target"
}

network_speed_test() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              INTERNET SPEED TEST"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if command -v speedtest-cli &>/dev/null; then
            speedtest-cli --simple 2>&1
            echo ""
            echo "DETAILED TEST:"
            speedtest-cli 2>&1
        elif command -v speedtest &>/dev/null; then
            speedtest 2>&1
        else
            echo "Speed test tools not found."
            echo ""
            echo "Install with:"
            echo "  sudo apt install speedtest-cli"
            echo "  or"
            echo "  pip install speedtest-cli"
            echo ""
            echo "Or use: https://speedtest.net in browser"
        fi
    } > "$TMP_FILE"
    show_text "Speed Test" "$TMP_FILE"
    log "Ran speed test"
}