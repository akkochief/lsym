#!/usr/bin/env bash

monitor_menu() {
    while true; do
        local choice=$(d --clear --title "System Monitoring & Alerts" \
            --menu "\nSelect monitoring operation:" $HEIGHT $WIDTH $MENU_HEIGHT \
            1 "System Dashboard" \
            2 "CPU Monitor" \
            3 "Memory Monitor" \
            4 "Disk Monitor" \
            5 "Network Monitor" \
            6 "Process Monitor" \
            7 "Service Monitor" \
            8 "Resource Alerts" \
            9 "Alert Configuration" \
            10 "View Alerts" \
            11 "Clear Alerts" \
            12 "Performance Graph" \
            13 "Real-time Log Monitor" \
            14 "System Activity Report" \
            0 "Main Menu" \
            3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$choice" == "0" ]] && break
        
        case "$choice" in
            1) monitor_dashboard ;;
            2) monitor_cpu ;;
            3) monitor_memory ;;
            4) monitor_disk ;;
            5) monitor_network ;;
            6) monitor_processes ;;
            7) monitor_services ;;
            8) monitor_resource_alerts ;;
            9) monitor_alert_config ;;
            10) monitor_view_alerts ;;
            11) monitor_clear_alerts ;;
            12) monitor_performance_graph ;;
            13) monitor_real_time_logs ;;
            14) monitor_activity_report ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

monitor_dashboard() {
    {
        echo "========================================================================"
        echo "                    SYSTEM DASHBOARD"
        echo "========================================================================"
        echo ""
        echo "SYSTEM OVERVIEW:"
        echo "-----------------------------------------------------------------------"
        echo "   Hostname    : $(hostname)"
        echo "   Kernel      : $(uname -r)"
        echo "   Uptime      : $(uptime -p 2>/dev/null || uptime)"
        echo "   Date/Time   : $(date)"
        echo "   Users       : $(who | wc -l) logged in"
        echo ""
        echo "LOAD AVERAGE:"
        echo "-----------------------------------------------------------------------"
        echo "   1 min  : $(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | tr -d ' ')"
        echo "   5 min  : $(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $2}' | tr -d ' ')"
        echo "   15 min : $(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $3}' | tr -d ' ')"
        echo ""
        echo "CPU USAGE:"
        echo "-----------------------------------------------------------------------"
        top -bn1 | grep "Cpu(s)" | awk '{print "   User: " $2 "%, System: " $4 "%, Idle: " $8 "%, IOWait: " $10 "%"}'
        echo ""
        echo "MEMORY USAGE:"
        echo "-----------------------------------------------------------------------"
        free -h | awk '/Mem:/ {print "   Total: " $2 ", Used: " $3 ", Free: " $4 ", Available: " $7}'
        free -h | awk '/Swap:/ {print "   Swap Total: " $2 ", Used: " $3 ", Free: " $4}'
        echo ""
        echo "DISK USAGE:"
        echo "-----------------------------------------------------------------------"
        df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | head -10
        echo ""
        echo "TOP 5 CPU PROCESSES:"
        echo "-----------------------------------------------------------------------"
        ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "   %-20s %-10s %-10s %-10s\n", $11, $3"%", $4"%", $2}'
        echo ""
        echo "TOP 5 MEMORY PROCESSES:"
        echo "-----------------------------------------------------------------------"
        ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "   %-20s %-10s %-10s %-10s\n", $11, $4"%", $3"%", $2}'
        echo ""
        echo "NETWORK STATUS:"
        echo "-----------------------------------------------------------------------"
        ip -br link show | grep -v lo | awk '{printf "   %-10s %-10s %-15s\n", $1, $2, $3}'
        echo ""
        echo "SERVICES STATUS:"
        echo "-----------------------------------------------------------------------"
        echo "   Running services: $(systemctl list-units --type=service --state=running 2>/dev/null | wc -l)"
        echo "   Failed services: $(systemctl --failed 2>/dev/null | wc -l)"
        echo "   Active timers: $(systemctl list-timers --state=running 2>/dev/null | wc -l)"
    } > "$TMP_FILE"
    show_text "System Dashboard" "$TMP_FILE"
    log "Viewed system dashboard"
}

