#!/usr/bin/env bash

user_menu() {
    while true; do
        local choice=$(d --clear --title "User & Group Management" \
            --menu "\nSelect user operation:" $HEIGHT $WIDTH $MENU_HEIGHT \
            1 "List All Users" \
            2 "List Logged-in Users" \
            3 "Create New User" \
            4 "Delete User" \
            5 "Change User Password" \
            6 "Lock/Unlock User" \
            7 "Modify User" \
            8 "List All Groups" \
            9 "Create Group" \
            10 "Delete Group" \
            11 "Add User to Group" \
            12 "Remove User from Group" \
            13 "Manage Sudo Access" \
            14 "Set User Quota" \
            15 "User SSH Key Management" \
            16 "View User Details" \
            0 "Main Menu" \
            3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$choice" == "0" ]] && break
        
        case "$choice" in
            1) user_list_all ;;
            2) user_list_logged ;;
            3) user_create ;;
            4) user_delete ;;
            5) user_change_password ;;
            6) user_lock_unlock ;;
            7) user_modify ;;
            8) user_list_groups ;;
            9) user_create_group ;;
            10) user_delete_group ;;
            11) user_add_to_group ;;
            12) user_remove_from_group ;;
            13) user_sudo_access ;;
            14) user_set_quota ;;
            15) user_ssh_keys ;;
            16) user_view_details ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

user_list_all() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    ALL USERS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "REGULAR USERS (UID >= 1000):"
        echo "────────────────────────────────────────────────────────────────────────"
        awk -F: '$3 >= 1000 && $3 != 65534 {print "   " $1 " (UID:" $3 ", GID:" $4 ", Home:" $6 ", Shell:" $7 ")"}' /etc/passwd
        echo ""
        echo "SYSTEM USERS (UID < 1000):"
        echo "────────────────────────────────────────────────────────────────────────"
        awk -F: '$3 < 1000 {print "   " $1 " (UID:" $3 ", Home:" $6 ", Shell:" $7 ")"}' /etc/passwd | head -30
        echo ""
        echo "USER STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total users: $(cat /etc/passwd | wc -l)"
        echo "   Regular users: $(awk -F: '$3 >= 1000 && $3 != 65534 {print}' /etc/passwd | wc -l)"
        echo "   System users: $(awk -F: '$3 < 1000 {print}' /etc/passwd | wc -l)"
        echo "   Users with shell: $(awk -F: '$7 != "/sbin/nologin" && $7 != "/bin/false" {print}' /etc/passwd | wc -l)"
        echo ""
        echo "LAST LOGIN TIMES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lastlog 2>/dev/null | head -20
        echo ""
        echo "LOGGED-IN USERS:"
        echo "────────────────────────────────────────────────────────────────────────"
        who
    } > "$TMP_FILE"
    show_text "All Users" "$TMP_FILE"
    log "Listed all users"
}

user_list_logged() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    LOGGED-IN USERS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "CURRENT SESSIONS:"
        echo "────────────────────────────────────────────────────────────────────────"
        who
        echo ""
        echo "DETAILED USER INFO:"
        echo "────────────────────────────────────────────────────────────────────────"
        w
        echo ""
        echo "USER PROCESSES:"
        echo "────────────────────────────────────────────────────────────────────────"
        for user in $(who | awk '{print $1}' | sort -u); do
            echo "   $user: $(ps -u $user 2>/dev/null | wc -l) processes"
        done
        echo ""
        echo "LAST LOGIN:"
        echo "────────────────────────────────────────────────────────────────────────"
        last -n 10 2>/dev/null
        echo ""
        echo "FAILED LOGIN ATTEMPTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 || echo "No failed login attempts found"
    } > "$TMP_FILE"
    show_text "Logged-in Users" "$TMP_FILE"
    log "Listed logged-in users"
}

