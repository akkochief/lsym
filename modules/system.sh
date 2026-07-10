#!/usr/bin/env bash

system_menu() {
    while true; do
        local choice=$(d --clear --title "System Information" \
            --menu "\nSelect a category:" $HEIGHT $WIDTH $MENU_HEIGHT \
            1 "Complete System Overview" \
            2 "CPU Information" \
            3 "Memory & Swap Usage" \
            4 "Hardware Inventory" \
            5 "Temperature & Sensors" \
            6 "System Performance Benchmark" \
            7 "Kernel & Modules" \
            8 "Date, Time & Uptime" \
            9 "System Logs (journalctl)" \
            10 "Environment Variables" \
            11 "System Limits & Sysctl" \
            0 "Main Menu" \
            3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$choice" == "0" ]] && break
        
        case "$choice" in
            1) system_overview ;;
            2) system_cpu_info ;;
            3) system_memory_info ;;
            4) system_hardware_inventory ;;
            5) system_temperature ;;
            6) system_benchmark ;;
            7) system_kernel_info ;;
            8) system_time_info ;;
            9) system_logs ;;
            10) system_env ;;
            11) system_sysctl ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

system_overview() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                   SYSTEM OVERVIEW"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "OPERATING SYSTEM:"
        echo "────────────────────────────────────────────────────────────────────────"
        cat /etc/os-release 2>/dev/null
        echo ""
        echo "KERNEL: $(uname -r)"
        echo "ARCHITECTURE: $(uname -m)"
        echo "HOSTNAME: $(hostname)"
        echo ""
        echo "UPTIME:"
        echo "────────────────────────────────────────────────────────────────────────"
        uptime -p 2>/dev/null || uptime
        echo ""
        echo "DATE & TIME: $(date)"
        echo ""
        echo "CPU:"
        echo "────────────────────────────────────────────────────────────────────────"
        lscpu | grep -E "Model name|Architecture|CPU\(s\)|Thread|Core|Socket|Vendor|MHz|Cache" 2>/dev/null
        echo ""
        echo "MEMORY:"
        echo "────────────────────────────────────────────────────────────────────────"
        free -h
        echo ""
        echo "DISK USAGE:"
        echo "────────────────────────────────────────────────────────────────────────"
        df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null
        echo ""
        echo "LOAD AVERAGE: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""
        echo "LOGGED USERS:"
        echo "────────────────────────────────────────────────────────────────────────"
        who
        echo ""
        echo "SYSTEM PROCESSES: $(ps aux | wc -l)"
    } > "$TMP_FILE"
    show_text "System Overview" "$TMP_FILE"
    log "Viewed system overview"
}

system_cpu_info() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                     CPU INFORMATION"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "CPU MODEL:"
        echo "────────────────────────────────────────────────────────────────────────"
        lscpu | grep "Model name" | head -1
        echo ""
        echo "ARCHITECTURE:"
        echo "────────────────────────────────────────────────────────────────────────"
        lscpu | grep -E "Architecture|CPU op-mode"
        echo ""
        echo "CORES & THREADS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Physical cores: $(lscpu | grep 'Core(s) per socket' | awk '{print $NF}')"
        echo "   Sockets: $(lscpu | grep 'Socket(s)' | awk '{print $NF}')"
        echo "   Total cores: $(nproc)"
        echo "   Threads per core: $(lscpu | grep 'Thread(s) per core' | awk '{print $NF}')"
        echo ""
        echo "FREQUENCY:"
        echo "────────────────────────────────────────────────────────────────────────"
        lscpu | grep -E "MHz|max MHz|min MHz" 2>/dev/null
        echo ""
        echo "CACHE:"
        echo "────────────────────────────────────────────────────────────────────────"
        lscpu | grep -E "L[1-3] cache"
        echo ""
        echo "VIRTUALIZATION:"
        echo "────────────────────────────────────────────────────────────────────────"
        lscpu | grep Virtualization
        echo ""
        echo "CPU FLAGS:"
        echo "────────────────────────────────────────────────────────────────────────"
        lscpu | grep Flags | head -1 | fold -w 60
        echo ""
        echo "TOP 10 CPU CONSUMING PROCESSES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps aux --sort=-%cpu | head -11
    } > "$TMP_FILE"
    show_text "CPU Information" "$TMP_FILE"
    log "Viewed CPU information"
}

