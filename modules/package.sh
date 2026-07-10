#!/usr/bin/env bash

package_menu() {
    while true; do
        local choice=$(d --clear --title "Package Management" \
            --menu "\nSelect package operation:" $HEIGHT $WIDTH $MENU_HEIGHT \
            1 "Package Manager Info" \
            2 "List Installed Packages" \
            3 "Search Package" \
            4 "Install Package" \
            5 "Remove Package" \
            6 "Purge Package" \
            7 "Update Package List" \
            8 "Upgrade System" \
            9 "Dist-Upgrade" \
            10 "Package Information" \
            11 "List Dependencies" \
            12 "Check Broken Packages" \
            13 "Fix Broken Packages" \
            14 "Add Repository" \
            15 "Remove Repository" \
            16 "List Repositories" \
            0 "Main Menu" \
            3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$choice" == "0" ]] && break
        
        case "$choice" in
            1) package_manager_info ;;
            2) package_list_installed ;;
            3) package_search ;;
            4) package_install ;;
            5) package_remove ;;
            6) package_purge ;;
            7) package_update ;;
            8) package_upgrade ;;
            9) package_dist_upgrade ;;
            10) package_info ;;
            11) package_dependencies ;;
            12) package_check_broken ;;
            13) package_fix_broken ;;
            14) package_add_repo ;;
            15) package_remove_repo ;;
            16) package_list_repos ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

package_detect_manager() {
    if command -v apt &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v emerge &>/dev/null; then
        echo "emerge"
    else
        echo "unknown"
    fi
}

package_manager_info() {
    local pkg_mgr=$(package_detect_manager)
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              PACKAGE MANAGER INFORMATION"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "DETECTED MANAGER: $pkg_mgr"
        echo "────────────────────────────────────────────────────────────────────────"
        
        case "$pkg_mgr" in
            apt)
                echo "APT Version: $(apt --version 2>/dev/null | head -1)"
                echo "Package count: $(dpkg -l 2>/dev/null | grep -c '^ii')"
                echo "Cache size: $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)"
                echo "Source list: /etc/apt/sources.list"
                echo "Sources dir: /etc/apt/sources.list.d/"
                echo ""
                echo "APT Configuration:"
                apt-config dump 2>/dev/null | head -20
                ;;
            dnf)
                echo "DNF Version: $(dnf --version 2>/dev/null | head -1)"
                echo "Package count: $(dnf list installed 2>/dev/null | wc -l)"
                echo "Cache size: $(du -sh /var/cache/dnf 2>/dev/null | cut -f1)"
                echo "Repo dir: /etc/yum.repos.d/"
                echo ""
                echo "DNF Configuration:"
                dnf config-manager --dump 2>/dev/null | head -20
                ;;
            yum)
                echo "YUM Version: $(yum --version 2>/dev/null | head -1)"
                echo "Package count: $(yum list installed 2>/dev/null | wc -l)"
                echo "Cache size: $(du -sh /var/cache/yum 2>/dev/null | cut -f1)"
                echo "Repo dir: /etc/yum.repos.d/"
                ;;
            pacman)
                echo "Pacman Version: $(pacman -V 2>/dev/null | head -1)"
                echo "Package count: $(pacman -Q 2>/dev/null | wc -l)"
                echo "Cache size: $(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"
                echo "Config file: /etc/pacman.conf"
                echo ""
                echo "Pacman Configuration:"
                cat /etc/pacman.conf 2>/dev/null | grep -v "^#" | grep -v "^$" | head -20
                ;;
            zypper)
                echo "Zypper Version: $(zypper --version 2>/dev/null | head -1)"
                echo "Package count: $(zypper se --installed-only 2>/dev/null | wc -l)"
                echo "Repo dir: /etc/zypp/repos.d/"
                ;;
            apk)
                echo "APK Version: $(apk --version 2>/dev/null | head -1)"
                echo "Package count: $(apk list --installed 2>/dev/null | wc -l)"
                echo "Repository: /etc/apk/repositories"
                ;;
            emerge)
                echo "Portage Version: $(emerge --version 2>/dev/null | head -1)"
                echo "Package count: $(equery list '*' 2>/dev/null | wc -l)"
                echo "Portage dir: /usr/portage"
                ;;
            *)
                echo "Unknown package manager or not installed!"
                ;;
        esac
        
        echo ""
        echo "SYSTEM INFORMATION:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Distribution: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
        echo "   Architecture: $(uname -m)"
        echo "   Kernel: $(uname -r)"
    } > "$TMP_FILE"
    show_text "Package Manager Info" "$TMP_FILE"
    log "Viewed package manager information"
}