user_create() {
    local username=$(get_input "Create User" "Enter username:")
    [[ -z "$username" ]] && return
    
    if id "$username" &>/dev/null; then
        show_msg "Error" "User $username already exists!"
        return
    fi
    
    local fullname=$(get_input "Create User" "Enter full name:" "$username")
    [[ -z "$fullname" ]] && return
    
    local shell=$(d --title "User Shell" --menu "\nSelect shell:" 14 60 5 \
        "/bin/bash" "Bash Shell" \
        "/bin/zsh" "Zsh Shell" \
        "/bin/sh" "Sh Shell" \
        "/bin/false" "No Shell (system user)" \
        "/sbin/nologin" "No Login" \
        3>&1 1>&2 2>&3)
    [[ -z "$shell" ]] && return
    
    local home_dir=$(get_input "Create User" "Enter home directory:" "/home/$username")
    [[ -z "$home_dir" ]] && return
    
    local create_home=$(d --title "Create Home" --menu "\nCreate home directory?" 10 60 2 \
        "yes" "Create Home Directory" \
        "no" "Don't Create Home" \
        3>&1 1>&2 2>&3)
    [[ -z "$create_home" ]] && return
    
    if ask_yesno "Create user: $username\nFull name: $fullname\nShell: $shell\nHome: $home_dir\nCreate home: $create_home"; then
        {
            echo "Creating user $username..."
            if [[ "$create_home" == "yes" ]]; then
                sudo useradd -m -d "$home_dir" -s "$shell" -c "$fullname" "$username" 2>&1
                sudo cp -r /etc/skel/. "$home_dir" 2>/dev/null
                sudo chown -R "$username:$username" "$home_dir" 2>&1
            else
                sudo useradd -M -s "$shell" -c "$fullname" "$username" 2>&1
            fi
            
            echo ""
            echo "User created successfully!"
            echo "Setting password for $username..."
            echo ""
            echo "Please enter password for $username:"
            sudo passwd "$username" 2>&1
            
            echo ""
            echo "User details:"
            id "$username"
            echo ""
            echo "Home directory: $(eval echo ~$username)"
        } > "$TMP_FILE" 2>&1
        show_text "Create User" "$TMP_FILE"
        log "Created user: $username"
    fi
}

user_delete() {
    local username=$(get_input "Delete User" "Enter username to delete:")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    local remove_home=$(d --title "Remove Home" --menu "\nRemove home directory and mail spool?" 12 60 2 \
        "yes" "Remove Home & Mail" \
        "no" "Keep Home & Mail" \
        3>&1 1>&2 2>&3)
    [[ -z "$remove_home" ]] && return
    
    if ask_yesno "DELETE user: $username\nRemove home: $remove_home\n\nWARNING: This cannot be undone!"; then
        {
            if [[ "$remove_home" == "yes" ]]; then
                sudo userdel -r "$username" 2>&1
            else
                sudo userdel "$username" 2>&1
            fi
            echo "User $username deleted successfully!"
        } > "$TMP_FILE" 2>&1
        show_text "Delete User" "$TMP_FILE"
        log "Deleted user: $username"
    fi
}

user_change_password() {
    local username=$(get_input "Change Password" "Enter username:" "$(whoami)")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    if ask_yesno "Change password for user: $username?"; then
        {
            echo "Changing password for $username..."
            echo ""
            sudo passwd "$username" 2>&1
        } > "$TMP_FILE" 2>&1
        show_text "Change Password" "$TMP_FILE"
        log "Changed password for user: $username"
    fi
}

user_lock_unlock() {
    local username=$(get_input "Lock/Unlock User" "Enter username:")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    local action=$(d --title "User Action" --menu "\nSelect action:" 12 60 2 \
        "lock" "Lock User Account" \
        "unlock" "Unlock User Account" \
        3>&1 1>&2 2>&3)
    [[ -z "$action" ]] && return
    
    if ask_yesno "$action user account: $username?"; then
        {
            if [[ "$action" == "lock" ]]; then
                sudo usermod -L "$username" 2>&1
                echo "User $username locked!"
                echo "Password status:"
                sudo passwd -S "$username"
            else
                sudo usermod -U "$username" 2>&1
                echo "User $username unlocked!"
                echo "Password status:"
                sudo passwd -S "$username"
            fi
        } > "$TMP_FILE" 2>&1
        show_text "User Lock/Unlock" "$TMP_FILE"
        log "$action user: $username"
    fi
}

