#!/usr/bin/env bash

backup_menu() {
    while true; do
        local choice=$(d --clear --title "Backup & Maintenance" \
            --menu "\nSelect backup operation:" $HEIGHT $WIDTH $MENU_HEIGHT \
            1 "Create Backup" \
            2 "Restore Backup" \
            3 "List Backups" \
            4 "Delete Backup" \
            5 "Scheduled Backup" \
            6 "System Backup" \
            7 "Home Directory Backup" \
            8 "Database Backup" \
            9 "System Cleanup" \
            10 "Log Rotation" \
            11 "Temp File Cleanup" \
            12 "Find Large Files" \
            13 "System Health Check" \
            14 "Performance Report" \
            0 "Main Menu" \
            3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$choice" == "0" ]] && break
        
        case "$choice" in
            1) backup_create ;;
            2) backup_restore ;;
            3) backup_list ;;
            4) backup_delete ;;
            5) backup_scheduled ;;
            6) backup_system ;;
            7) backup_home ;;
            8) backup_database ;;
            9) backup_cleanup ;;
            10) backup_log_rotate ;;
            11) backup_temp_cleanup ;;
            12) backup_find_large_files ;;
            13) backup_health_check ;;
            14) backup_performance_report ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

backup_create() {
    local source_path=$(get_input "Create Backup" "Enter source path to backup:" "/home")
    [[ -z "$source_path" ]] && return
    
    if [[ ! -d "$source_path" ]] && [[ ! -f "$source_path" ]]; then
        show_msg "Error" "Path does not exist!"
        return
    fi
    
    local dest_dir=$(get_input "Create Backup" "Enter destination directory:" "${BACKUP_PATH:-/var/backups/lsym}")
    [[ -z "$dest_dir" ]] && return
    
    sudo mkdir -p "$dest_dir" 2>/dev/null
    
    local backup_name=$(basename "$source_path")_$(date +%Y%m%d_%H%M%S)
    
    local compression=$(d --title "Compression" --menu "\nSelect compression:" 14 60 4 \
        "gzip" "GZIP (fast, medium size)" \
        "bzip2" "BZIP2 (slower, smaller)" \
        "xz" "XZ (slowest, smallest)" \
        "none" "No compression" \
        3>&1 1>&2 2>&3)
    [[ -z "$compression" ]] && return
    
    local encrypt=$(d --title "Encryption" --menu "\nEncrypt backup?" 10 60 2 \
        "no" "No encryption" \
        "yes" "Encrypt with GPG" \
        3>&1 1>&2 2>&3)
    [[ -z "$encrypt" ]] && return
    
    local backup_file=""
    
    if [[ "$compression" == "gzip" ]]; then
        backup_file="$dest_dir/${backup_name}.tar.gz"
    elif [[ "$compression" == "bzip2" ]]; then
        backup_file="$dest_dir/${backup_name}.tar.bz2"
    elif [[ "$compression" == "xz" ]]; then
        backup_file="$dest_dir/${backup_name}.tar.xz"
    else
        backup_file="$dest_dir/${backup_name}.tar"
    fi
    
    if [[ "$encrypt" == "yes" ]]; then
        backup_file="${backup_file}.gpg"
    fi
    
    if ask_yesno "Create backup:\nSource: $source_path\nDestination: $backup_file\nCompression: $compression\nEncryption: $encrypt"; then
        {
            echo "Creating backup from $source_path..."
            echo ""
            
            local temp_tar="/tmp/backup_${backup_name}.tar"
            
            if [[ "$compression" == "none" ]]; then
                tar -cf "$temp_tar" -C "$(dirname "$source_path")" "$(basename "$source_path")" 2>&1
            elif [[ "$compression" == "gzip" ]]; then
                tar -czf "$backup_file" -C "$(dirname "$source_path")" "$(basename "$source_path")" 2>&1
                temp_tar="$backup_file"
            elif [[ "$compression" == "bzip2" ]]; then
                tar -cjf "$backup_file" -C "$(dirname "$source_path")" "$(basename "$source_path")" 2>&1
                temp_tar="$backup_file"
            elif [[ "$compression" == "xz" ]]; then
                tar -cJf "$backup_file" -C "$(dirname "$source_path")" "$(basename "$source_path")" 2>&1
                temp_tar="$backup_file"
            fi
            
            if [[ "$encrypt" == "yes" ]] && [[ "$compression" != "none" ]]; then
                echo "Encrypting backup..."
                gpg --symmetric --cipher-algo AES256 "$temp_tar" 2>&1
                rm -f "$temp_tar" 2>/dev/null
            elif [[ "$encrypt" == "yes" ]] && [[ "$compression" == "none" ]]; then
                echo "Encrypting backup..."
                gpg --symmetric --cipher-algo AES256 "$temp_tar" 2>&1
                rm -f "$temp_tar" 2>/dev/null
            fi
            
            echo ""
            echo "Backup created successfully!"
            echo ""
            echo "File: $(ls -lh "$backup_file" 2>/dev/null | awk '{print $9, $5}')"
            echo ""
            echo "Checksum (SHA256):"
            sha256sum "$backup_file" 2>/dev/null
        } > "$TMP_FILE" 2>&1
        show_text "Backup Created" "$TMP_FILE"
        log "Created backup: $backup_file from $source_path"
    fi
}