package_list_installed() {
    local pkg_mgr=$(package_detect_manager)
    
    local choice=$(d --title "List Packages" --menu "\nSelect output format:" 12 60 3 \
        "all" "All Packages" \
        "recent" "Recently Installed" \
        "size" "By Size (largest)" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              INSTALLED PACKAGES"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        case "$pkg_mgr" in
            apt)
                case "$choice" in
                    all)
                        dpkg -l 2>/dev/null | grep '^ii'
                        ;;
                    recent)
                        grep " install " /var/log/dpkg.log 2>/dev/null | tail -30
                        ;;
                    size)
                        dpkg-query -W --showformat='${Installed-Size} ${Package}\n' 2>/dev/null | sort -rn | head -50
                        ;;
                esac
                ;;
            dnf|yum)
                case "$choice" in
                    all)
                        "$pkg_mgr" list installed 2>/dev/null
                        ;;
                    recent)
                        "$pkg_mgr" history 2>/dev/null | head -30
                        ;;
                    size)
                        "$pkg_mgr" list installed 2>/dev/null | head -50
                        ;;
                esac
                ;;
            pacman)
                case "$choice" in
                    all)
                        pacman -Q 2>/dev/null
                        ;;
                    recent)
                        pacman -Q --date=week 2>/dev/null | head -30
                        ;;
                    size)
                        pacman -Qi 2>/dev/null | grep -E "Name|Installed Size" | paste -d' ' - - | sort -rnk6 | head -50
                        ;;
                esac
                ;;
            zypper)
                case "$choice" in
                    all)
                        zypper se --installed-only 2>/dev/null
                        ;;
                    recent)
                        zypper ps 2>/dev/null | head -30
                        ;;
                    size)
                        zypper se --installed-only 2>/dev/null | head -50
                        ;;
                esac
                ;;
            *)
                echo "Package listing not supported for this package manager"
                ;;
        esac
        
        echo ""
        echo "PACKAGE STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total installed: $(package_count_installed)"
    } > "$TMP_FILE"
    show_text "Installed Packages" "$TMP_FILE"
    log "Listed installed packages"
}

package_count_installed() {
    local pkg_mgr=$(package_detect_manager)
    
    case "$pkg_mgr" in
        apt)
            dpkg -l 2>/dev/null | grep -c '^ii'
            ;;
        dnf|yum)
            "$pkg_mgr" list installed 2>/dev/null | wc -l
            ;;
        pacman)
            pacman -Q 2>/dev/null | wc -l
            ;;
        zypper)
            zypper se --installed-only 2>/dev/null | wc -l
            ;;
        apk)
            apk list --installed 2>/dev/null | wc -l
            ;;
        *)
            echo "0"
            ;;
    esac
}

