#!/usr/bin/env bash

security_menu() {
    while true; do
        local choice=$(d --clear --title "Security & Firewall Management" \
            --menu "\nSelect security operation:" $HEIGHT $WIDTH $MENU_HEIGHT \
            1 "Firewall Status" \
            2 "Enable Firewall" \
            3 "Disable Firewall" \
            4 "Add Firewall Rule" \
            5 "Remove Firewall Rule" \
            6 "List Firewall Rules" \
            7 "Port Scanning" \
            8 "Vulnerability Check" \
            9 "SSL Certificate Info" \
            10 "Password Policy" \
            11 "SSH Security" \
            12 "Failed Login Attempts" \
            13 "System Audit" \
            14 "Malware Scan" \
            15 "Security Report" \
            0 "Main Menu" \
            3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$choice" == "0" ]] && break
        
        case "$choice" in
            1) security_firewall_status ;;
            2) security_firewall_enable ;;
            3) security_firewall_disable ;;
            4) security_firewall_add_rule ;;
            5) security_firewall_remove_rule ;;
            6) security_firewall_list_rules ;;
            7) security_port_scan ;;
            8) security_vulnerability_check ;;
            9) security_ssl_cert ;;
            10) security_password_policy ;;
            11) security_ssh_security ;;
            12) security_failed_logins ;;
            13) security_audit ;;
            14) security_malware_scan ;;
            15) security_report ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

security_firewall_status() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    FIREWALL STATUS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if command -v ufw &>/dev/null; then
            echo "UFW STATUS:"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo ufw status verbose 2>/dev/null
            echo ""
        fi
        
        if command -v iptables &>/dev/null; then
            echo "IPTABLES STATUS:"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo iptables -L -v -n 2>/dev/null | head -30
            echo ""
            echo "NAT TABLE:"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo iptables -t nat -L -v -n 2>/dev/null | head -20
            echo ""
            echo "MANGLE TABLE:"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo iptables -t mangle -L -v -n 2>/dev/null | head -20
            echo ""
        fi
        
        if command -v nft &>/dev/null; then
            echo "NFTABLES STATUS:"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo nft list ruleset 2>/dev/null | head -30
            echo ""
        fi
        
        echo "FIREWALL STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   UFW installed: $(command -v ufw &>/dev/null && echo "Yes" || echo "No")"
        echo "   UFW active: $(sudo ufw status 2>/dev/null | grep -q "Status: active" && echo "Yes" || echo "No")"
        echo "   iptables rules: $(sudo iptables -L 2>/dev/null | wc -l)"
        echo "   nftables rules: $(sudo nft list ruleset 2>/dev/null | wc -l)"
    } > "$TMP_FILE"
    show_text "Firewall Status" "$TMP_FILE"
    log "Viewed firewall status"
}

security_firewall_enable() {
    if ! command -v ufw &>/dev/null; then
        show_msg "Error" "UFW not installed.\n\nInstall: sudo apt install ufw"
        return
    fi
    
    if ask_yesno "Enable UFW firewall?\n\nWARNING: This may disconnect SSH sessions if not configured properly!"; then
        {
            echo "Enabling UFW..."
            sudo ufw --force enable 2>&1
            echo ""
            echo "UFW enabled successfully!"
            sudo ufw status verbose
        } > "$TMP_FILE" 2>&1
        show_text "Enable Firewall" "$TMP_FILE"
        log "Enabled firewall"
    fi
}

security_firewall_disable() {
    if ! command -v ufw &>/dev/null; then
        show_msg "Error" "UFW not installed."
        return
    fi
    
    if ask_yesno "Disable UFW firewall?"; then
        {
            echo "Disabling UFW..."
            sudo ufw disable 2>&1
            echo ""
            echo "UFW disabled successfully!"
            sudo ufw status
        } > "$TMP_FILE" 2>&1
        show_text "Disable Firewall" "$TMP_FILE"
        log "Disabled firewall"
    fi
}

