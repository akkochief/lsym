#!/usr/bin/env bash

service_menu() {
    while true; do
        local choice=$(d --clear --title "Service & Process Management" \
            --menu "\nSelect operation:" $HEIGHT $WIDTH $MENU_HEIGHT \
            1 "List All Services" \
            2 "List Running Services" \
            3 "List Failed Services" \
            4 "Start Service" \
            5 "Stop Service" \
            6 "Restart Service" \
            7 "Reload Service" \
            8 "Enable Service" \
            9 "Disable Service" \
            10 "Service Status" \
            11 "Service Logs" \
            12 "List All Processes" \
            13 "Kill Process" \
            14 "Process Priority" \
            15 "Process Tree" \
            16 "System Resources" \
            0 "Main Menu" \
            3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$choice" == "0" ]] && break
        
        case "$choice" in
            1) service_list_all ;;
            2) service_list_running ;;
            3) service_list_failed ;;
            4) service_start ;;
            5) service_stop ;;
            6) service_restart ;;
            7) service_reload ;;
            8) service_enable ;;
            9) service_disable ;;
            10) service_status ;;
            11) service_logs ;;
            12) service_list_processes ;;
            13) service_kill_process ;;
            14) service_process_priority ;;
            15) service_process_tree ;;
            16) service_system_resources ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

service_list_all() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    ALL SERVICES"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "SYSTEMD SERVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        systemctl list-units --type=service --all --no-pager 2>/dev/null
        echo ""
        echo "SERVICE STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total services: $(systemctl list-units --type=service --all --no-pager 2>/dev/null | wc -l)"
        echo "   Running: $(systemctl list-units --type=service --state=running --no-pager 2>/dev/null | wc -l)"
        echo "   Failed: $(systemctl list-units --type=service --state=failed --no-pager 2>/dev/null | wc -l)"
        echo "   Disabled: $(systemctl list-units --type=service --state=disabled --no-pager 2>/dev/null | wc -l)"
        echo ""
        echo "SYSV INIT SERVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        service --status-all 2>/dev/null | head -20
        echo ""
        echo "TIMERS (systemd):"
        echo "────────────────────────────────────────────────────────────────────────"
        systemctl list-timers --no-pager 2>/dev/null | head -20
    } > "$TMP_FILE"
    show_text "All Services" "$TMP_FILE"
    log "Listed all services"
}

service_list_running() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    RUNNING SERVICES"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        systemctl list-units --type=service --state=running --no-pager 2>/dev/null
        echo ""
        echo "RUNNING SERVICE STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Running: $(systemctl list-units --type=service --state=running --no-pager 2>/dev/null | wc -l)"
        echo ""
        echo "TOP 10 CPU CONSUMING SERVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        systemd-cgtop -d 2 -n 1 2>/dev/null | head -15
    } > "$TMP_FILE"
    show_text "Running Services" "$TMP_FILE"
    log "Listed running services"
}

service_list_failed() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    FAILED SERVICES"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        systemctl --failed --no-pager 2>/dev/null
        echo ""
        echo "FAILED SERVICE DETAILS:"
        echo "────────────────────────────────────────────────────────────────────────"
        for service in $(systemctl --failed --no-pager 2>/dev/null | awk 'NR>1 {print $1}'); do
            echo ""
            echo "=== $service ==="
            systemctl status "$service" --no-pager 2>/dev/null | head -10
        done
        echo ""
        echo "FAILED SERVICE STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Failed: $(systemctl --failed --no-pager 2>/dev/null | wc -l)"
    } > "$TMP_FILE"
    show_text "Failed Services" "$TMP_FILE"
    log "Listed failed services"
}

service_start() {
    local service=$(get_input "Start Service" "Enter service name:" "")
    [[ -z "$service" ]] && return
    
    if ! systemctl list-units --type=service --all --no-pager | grep -q "$service.service"; then
        show_msg "Error" "Service $service does not exist!"
        return
    fi
    
    if ask_yesno "Start service: $service?"; then
        {
            echo "Starting $service..."
            sudo systemctl start "$service" 2>&1
            echo ""
            echo "Service started!"
            echo ""
            systemctl status "$service" --no-pager 2>&1 | head -10
        } > "$TMP_FILE" 2>&1
        show_text "Start Service" "$TMP_FILE"
        log "Started service: $service"
    fi
}