package_search() {
    local pkg_mgr=$(package_detect_manager)
    local search_term=$(get_input "Search Package" "Enter package name or keyword:" "")
    [[ -z "$search_term" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              SEARCH RESULTS - $search_term"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        case "$pkg_mgr" in
            apt)
                apt-cache search "$search_term" 2>/dev/null
                echo ""
                echo "SEARCH STATISTICS:"
                echo "────────────────────────────────────────────────────────────────────────"
                echo "   Results: $(apt-cache search "$search_term" 2>/dev/null | wc -l)"
                ;;
            dnf)
                dnf search "$search_term" 2>/dev/null
                echo ""
                echo "SEARCH STATISTICS:"
                echo "────────────────────────────────────────────────────────────────────────"
                echo "   Results: $(dnf search "$search_term" 2>/dev/null | wc -l)"
                ;;
            yum)
                yum search "$search_term" 2>/dev/null
                echo ""
                echo "SEARCH STATISTICS:"
                echo "────────────────────────────────────────────────────────────────────────"
                echo "   Results: $(yum search "$search_term" 2>/dev/null | wc -l)"
                ;;
            pacman)
                pacman -Ss "$search_term" 2>/dev/null
                echo ""
                echo "SEARCH STATISTICS:"
                echo "────────────────────────────────────────────────────────────────────────"
                echo "   Results: $(pacman -Ss "$search_term" 2>/dev/null | wc -l)"
                ;;
            zypper)
                zypper search "$search_term" 2>/dev/null
                echo ""
                echo "SEARCH STATISTICS:"
                echo "────────────────────────────────────────────────────────────────────────"
                echo "   Results: $(zypper search "$search_term" 2>/dev/null | wc -l)"
                ;;
            apk)
                apk search "$search_term" 2>/dev/null
                ;;
            *)
                echo "Search not supported for this package manager"
                ;;
        esac
    } > "$TMP_FILE"
    show_text "Package Search" "$TMP_FILE"
    log "Searched for package: $search_term"
}

package_install() {
    local pkg_mgr=$(package_detect_manager)
    local package=$(get_input "Install Package" "Enter package name(s) (space separated):" "")
    [[ -z "$package" ]] && return
    
    local options=$(d --title "Install Options" --menu "\nSelect options:" 12 60 3 \
        "normal" "Normal Install" \
        "no-recommends" "Skip Recommended" \
        "dry-run" "Dry Run (preview)" \
        3>&1 1>&2 2>&3)
    [[ -z "$options" ]] && return
    
    if ask_yesno "Install package(s): $package\nOptions: $options"; then
        {
            echo "Installing $package..."
            echo ""
            
            case "$pkg_mgr" in
                apt)
                    if [[ "$options" == "no-recommends" ]]; then
                        sudo apt install --no-install-recommends -y $package 2>&1
                    elif [[ "$options" == "dry-run" ]]; then
                        sudo apt install --dry-run $package 2>&1
                    else
                        sudo apt install -y $package 2>&1
                    fi
                    ;;
                dnf)
                    if [[ "$options" == "dry-run" ]]; then
                        sudo dnf install --assumeno $package 2>&1
                    else
                        sudo dnf install -y $package 2>&1
                    fi
                    ;;
                yum)
                    if [[ "$options" == "dry-run" ]]; then
                        sudo yum install --assumeno $package 2>&1
                    else
                        sudo yum install -y $package 2>&1
                    fi
                    ;;
                pacman)
                    if [[ "$options" == "no-recommends" ]]; then
                        sudo pacman -S --noconfirm --needed $package 2>&1
                    elif [[ "$options" == "dry-run" ]]; then
                        sudo pacman -S --print $package 2>&1
                    else
                        sudo pacman -S --noconfirm $package 2>&1
                    fi
                    ;;
                zypper)
                    if [[ "$options" == "dry-run" ]]; then
                        sudo zypper --dry-run install $package 2>&1
                    else
                        sudo zypper install -y $package 2>&1
                    fi
                    ;;
                apk)
                    sudo apk add $package 2>&1
                    ;;
                *)
                    echo "Install not supported for this package manager"
                    ;;
            esac
            
            echo ""
            echo "Installation completed!"
            echo ""
            echo "Verification:"
            if [[ "$options" != "dry-run" ]]; then
                package_verify_installed "$package"
            fi
        } > "$TMP_FILE" 2>&1
        show_text "Install Package" "$TMP_FILE"
        log "Installed package: $package"
    fi
}

package_verify_installed() {
    local packages=$1
    local pkg_mgr=$(package_detect_manager)
    
    for pkg in $packages; do
        case "$pkg_mgr" in
            apt)
                dpkg -l | grep -q "^ii.*$pkg"
                ;;
            dnf|yum)
                "$pkg_mgr" list installed | grep -q "^$pkg"
                ;;
            pacman)
                pacman -Q | grep -q "^$pkg"
                ;;
            zypper)
                zypper se --installed-only | grep -q "^$pkg"
                ;;
            *)
                return 1
                ;;
        esac
        
        if [[ $? -eq 0 ]]; then
            echo "   ✓ $pkg installed"
        else
            echo "   ✗ $pkg NOT installed"
        fi
    done
}