monitor_cpu() {
    local interval=$(get_input "CPU Monitor" "Refresh interval (seconds):" "2")
    [[ -z "$interval" ]] && return
    
    local count=$(get_input "CPU Monitor" "Number of samples:" "5")
    [[ -z "$count" ]] && return
    
    {
        echo "========================================================================"
        echo "                    CPU MONITOR"
        echo "========================================================================"
        echo ""
        echo "Monitoring CPU for $count samples every $interval seconds..."
        echo ""
        
        for i in $(seq 1 $count); do
            echo "Sample $i:"
            echo "-----------------------------------------------------------------------"
            top -bn1 | grep "Cpu(s)" | awk '{print "   User: " $2 "%, System: " $4 "%, Idle: " $8 "%, IOWait: " $10 "%"}'
            echo "   Load: $(uptime | awk -F'load average:' '{print $2}')"
            echo ""
            
            if [[ $i -lt $count ]]; then
                sleep $interval
            fi
        done
        
        echo "CPU STATISTICS:"
        echo "-----------------------------------------------------------------------"
        echo "   CPU Model: $(lscpu | grep "Model name" | head -1 | cut -d: -f2 | xargs)"
        echo "   Cores: $(nproc)"
        echo "   Architecture: $(uname -m)"
        echo "   CPU Frequency: $(lscpu | grep "MHz" | head -1 | awk '{print $3 " MHz"}')"
        echo ""
        echo "TOP CPU CONSUMERS:"
        echo "-----------------------------------------------------------------------"
        ps aux --sort=-%cpu | head -10
    } > "$TMP_FILE"
    show_text "CPU Monitor" "$TMP_FILE"
    log "Monitored CPU"
}

monitor_memory() {
    {
        echo "========================================================================"
        echo "                    MEMORY MONITOR"
        echo "========================================================================"
        echo ""
        
        echo "MEMORY USAGE:"
        echo "-----------------------------------------------------------------------"
        free -h
        echo ""
        
        echo "MEMORY DETAILS:"
        echo "-----------------------------------------------------------------------"
        cat /proc/meminfo | head -20
        echo ""
        
        echo "TOP MEMORY CONSUMERS:"
        echo "-----------------------------------------------------------------------"
        ps aux --sort=-%mem | head -15
        echo ""
        
        echo "MEMORY STATISTICS:"
        echo "-----------------------------------------------------------------------"
        echo "   Total RAM: $(free | awk '/Mem:/ {printf "%.1f GB", $2/1024/1024}')"
        echo "   Used RAM: $(free | awk '/Mem:/ {printf "%.1f GB (%.1f%%)", $3/1024/1024, $3/$2*100}')"
        echo "   Available RAM: $(free | awk '/Mem:/ {printf "%.1f GB", $7/1024/1024}')"
        echo "   Swap Total: $(free | awk '/Swap:/ {printf "%.1f GB", $2/1024/1024}')"
        echo "   Swap Used: $(free | awk '/Swap:/ {printf "%.1f GB (%.1f%%)", $3/1024/1024, $3/$2*100}')"
        echo ""
        
        echo "MEMORY PRESSURE:"
        echo "-----------------------------------------------------------------------"
        if [[ -f /proc/pressure/memory ]]; then
            cat /proc/pressure/memory
        else
            echo "Memory pressure info not available"
        fi
        echo ""
        
        echo "ZRAM STATUS:"
        echo "-----------------------------------------------------------------------"
        if command -v zramctl &>/dev/null; then
            zramctl 2>/dev/null
        else
            echo "zramctl not available"
        fi
    } > "$TMP_FILE"
    show_text "Memory Monitor" "$TMP_FILE"
    log "Monitored memory"
}