backup_restore() {
    local backup_file=$(get_input "Restore Backup" "Enter backup file path:" "")
    [[ -z "$backup_file" ]] && return
    
    if [[ ! -f "$backup_file" ]]; then
        show_msg "Error" "Backup file does not exist!"
        return
    fi
    
    local dest_path=$(get_input "Restore Backup" "Enter destination path:" "/")
    [[ -z "$dest_path" ]] && return
    
    if [[ ! -d "$dest_path" ]]; then
        mkdir -p "$dest_path" 2>/dev/null
    fi
    
    local is_encrypted=false
    local is_compressed=false
    local compression_type=""
    
    if [[ "$backup_file" == *.gpg ]]; then
        is_encrypted=true
        backup_file="${backup_file%.gpg}"
    fi
    
    if [[ "$backup_file" == *.tar.gz ]] || [[ "$backup_file" == *.tgz ]]; then
        is_compressed=true
        compression_type="gzip"
    elif [[ "$backup_file" == *.tar.bz2 ]] || [[ "$backup_file" == *.tbz2 ]]; then
        is_compressed=true
        compression_type="bzip2"
    elif [[ "$backup_file" == *.tar.xz ]] || [[ "$backup_file" == *.txz ]]; then
        is_compressed=true
        compression_type="xz"
    elif [[ "$backup_file" == *.tar ]]; then
        is_compressed=false
    fi
    
    if ask_yesno "Restore backup to $dest_path?\n\nFile: $backup_file\nEncrypted: $is_encrypted\nCompressed: $is_compressed"; then
        {
            echo "Restoring backup to $dest_path..."
            echo ""
            
            local temp_file="$backup_file"
            local restore_file="$backup_file"
            
            if [[ "$is_encrypted" == true ]]; then
                echo "Decrypting backup..."
                gpg -d "$backup_file.gpg" > "$backup_file" 2>&1
                restore_file="$backup_file"
            fi
            
            echo "Extracting files..."
            if [[ "$compression_type" == "gzip" ]]; then
                tar -xzf "$restore_file" -C "$dest_path" 2>&1
            elif [[ "$compression_type" == "bzip2" ]]; then
                tar -xjf "$restore_file" -C "$dest_path" 2>&1
            elif [[ "$compression_type" == "xz" ]]; then
                tar -xJf "$restore_file" -C "$dest_path" 2>&1
            else
                tar -xf "$restore_file" -C "$dest_path" 2>&1
            fi
            
            if [[ "$is_encrypted" == true ]]; then
                rm -f "$backup_file" 2>/dev/null
            fi
            
            echo ""
            echo "Restore completed successfully!"
            echo ""
            echo "Destination: $dest_path"
            echo "Files restored: $(find "$dest_path" -type f -mmin -5 2>/dev/null | wc -l)"
        } > "$TMP_FILE" 2>&1
        show_text "Backup Restored" "$TMP_FILE"
        log "Restored backup: $backup_file to $dest_path"
    fi
}