package_remove() {
    local pkg_mgr=$(package_detect_manager)
    local package=$(get_input "Remove Package" "Enter package name(s) to remove:" "")
    [[ -z "$package" ]] && return
    
    if ask_yesno "Remove package(s): $package?"; then
        {
            echo "Removing $package..."
            echo ""
            
            case "$pkg_mgr" in
                apt)
                    sudo apt remove -y $package 2>&1
                    ;;
                dnf)
                    sudo dnf remove -y $package 2>&1
                    ;;
                yum)
                    sudo yum remove -y $package 2>&1
                    ;;
                pacman)
                    sudo pacman -R --noconfirm $package 2>&1
                    ;;
                zypper)
                    sudo zypper remove -y $package 2>&1
                    ;;
                apk)
                    sudo apk del $package 2>&1
                    ;;
                *)
                    echo "Remove not supported for this package manager"
                    ;;
            esac
            
            echo ""
            echo "Removal completed!"
        } > "$TMP_FILE" 2>&1
        show_text "Remove Package" "$TMP_FILE"
        log "Removed package: $package"
    fi
}

package_purge() {
    local pkg_mgr=$(package_detect_manager)
    local package=$(get_input "Purge Package" "Enter package name(s) to purge:" "")
    [[ -z "$package" ]] && return
    
    if ask_yesno "PURGE package(s): $package?\n\nWARNING: Configuration files will be removed!"; then
        {
            echo "Purging $package..."
            echo ""
            
            case "$pkg_mgr" in
                apt)
                    sudo apt purge -y $package 2>&1
                    sudo apt autoremove -y 2>&1
                    ;;
                dnf)
                    sudo dnf remove -y $package 2>&1
                    sudo dnf autoremove -y 2>&1
                    ;;
                pacman)
                    sudo pacman -Rns --noconfirm $package 2>&1
                    ;;
                zypper)
                    sudo zypper remove -y --clean-deps $package 2>&1
                    ;;
                *)
                    echo "Purge not supported for this package manager"
                    ;;
            esac
            
            echo ""
            echo "Purge completed!"
        } > "$TMP_FILE" 2>&1
        show_text "Purge Package" "$TMP_FILE"
        log "Purged package: $package"
    fi
}

package_update() {
    local pkg_mgr=$(package_detect_manager)
    
    if ask_yesno "Update package lists?"; then
        {
            echo "Updating package lists..."
            echo ""
            
            case "$pkg_mgr" in
                apt)
                    sudo apt update 2>&1
                    ;;
                dnf|yum)
                    sudo "$pkg_mgr" check-update 2>&1
                    ;;
                pacman)
                    sudo pacman -Sy 2>&1
                    ;;
                zypper)
                    sudo zypper refresh 2>&1
                    ;;
                apk)
                    sudo apk update 2>&1
                    ;;
                *)
                    echo "Update not supported for this package manager"
                    ;;
            esac
            
            echo ""
            echo "Update completed!"
        } > "$TMP_FILE" 2>&1
        show_text "Update Package Lists" "$TMP_FILE"
        log "Updated package lists"
    fi
}