monitor_disk() {
    local choice=$(d --title "Disk Monitor" --menu "\nSelect disk monitoring type:" 12 60 3 \
        "usage" "Disk Usage" \
        "io" "I/O Statistics" \
        "inodes" "Inode Usage" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        usage)
            {
                echo "========================================================================"
                echo "                    DISK USAGE MONITOR"
                echo "========================================================================"
                echo ""
                
                echo "DISK USAGE:"
                echo "-----------------------------------------------------------------------"
                df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null
                echo ""
                
                echo "DISK STATISTICS:"
                echo "-----------------------------------------------------------------------"
                echo "   Total disks: $(lsblk -d | wc -l)"
                echo "   Total partitions: $(lsblk -l | grep -c part)"
                echo "   Total filesystems: $(df -T --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | wc -l)"
                echo ""
                
                echo "DISK SPACE ALERT:"
                echo "-----------------------------------------------------------------------"
                df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | awk 'NR>1 {if ($5+0 > 80) print "   WARNING: " $7 " is " $5 " full"}'
                echo ""
                
                echo "TOP 10 LARGEST DIRECTORIES:"
                echo "-----------------------------------------------------------------------"
                du -h / 2>/dev/null | sort -rh | head -10
            } > "$TMP_FILE"
            show_text "Disk Usage Monitor" "$TMP_FILE"
            ;;
        io)
            {
                echo "========================================================================"
                echo "                    DISK I/O MONITOR"
                echo "========================================================================"
                echo ""
                
                if command -v iostat &>/dev/null; then
                    echo "DISK I/O STATISTICS:"
                    echo "-----------------------------------------------------------------------"
                    iostat -x 2>/dev/null
                    echo ""
                    
                    echo "I/O STATISTICS SUMMARY:"
                    echo "-----------------------------------------------------------------------"
                    iostat -dx 2>/dev/null | awk 'NR>3 {printf "   %-15s %-10s %-10s %-10s\n", $1, $4, $12, $14}'
                else
                    echo "iostat not installed. Install: sudo apt install sysstat"
                fi
                echo ""
                
                echo "I/O WAIT:"
                echo "-----------------------------------------------------------------------"
                top -bn1 | grep "Cpu(s)" | awk '{print "   I/O Wait: " $10 "%"}'
                echo ""
                
                echo "PROCESSES WITH HIGH I/O:"
                echo "-----------------------------------------------------------------------"
                ps aux | awk '$8 ~ /D/ {print $0}' | head -10
            } > "$TMP_FILE"
            show_text "Disk I/O Monitor" "$TMP_FILE"
            ;;
        inodes)
            {
                echo "========================================================================"
                echo "                    INODE USAGE MONITOR"
                echo "========================================================================"
                echo ""
                
                echo "INODE USAGE:"
                echo "-----------------------------------------------------------------------"
                df -i --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null
                echo ""
                
                echo "INODE ALERT:"
                echo "-----------------------------------------------------------------------"
                df -i --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | awk 'NR>1 {if ($5+0 > 80) print "   WARNING: " $6 " is " $5 " inodes full"}'
                echo ""
                
                echo "DIRECTORIES WITH HIGH INODE USAGE:"
                echo "-----------------------------------------------------------------------"
                find / -xdev -type d -exec sh -c "echo {} \; find {} -maxdepth 1 -type f 2>/dev/null | wc -l" \; 2>/dev/null | paste -d' ' - - | sort -rn -k2 | head -10
            } > "$TMP_FILE"
            show_text "Inode Usage Monitor" "$TMP_FILE"
            ;;
    esac
    log "Monitored disk"
}