user_modify() {
    local username=$(get_input "Modify User" "Enter username to modify:")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    local choice=$(d --title "Modify User" --menu "\nSelect what to modify:" 14 60 5 \
        "shell" "Change Shell" \
        "home" "Change Home Directory" \
        "uid" "Change UID" \
        "gid" "Change Primary Group" \
        "gecos" "Change Full Name" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        shell)
            local shell=$(d --title "Shell" --menu "\nSelect new shell:" 14 60 5 \
                "/bin/bash" "Bash Shell" \
                "/bin/zsh" "Zsh Shell" \
                "/bin/sh" "Sh Shell" \
                "/bin/false" "No Shell" \
                "/sbin/nologin" "No Login" \
                3>&1 1>&2 2>&3)
            [[ -z "$shell" ]] && return
            if ask_yesno "Change shell for $username to $shell?"; then
                sudo usermod -s "$shell" "$username" > "$TMP_FILE" 2>&1
                show_text "Modify Shell" "$TMP_FILE"
                log "Changed shell for $username to $shell"
            fi
            ;;
        home)
            local new_home=$(get_input "New Home" "Enter new home directory:" "/home/$username")
            [[ -z "$new_home" ]] && return
            if ask_yesno "Change home directory for $username to $new_home?"; then
                {
                    sudo usermod -m -d "$new_home" "$username" 2>&1
                    echo "Home directory changed to $new_home"
                    echo "New home: $(eval echo ~$username)"
                } > "$TMP_FILE" 2>&1
                show_text "Modify Home" "$TMP_FILE"
                log "Changed home for $username to $new_home"
            fi
            ;;
        uid)
            local new_uid=$(get_input "New UID" "Enter new UID (numeric):")
            [[ -z "$new_uid" ]] && return
            if ask_yesno "Change UID for $username to $new_uid?"; then
                sudo usermod -u "$new_uid" "$username" > "$TMP_FILE" 2>&1
                show_text "Modify UID" "$TMP_FILE"
                log "Changed UID for $username to $new_uid"
            fi
            ;;
        gid)
            local new_gid=$(get_input "New GID" "Enter new GID (numeric):")
            [[ -z "$new_gid" ]] && return
            if ask_yesno "Change primary group for $username to GID $new_gid?"; then
                sudo usermod -g "$new_gid" "$username" > "$TMP_FILE" 2>&1
                show_text "Modify GID" "$TMP_FILE"
                log "Changed primary group for $username to GID $new_gid"
            fi
            ;;
        gecos)
            local fullname=$(get_input "Full Name" "Enter full name:" "$username")
            [[ -z "$fullname" ]] && return
            if ask_yesno "Change full name for $username to '$fullname'?"; then
                sudo usermod -c "$fullname" "$username" > "$TMP_FILE" 2>&1
                show_text "Modify Full Name" "$TMP_FILE"
                log "Changed full name for $username to $fullname"
            fi
            ;;
    esac
}

user_list_groups() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    ALL GROUPS"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "SYSTEM GROUPS:"
        echo "────────────────────────────────────────────────────────────────────────"
        awk -F: '$3 < 1000 {print "   " $1 " (GID:" $3 ")"}' /etc/group
        echo ""
        echo "USER GROUPS (GID >= 1000):"
        echo "────────────────────────────────────────────────────────────────────────"
        awk -F: '$3 >= 1000 {print "   " $1 " (GID:" $3 ")"}' /etc/group
        echo ""
        echo "GROUP STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total groups: $(cat /etc/group | wc -l)"
        echo "   System groups: $(awk -F: '$3 < 1000 {print}' /etc/group | wc -l)"
        echo "   User groups: $(awk -F: '$3 >= 1000 {print}' /etc/group | wc -l)"
        echo ""
        echo "GROUPS WITH MEMBERS:"
        echo "────────────────────────────────────────────────────────────────────────"
        for group in $(awk -F: '$3 >= 1000 {print $1}' /etc/group); do
            local members=$(getent group "$group" | cut -d: -f4)
            if [[ -n "$members" ]]; then
                echo "   $group: $members"
            fi
        done
    } > "$TMP_FILE"
    show_text "All Groups" "$TMP_FILE"
    log "Listed all groups"
}