package_upgrade() {
    local pkg_mgr=$(package_detect_manager)
    
    local choice=$(d --title "Upgrade Options" --menu "\nSelect upgrade type:" 12 60 3 \
        "normal" "Normal Upgrade" \
        "security" "Security Only" \
        "dry-run" "Dry Run (preview)" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    if ask_yesno "Upgrade system packages? (This may take a while)"; then
        {
            echo "Upgrading system..."
            echo ""
            
            case "$pkg_mgr" in
                apt)
                    if [[ "$choice" == "security" ]]; then
                        sudo apt upgrade -y --only-upgrade 2>&1
                    elif [[ "$choice" == "dry-run" ]]; then
                        sudo apt upgrade --dry-run 2>&1
                    else
                        sudo apt upgrade -y 2>&1
                    fi
                    ;;
                dnf)
                    if [[ "$choice" == "security" ]]; then
                        sudo dnf upgrade --security -y 2>&1
                    elif [[ "$choice" == "dry-run" ]]; then
                        sudo dnf upgrade --assumeno 2>&1
                    else
                        sudo dnf upgrade -y 2>&1
                    fi
                    ;;
                yum)
                    if [[ "$choice" == "security" ]]; then
                        sudo yum upgrade --security -y 2>&1
                    else
                        sudo yum upgrade -y 2>&1
                    fi
                    ;;
                pacman)
                    if [[ "$choice" == "dry-run" ]]; then
                        sudo pacman -Su --print 2>&1
                    else
                        sudo pacman -Su --noconfirm 2>&1
                    fi
                    ;;
                zypper)
                    if [[ "$choice" == "security" ]]; then
                        sudo zypper patch --security 2>&1
                    else
                        sudo zypper update -y 2>&1
                    fi
                    ;;
                apk)
                    sudo apk upgrade 2>&1
                    ;;
                *)
                    echo "Upgrade not supported for this package manager"
                    ;;
            esac
            
            echo ""
            echo "Upgrade completed!"
        } > "$TMP_FILE" 2>&1
        show_text "System Upgrade" "$TMP_FILE"
        log "Performed system upgrade"
    fi
}

package_dist_upgrade() {
    local pkg_mgr=$(package_detect_manager)
    
    if [[ "$pkg_mgr" != "apt" ]]; then
        show_msg "Info" "Distribution upgrade is only supported for APT (Debian/Ubuntu)"
        return
    fi
    
    if ask_yesno "Perform distribution upgrade?\n\nWARNING: This will upgrade to a new distribution version!"; then
        {
            echo "Performing distribution upgrade..."
            echo ""
            sudo apt update 2>&1
            sudo apt dist-upgrade -y 2>&1
            sudo apt autoremove -y 2>&1
            sudo apt autoclean -y 2>&1
            echo ""
            echo "Distribution upgrade completed!"
        } > "$TMP_FILE" 2>&1
        show_text "Distribution Upgrade" "$TMP_FILE"
        log "Performed distribution upgrade"
    fi
}

package_info() {
    local pkg_mgr=$(package_detect_manager)
    local package=$(get_input "Package Information" "Enter package name:" "")
    [[ -z "$package" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              PACKAGE INFORMATION - $package"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        case "$pkg_mgr" in
            apt)
                apt-cache show "$package" 2>/dev/null
                echo ""
                echo "INSTALLED VERSION:"
                dpkg -l | grep "$package" 2>/dev/null
                echo ""
                echo "DEPENDENCIES:"
                apt-cache depends "$package" 2>/dev/null
                echo ""
                echo "REVERSE DEPENDENCIES:"
                apt-cache rdepends "$package" 2>/dev/null
                ;;
            dnf)
                dnf info "$package" 2>/dev/null
                echo ""
                echo "DEPENDENCIES:"
                dnf deplist "$package" 2>/dev/null
                ;;
            pacman)
                pacman -Qi "$package" 2>/dev/null
                echo ""
                echo "FILES:"
                pacman -Ql "$package" 2>/dev/null
                ;;
            zypper)
                zypper info "$package" 2>/dev/null
                ;;
            *)
                echo "Package info not supported for this package manager"
                ;;
        esac
    } > "$TMP_FILE"
    show_text "Package Information" "$TMP_FILE"
    log "Viewed info for package: $package"
}