system_memory_info() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                 MEMORY & SWAP INFORMATION"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "PHYSICAL MEMORY (RAM):"
        echo "────────────────────────────────────────────────────────────────────────"
        free -h
        echo ""
        echo "MEMORY DETAILS:"
        echo "────────────────────────────────────────────────────────────────────────"
        cat /proc/meminfo | head -20
        echo ""
        echo "SWAP:"
        echo "────────────────────────────────────────────────────────────────────────"
        swapon --show 2>/dev/null || echo "No swap configured"
        echo ""
        echo "TOP 10 MEMORY CONSUMING PROCESSES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps aux --sort=-%mem | head -11
        echo ""
        echo "ZRAM STATUS:"
        echo "────────────────────────────────────────────────────────────────────────"
        if command -v zramctl &>/dev/null; then
            zramctl
        else
            echo "zramctl not available"
        fi
    } > "$TMP_FILE"
    show_text "Memory Information" "$TMP_FILE"
    log "Viewed memory information"
}

system_hardware_inventory() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "               HARDWARE INVENTORY"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "PCI DEVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lspci -v 2>/dev/null | head -100
        echo ""
        echo "USB DEVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lsusb -v 2>/dev/null | head -50
        echo ""
        echo "SCSI DEVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lsscsi 2>/dev/null || echo "lsscsi not available"
        echo ""
        echo "NVME DEVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lsblk -dno NAME,MODEL,SIZE,TYPE 2>/dev/null | grep nvme || echo "No NVMe devices found"
        echo ""
        echo "BLOCK DEVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,SERIAL 2>/dev/null
        echo ""
        echo "NETWORK INTERFACES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lspci | grep -i network
        echo ""
        echo "GRAPHICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        lspci | grep -i vga
    } > "$TMP_FILE"
    show_text "Hardware Inventory" "$TMP_FILE"
    log "Viewed hardware inventory"
}

system_temperature() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                  TEMPERATURE & SENSORS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        if command -v sensors &>/dev/null; then
            sensors 2>/dev/null
            echo ""
            echo "DISK TEMPERATURES:"
            echo "────────────────────────────────────────────────────────────────────────"
            for disk in $(lsblk -dno NAME | grep -E '^sd|^nvme|^vd'); do
                if command -v smartctl &>/dev/null; then
                    temp=$(sudo smartctl -A /dev/$disk 2>/dev/null | grep -i temperature | awk '{print $NF}' | head -1)
                    if [[ -n "$temp" ]]; then
                        echo "   /dev/$disk: ${temp}°C"
                    fi
                fi
            done
            echo ""
            echo "CPU TEMPERATURE:"
            echo "────────────────────────────────────────────────────────────────────────"
            if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
                temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
                temp=$((temp / 1000))
                echo "   CPU: ${temp}°C"
            fi
            if command -v sensors &>/dev/null; then
                sensors | grep -i "core" | head -10
            fi
        else
            echo "lm-sensors not installed. Install with:"
            echo "   sudo apt install lm-sensors  # Debian/Ubuntu"
            echo "   sudo dnf install lm_sensors   # RHEL/Fedora"
            echo "   sudo pacman -S lm_sensors     # Arch"
            echo ""
            echo "Then run: sudo sensors-detect"
        fi
    } > "$TMP_FILE"
    show_text "Temperature & Sensors" "$TMP_FILE"
    log "Viewed temperature information"
}