backup_list() {
    local backup_dir=$(get_input "List Backups" "Enter backup directory:" "${BACKUP_PATH:-/var/backups/lsym}")
    [[ -z "$backup_dir" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    BACKUP LIST - $backup_dir"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "BACKUP FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -d "$backup_dir" ]]; then
            ls -lh "$backup_dir" 2>/dev/null | grep -v "^total"
            echo ""
            echo "BACKUP STATISTICS:"
            echo "────────────────────────────────────────────────────────────────────────"
            echo "   Total backups: $(find "$backup_dir" -type f -name "*.tar*" 2>/dev/null | wc -l)"
            echo "   Total size: $(du -sh "$backup_dir" 2>/dev/null | cut -f1)"
            echo "   Oldest backup: $(find "$backup_dir" -type f -name "*.tar*" -printf "%T+ %p\n" 2>/dev/null | sort | head -1)"
            echo "   Newest backup: $(find "$backup_dir" -type f -name "*.tar*" -printf "%T+ %p\n" 2>/dev/null | sort | tail -1)"
        else
            echo "Backup directory does not exist!"
        fi
    } > "$TMP_FILE"
    show_text "Backup List" "$TMP_FILE"
    log "Listed backups in $backup_dir"
}

backup_delete() {
    local backup_dir=$(get_input "Delete Backup" "Enter backup directory:" "${BACKUP_PATH:-/var/backups/lsym}")
    [[ -z "$backup_dir" ]] && return
    
    local backup_file=$(d --title "Select Backup" --menu "\nSelect backup to delete:" $HEIGHT $WIDTH 8 \
        $(find "$backup_dir" -type f -name "*.tar*" 2>/dev/null | xargs -n1 basename | awk '{print NR " " $0}') \
        3>&1 1>&2 2>&3)
    [[ -z "$backup_file" ]] && return
    
    local full_path="$backup_dir/$backup_file"
    
    if ask_yesno "DELETE backup: $backup_file\n\nSize: $(du -h "$full_path" 2>/dev/null | cut -f1)\nThis cannot be undone!"; then
        {
            rm -f "$full_path" 2>&1
            echo "Backup deleted successfully!"
        } > "$TMP_FILE" 2>&1
        show_text "Delete Backup" "$TMP_FILE"
        log "Deleted backup: $full_path"
    fi
}

backup_scheduled() {
    local choice=$(d --title "Scheduled Backup" --menu "\nSelect operation:" 12 60 3 \
        "create" "Create Scheduled Backup" \
        "list" "List Scheduled Backups" \
        "remove" "Remove Scheduled Backup" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        create)
            local source=$(get_input "Scheduled Backup" "Enter source path:" "/home")
            [[ -z "$source" ]] && return
            
            local dest=$(get_input "Scheduled Backup" "Enter destination directory:" "${BACKUP_PATH:-/var/backups/lsym}")
            [[ -z "$dest" ]] && return
            
            local schedule=$(d --title "Schedule" --menu "\nSelect schedule:" 12 60 4 \
                "daily" "Daily at 2AM" \
                "weekly" "Weekly on Sunday" \
                "monthly" "Monthly on 1st" \
                "custom" "Custom cron schedule" \
                3>&1 1>&2 2>&3)
            [[ -z "$schedule" ]] && return
            
            local cron_time=""
            case "$schedule" in
                daily) cron_time="0 2 * * *" ;;
                weekly) cron_time="0 2 * * 0" ;;
                monthly) cron_time="0 2 1 * *" ;;
                custom)
                    local custom=$(get_input "Scheduled Backup" "Enter cron schedule (min hour day month dow):" "0 2 * * *")
                    [[ -z "$custom" ]] && return
                    cron_time="$custom"
                    ;;
            esac
            
            local backup_script="/tmp/backup_$(date +%s).sh"
            cat > "$backup_script" <<EOF
#!/bin/bash
tar -czf "$dest/backup_\$(date +%Y%m%d_%H%M%S).tar.gz" "$source" 2>&1
EOF
            chmod +x "$backup_script"
            
            if ask_yesno "Create scheduled backup:\nSource: $source\nDestination: $dest\nSchedule: $cron_time"; then
                {
                    (crontab -l 2>/dev/null; echo "$cron_time $backup_script") | crontab -
                    echo "Scheduled backup added successfully!"
                    echo ""
                    echo "Current crontab:"
                    crontab -l
                } > "$TMP_FILE" 2>&1
                show_text "Scheduled Backup" "$TMP_FILE"
                log "Created scheduled backup: $source -> $dest ($cron_time)"
            fi
            ;;
        list)
            {
                echo "SCHEDULED BACKUPS:"
                echo "────────────────────────────────────────────────────────────────────────"
                crontab -l 2>/dev/null | grep -i backup
                echo ""
                echo "ALL CRON JOBS:"
                echo "────────────────────────────────────────────────────────────────────────"
                crontab -l 2>/dev/null
            } > "$TMP_FILE"
            show_text "Scheduled Backups" "$TMP_FILE"
            log "Listed scheduled backups"
            ;;
        remove)
            local job=$(get_input "Remove Scheduled Backup" "Enter cron job pattern to remove (e.g., backup):" "backup")
            [[ -z "$job" ]] && return
            
            if ask_yesno "Remove scheduled backups containing '$job'?"; then
                {
                    crontab -l 2>/dev/null | grep -v "$job" | crontab -
                    echo "Scheduled backup removed!"
                } > "$TMP_FILE" 2>&1
                show_text "Remove Scheduled Backup" "$TMP_FILE"
                log "Removed scheduled backup containing $job"
            fi
            ;;
    esac
}