package_dependencies() {
    local pkg_mgr=$(package_detect_manager)
    local package=$(get_input "Package Dependencies" "Enter package name:" "")
    [[ -z "$package" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              DEPENDENCIES - $package"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        case "$pkg_mgr" in
            apt)
                echo "DEPENDS:"
                apt-cache depends "$package" 2>/dev/null
                echo ""
                echo "REVERSE DEPENDS:"
                apt-cache rdepends "$package" 2>/dev/null
                ;;
            dnf)
                echo "DEPENDENCIES:"
                dnf deplist "$package" 2>/dev/null
                ;;
            pacman)
                echo "DEPENDS:"
                pacman -Qi "$package" 2>/dev/null | grep -A 10 "Depends"
                echo ""
                echo "REQUIRED BY:"
                pacman -Qi "$package" 2>/dev/null | grep -A 10 "Required By"
                ;;
            zypper)
                zypper info "$package" 2>/dev/null | grep -A 10 "Requires"
                ;;
            *)
                echo "Dependencies not supported for this package manager"
                ;;
        esac
    } > "$TMP_FILE"
    show_text "Package Dependencies" "$TMP_FILE"
    log "Viewed dependencies for package: $package"
}

package_check_broken() {
    local pkg_mgr=$(package_detect_manager)
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              CHECKING BROKEN PACKAGES"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        case "$pkg_mgr" in
            apt)
                echo "Checking broken packages..."
                sudo apt --fix-broken --dry-run 2>&1
                echo ""
                echo "Broken packages:"
                dpkg -l | grep '^rc' 2>/dev/null
                echo ""
                echo "Unconfigured packages:"
                dpkg -l | grep '^iU' 2>/dev/null
                ;;
            dnf)
                echo "Checking broken dependencies..."
                sudo dnf check 2>&1
                ;;
            pacman)
                echo "Checking for broken packages..."
                pacman -Dk 2>&1
                ;;
            zypper)
                echo "Checking for broken packages..."
                zypper verify 2>&1
                ;;
            *)
                echo "Broken packages check not supported for this package manager"
                ;;
        esac
    } > "$TMP_FILE"
    show_text "Broken Packages" "$TMP_FILE"
    log "Checked for broken packages"
}

package_fix_broken() {
    local pkg_mgr=$(package_detect_manager)
    
    if ask_yesno "Fix broken packages?"; then
        {
            echo "Fixing broken packages..."
            echo ""
            
            case "$pkg_mgr" in
                apt)
                    sudo apt --fix-broken install -y 2>&1
                    ;;
                dnf)
                    sudo dnf check 2>&1
                    sudo dnf distro-sync -y 2>&1
                    ;;
                pacman)
                    sudo pacman -Syu --noconfirm 2>&1
                    sudo pacman -Dk 2>&1
                    ;;
                zypper)
                    sudo zypper verify 2>&1
                    ;;
                *)
                    echo "Fix not supported for this package manager"
                    ;;
            esac
            
            echo ""
            echo "Fix completed!"
        } > "$TMP_FILE" 2>&1
        show_text "Fix Broken Packages" "$TMP_FILE"
        log "Fixed broken packages"
    fi
}

package_add_repo() {
    local pkg_mgr=$(package_detect_manager)
    
    case "$pkg_mgr" in
        apt)
            local repo_line=$(get_input "Add Repository" "Enter repository line (e.g., deb http://archive.ubuntu.com/ubuntu focal main):" "")
            [[ -z "$repo_line" ]] && return
            
            if ask_yesno "Add repository: $repo_line"; then
                {
                    echo "$repo_line" | sudo tee -a /etc/apt/sources.list 2>&1
                    sudo apt update 2>&1
                    echo ""
                    echo "Repository added successfully!"
                } > "$TMP_FILE" 2>&1
                show_text "Add Repository" "$TMP_FILE"
                log "Added repository: $repo_line"
            fi
            ;;
        dnf|yum)
            local repo_name=$(get_input "Add Repository" "Enter repository name:" "")
            [[ -z "$repo_name" ]] && return
            local repo_url=$(get_input "Add Repository" "Enter repository URL:" "")
            [[ -z "$repo_url" ]] && return
            
            if ask_yesno "Add repository: $repo_name - $repo_url"; then
                {
                    sudo "$pkg_mgr"-config-manager --add-repo "$repo_url" 2>&1
                    echo ""
                    echo "Repository added successfully!"
                } > "$TMP_FILE" 2>&1
                show_text "Add Repository" "$TMP_FILE"
                log "Added repository: $repo_name"
            fi
            ;;
        pacman)
            local repo_line=$(get_input "Add Repository" "Enter repository line for pacman.conf:" "")
            [[ -z "$repo_line" ]] && return
            
            if ask_yesno "Add repository: $repo_line"; then
                {
                    echo "$repo_line" | sudo tee -a /etc/pacman.conf 2>&1
                    sudo pacman -Sy 2>&1
                    echo ""
                    echo "Repository added successfully!"
                } > "$TMP_FILE" 2>&1
                show_text "Add Repository" "$TMP_FILE"
                log "Added repository: $repo_line"
            fi
            ;;
        *)
            show_msg "Error" "Adding repositories not supported for this package manager"
            ;;
    esac
}