user_create_group() {
    local groupname=$(get_input "Create Group" "Enter group name:")
    [[ -z "$groupname" ]] && return
    
    if getent group "$groupname" &>/dev/null; then
        show_msg "Error" "Group $groupname already exists!"
        return
    fi
    
    local gid=$(get_input "Create Group" "Enter GID (optional, leave blank for auto):" "")
    
    if ask_yesno "Create group: $groupname${gid:+ (GID: $gid)}"; then
        {
            if [[ -n "$gid" ]]; then
                sudo groupadd -g "$gid" "$groupname" 2>&1
            else
                sudo groupadd "$groupname" 2>&1
            fi
            echo "Group $groupname created successfully!"
            getent group "$groupname"
        } > "$TMP_FILE" 2>&1
        show_text "Create Group" "$TMP_FILE"
        log "Created group: $groupname"
    fi
}

user_delete_group() {
    local groupname=$(get_input "Delete Group" "Enter group name to delete:")
    [[ -z "$groupname" ]] && return
    
    if ! getent group "$groupname" &>/dev/null; then
        show_msg "Error" "Group $groupname does not exist!"
        return
    fi
    
    if ask_yesno "DELETE group: $groupname?\n\nWARNING: This cannot be undone!"; then
        {
            sudo groupdel "$groupname" 2>&1
            echo "Group $groupname deleted successfully!"
        } > "$TMP_FILE" 2>&1
        show_text "Delete Group" "$TMP_FILE"
        log "Deleted group: $groupname"
    fi
}

user_add_to_group() {
    local username=$(get_input "Add User to Group" "Enter username:")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    local groupname=$(get_input "Add User to Group" "Enter group name:")
    [[ -z "$groupname" ]] && return
    
    if ! getent group "$groupname" &>/dev/null; then
        show_msg "Error" "Group $groupname does not exist!"
        return
    fi
    
    if ask_yesno "Add user $username to group $groupname?"; then
        {
            sudo usermod -aG "$groupname" "$username" 2>&1
            echo "User $username added to group $groupname!"
            echo ""
            echo "User groups:"
            groups "$username"
        } > "$TMP_FILE" 2>&1
        show_text "Add to Group" "$TMP_FILE"
        log "Added user $username to group $groupname"
    fi
}

user_remove_from_group() {
    local username=$(get_input "Remove User from Group" "Enter username:")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    local groupname=$(get_input "Remove User from Group" "Enter group name:")
    [[ -z "$groupname" ]] && return
    
    if ! getent group "$groupname" &>/dev/null; then
        show_msg "Error" "Group $groupname does not exist!"
        return
    fi
    
    if ! groups "$username" | grep -q "$groupname"; then
        show_msg "Error" "User $username is not in group $groupname!"
        return
    fi
    
    if ask_yesno "Remove user $username from group $groupname?"; then
        {
            sudo gpasswd -d "$username" "$groupname" 2>&1
            echo "User $username removed from group $groupname!"
            echo ""
            echo "User groups:"
            groups "$username"
        } > "$TMP_FILE" 2>&1
        show_text "Remove from Group" "$TMP_FILE"
        log "Removed user $username from group $groupname"
    fi
}