backup_system() {
    if ask_yesno "Create system backup?\n\nThis will backup:\n- /etc (system configuration)\n- /var/log (logs)\n- /usr/local (custom apps)\n- Running services\n\nWARNING: This may take a while!"; then
        {
            echo "Creating system backup..."
            echo ""
            
            local dest_dir="${BACKUP_PATH:-/var/backups/lsym}/system_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$dest_dir" 2>/dev/null
            
            echo "Backing up system configuration (/etc)..."
            tar -czf "$dest_dir/etc_backup.tar.gz" /etc 2>&1
            
            echo "Backing up logs (/var/log)..."
            tar -czf "$dest_dir/logs_backup.tar.gz" /var/log 2>&1
            
            echo "Backing up local apps (/usr/local)..."
            tar -czf "$dest_dir/local_backup.tar.gz" /usr/local 2>&1
            
            echo "Backing up package list..."
            if command -v apt &>/dev/null; then
                dpkg -l > "$dest_dir/packages.txt" 2>&1
                apt list --installed > "$dest_dir/apt_packages.txt" 2>&1
            elif command -v dnf &>/dev/null; then
                dnf list installed > "$dest_dir/packages.txt" 2>&1
            elif command -v pacman &>/dev/null; then
                pacman -Q > "$dest_dir/packages.txt" 2>&1
            fi
            
            echo "Backing up running services..."
            systemctl list-units --state=running > "$dest_dir/services.txt" 2>&1
            
            echo ""
            echo "System backup completed!"
            echo ""
            echo "Backup location: $dest_dir"
            echo "Total size: $(du -sh "$dest_dir" 2>/dev/null | cut -f1)"
            echo ""
            echo "Created files:"
            ls -lh "$dest_dir" 2>/dev/null
        } > "$TMP_FILE" 2>&1
        show_text "System Backup" "$TMP_FILE"
        log "Created system backup"
    fi
}

backup_home() {
    local user=$(get_input "Home Backup" "Enter username:" "$(whoami)")
    [[ -z "$user" ]] && return
    
    if ! id "$user" &>/dev/null; then
        show_msg "Error" "User $user does not exist!"
        return
    fi
    
    local home_dir=$(eval echo ~$user)
    
    if ask_yesno "Backup home directory for $user?\n\nDirectory: $home_dir"; then
        {
            echo "Backing up home directory for $user..."
            echo ""
            
            local dest_dir="${BACKUP_PATH:-/var/backups/lsym}/home_${user}_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$dest_dir" 2>/dev/null
            
            echo "Backing up home directory..."
            tar -czf "$dest_dir/home_backup.tar.gz" -C "$(dirname "$home_dir")" "$(basename "$home_dir")" 2>&1
            
            echo "Backing up SSH keys..."
            if [[ -d "$home_dir/.ssh" ]]; then
                cp -r "$home_dir/.ssh" "$dest_dir/" 2>/dev/null
            fi
            
            echo "Backing up bash history..."
            if [[ -f "$home_dir/.bash_history" ]]; then
                cp "$home_dir/.bash_history" "$dest_dir/" 2>/dev/null
            fi
            
            echo "Backing up user crontab..."
            crontab -u "$user" -l > "$dest_dir/crontab.txt" 2>/dev/null
            
            echo ""
            echo "Home backup completed!"
            echo ""
            echo "Backup location: $dest_dir"
            echo "Total size: $(du -sh "$dest_dir" 2>/dev/null | cut -f1)"
            echo ""
            echo "Created files:"
            ls -lh "$dest_dir" 2>/dev/null
        } > "$TMP_FILE" 2>&1
        show_text "Home Backup" "$TMP_FILE"
        log "Created home backup for $user"
    fi
}