monitor_network() {
    local choice=$(d --title "Network Monitor" --menu "\nSelect network monitoring type:" 12 60 4 \
        "traffic" "Network Traffic" \
        "connections" "Active Connections" \
        "statistics" "Network Statistics" \
        "interface" "Interface Status" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        traffic)
            local iface=$(get_input "Network Traffic" "Enter interface (or 'all'):" "all")
            [[ -z "$iface" ]] && return
            
            local duration=$(get_input "Network Traffic" "Monitor duration (seconds):" "5")
            [[ -z "$duration" ]] && return
            
            {
                echo "========================================================================"
                echo "                    NETWORK TRAFFIC MONITOR"
                echo "========================================================================"
                echo ""
                
                if command -v iftop &>/dev/null; then
                    echo "Monitoring network traffic for $duration seconds..."
                    if [[ "$iface" == "all" ]]; then
                        sudo iftop -t -s "$duration" 2>&1
                    else
                        sudo iftop -t -s "$duration" -i "$iface" 2>&1
                    fi
                elif command -v nload &>/dev/null; then
                    echo "nload installed. Run: nload $iface"
                elif command -v bmon &>/dev/null; then
                    echo "bmon installed. Run: bmon"
                else
                    echo "Network monitoring tools not found."
                    echo "Install with: sudo apt install iftop nload bmon"
                    echo ""
                    echo "Basic traffic statistics:"
                    if [[ "$iface" != "all" ]]; then
                        echo "RX bytes: $(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null)"
                        echo "TX bytes: $(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null)"
                    fi
                fi
            } > "$TMP_FILE"
            show_text "Network Traffic" "$TMP_FILE"
            ;;
        connections)
            {
                echo "========================================================================"
                echo "                    ACTIVE CONNECTIONS"
                echo "========================================================================"
                echo ""
                
                echo "ALL CONNECTIONS:"
                echo "-----------------------------------------------------------------------"
                sudo ss -tunp 2>/dev/null
                echo ""
                
                echo "CONNECTION STATISTICS:"
                echo "-----------------------------------------------------------------------"
                echo "   ESTABLISHED: $(sudo ss -tunp 2>/dev/null | grep -c ESTAB)"
                echo "   LISTENING: $(sudo ss -tunp 2>/dev/null | grep -c LISTEN)"
                echo "   TIME_WAIT: $(sudo ss -tunp 2>/dev/null | grep -c TIME_WAIT)"
                echo "   CLOSE_WAIT: $(sudo ss -tunp 2>/dev/null | grep -c CLOSE_WAIT)"
                echo ""
                
                echo "TOP CONNECTIONS BY IP:"
                echo "-----------------------------------------------------------------------"
                sudo ss -tunp 2>/dev/null | awk 'NR>1 {print $6}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10
                echo ""
                
                echo "OPEN PORTS:"
                echo "-----------------------------------------------------------------------"
                sudo ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | cut -d: -f2 | sort -n | uniq
            } > "$TMP_FILE"
            show_text "Active Connections" "$TMP_FILE"
            ;;
        statistics)
            {
                echo "========================================================================"
                echo "                    NETWORK STATISTICS"
                echo "========================================================================"
                echo ""
                
                echo "INTERFACE STATISTICS:"
                echo "-----------------------------------------------------------------------"
                ip -s link show 2>/dev/null
                echo ""
                
                echo "PROTOCOL STATISTICS:"
                echo "-----------------------------------------------------------------------"
                netstat -s 2>/dev/null | head -50
                echo ""
                
                echo "ROUTING STATISTICS:"
                echo "-----------------------------------------------------------------------"
                ip route show 2>/dev/null
                echo ""
                
                echo "ARP CACHE:"
                echo "-----------------------------------------------------------------------"
                ip neigh show 2>/dev/null
            } > "$TMP_FILE"
            show_text "Network Statistics" "$TMP_FILE"
            ;;
        interface)
            {
                echo "========================================================================"
                echo "                    INTERFACE STATUS"
                echo "========================================================================"
                echo ""
                
                echo "INTERFACE DETAILS:"
                echo "-----------------------------------------------------------------------"
                ip addr show 2>/dev/null
                echo ""
                
                echo "INTERFACE SUMMARY:"
                echo "-----------------------------------------------------------------------"
                echo "   Total interfaces: $(ip -o link show | wc -l)"
                echo "   Up interfaces: $(ip -o link show | grep -c "state UP")"
                echo "   Down interfaces: $(ip -o link show | grep -c "state DOWN")"
                echo ""
                
                echo "INTERFACE SPEEDS:"
                echo "-----------------------------------------------------------------------"
                for iface in $(ip -o link show | awk '{print $2}' | cut -d: -f1 | grep -v lo); do
                    if command -v ethtool &>/dev/null; then
                        speed=$(ethtool "$iface" 2>/dev/null | grep Speed | awk '{print $2}')
                        echo "   $iface: ${speed:-N/A}"
                    fi
                done
            } > "$TMP_FILE"
            show_text "Interface Status" "$TMP_FILE"
            ;;
    esac
    log "Monitored network"
}