service_stop() {
    local service=$(get_input "Stop Service" "Enter service name:" "")
    [[ -z "$service" ]] && return
    
    if ! systemctl list-units --type=service --all --no-pager | grep -q "$service.service"; then
        show_msg "Error" "Service $service does not exist!"
        return
    fi
    
    if ask_yesno "Stop service: $service?"; then
        {
            echo "Stopping $service..."
            sudo systemctl stop "$service" 2>&1
            echo ""
            echo "Service stopped!"
            echo ""
            systemctl status "$service" --no-pager 2>&1 | head -10
        } > "$TMP_FILE" 2>&1
        show_text "Stop Service" "$TMP_FILE"
        log "Stopped service: $service"
    fi
}

service_restart() {
    local service=$(get_input "Restart Service" "Enter service name:" "")
    [[ -z "$service" ]] && return
    
    if ! systemctl list-units --type=service --all --no-pager | grep -q "$service.service"; then
        show_msg "Error" "Service $service does not exist!"
        return
    fi
    
    if ask_yesno "Restart service: $service?"; then
        {
            echo "Restarting $service..."
            sudo systemctl restart "$service" 2>&1
            echo ""
            echo "Service restarted!"
            echo ""
            systemctl status "$service" --no-pager 2>&1 | head -10
        } > "$TMP_FILE" 2>&1
        show_text "Restart Service" "$TMP_FILE"
        log "Restarted service: $service"
    fi
}

service_reload() {
    local service=$(get_input "Reload Service" "Enter service name:" "")
    [[ -z "$service" ]] && return
    
    if ! systemctl list-units --type=service --all --no-pager | grep -q "$service.service"; then
        show_msg "Error" "Service $service does not exist!"
        return
    fi
    
    if ask_yesno "Reload service: $service?"; then
        {
            echo "Reloading $service..."
            sudo systemctl reload "$service" 2>&1
            echo ""
            echo "Service reloaded!"
            echo ""
            systemctl status "$service" --no-pager 2>&1 | head -10
        } > "$TMP_FILE" 2>&1
        show_text "Reload Service" "$TMP_FILE"
        log "Reloaded service: $service"
    fi
}

service_enable() {
    local service=$(get_input "Enable Service" "Enter service name:" "")
    [[ -z "$service" ]] && return
    
    if ! systemctl list-units --type=service --all --no-pager | grep -q "$service.service"; then
        show_msg "Error" "Service $service does not exist!"
        return
    fi
    
    if ask_yesno "Enable service $service (start at boot)?"; then
        {
            echo "Enabling $service..."
            sudo systemctl enable "$service" 2>&1
            echo ""
            echo "Service enabled!"
            echo ""
            systemctl status "$service" --no-pager 2>&1 | head -10
        } > "$TMP_FILE" 2>&1
        show_text "Enable Service" "$TMP_FILE"
        log "Enabled service: $service"
    fi
}

service_disable() {
    local service=$(get_input "Disable Service" "Enter service name:" "")
    [[ -z "$service" ]] && return
    
    if ! systemctl list-units --type=service --all --no-pager | grep -q "$service.service"; then
        show_msg "Error" "Service $service does not exist!"
        return
    fi
    
    if ask_yesno "Disable service $service (prevent start at boot)?"; then
        {
            echo "Disabling $service..."
            sudo systemctl disable "$service" 2>&1
            echo ""
            echo "Service disabled!"
            echo ""
            systemctl status "$service" --no-pager 2>&1 | head -10
        } > "$TMP_FILE" 2>&1
        show_text "Disable Service" "$TMP_FILE"
        log "Disabled service: $service"
    fi
}