system_benchmark() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              SYSTEM PERFORMANCE BENCHMARK"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "CPU BENCHMARK:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Calculating CPU speed..."
        time echo "scale=10000; 4*a(1)" | bc -l 2>/dev/null | head -1 | tr -d '\\' | xargs echo "   Pi calculation (10000 digits):"
        echo ""
        echo "   CPU BogoMIPS: $(cat /proc/cpuinfo | grep -m1 "bogomips" | awk '{print $NF}')"
        echo ""
        echo "MEMORY BENCHMARK:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Memory write speed test:"
        dd if=/dev/zero of=/dev/shm/test bs=1M count=1024 2>&1 | grep -E "copied|MB/s"
        echo ""
        echo "DISK BENCHMARK:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Sequential write speed:"
        dd if=/dev/zero of=./testfile bs=1M count=1024 conv=fdatasync 2>&1 | grep -E "copied|MB/s"
        rm -f ./testfile
        echo ""
        echo "   Sequential read speed:"
        dd if=/dev/zero of=./testfile bs=1M count=1024 conv=fdatasync 2>/dev/null
        dd if=./testfile of=/dev/null bs=1M 2>&1 | grep -E "copied|MB/s"
        rm -f ./testfile
        echo ""
        echo "NETWORK BENCHMARK:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Localhost throughput test:"
        dd if=/dev/zero bs=1M count=100 | nc -l -p 9999 2>/dev/null &
        sleep 1
        nc localhost 9999 | dd of=/dev/null bs=1M 2>&1 | grep -E "copied|MB/s"
        killall nc 2>/dev/null
        echo ""
        echo "INTERNET SPEED TEST (if speedtest-cli installed):"
        echo "────────────────────────────────────────────────────────────────────────"
        if command -v speedtest-cli &>/dev/null; then
            speedtest-cli --simple 2>/dev/null
        else
            echo "speedtest-cli not installed. Install with:"
            echo "   sudo apt install speedtest-cli"
            echo "   pip install speedtest-cli"
        fi
    } > "$TMP_FILE"
    show_text "System Benchmark" "$TMP_FILE"
    log "Ran system benchmark"
}

system_kernel_info() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              KERNEL & MODULES INFORMATION"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "KERNEL VERSION:"
        echo "────────────────────────────────────────────────────────────────────────"
        uname -a
        echo ""
        echo "KERNEL PARAMETERS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sysctl -a 2>/dev/null | head -30
        echo ""
        echo "LOADED KERNEL MODULES (TOP 50):"
        echo "────────────────────────────────────────────────────────────────────────"
        lsmod | head -50
        echo ""
        echo "KERNEL MODULE INFORMATION:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total modules: $(lsmod | wc -l)"
        echo "   Module path: /lib/modules/$(uname -r)"
        echo ""
        echo "MODULE DEPENDENCIES:"
        echo "────────────────────────────────────────────────────────────────────────"
        for module in $(lsmod | awk 'NR>1 {print $1}' | head -10); do
            echo "   $module: $(modinfo $module 2>/dev/null | grep -E "description|author|license" | head -3)"
        done
    } > "$TMP_FILE"
    show_text "Kernel Information" "$TMP_FILE"
    log "Viewed kernel information"
}

system_time_info() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "             DATE, TIME & UPTIME INFORMATION"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "CURRENT DATE & TIME:"
        echo "────────────────────────────────────────────────────────────────────────"
        date
        echo ""
        echo "   UTC Time: $(date -u)"
        echo "   Unix Epoch: $(date +%s)"
        echo "   Weekday: $(date +%A)"
        echo "   Timezone: $(date +%Z)"
        echo ""
        echo "SYSTEM UPTIME:"
        echo "────────────────────────────────────────────────────────────────────────"
        uptime
        echo ""
        echo "   Boot time: $(who -b | awk '{print $3,$4}')"
        echo "   Users logged in: $(who | wc -l)"
        echo ""
        echo "NTP STATUS:"
        echo "────────────────────────────────────────────────────────────────────────"
        if command -v timedatectl &>/dev/null; then
            timedatectl
        else
            echo "timedatectl not available"
        fi
        echo ""
        echo "CLOCK SYNC STATUS:"
        echo "────────────────────────────────────────────────────────────────────────"
        if command -v ntpq &>/dev/null; then
            ntpq -p 2>/dev/null | head -10
        else
            echo "ntpq not available"
        fi
        echo ""
        echo "HARDWARE CLOCK:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo hwclock --show 2>/dev/null || echo "hwclock not accessible"
    } > "$TMP_FILE"
    show_text "Time & Uptime" "$TMP_FILE"
    log "Viewed time information"
}