security_firewall_add_rule() {
    local choice=$(d --title "Add Firewall Rule" --menu "\nSelect rule type:" 14 60 5 \
        "allow" "Allow Port" \
        "deny" "Deny Port" \
        "allow_ip" "Allow IP" \
        "deny_ip" "Deny IP" \
        "limit" "Limit Connections" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        allow|deny)
            local port=$(get_input "Add Rule" "Enter port number:" "80")
            [[ -z "$port" ]] && return
            local proto=$(d --title "Protocol" --menu "\nSelect protocol:" 12 60 2 \
                "tcp" "TCP" \
                "udp" "UDP" \
                3>&1 1>&2 2>&3)
            [[ -z "$proto" ]] && return
            
            if ask_yesno "$choice port $port/$proto?"; then
                {
                    if [[ "$choice" == "allow" ]]; then
                        sudo ufw allow "$port"/"$proto" 2>&1
                    else
                        sudo ufw deny "$port"/"$proto" 2>&1
                    fi
                    echo ""
                    echo "Rule added successfully!"
                    sudo ufw status
                } > "$TMP_FILE" 2>&1
                show_text "Add Firewall Rule" "$TMP_FILE"
                log "Added rule: $choice $port/$proto"
            fi
            ;;
        allow_ip|deny_ip)
            local ip=$(get_input "Add Rule" "Enter IP address:" "192.168.1.100")
            [[ -z "$ip" ]] && return
            
            if ask_yesno "$choice IP: $ip?"; then
                {
                    if [[ "$choice" == "allow_ip" ]]; then
                        sudo ufw allow from "$ip" 2>&1
                    else
                        sudo ufw deny from "$ip" 2>&1
                    fi
                    echo ""
                    echo "Rule added successfully!"
                    sudo ufw status
                } > "$TMP_FILE" 2>&1
                show_text "Add Firewall Rule" "$TMP_FILE"
                log "Added rule: $choice $ip"
            fi
            ;;
        limit)
            local port=$(get_input "Add Rule" "Enter port number:" "22")
            [[ -z "$port" ]] && return
            
            if ask_yesno "Limit connections to port $port?"; then
                {
                    sudo ufw limit "$port" 2>&1
                    echo ""
                    echo "Rule added successfully!"
                    sudo ufw status
                } > "$TMP_FILE" 2>&1
                show_text "Add Firewall Rule" "$TMP_FILE"
                log "Added rule: limit $port"
            fi
            ;;
    esac
}

security_firewall_remove_rule() {
    if ! command -v ufw &>/dev/null; then
        show_msg "Error" "UFW not installed."
        return
    fi
    
    local rule_num=$(get_input "Remove Firewall Rule" "Enter rule number to remove (from list):" "")
    [[ -z "$rule_num" ]] && return
    
    if ask_yesno "Remove firewall rule number $rule_num?"; then
        {
            sudo ufw delete "$rule_num" 2>&1
            echo ""
            echo "Rule removed successfully!"
            sudo ufw status
        } > "$TMP_FILE" 2>&1
        show_text "Remove Firewall Rule" "$TMP_FILE"
        log "Removed firewall rule: $rule_num"
    fi
}

security_firewall_list_rules() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    FIREWALL RULES"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if command -v ufw &>/dev/null; then
            echo "UFW RULES (numbered):"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo ufw status numbered 2>/dev/null
            echo ""
            echo "UFW RULES (verbose):"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo ufw status verbose 2>/dev/null
            echo ""
        fi
        
        echo "IPTABLES RULES:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo iptables -L -n -v --line-numbers 2>/dev/null
        echo ""
        echo "IPTABLES NAT RULES:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo iptables -t nat -L -n -v --line-numbers 2>/dev/null
    } > "$TMP_FILE"
    show_text "Firewall Rules" "$TMP_FILE"
    log "Listed firewall rules"
}