monitor_processes() {
    local choice=$(d --title "Process Monitor" --menu "\nSelect process view:" 12 60 4 \
        "all" "All Processes" \
        "cpu" "CPU Sort" \
        "mem" "Memory Sort" \
        "user" "By User" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        all)
            {
                echo "========================================================================"
                echo "                    ALL PROCESSES"
                echo "========================================================================"
                echo ""
                ps aux | head -50
                echo ""
                echo "PROCESS STATISTICS:"
                echo "-----------------------------------------------------------------------"
                echo "   Total processes: $(ps aux | wc -l)"
                echo "   Running: $(ps aux | grep -c " R ")"
                echo "   Sleeping: $(ps aux | grep -c " S ")"
                echo "   Zombie: $(ps aux | grep -c " Z ")"
            } > "$TMP_FILE"
            show_text "All Processes" "$TMP_FILE"
            ;;
        cpu)
            {
                echo "========================================================================"
                echo "                    PROCESSES BY CPU"
                echo "========================================================================"
                echo ""
                ps aux --sort=-%cpu | head -30
            } > "$TMP_FILE"
            show_text "Processes by CPU" "$TMP_FILE"
            ;;
        mem)
            {
                echo "========================================================================"
                echo "                    PROCESSES BY MEMORY"
                echo "========================================================================"
                echo ""
                ps aux --sort=-%mem | head -30
            } > "$TMP_FILE"
            show_text "Processes by Memory" "$TMP_FILE"
            ;;
        user)
            local user=$(get_input "Processes by User" "Enter username:" "$(whoami)")
            [[ -z "$user" ]] && return
            {
                echo "========================================================================"
                echo "                    PROCESSES FOR USER: $user"
                echo "========================================================================"
                echo ""
                ps -u "$user" 2>/dev/null
                echo ""
                echo "PROCESS STATISTICS:"
                echo "-----------------------------------------------------------------------"
                echo "   Total processes: $(ps -u "$user" 2>/dev/null | wc -l)"
            } > "$TMP_FILE"
            show_text "Processes by User" "$TMP_FILE"
            ;;
    esac
    log "Monitored processes"
}

monitor_services() {
    {
        echo "========================================================================"
        echo "                    SERVICE MONITOR"
        echo "========================================================================"
        echo ""
        
        echo "RUNNING SERVICES:"
        echo "-----------------------------------------------------------------------"
        systemctl list-units --type=service --state=running --no-pager 2>/dev/null
        echo ""
        
        echo "FAILED SERVICES:"
        echo "-----------------------------------------------------------------------"
        systemctl --failed --no-pager 2>/dev/null
        echo ""
        
        echo "ENABLED SERVICES:"
        echo "-----------------------------------------------------------------------"
        systemctl list-unit-files --state=enabled --no-pager 2>/dev/null | head -20
        echo ""
        
        echo "TIMERS:"
        echo "-----------------------------------------------------------------------"
        systemctl list-timers --no-pager 2>/dev/null | head -20
        echo ""
        
        echo "SERVICE STATISTICS:"
        echo "-----------------------------------------------------------------------"
        echo "   Total services: $(systemctl list-units --type=service --all --no-pager 2>/dev/null | wc -l)"
        echo "   Running: $(systemctl list-units --type=service --state=running --no-pager 2>/dev/null | wc -l)"
        echo "   Failed: $(systemctl --failed --no-pager 2>/dev/null | wc -l)"
        echo "   Enabled: $(systemctl list-unit-files --state=enabled --no-pager 2>/dev/null | wc -l)"
    } > "$TMP_FILE"
    show_text "Service Monitor" "$TMP_FILE"
    log "Monitored services"
}