backup_database() {
    local db_type=$(d --title "Database Type" --menu "\nSelect database type:" 12 60 3 \
        "mysql" "MySQL/MariaDB" \
        "postgres" "PostgreSQL" \
        "all" "All Databases" \
        3>&1 1>&2 2>&3)
    [[ -z "$db_type" ]] && return
    
    local db_user=$(get_input "Database Backup" "Enter database username:" "root")
    [[ -z "$db_user" ]] && return
    
    local db_password=$(get_password "Database Backup" "Enter database password:")
    
    case "$db_type" in
        mysql)
            if ! command -v mysqldump &>/dev/null; then
                show_msg "Error" "mysqldump not installed!\nInstall: sudo apt install mysql-client"
                return
            fi
            
            local db_name=$(get_input "Database Backup" "Enter database name (or 'all'):" "all")
            [[ -z "$db_name" ]] && return
            
            if ask_yesno "Backup MySQL database $db_name?"; then
                {
                    local dest_dir="${BACKUP_PATH:-/var/backups/lsym}/mysql_$(date +%Y%m%d_%H%M%S)"
                    mkdir -p "$dest_dir" 2>/dev/null
                    
                    echo "Backing up MySQL databases..."
                    if [[ "$db_name" == "all" ]]; then
                        mysqldump -u "$db_user" -p"$db_password" --all-databases > "$dest_dir/all_databases.sql" 2>&1
                    else
                        mysqldump -u "$db_user" -p"$db_password" "$db_name" > "$dest_dir/${db_name}.sql" 2>&1
                    fi
                    
                    gzip "$dest_dir"/*.sql 2>/dev/null
                    
                    echo ""
                    echo "Database backup completed!"
                    echo ""
                    echo "Backup location: $dest_dir"
                    echo "Total size: $(du -sh "$dest_dir" 2>/dev/null | cut -f1)"
                    echo ""
                    echo "Created files:"
                    ls -lh "$dest_dir" 2>/dev/null
                } > "$TMP_FILE" 2>&1
                show_text "Database Backup" "$TMP_FILE"
                log "Created MySQL backup for $db_name"
            fi
            ;;
        postgres)
            if ! command -v pg_dump &>/dev/null; then
                show_msg "Error" "pg_dump not installed!\nInstall: sudo apt install postgresql-client"
                return
            fi
            
            local db_name=$(get_input "Database Backup" "Enter database name (or 'all'):" "all")
            [[ -z "$db_name" ]] && return
            
            if ask_yesno "Backup PostgreSQL database $db_name?"; then
                {
                    local dest_dir="${BACKUP_PATH:-/var/backups/lsym}/postgres_$(date +%Y%m%d_%H%M%S)"
                    mkdir -p "$dest_dir" 2>/dev/null
                    
                    echo "Backing up PostgreSQL databases..."
                    if [[ "$db_name" == "all" ]]; then
                        pg_dumpall -U "$db_user" > "$dest_dir/all_databases.sql" 2>&1
                    else
                        pg_dump -U "$db_user" "$db_name" > "$dest_dir/${db_name}.sql" 2>&1
                    fi
                    
                    gzip "$dest_dir"/*.sql 2>/dev/null
                    
                    echo ""
                    echo "Database backup completed!"
                    echo ""
                    echo "Backup location: $dest_dir"
                    echo "Total size: $(du -sh "$dest_dir" 2>/dev/null | cut -f1)"
                    echo ""
                    echo "Created files:"
                    ls -lh "$dest_dir" 2>/dev/null
                } > "$TMP_FILE" 2>&1
                show_text "Database Backup" "$TMP_FILE"
                log "Created PostgreSQL backup for $db_name"
            fi
            ;;
        all)
            if ask_yesno "Backup ALL databases (MySQL and PostgreSQL)?"; then
                {
                    local dest_dir="${BACKUP_PATH:-/var/backups/lsym}/all_db_$(date +%Y%m%d_%H%M%S)"
                    mkdir -p "$dest_dir" 2>/dev/null
                    
                    if command -v mysqldump &>/dev/null; then
                        echo "Backing up MySQL databases..."
                        mysqldump -u "$db_user" -p"$db_password" --all-databases > "$dest_dir/mysql_all.sql" 2>&1
                        gzip "$dest_dir"/mysql_*.sql 2>/dev/null
                    fi
                    
                    if command -v pg_dump &>/dev/null; then
                        echo "Backing up PostgreSQL databases..."
                        pg_dumpall -U "$db_user" > "$dest_dir/postgres_all.sql" 2>&1
                        gzip "$dest_dir"/postgres_*.sql 2>/dev/null
                    fi
                    
                    echo ""
                    echo "All databases backup completed!"
                    echo ""
                    echo "Backup location: $dest_dir"
                    echo "Total size: $(du -sh "$dest_dir" 2>/dev/null | cut -f1)"
                    echo ""
                    echo "Created files:"
                    ls -lh "$dest_dir" 2>/dev/null
                } > "$TMP_FILE" 2>&1
                show_text "All Databases Backup" "$TMP_FILE"
                log "Created all databases backup"
            fi
            ;;
    esac
}

backup_cleanup() {
    if ask_yesno "Perform system cleanup?\n\nThis will remove:\n- Old log files\n- Temporary files\n- Package cache\n- Trash files"; then
        {
            echo "Starting system cleanup..."
            echo ""
            
            echo "Cleaning up old logs..."
            sudo journalctl --vacuum-time=7d 2>&1
            find /var/log -type f -name "*.log" -mtime +30 -delete 2>&1
            
            echo "Cleaning up temporary files..."
            sudo rm -rf /tmp/* 2>/dev/null
            sudo rm -rf /var/tmp/* 2>/dev/null
            
            echo "Cleaning up package cache..."
            if command -v apt &>/dev/null; then
                sudo apt autoclean -y 2>&1
                sudo apt autoremove -y 2>&1
            elif command -v dnf &>/dev/null; then
                sudo dnf clean all 2>&1
            elif command -v pacman &>/dev/null; then
                sudo pacman -Sc --noconfirm 2>&1
            fi
            
            echo "Cleaning up trash..."
            rm -rf ~/.local/share/Trash/* 2>/dev/null
            
            echo "Cleaning up old backups..."
            if [[ -d "${BACKUP_PATH:-/var/backups/lsym}" ]]; then
                find "${BACKUP_PATH:-/var/backups/lsym}" -type f -name "*.tar*" -mtime +30 -delete 2>&1
            fi
            
            echo ""
            echo "Cleanup completed!"
            echo ""
            echo "Disk space freed:"
            df -h /
        } > "$TMP_FILE" 2>&1
        show_text "System Cleanup" "$TMP_FILE"
        log "Performed system cleanup"
    fi
}

backup_log_rotate() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    LOG ROTATION STATUS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "LOG ROTATE CONFIGURATION:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f /etc/logrotate.conf ]]; then
            cat /etc/logrotate.conf 2>/dev/null | grep -v "^#" | grep -v "^$"
        fi
        
        echo ""
        echo "LOG ROTATE SCRIPTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        for file in /etc/logrotate.d/*; do
            if [[ -f "$file" ]]; then
                echo "=== $(basename "$file") ==="
                cat "$file" 2>/dev/null | grep -v "^#" | grep -v "^$" | head -10
                echo ""
            fi
        done
        
        echo ""
        echo "LOG FILES SIZE:"
        echo "────────────────────────────────────────────────────────────────────────"
        find /var/log -type f -name "*.log" -exec ls -lh {} \; 2>/dev/null | awk '{print $9, $5}' | head -20
        
        echo ""
        echo "LARGEST LOG FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        find /var/log -type f -name "*.log" -exec du -h {} \; 2>/dev/null | sort -rh | head -10
    } > "$TMP_FILE"
    show_text "Log Rotation" "$TMP_FILE"
    log "Viewed log rotation status"
}

backup_temp_cleanup() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    TEMPORARY FILES CLEANUP"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "TEMP DIRECTORIES:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   /tmp: $(du -sh /tmp 2>/dev/null | cut -f1)"
        echo "   /var/tmp: $(du -sh /var/tmp 2>/dev/null | cut -f1)"
        echo "   /var/cache: $(du -sh /var/cache 2>/dev/null | cut -f1)"
        
        echo ""
        echo "LARGE FILES IN /tmp:"
        echo "────────────────────────────────────────────────────────────────────────"
        find /tmp -type f -size +10M -exec ls -lh {} \; 2>/dev/null | head -10
        
        echo ""
        echo "FILES OLDER THAN 7 DAYS:"
        echo "────────────────────────────────────────────────────────────────────────"
        find /tmp -type f -mtime +7 -exec ls -lh {} \; 2>/dev/null | head -10
        
        echo ""
        echo "PROCESS USING TEMP FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lsof /tmp 2>/dev/null | head -10
    } > "$TMP_FILE"
    show_text "Temp Files Cleanup" "$TMP_FILE"
    log "Viewed temp files"
}

backup_find_large_files() {
    local path=$(get_input "Find Large Files" "Enter path to search:" "/")
    [[ -z "$path" ]] && return
    
    local size=$(get_input "Find Large Files" "Enter minimum size (e.g., 100M, 1G):" "100M")
    [[ -z "$size" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              LARGE FILES - $path ( > $size )"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "LARGEST FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        find "$path" -type f -size +"$size" -exec du -h {} \; 2>/dev/null | sort -rh | head -50
        
        echo ""
        echo "FILES BY DIRECTORY:"
        echo "────────────────────────────────────────────────────────────────────────"
        find "$path" -type d -exec sh -c "find \"{}\" -type f -size +$size 2>/dev/null | wc -l | xargs echo \"{}\" :" \; 2>/dev/null | sort -rn | head -10
        
        echo ""
        echo "FILE TYPES:"
        echo "────────────────────────────────────────────────────────────────────────"
        find "$path" -type f -size +"$size" 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -10
        
        echo ""
        echo "TOTAL SPACE USED BY LARGE FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        find "$path" -type f -size +"$size" -exec du -ch {} \; 2>/dev/null | tail -1
    } > "$TMP_FILE"
    show_text "Large Files" "$TMP_FILE"
    log "Found large files in $path > $size"
}

backup_health_check() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    SYSTEM HEALTH CHECK"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "CPU HEALTH:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Load average: $(uptime | awk -F'load average:' '{print $2}')"
        echo "   CPU usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
        echo "   Temperature: $(sensors 2>/dev/null | grep -m1 "Core 0" | awk '{print $3}')"
        
        echo ""
        echo "MEMORY HEALTH:"
        echo "────────────────────────────────────────────────────────────────────────"
        free -h
        echo "   Swap usage: $(free | grep Swap | awk '{printf "%.1f%%", $3/$2 * 100}')"
        
        echo ""
        echo "DISK HEALTH:"
        echo "────────────────────────────────────────────────────────────────────────"
        df -h
        echo ""
        echo "   Inode usage:"
        df -i
        
        echo ""
        echo "NETWORK HEALTH:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Interface status:"
        ip -br link show | grep -v lo
        echo ""
        echo "   Network connectivity:"
        ping -c 1 8.8.8.8 2>/dev/null && echo "   ✓ Internet reachable" || echo "   ✗ Internet not reachable"
        
        echo ""
        echo "SERVICES HEALTH:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Failed services: $(systemctl --failed 2>/dev/null | wc -l)"
        echo "   Running services: $(systemctl list-units --state=running 2>/dev/null | wc -l)"
        
        echo ""
        echo "DISK I/O HEALTH:"
        echo "────────────────────────────────────────────────────────────────────────"
        iostat 2>/dev/null | head -15
        
        echo ""
        echo "HEALTH SCORE:"
        echo "────────────────────────────────────────────────────────────────────────"
        score=10
        
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | tr -d ' ')
        if (( $(echo "$load_avg > 2" | bc -l) )); then
            echo "   ! -1: High load average: $load_avg"
            ((score--))
        fi
        
        if [[ $(df -h / | awk 'NR==2 {print $5}' | tr -d '%') -gt 80 ]]; then
            echo "   ! -1: Disk usage > 80%"
            ((score--))
        fi
        
        if [[ $(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}') -gt 90 ]]; then
            echo "   ! -1: Memory usage > 90%"
            ((score--))
        fi
        
        if [[ $(systemctl --failed 2>/dev/null | wc -l) -gt 2 ]]; then
            echo "   ! -1: Failed services > 2"
            ((score--))
        fi
        
        echo ""
        echo "   Health Score: $score/10"
        if [[ $score -ge 8 ]]; then
            echo "   ✓ System is healthy"
        elif [[ $score -ge 5 ]]; then
            echo "   ! System has some issues"
        else
            echo "   🚨 WARNING: System has critical health issues!"
        fi
    } > "$TMP_FILE"
    show_text "Health Check" "$TMP_FILE"
    log "Performed health check"
}

backup_performance_report() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    PERFORMANCE REPORT"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "REPORT GENERATED: $(date)"
        echo "────────────────────────────────────────────────────────────────────────"
        echo ""
        
        echo "1. CPU PERFORMANCE:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   CPU Model: $(lscpu | grep "Model name" | head -1 | cut -d: -f2 | xargs)"
        echo "   Cores: $(nproc)"
        echo "   Load Average: $(uptime | awk -F'load average:' '{print $2}')"
        echo "   CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
        
        echo ""
        echo "2. MEMORY PERFORMANCE:"
        echo "────────────────────────────────────────────────────────────────────────"
        free -h
        echo "   Swap Usage: $(free | grep Swap | awk '{printf "%.1f%%", $3/$2 * 100}')"
        
        echo ""
        echo "3. DISK PERFORMANCE:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Read Speed: $(sudo dd if=/dev/zero of=/dev/null bs=1M count=100 2>&1 | grep -E "MB/s|GB/s" | tail -1)"
        echo "   Write Speed: $(sudo dd if=/dev/zero of=/tmp/testfile bs=1M count=100 conv=fdatasync 2>&1 | grep -E "MB/s|GB/s" | tail -1)"
        rm -f /tmp/testfile 2>/dev/null
        
        echo ""
        echo "4. NETWORK PERFORMANCE:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Interface stats:"
        ip -s link show | grep -E "^[0-9]|RX|TX" | head -15
        
        echo ""
        echo "5. PROCESS PERFORMANCE:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total processes: $(ps aux | wc -l)"
        echo "   Zombie processes: $(ps aux | grep -c " Z ")"

        echo ""
        echo "6. SERVICE PERFORMANCE:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Running services: $(systemctl list-units --state=running 2>/dev/null | wc -l)"
        echo "   Failed services: $(systemctl --failed 2>/dev/null | wc -l)"
        
        echo ""
        echo "7. I/O STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        iostat 2>/dev/null | head -20
        
        echo ""
        echo "8. SYSTEM LIMITS:"
        echo "────────────────────────────────────────────────────────────────────────"
        ulimit -a
        
        echo ""
        echo "9. PERFORMANCE SCORE:"
        echo "────────────────────────────────────────────────────────────────────────"
        score=10
        
        # CPU Performance
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | tr -d ' ')
        if (( $(echo "$load_avg > 5" | bc -l) )); then
            echo "   ! -2: CPU overload"
            ((score-=2))
        elif (( $(echo "$load_avg > 2" | bc -l) )); then
            echo "   ! -1: CPU moderate load"
            ((score--))
        fi
        
        # Memory Performance
        if [[ $(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}') -gt 90 ]]; then
            echo "   ! -2: Memory critical usage > 90%"
            ((score-=2))
        elif [[ $(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}') -gt 80 ]]; then
            echo "   ! -1: Memory high usage > 80%"
            ((score--))
        fi
        
        # Disk Performance
        if [[ $(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%') -gt 85 ]]; then
            echo "   ! -1: Disk space critical > 85%"
            ((score--))
        fi
        
        # Process Performance
        if [[ $(ps aux | grep -c " Z ") -gt 0 ]]; then
            echo "   ! -1: Zombie processes found"
            ((score--))
        fi
        
        echo ""
        echo "   Performance Score: $score/10"
        if [[ $score -ge 8 ]]; then
            echo "   ✓ System performance is excellent"
        elif [[ $score -ge 5 ]]; then
            echo "   ! System performance is acceptable but has issues"
        else
            echo "   🚨 WARNING: System performance is critical!"
        fi
        
        echo ""
        echo "10. RECOMMENDATIONS:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ $(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}') -gt 80 ]]; then
            echo "   - Add more RAM or optimize memory usage"
        fi
        if [[ $(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%') -gt 80 ]]; then
            echo "   - Free up disk space or add more storage"
        fi
        if (( $(echo "$load_avg > 2" | bc -l) )); then
            echo "   - Reduce CPU load or upgrade processor"
        fi
        if [[ $(ps aux | grep -c " Z ") -gt 0 ]]; then
            echo "   - Investigate and kill zombie processes"
        fi
    } > "$TMP_FILE"
    show_text "Performance Report" "$TMP_FILE"
    log "Generated performance report"
}