service_status() {
    local service=$(get_input "Service Status" "Enter service name:" "")
    [[ -z "$service" ]] && return
    
    if ! systemctl list-units --type=service --all --no-pager | grep -q "$service.service"; then
        show_msg "Error" "Service $service does not exist!"
        return
    fi
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              SERVICE STATUS - $service"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        systemctl status "$service" --no-pager 2>&1
        echo ""
        echo "SERVICE DETAILS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Unit file: $(systemctl show "$service" --property=UnitFileState --no-pager 2>/dev/null | cut -d= -f2)"
        echo "   Load state: $(systemctl show "$service" --property=LoadState --no-pager 2>/dev/null | cut -d= -f2)"
        echo "   Active state: $(systemctl show "$service" --property=ActiveState --no-pager 2>/dev/null | cut -d= -f2)"
        echo "   Sub state: $(systemctl show "$service" --property=SubState --no-pager 2>/dev/null | cut -d= -f2)"
        echo "   Main PID: $(systemctl show "$service" --property=MainPID --no-pager 2>/dev/null | cut -d= -f2)"
        echo "   Memory: $(systemctl show "$service" --property=MemoryCurrent --no-pager 2>/dev/null | cut -d= -f2 | numfmt --to=iec 2>/dev/null)"
        echo "   CPU usage: $(systemctl show "$service" --property=CPUUsageNSec --no-pager 2>/dev/null | cut -d= -f2 | numfmt --to=iec 2>/dev/null)"
        echo ""
        echo "DEPENDENCIES:"
        echo "────────────────────────────────────────────────────────────────────────"
        systemctl list-dependencies "$service" --no-pager 2>&1 | head -20
        echo ""
        echo "RELATED PROCESSES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps aux | grep -E "$service|$(systemctl show $service --property=MainPID --no-pager 2>/dev/null | cut -d= -f2)" | grep -v grep | head -10
    } > "$TMP_FILE"
    show_text "Service Status" "$TMP_FILE"
    log "Viewed status for service: $service"
}

service_logs() {
    local service=$(get_input "Service Logs" "Enter service name:" "")
    [[ -z "$service" ]] && return
    
    local lines=$(get_input "Service Logs" "Number of lines to show:" "100")
    [[ -z "$lines" ]] && return
    
    local log_type=$(d --title "Log Type" --menu "\nSelect log type:" 12 60 3 \
        "all" "All Logs" \
        "errors" "Errors Only" \
        "follow" "Follow (live)" \
        3>&1 1>&2 2>&3)
    [[ -z "$log_type" ]] && return
    
    if [[ "$log_type" == "follow" ]]; then
        {
            echo "Following logs for $service (press Ctrl+C to stop)..."
            echo ""
            sudo journalctl -u "$service" -f --no-pager 2>&1
        } > "$TMP_FILE" 2>&1
        show_text "Service Logs (Live)" "$TMP_FILE"
    else
        {
            echo "════════════════════════════════════════════════════════════════════════"
            echo "              SERVICE LOGS - $service"
            echo "════════════════════════════════════════════════════════════════════════"
            echo ""
            if [[ "$log_type" == "errors" ]]; then
                echo "ERROR LOGS:"
                echo "────────────────────────────────────────────────────────────────────────"
                sudo journalctl -u "$service" -p err -n "$lines" --no-pager 2>&1
            else
                echo "ALL LOGS (Last $lines lines):"
                echo "────────────────────────────────────────────────────────────────────────"
                sudo journalctl -u "$service" -n "$lines" --no-pager 2>&1
            fi
            echo ""
            echo "LOG STATISTICS:"
            echo "────────────────────────────────────────────────────────────────────────"
            echo "   Total entries: $(sudo journalctl -u "$service" --no-pager 2>/dev/null | wc -l)"
            echo "   Errors: $(sudo journalctl -u "$service" -p err --no-pager 2>/dev/null | wc -l)"
            echo "   Warnings: $(sudo journalctl -u "$service" -p warning --no-pager 2>/dev/null | wc -l)"
        } > "$TMP_FILE"
        show_text "Service Logs" "$TMP_FILE"
    fi
    log "Viewed logs for service: $service"
}