security_port_scan() {
    local target=$(get_input "Port Scan" "Enter target IP/hostname:" "localhost")
    [[ -z "$target" ]] && return
    
    local ports=$(get_input "Port Scan" "Enter ports to scan (e.g., 22,80,443 or 1-1000):" "22,80,443,3306,5432,8080,8443")
    [[ -z "$ports" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              PORT SCAN - $target"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if command -v nmap &>/dev/null; then
            echo "NMAP SCAN:"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo nmap -p "$ports" -sV "$target" 2>&1
            echo ""
            echo "NMAP OS DETECTION:"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo nmap -O "$target" 2>&1
        else
            echo "nmap not installed. Installing..."
            sudo apt install -y nmap 2>/dev/null || sudo dnf install -y nmap 2>/dev/null
            echo ""
            echo "Installing nmap... Please run again after installation."
        fi
        
        echo ""
        echo "OPEN PORTS (local):"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo netstat -tulpn 2>/dev/null | grep LISTEN
        echo ""
        echo "CONNECTIONS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo ss -tunp 2>/dev/null | head -20
    } > "$TMP_FILE"
    show_text "Port Scan" "$TMP_FILE"
    log "Performed port scan on $target"
}

security_vulnerability_check() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    VULNERABILITY CHECK"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "OS VULNERABILITIES:"
        echo "────────────────────────────────────────────────────────────────────────"
        if command -v lynis &>/dev/null; then
            sudo lynis audit system 2>&1 | grep -A 5 -B 5 "Warning"
        else
            echo "lynis not installed. Install with: sudo apt install lynis"
        fi
        
        echo ""
        echo "OPEN PORTS CHECK:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo ss -tuln 2>/dev/null | grep -E "LISTEN|tcp|udp"
        
        echo ""
        echo "SUID BINARIES:"
        echo "────────────────────────────────────────────────────────────────────────"
        find / -type f -perm -4000 2>/dev/null | head -20
        
        echo ""
        echo "WORLD-WRITABLE FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        find / -type f -perm -o+w 2>/dev/null | head -20
        
        echo ""
        echo "FAILED LOGIN ATTEMPTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l
        sudo grep "Failed password" /var/log/secure 2>/dev/null | wc -l
        
        echo ""
        echo "SUSPICIOUS PROCESSES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps aux | grep -E "nc|netcat|socat|nmap|hydra|john|aircrack" | grep -v grep
        
        echo ""
        echo "OUTDATED PACKAGES:"
        echo "────────────────────────────────────────────────────────────────────────"
        if command -v apt &>/dev/null; then
            apt list --upgradable 2>/dev/null | wc -l
        elif command -v dnf &>/dev/null; then
            dnf check-update 2>/dev/null | wc -l
        elif command -v pacman &>/dev/null; then
            pacman -Qu 2>/dev/null | wc -l
        fi
    } > "$TMP_FILE"
    show_text "Vulnerability Check" "$TMP_FILE"
    log "Performed vulnerability check"
}

security_ssl_cert() {
    local host=$(get_input "SSL Certificate" "Enter hostname or IP:" "google.com")
    [[ -z "$host" ]] && return
    
    local port=$(get_input "SSL Certificate" "Enter port:" "443")
    [[ -z "$port" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              SSL CERTIFICATE - $host:$port"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if command -v openssl &>/dev/null; then
            echo "CERTIFICATE INFO:"
            echo "────────────────────────────────────────────────────────────────────────"
            echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null | openssl x509 -text -noout
            echo ""
            echo "EXPIRY DATE:"
            echo "────────────────────────────────────────────────────────────────────────"
            echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null | openssl x509 -noout -enddate
            echo ""
            echo "ISSUER:"
            echo "────────────────────────────────────────────────────────────────────────"
            echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null | openssl x509 -noout -issuer
            echo ""
            echo "SUBJECT:"
            echo "────────────────────────────────────────────────────────────────────────"
            echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null | openssl x509 -noout -subject
            echo ""
            echo "CHECK EXPIRY:"
            echo "────────────────────────────────────────────────────────────────────────"
            expiry_date=$(echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
            echo "   $expiry_date"
            
            if date --date "$expiry_date" +%s &>/dev/null; then
                expiry_epoch=$(date --date "$expiry_date" +%s)
                current_epoch=$(date +%s)
                days_left=$(( ($expiry_epoch - $current_epoch) / 86400 ))
                echo "   Days left: $days_left"
                
                if [[ $days_left -lt 7 ]]; then
                    echo "   ! WARNING: Certificate expires in less than 7 days!"
                elif [[ $days_left -lt 30 ]]; then
                    echo "   ! Certificate expires in less than 30 days"
                else
                    echo "   ✓ Certificate is valid for $days_left more days"
                fi
            fi
        else
            echo "openssl not installed. Install with: sudo apt install openssl"
        fi
        
        echo ""
        echo "CERTIFICATE CHAIN:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo | openssl s_client -connect "$host:$port" -servername "$host" -showcerts 2>/dev/null | grep "subject="
    } > "$TMP_FILE"
    show_text "SSL Certificate" "$TMP_FILE"
    log "Checked SSL certificate for $host:$port"
}

security_password_policy() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    PASSWORD POLICY"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "PASSWORD AGING:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f /etc/login.defs ]]; then
            grep -E "PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_MIN_LEN|PASS_WARN_AGE" /etc/login.defs
        fi
        
        echo ""
        echo "USER PASSWORD AGING:"
        echo "────────────────────────────────────────────────────────────────────────"
        for user in $(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd | head -10); do
            echo "   $user:"
            sudo chage -l "$user" 2>/dev/null | grep -E "Last password|Password expires|Account expires"
        done
        
        echo ""
        echo "PASSWORD COMPLEXITY (PAM):"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f /etc/pam.d/common-password ]]; then
            cat /etc/pam.d/common-password 2>/dev/null | grep -v "^#" | grep -v "^$"
        elif [[ -f /etc/pam.d/system-auth ]]; then
            cat /etc/pam.d/system-auth 2>/dev/null | grep -v "^#" | grep -v "^$"
        fi
        
        echo ""
        echo "HASH ALGORITHM:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f /etc/login.defs ]]; then
            grep -E "ENCRYPT_METHOD" /etc/login.defs
        fi
        
        echo ""
        echo "PASSWORD COMPLEXITY SETTINGS:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f /etc/security/pwquality.conf ]]; then
            cat /etc/security/pwquality.conf 2>/dev/null | grep -v "^#" | grep -v "^$"
        fi
    } > "$TMP_FILE"
    show_text "Password Policy" "$TMP_FILE"
    log "Viewed password policy"
}