package_remove_repo() {
    local pkg_mgr=$(package_detect_manager)
    
    case "$pkg_mgr" in
        apt)
            local repo_line=$(get_input "Remove Repository" "Enter repository line to remove (exact match):" "")
            [[ -z "$repo_line" ]] && return
            
            if ask_yesno "Remove repository: $repo_line"; then
                {
                    sudo sed -i "/$repo_line/d" /etc/apt/sources.list 2>&1
                    sudo apt update 2>&1
                    echo ""
                    echo "Repository removed successfully!"
                } > "$TMP_FILE" 2>&1
                show_text "Remove Repository" "$TMP_FILE"
                log "Removed repository: $repo_line"
            fi
            ;;
        dnf|yum)
            local repo_name=$(get_input "Remove Repository" "Enter repository name:" "")
            [[ -z "$repo_name" ]] && return
            
            if ask_yesno "Remove repository: $repo_name"; then
                {
                    sudo "$pkg_mgr"-config-manager --remove "$repo_name" 2>&1
                    echo ""
                    echo "Repository removed successfully!"
                } > "$TMP_FILE" 2>&1
                show_text "Remove Repository" "$TMP_FILE"
                log "Removed repository: $repo_name"
            fi
            ;;
        *)
            show_msg "Error" "Removing repositories not supported for this package manager"
            ;;
    esac
}

package_list_repos() {
    local pkg_mgr=$(package_detect_manager)
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              REPOSITORY LIST"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        
        case "$pkg_mgr" in
            apt)
                echo "APT SOURCES:"
                echo "────────────────────────────────────────────────────────────────────────"
                cat /etc/apt/sources.list 2>/dev/null | grep -v "^#" | grep -v "^$"
                echo ""
                echo "SOURCES LIST D:"
                echo "────────────────────────────────────────────────────────────────────────"
                for file in /etc/apt/sources.list.d/*.list; do
                    if [[ -f "$file" ]]; then
                        echo "=== $file ==="
                        cat "$file" 2>/dev/null | grep -v "^#" | grep -v "^$"
                        echo ""
                    fi
                done
                ;;
            dnf|yum)
                echo "REPOSITORIES:"
                echo "────────────────────────────────────────────────────────────────────────"
                "$pkg_mgr" repolist all 2>/dev/null
                echo ""
                echo "REPO FILES:"
                echo "────────────────────────────────────────────────────────────────────────"
                for file in /etc/yum.repos.d/*.repo; do
                    if [[ -f "$file" ]]; then
                        echo "=== $file ==="
                        cat "$file" 2>/dev/null | grep -v "^#" | grep -v "^$" | head -10
                        echo ""
                    fi
                done
                ;;
            pacman)
                echo "PACMAN REPOSITORIES:"
                echo "────────────────────────────────────────────────────────────────────────"
                cat /etc/pacman.conf 2>/dev/null | grep -v "^#" | grep -v "^$"
                ;;
            zypper)
                echo "ZYPPER REPOSITORIES:"
                echo "────────────────────────────────────────────────────────────────────────"
                zypper repos 2>/dev/null
                ;;
            *)
                echo "Repository listing not supported for this package manager"
                ;;
        esac
    } > "$TMP_FILE"
    show_text "Repositories" "$TMP_FILE"
    log "Listed repositories"
}