monitor_resource_alerts() {
    {
        echo "========================================================================"
        echo "                    RESOURCE ALERTS"
        echo "========================================================================"
        echo ""
        
        echo "CPU ALERTS:"
        echo "-----------------------------------------------------------------------"
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | tr -d ' ')
        if (( $(echo "$load_avg > 5" | bc -l) )); then
            echo "   CRITICAL: CPU load is $load_avg (threshold: 5)"
        elif (( $(echo "$load_avg > 2" | bc -l) )); then
            echo "   WARNING: CPU load is $load_avg (threshold: 2)"
        else
            echo "   CPU load is normal: $load_avg"
        fi
        
        echo ""
        echo "MEMORY ALERTS:"
        echo "-----------------------------------------------------------------------"
        mem_usage=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
        if [[ $(echo "$mem_usage > 90" | bc -l) -eq 1 ]]; then
            echo "   CRITICAL: Memory usage is ${mem_usage}% (threshold: 90%)"
        elif [[ $(echo "$mem_usage > 80" | bc -l) -eq 1 ]]; then
            echo "   WARNING: Memory usage is ${mem_usage}% (threshold: 80%)"
        else
            echo "   Memory usage is normal: ${mem_usage}%"
        fi
        
        echo ""
        echo "DISK ALERTS:"
        echo "-----------------------------------------------------------------------"
        df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | awk 'NR>1 {
            usage=$5+0
            if (usage > 85) print "   CRITICAL: " $7 " is " usage "% full (threshold: 85%)"
            else if (usage > 70) print "   WARNING: " $7 " is " usage "% full (threshold: 70%)"
            else print "   " $7 " usage is normal: " usage "%"
        }'
        
        echo ""
        echo "INODE ALERTS:"
        echo "-----------------------------------------------------------------------"
        df -i --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | awk 'NR>1 {
            usage=$5+0
            if (usage > 85) print "   CRITICAL: " $6 " inodes are " usage "% full"
            else if (usage > 70) print "   WARNING: " $6 " inodes are " usage "% full"
            else print "   " $6 " inodes are normal: " usage "%"
        }'
        
        echo ""
        echo "SERVICE ALERTS:"
        echo "-----------------------------------------------------------------------"
        failed_services=$(systemctl --failed 2>/dev/null | wc -l)
        if [[ $failed_services -gt 0 ]]; then
            echo "   CRITICAL: $failed_services services are failed"
            systemctl --failed --no-pager 2>/dev/null | awk 'NR>1 {print "      - " $0}'
        else
            echo "   All services are running"
        fi
        
        echo ""
        echo "PROCESS ALERTS:"
        echo "-----------------------------------------------------------------------"
        zombie=$(ps aux | grep -c " Z ")
        if [[ $zombie -gt 0 ]]; then
            echo "   WARNING: $zombie zombie processes found"
        else
            echo "   No zombie processes"
        fi
        
        echo ""
        echo "ALERT SUMMARY:"
        echo "-----------------------------------------------------------------------"
        critical=$(grep -c "CRITICAL" "$TMP_FILE")
        warnings=$(grep -c "WARNING" "$TMP_FILE")
        echo "   Critical: $critical"
        echo "   Warnings: $warnings"
        
        if [[ $critical -eq 0 ]] && [[ $warnings -eq 0 ]]; then
            echo "   System is healthy"
        elif [[ $critical -eq 0 ]]; then
            echo "   System has warnings"
        else
            echo "   CRITICAL: System needs immediate attention!"
        fi
    } > "$TMP_FILE"
    show_text "Resource Alerts" "$TMP_FILE"
    log "Generated resource alerts"
}

monitor_alert_config() {
    local config_file="${BASE_DIR}/alert_config.conf"
    
    local choice=$(d --title "Alert Configuration" --menu "\nSelect configuration:" 14 60 5 \
        "view" "View Current Config" \
        "set_cpu" "Set CPU Threshold" \
        "set_mem" "Set Memory Threshold" \
        "set_disk" "Set Disk Threshold" \
        "email" "Set Email Notification" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        view)
            {
                echo "CURRENT ALERT CONFIGURATION:"
                echo "-----------------------------------------------------------------------"
                if [[ -f "$config_file" ]]; then
                    cat "$config_file"
                else
                    echo "No configuration file found. Using defaults:"
                    echo "CPU threshold: 5.0"
                    echo "Memory threshold: 90%"
                    echo "Disk threshold: 85%"
                    echo "Email: admin@localhost"
                fi
            } > "$TMP_FILE"
            show_text "Alert Configuration" "$TMP_FILE"
            ;;
        set_cpu)
            local threshold=$(get_input "CPU Threshold" "Enter CPU load threshold (e.g., 5.0):" "5.0")
            [[ -z "$threshold" ]] && return
            {
                echo "CPU_LOAD_THRESHOLD=$threshold" >> "$config_file"
                echo "CPU threshold set to $threshold"
            } > "$TMP_FILE"
            show_text "Set CPU Threshold" "$TMP_FILE"
            log "Set CPU threshold to $threshold"
            ;;
        set_mem)
            local threshold=$(get_input "Memory Threshold" "Enter memory usage threshold (%):" "90")
            [[ -z "$threshold" ]] && return
            {
                echo "MEMORY_THRESHOLD=$threshold" >> "$config_file"
                echo "Memory threshold set to $threshold%"
            } > "$TMP_FILE"
            show_text "Set Memory Threshold" "$TMP_FILE"
            log "Set memory threshold to $threshold%"
            ;;
        set_disk)
            local threshold=$(get_input "Disk Threshold" "Enter disk usage threshold (%):" "85")
            [[ -z "$threshold" ]] && return
            {
                echo "DISK_THRESHOLD=$threshold" >> "$config_file"
                echo "Disk threshold set to $threshold%"
            } > "$TMP_FILE"
            show_text "Set Disk Threshold" "$TMP_FILE"
            log "Set disk threshold to $threshold%"
            ;;
        email)
            local email=$(get_input "Email Notification" "Enter email address:" "admin@localhost")
            [[ -z "$email" ]] && return
            {
                echo "ALERT_EMAIL=$email" >> "$config_file"
                echo "Email set to $email"
            } > "$TMP_FILE"
            show_text "Set Email Notification" "$TMP_FILE"
            log "Set alert email to $email"
            ;;
    esac
}