user_sudo_access() {
    local username=$(get_input "Sudo Access" "Enter username:")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    local action=$(d --title "Sudo Access" --menu "\nSelect action:" 12 60 2 \
        "add" "Add Sudo Access" \
        "remove" "Remove Sudo Access" \
        3>&1 1>&2 2>&3)
    [[ -z "$action" ]] && return
    
    if [[ "$action" == "add" ]]; then
        if ask_yesno "Add sudo access for user $username?"; then
            {
                echo "$username ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers > /dev/null
                echo "Sudo access added for $username!"
                echo ""
                echo "User sudo status:"
                sudo -l -U "$username" 2>&1
            } > "$TMP_FILE" 2>&1
            show_text "Sudo Access" "$TMP_FILE"
            log "Added sudo access for $username"
        fi
    else
        if ask_yesno "Remove sudo access for user $username?"; then
            {
                sudo sed -i "/^$username .*ALL$/d" /etc/sudoers 2>&1
                echo "Sudo access removed for $username!"
                echo ""
                echo "User sudo status:"
                sudo -l -U "$username" 2>&1
            } > "$TMP_FILE" 2>&1
            show_text "Sudo Access" "$TMP_FILE"
            log "Removed sudo access for $username"
        fi
    fi
}

user_set_quota() {
    if ! command -v quota &>/dev/null; then
        show_msg "Error" "quota not installed.\n\nInstall: sudo apt install quota"
        return
    fi
    
    local username=$(get_input "Set Quota" "Enter username:")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    local soft_limit=$(get_input "Set Quota" "Enter soft limit (MB):" "100")
    [[ -z "$soft_limit" ]] && return
    
    local hard_limit=$(get_input "Set Quota" "Enter hard limit (MB):" "200")
    [[ -z "$hard_limit" ]] && return
    
    if ask_yesno "Set quota for $username:\nSoft: ${soft_limit}MB\nHard: ${hard_limit}MB"; then
        {
            sudo setquota -u "$username" "$soft_limit" "$hard_limit" 0 0 / 2>&1
            echo "Quota set successfully!"
            echo ""
            echo "Current quota:"
            sudo quota -u "$username"
        } > "$TMP_FILE" 2>&1
        show_text "Set Quota" "$TMP_FILE"
        log "Set quota for $username: $soft_limit/$hard_limit MB"
    fi
}

user_ssh_keys() {
    local username=$(get_input "SSH Keys" "Enter username:")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    local home_dir=$(eval echo ~$username)
    local ssh_dir="$home_dir/.ssh"
    local auth_file="$ssh_dir/authorized_keys"
    
    local choice=$(d --title "SSH Keys" --menu "\nSelect operation:" 14 60 4 \
        "list" "List SSH Keys" \
        "add" "Add SSH Key" \
        "remove" "Remove SSH Key" \
        "generate" "Generate SSH Key Pair" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        list)
            {
                echo "SSH KEYS for $username:"
                echo "────────────────────────────────────────────────────────────────────────"
                if [[ -f "$auth_file" ]]; then
                    echo "Authorized keys (${auth_file}):"
                    cat "$auth_file" 2>/dev/null
                    echo ""
                    echo "Total keys: $(cat "$auth_file" 2>/dev/null | wc -l)"
                else
                    echo "No authorized keys found for $username"
                fi
                echo ""
                echo "SSH directory:"
                ls -la "$ssh_dir" 2>/dev/null
            } > "$TMP_FILE"
            show_text "SSH Keys" "$TMP_FILE"
            log "Listed SSH keys for $username"
            ;;
        add)
            local pub_key=$(get_input "Add SSH Key" "Enter public key (paste entire key):" "")
            [[ -z "$pub_key" ]] && return
            
            {
                sudo mkdir -p "$ssh_dir" 2>&1
                sudo chown "$username:$username" "$ssh_dir" 2>&1
                sudo chmod 700 "$ssh_dir" 2>&1
                echo "$pub_key" | sudo tee -a "$auth_file" > /dev/null
                sudo chown "$username:$username" "$auth_file" 2>&1
                sudo chmod 600 "$auth_file" 2>&1
                echo "SSH key added successfully!"
                echo ""
                echo "Authorized keys:"
                cat "$auth_file"
            } > "$TMP_FILE" 2>&1
            show_text "Add SSH Key" "$TMP_FILE"
            log "Added SSH key for $username"
            ;;
        remove)
            local key_line=$(get_input "Remove SSH Key" "Enter line number or key comment to remove:")
            [[ -z "$key_line" ]] && return
            
            if [[ -f "$auth_file" ]]; then
                {
                    if [[ "$key_line" =~ ^[0-9]+$ ]]; then
                        sudo sed -i "${key_line}d" "$auth_file" 2>&1
                    else
                        sudo sed -i "/$key_line/d" "$auth_file" 2>&1
                    fi
                    echo "SSH key removed successfully!"
                    echo ""
                    echo "Remaining keys:"
                    cat "$auth_file"
                } > "$TMP_FILE" 2>&1
                show_text "Remove SSH Key" "$TMP_FILE"
                log "Removed SSH key for $username"
            else
                show_msg "Error" "No authorized_keys file found!"
            fi
            ;;
        generate)
            local key_type=$(d --title "Key Type" --menu "\nSelect key type:" 12 60 3 \
                "rsa" "RSA 4096" \
                "ed25519" "Ed25519" \
                "ecdsa" "ECDSA" \
                3>&1 1>&2 2>&3)
            [[ -z "$key_type" ]] && return
            
            {
                if [[ "$key_type" == "rsa" ]]; then
                    sudo -u "$username" ssh-keygen -t rsa -b 4096 -f "$ssh_dir/id_rsa" -N "" 2>&1
                    echo "RSA key generated: $ssh_dir/id_rsa"
                elif [[ "$key_type" == "ed25519" ]]; then
                    sudo -u "$username" ssh-keygen -t ed25519 -f "$ssh_dir/id_ed25519" -N "" 2>&1
                    echo "Ed25519 key generated: $ssh_dir/id_ed25519"
                else
                    sudo -u "$username" ssh-keygen -t ecdsa -f "$ssh_dir/id_ecdsa" -N "" 2>&1
                    echo "ECDSA key generated: $ssh_dir/id_ecdsa"
                fi
                echo ""
                echo "Public key:"
                cat "$ssh_dir/id_*.pub" 2>/dev/null
                echo ""
                echo "Keys generated successfully!"
            } > "$TMP_FILE" 2>&1
            show_text "Generate SSH Keys" "$TMP_FILE"
            log "Generated SSH keys for $username"
            ;;
    esac
}