service_list_processes() {
    local sort_by=$(d --title "Process Sort" --menu "\nSort by:" 14 60 5 \
        "cpu" "CPU Usage (highest first)" \
        "mem" "Memory Usage (highest first)" \
        "pid" "Process ID" \
        "user" "User" \
        "time" "CPU Time" \
        3>&1 1>&2 2>&3)
    [[ -z "$sort_by" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    PROCESS LIST"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "Sort by: $sort_by"
        echo "────────────────────────────────────────────────────────────────────────"
        
        case "$sort_by" in
            cpu)
                ps aux --sort=-%cpu | head -30
                ;;
            mem)
                ps aux --sort=-%mem | head -30
                ;;
            pid)
                ps aux --sort=pid | head -30
                ;;
            user)
                ps aux --sort=user | head -30
                ;;
            time)
                ps aux --sort=-time | head -30
                ;;
        esac
        
        echo ""
        echo "PROCESS STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total processes: $(ps aux | wc -l)"
        echo "   Running: $(ps aux | grep -c " R ")"
        echo "   Sleeping: $(ps aux | grep -c " S ")"
        echo "   Zombie: $(ps aux | grep -c " Z ")"
        echo ""
        echo "PROCESS BY USER:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps aux | awk '{print $1}' | sort | uniq -c | sort -rn | head -10
    } > "$TMP_FILE"
    show_text "Process List" "$TMP_FILE"
    log "Listed processes sorted by $sort_by"
}

service_kill_process() {
    local pid=$(get_input "Kill Process" "Enter PID to kill:" "")
    [[ -z "$pid" ]] && return
    
    if ! ps -p "$pid" &>/dev/null; then
        show_msg "Error" "Process $pid does not exist!"
        return
    fi
    
    local proc_name=$(ps -p "$pid" -o comm= 2>/dev/null)
    local proc_user=$(ps -p "$pid" -o user= 2>/dev/null)
    
    local signal=$(d --title "Signal" --menu "\nSelect signal:" 14 60 5 \
        "15" "TERM (graceful)" \
        "9" "KILL (force)" \
        "1" "HUP (reload)" \
        "2" "INT (interrupt)" \
        "3" "QUIT (core dump)" \
        3>&1 1>&2 2>&3)
    [[ -z "$signal" ]] && return
    
    if ask_yesno "Send SIG$signal to process $pid ($proc_name) owned by $proc_user?"; then
        {
            echo "Sending SIG$signal to process $pid..."
            kill -$signal "$pid" 2>&1
            echo ""
            echo "Signal sent!"
            echo ""
            if ps -p "$pid" &>/dev/null; then
                echo "Process still running:"
                ps -p "$pid"
            else
                echo "Process terminated successfully!"
            fi
        } > "$TMP_FILE" 2>&1
        show_text "Kill Process" "$TMP_FILE"
        log "Killed process $pid with SIG$signal"
    fi
}