monitor_view_alerts() {
    local alert_log="${BASE_DIR}/alerts.log"
    
    {
        echo "========================================================================"
        echo "                    ALERT HISTORY"
        echo "========================================================================"
        echo ""
        
        if [[ -f "$alert_log" ]]; then
            tail -50 "$alert_log"
            echo ""
            echo "ALERT STATISTICS:"
            echo "-----------------------------------------------------------------------"
            echo "   Total alerts: $(wc -l < "$alert_log")"
            echo "   Critical: $(grep -c "CRITICAL" "$alert_log")"
            echo "   Warning: $(grep -c "WARNING" "$alert_log")"
        else
            echo "No alerts recorded yet."
        fi
    } > "$TMP_FILE"
    show_text "Alert History" "$TMP_FILE"
    log "Viewed alert history"
}

monitor_clear_alerts() {
    local alert_log="${BASE_DIR}/alerts.log"
    
    if ask_yesno "Clear all alert history?"; then
        {
            > "$alert_log"
            echo "Alert history cleared successfully!"
        } > "$TMP_FILE"
        show_text "Clear Alerts" "$TMP_FILE"
        log "Cleared alert history"
    fi
}

monitor_performance_graph() {
    {
        echo "========================================================================"
        echo "                    PERFORMANCE GRAPHS"
        echo "========================================================================"
        echo ""
        
        echo "CPU USAGE (ASCII Graph):"
        echo "-----------------------------------------------------------------------"
        for i in {1..20}; do
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk "{print $2}" | cut -d. -f1)
            bar=$(printf '%*s' $((cpu_usage/2)) '' | tr ' ' '#')
            echo "   $i: $bar $cpu_usage%"
            sleep 0.5
        done 2>/dev/null
        
        echo ""
        echo "MEMORY USAGE (ASCII Graph):"
        echo "-----------------------------------------------------------------------"
        mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
        bar=$(printf '%*s' $((mem_usage/2)) '' | tr ' ' '#')
        echo "   Memory: $bar $mem_usage%"
        
        echo ""
        echo "DISK USAGE (ASCII Graph):"
        echo "-----------------------------------------------------------------------"
        df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | awk 'NR>1 {
            usage=$5+0
            bar_len=$5/5
            bar=""
            for (i=1; i<=bar_len; i++) bar=bar"#"
            printf "   %-10s %s %s\n", $7, bar, $5
        }'
        
        echo ""
        echo "NETWORK TRAFFIC (ASCII Graph):"
        echo "-----------------------------------------------------------------------"
        for iface in $(ip -o link show | awk '{print $2}' | cut -d: -f1 | grep -v lo | head -3); do
            rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null)
            tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null)
            if [[ -n "$rx" ]] && [[ -n "$tx" ]]; then
                rx_mb=$((rx / 1024 / 1024))
                tx_mb=$((tx / 1024 / 1024))
                rx_bar=$(printf '%*s' $((rx_mb / 10)) '' | tr ' ' '#')
                tx_bar=$(printf '%*s' $((tx_mb / 10)) '' | tr ' ' '#')
                echo "   $iface:"
                echo "      RX: $rx_bar ${rx_mb}MB"
                echo "      TX: $tx_bar ${tx_mb}MB"
            fi
        done
    } > "$TMP_FILE"
    show_text "Performance Graphs" "$TMP_FILE"
    log "Generated performance graphs"
}