security_ssh_security() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    SSH SECURITY"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "SSH CONFIGURATION:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f /etc/ssh/sshd_config ]]; then
            cat /etc/ssh/sshd_config 2>/dev/null | grep -v "^#" | grep -v "^$"
        else
            echo "sshd_config not found"
        fi
        
        echo ""
        echo "SSH KEY SETTINGS:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f /etc/ssh/sshd_config ]]; then
            grep -E "PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|PermitEmptyPasswords|X11Forwarding|ClientAliveInterval" /etc/ssh/sshd_config 2>/dev/null
        fi
        
        echo ""
        echo "SSH USERS:"
        echo "────────────────────────────────────────────────────────────────────────"
        for user in $(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd | head -10); do
            if [[ -f "/home/$user/.ssh/authorized_keys" ]]; then
                echo "   $user: $(cat /home/$user/.ssh/authorized_keys 2>/dev/null | wc -l) keys"
            fi
        done
        
        echo ""
        echo "SSH CONNECTIONS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo ss -tunp 2>/dev/null | grep ":22"
        
        echo ""
        echo "SSH BRUTE FORCE ATTEMPTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10
        sudo grep "Failed password" /var/log/secure 2>/dev/null | tail -10
        
        echo ""
        echo "SSH CONFIGURATION CHECK:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f /etc/ssh/sshd_config ]]; then
            # Check for common security issues
            if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
                echo "   ! WARNING: Root login is enabled"
            else
                echo "   ✓ Root login is disabled"
            fi
            
            if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
                echo "   ! WARNING: Password authentication is enabled"
            else
                echo "   ✓ Password authentication is disabled (using keys)"
            fi
            
            if grep -q "^PubkeyAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
                echo "   ! WARNING: Public key authentication is disabled"
            else
                echo "   ✓ Public key authentication is enabled"
            fi
        fi
    } > "$TMP_FILE"
    show_text "SSH Security" "$TMP_FILE"
    log "Checked SSH security"
}

security_failed_logins() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    FAILED LOGIN ATTEMPTS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "RECENT FAILED LOGINS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -30
        sudo grep "Failed password" /var/log/secure 2>/dev/null | tail -30
        
        echo ""
        echo "FAILED LOGIN STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total failed attempts: $(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)"
        echo "   Unique IPs: $(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{print $(NF-3)}' | sort -u | wc -l)"
        
        echo ""
        echo "TOP FAILED LOGIN ATTEMPTS BY IP:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -10
        
        echo ""
        echo "TOP FAILED LOGIN ATTEMPTS BY USER:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{print $(NF-5)}' | sort | uniq -c | sort -rn | head -10
        
        echo ""
        echo "RECENT INVALID USERS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep "Invalid user" /var/log/auth.log 2>/dev/null | tail -10
    } > "$TMP_FILE"
    show_text "Failed Logins" "$TMP_FILE"
    log "Viewed failed login attempts"
}

security_audit() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    SYSTEM AUDIT"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if command -v lynis &>/dev/null; then
            echo "LYNIS AUDIT:"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo lynis audit system 2>&1
        else
            echo "lynis not installed. Install with: sudo apt install lynis"
        fi
        
        echo ""
        echo "OPEN PORTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo netstat -tulpn 2>/dev/null | grep LISTEN
        
        echo ""
        echo "USER ACCOUNTS WITH PASSWORDS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep -E ":\$" /etc/shadow 2>/dev/null | awk -F: '{print $1}' | head -20
        
        echo ""
        echo "EMPTY PASSWORD ACCOUNTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo awk -F: '($2 == "" ) {print}' /etc/shadow 2>/dev/null
        
        echo ""
        echo "GROUPS WITH SUDO ACCESS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep -E "^sudo|^wheel|^admin" /etc/group 2>/dev/null
        
        echo ""
        echo "STARTUP SERVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        systemctl list-unit-files --state=enabled 2>/dev/null | head -20
    } > "$TMP_FILE"
    show_text "System Audit" "$TMP_FILE"
    log "Performed system audit"
}