service_process_priority() {
    local pid=$(get_input "Process Priority" "Enter PID:" "")
    [[ -z "$pid" ]] && return
    
    if ! ps -p "$pid" &>/dev/null; then
        show_msg "Error" "Process $pid does not exist!"
        return
    fi
    
    local current_nice=$(ps -p "$pid" -o nice= 2>/dev/null | tr -d ' ')
    local proc_name=$(ps -p "$pid" -o comm= 2>/dev/null)
    
    local choice=$(d --title "Process Priority" --menu "\nProcess: $pid ($proc_name)\nCurrent nice: $current_nice" 16 60 4 \
        "increase" "Increase Priority (lower nice)" \
        "decrease" "Decrease Priority (higher nice)" \
        "set" "Set Specific Nice Value" \
        "show" "Show Current Priority" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        increase)
            if ask_yesno "Increase priority of process $pid (renice -5)?"; then
                {
                    sudo renice -n -5 -p "$pid" 2>&1
                    echo ""
                    echo "New priority:"
                    ps -p "$pid" -o pid,comm,nice,pri
                } > "$TMP_FILE" 2>&1
                show_text "Process Priority" "$TMP_FILE"
                log "Increased priority of process $pid"
            fi
            ;;
        decrease)
            if ask_yesno "Decrease priority of process $pid (renice +5)?"; then
                {
                    sudo renice -n +5 -p "$pid" 2>&1
                    echo ""
                    echo "New priority:"
                    ps -p "$pid" -o pid,comm,nice,pri
                } > "$TMP_FILE" 2>&1
                show_text "Process Priority" "$TMP_FILE"
                log "Decreased priority of process $pid"
            fi
            ;;
        set)
            local nice_value=$(get_input "Set Nice" "Enter nice value (-20 to 19):" "0")
            [[ -z "$nice_value" ]] && return
            
            if ask_yesno "Set nice to $nice_value for process $pid?"; then
                {
                    sudo renice -n "$nice_value" -p "$pid" 2>&1
                    echo ""
                    echo "New priority:"
                    ps -p "$pid" -o pid,comm,nice,pri
                } > "$TMP_FILE" 2>&1
                show_text "Process Priority" "$TMP_FILE"
                log "Set nice $nice_value for process $pid"
            fi
            ;;
        show)
            {
                echo "PRIORITY INFO for PID $pid:"
                echo "────────────────────────────────────────────────────────────────────────"
                ps -p "$pid" -o pid,user,comm,nice,pri,psr,pcpu,pmem,time
                echo ""
                echo "SCHEDULING INFO:"
                chrt -p "$pid" 2>&1
            } > "$TMP_FILE"
            show_text "Process Priority" "$TMP_FILE"
            ;;
    esac
}

service_process_tree() {
    local pid=$(get_input "Process Tree" "Enter PID (or leave blank for all):" "")
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    PROCESS TREE"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if [[ -n "$pid" ]]; then
            if ! ps -p "$pid" &>/dev/null; then
                echo "Process $pid does not exist!"
            else
                echo "Process tree for PID $pid:"
                echo "────────────────────────────────────────────────────────────────────────"
                pstree -p "$pid" 2>/dev/null
                echo ""
                echo "Parent processes:"
                ps -f --ppid "$pid" 2>/dev/null
                echo ""
                echo "Children:"
                pstree -ps "$pid" 2>/dev/null
            fi
        else
            echo "FULL PROCESS TREE:"
            echo "────────────────────────────────────────────────────────────────────────"
            pstree -p 2>/dev/null | head -100
        fi
        
        echo ""
        echo "PROCESS HIERARCHY:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps -eo pid,comm,user,pcpu,pmem --forest 2>/dev/null | head -50
    } > "$TMP_FILE"
    show_text "Process Tree" "$TMP_FILE"
    log "Viewed process tree${pid:+ for PID $pid}"
}

service_system_resources() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    SYSTEM RESOURCES"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "CPU USAGE:"
        echo "────────────────────────────────────────────────────────────────────────"
        top -bn1 | head -10
        echo ""
        echo "MEMORY USAGE:"
        echo "────────────────────────────────────────────────────────────────────────"
        free -h
        echo ""
        echo "DISK USAGE:"
        echo "────────────────────────────────────────────────────────────────────────"
        df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null
        echo ""
        echo "LOAD AVERAGE:"
        echo "────────────────────────────────────────────────────────────────────────"
        uptime
        echo ""
        echo "OPEN FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total open files: $(lsof 2>/dev/null | wc -l)"
        echo "   File descriptor limit: $(ulimit -n)"
        echo ""
        echo "IO STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        iostat 2>/dev/null | head -20 || echo "iostat not available"
        echo ""
        echo "NETWORK STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        netstat -i 2>/dev/null | head -10
        echo ""
        echo "PROCESS LIMITS:"
        echo "────────────────────────────────────────────────────────────────────────"
        ulimit -a
        echo ""
        echo "SYSTEM RESOURCE STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total processes: $(ps aux | wc -l)"
        echo "   Total threads: $(ps -eLf | wc -l)"
        echo "   Total users: $(who | wc -l)"
        echo "   System uptime: $(uptime -p 2>/dev/null || uptime)"
    } > "$TMP_FILE"
    show_text "System Resources" "$TMP_FILE"
    log "Viewed system resources"
}