user_view_details() {
    local username=$(get_input "User Details" "Enter username:" "$(whoami)")
    [[ -z "$username" ]] && return
    
    if ! id "$username" &>/dev/null; then
        show_msg "Error" "User $username does not exist!"
        return
    fi
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                    USER DETAILS - $username"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "BASIC INFO:"
        echo "────────────────────────────────────────────────────────────────────────"
        id "$username"
        echo ""
        echo "USER ENTRY:"
        echo "────────────────────────────────────────────────────────────────────────"
        grep "^$username:" /etc/passwd
        echo ""
        echo "PASSWORD INFO:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo passwd -S "$username"
        echo ""
        echo "GROUPS:"
        echo "────────────────────────────────────────────────────────────────────────"
        groups "$username"
        echo ""
        echo "HOME DIRECTORY:"
        echo "────────────────────────────────────────────────────────────────────────"
        local home_dir=$(eval echo ~$username)
        echo "   $home_dir"
        echo "   Size: $(du -sh "$home_dir" 2>/dev/null | cut -f1)"
        echo "   Files: $(find "$home_dir" -type f 2>/dev/null | wc -l)"
        echo ""
        echo "MAIL SPOOL:"
        echo "────────────────────────────────────────────────────────────────────────"
        ls -la /var/spool/mail/$username 2>/dev/null
        echo ""
        echo "LAST LOGIN:"
        echo "────────────────────────────────────────────────────────────────────────"
        last "$username" | head -5
        echo ""
        echo "PROCESSES:"
        echo "────────────────────────────────────────────────────────────────────────"
        ps -u "$username" --no-headers 2>/dev/null | wc -l
        echo ""
        echo "USER CRON JOBS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo crontab -u "$username" -l 2>/dev/null || echo "No cron jobs for $username"
        echo ""
        echo "SUDO ACCESS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo -l -U "$username" 2>&1
        echo ""
        echo "OPEN FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lsof -u "$username" 2>/dev/null | wc -l
    } > "$TMP_FILE"
    show_text "User Details" "$TMP_FILE"
    log "Viewed details for user $username"
}