monitor_real_time_logs() {
    local log_file=$(get_input "Real-time Log Monitor" "Enter log file path:" "/var/log/syslog")
    [[ -z "$log_file" ]] && return
    
    local lines=$(get_input "Real-time Log Monitor" "Number of lines to show:" "20")
    [[ -z "$lines" ]] && return
    
    {
        echo "========================================================================"
        echo "                    REAL-TIME LOG MONITOR"
        echo "========================================================================"
        echo ""
        echo "Monitoring: $log_file"
        echo "Press Ctrl+C to stop"
        echo ""
        
        tail -f "$log_file" 2>&1 | head -"$lines"
    } > "$TMP_FILE"
    show_text "Real-time Log Monitor" "$TMP_FILE"
    log "Monitored real-time logs from $log_file"
}

monitor_activity_report() {
    {
        echo "========================================================================"
        echo "                    SYSTEM ACTIVITY REPORT"
        echo "========================================================================"
        echo ""
        echo "REPORT GENERATED: $(date)"
        echo "-----------------------------------------------------------------------"
        echo ""
        
        echo "1. SYSTEM UPTIME:"
        echo "-----------------------------------------------------------------------"
        uptime
        echo ""
        
        echo "2. RECENT LOGINS:"
        echo "-----------------------------------------------------------------------"
        last -n 10 2>/dev/null
        echo ""
        
        echo "3. RECENT COMMANDS (root):"
        echo "-----------------------------------------------------------------------"
        if [[ -f /root/.bash_history ]]; then
            tail -20 /root/.bash_history 2>/dev/null
        fi
        echo ""
        
        echo "4. SYSTEM ERRORS (last 50):"
        echo "-----------------------------------------------------------------------"
        sudo journalctl -p err -n 50 --no-pager 2>/dev/null
        echo ""
        
        echo "5. RECENT CRON JOBS:"
        echo "-----------------------------------------------------------------------"
        sudo grep CRON /var/log/syslog 2>/dev/null | tail -20
        echo ""
        
        echo "6. DISK ACTIVITY:"
        echo "-----------------------------------------------------------------------"
        iostat 2>/dev/null | head -20
        echo ""
        
        echo "7. NETWORK ACTIVITY:"
        echo "-----------------------------------------------------------------------"
        sudo ss -tunp 2>/dev/null | head -20
        echo ""
        
        echo "8. PROCESS ACTIVITY:"
        echo "-----------------------------------------------------------------------"
        ps aux --sort=-%cpu | head -10
        echo ""
        
        echo "9. AUTHENTICATION LOGS:"
        echo "-----------------------------------------------------------------------"
        sudo tail -20 /var/log/auth.log 2>/dev/null
        sudo tail -20 /var/log/secure 2>/dev/null
        echo ""
        
        echo "10. SYSTEM CHANGES (last 24h):"
        echo "-----------------------------------------------------------------------"
        find /etc -type f -mtime -1 2>/dev/null | head -20
        echo ""
        
        echo "REPORT SUMMARY:"
        echo "-----------------------------------------------------------------------"
        echo "   System uptime: $(uptime -p 2>/dev/null)"
        echo "   Load average: $(uptime | awk -F'load average:' '{print $2}')"
        echo "   Memory usage: $(free | awk '/Mem:/ {printf "%.1f%%", $3/$2*100}')"
        echo "   Disk usage: $(df -h / 2>/dev/null | awk 'NR==2 {print $5}')"
        echo "   Processes: $(ps aux | wc -l)"
        echo "   Failed logins: $(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)"
        echo "   Package updates: $(apt list --upgradable 2>/dev/null | wc -l)"
    } > "$TMP_FILE"
    show_text "System Activity Report" "$TMP_FILE"
    log "Generated system activity report"
}