security_malware_scan() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    MALWARE SCAN"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if command -v clamscan &>/dev/null; then
            echo "CLAMAV SCAN:"
            echo "────────────────────────────────────────────────────────────────────────"
            echo "Starting ClamAV scan of /home..."
            sudo clamscan -r -i /home 2>&1 | head -50
            echo ""
            echo "Scanning /tmp..."
            sudo clamscan -r -i /tmp 2>&1 | head -30
        else
            echo "ClamAV not installed. Installing..."
            sudo apt install -y clamav clamav-daemon 2>/dev/null
            echo ""
            echo "Installing ClamAV... Please run again after installation."
        fi
        
        echo ""
        echo "SUSPICIOUS FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "SUID binaries:"
        find / -type f -perm -4000 -ls 2>/dev/null | head -20
        echo ""
        echo "SGID binaries:"
        find / -type f -perm -2000 -ls 2>/dev/null | head -20
        echo ""
        echo "World writable files:"
        find / -type f -perm -o+w -ls 2>/dev/null | head -20
        
        echo ""
        echo "SUSPICIOUS PROCESSES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps aux | grep -E "nc|netcat|socat|nmap|hydra|john|aircrack|metasploit" | grep -v grep
        
        echo ""
        echo "RECENTLY MODIFIED FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        find / -type f -mtime -1 -ls 2>/dev/null | head -20
    } > "$TMP_FILE"
    show_text "Malware Scan" "$TMP_FILE"
    log "Performed malware scan"
}

security_report() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    SECURITY REPORT"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "REPORT GENERATED: $(date)"
        echo "────────────────────────────────────────────────────────────────────────"
        echo ""
        
        echo "1. FIREWALL STATUS:"
        echo "────────────────────────────────────────────────────────────────────────"
        if command -v ufw &>/dev/null; then
            sudo ufw status 2>/dev/null
        fi
        
        echo ""
        echo "2. OPEN PORTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo netstat -tuln 2>/dev/null | grep LISTEN | head -10
        
        echo ""
        echo "3. USERS WITH SUDO:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep -E "^sudo|^wheel|^admin" /etc/group 2>/dev/null
        
        echo ""
        echo "4. SSH CONFIGURATION CHECK:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f /etc/ssh/sshd_config ]]; then
            grep -E "PermitRootLogin|PasswordAuthentication|PubkeyAuthentication" /etc/ssh/sshd_config 2>/dev/null
        fi
        
        echo ""
        echo "5. FAILED LOGIN ATTEMPTS (last 30 days):"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5
        sudo grep "Failed password" /var/log/secure 2>/dev/null | tail -5
        
        echo ""
        echo "6. SUSPICIOUS PROCESSES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps aux | grep -E "nc|netcat|socat|nmap|hydra|john" | grep -v grep
        
        echo ""
        echo "7. OUTDATED PACKAGES:"
        echo "────────────────────────────────────────────────────────────────────────"
        if command -v apt &>/dev/null; then
            apt list --upgradable 2>/dev/null | head -10
        elif command -v dnf &>/dev/null; then
            dnf check-update 2>/dev/null | head -10
        fi
        
        echo ""
        echo "8. SYSTEM UPTIME & LOAD:"
        echo "────────────────────────────────────────────────────────────────────────"
        uptime
        
        echo ""
        echo "9. DISK USAGE:"
        echo "────────────────────────────────────────────────────────────────────────"
        df -h
        
        echo ""
        echo "10. SECURITY SCORE:"
        echo "────────────────────────────────────────────────────────────────────────"
        score=10
        # Check common security issues
        if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
            echo "   ! -1: Root login enabled"
            ((score--))
        fi
        if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
            echo "   ! -1: Password authentication enabled"
            ((score--))
        fi
        if sudo ufw status 2>/dev/null | grep -q "Status: inactive"; then
            echo "   ! -2: Firewall is disabled"
            ((score-=2))
        fi
        if [[ $(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l) -gt 100 ]]; then
            echo "   ! -1: High number of failed login attempts"
            ((score--))
        fi
        echo ""
        echo "   Security Score: $score/10"
        if [[ $score -ge 8 ]]; then
            echo "   ✓ System is secure"
        elif [[ $score -ge 5 ]]; then
            echo "   ! System has some security issues"
        else
            echo "   ! WARNING: System has critical security issues!"
        fi
    } > "$TMP_FILE"
    show_text "Security Report" "$TMP_FILE"
    log "Generated security report"
}