system_logs() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                 SYSTEM LOGS (journalctl)"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "RECENT SYSTEM LOGS (Last 100 lines):"
        echo "────────────────────────────────────────────────────────────────────────"
        journalctl -n 100 --no-pager 2>/dev/null || echo "journalctl not available"
        echo ""
        echo "BOOT LOGS (Last 50 lines):"
        echo "────────────────────────────────────────────────────────────────────────"
        journalctl -b -n 50 --no-pager 2>/dev/null || echo "Boot logs not available"
        echo ""
        echo "KERNEL LOGS (Last 50 lines):"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo dmesg | tail -50 2>/dev/null || echo "dmesg not accessible"
        echo ""
        echo "AUTHENTICATION LOGS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo tail -50 /var/log/auth.log 2>/dev/null || sudo tail -50 /var/log/secure 2>/dev/null || echo "Auth logs not found"
        echo ""
        echo "FAILED LOGIN ATTEMPTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20 || echo "No failed login attempts found"
    } > "$TMP_FILE"
    show_text "System Logs" "$TMP_FILE"
    log "Viewed system logs"
}

system_env() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              ENVIRONMENT VARIABLES"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "SYSTEM ENVIRONMENT:"
        echo "────────────────────────────────────────────────────────────────────────"
        env | sort
        echo ""
        echo "SHELL VARIABLES:"
        echo "────────────────────────────────────────────────────────────────────────"
        set | head -50
        echo ""
        echo "PATH:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "$PATH" | tr ':' '\n'
        echo ""
        echo "LOCALE:"
        echo "────────────────────────────────────────────────────────────────────────"
        locale
        echo ""
        echo "PROCESS ENVIRONMENT:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps -eo pid,comm | tail -5 | while read pid cmd; do
            echo "   PID $pid ($cmd):"
            cat /proc/$pid/environ 2>/dev/null | tr '\0' '\n' | head -3
        done
    } > "$TMP_FILE"
    show_text "Environment Variables" "$TMP_FILE"
    log "Viewed environment variables"
}

system_sysctl() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "           SYSTEM LIMITS & SYSCTL PARAMETERS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "SYSCTL PARAMETERS (Selected):"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   kernel.ostype: $(sysctl -n kernel.ostype 2>/dev/null)"
        echo "   kernel.hostname: $(sysctl -n kernel.hostname 2>/dev/null)"
        echo "   kernel.osrelease: $(sysctl -n kernel.osrelease 2>/dev/null)"
        echo "   kernel.threads-max: $(sysctl -n kernel.threads-max 2>/dev/null)"
        echo "   kernel.pid_max: $(sysctl -n kernel.pid_max 2>/dev/null)"
        echo "   fs.file-max: $(sysctl -n fs.file-max 2>/dev/null)"
        echo "   net.ipv4.ip_forward: $(sysctl -n net.ipv4.ip_forward 2>/dev/null)"
        echo "   vm.swappiness: $(sysctl -n vm.swappiness 2>/dev/null)"
        echo "   vm.overcommit_memory: $(sysctl -n vm.overcommit_memory 2>/dev/null)"
        echo ""
        echo "USER LIMITS:"
        echo "────────────────────────────────────────────────────────────────────────"
        ulimit -a
        echo ""
        echo "OPEN FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Soft limit: $(ulimit -n)"
        echo "   Hard limit: $(ulimit -Hn)"
        echo "   Current open files: $(lsof 2>/dev/null | wc -l)"
        echo ""
        echo "PROCESS LIMITS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Max user processes: $(ulimit -u)"
        echo "   Pending signals: $(ulimit -i)"
        echo "   Core file size: $(ulimit -c)"
    } > "$TMP_FILE"
    show_text "System Limits & Sysctl" "$TMP_FILE"
    log "Viewed system limits"
}
