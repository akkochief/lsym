#!/usr/bin/env bash

disk_menu() {
    while true; do
        local choice=$(d --clear --title "Disk Management (diskpart+++)" \
            --menu "\nSelect disk operation:" $HEIGHT $WIDTH $MENU_HEIGHT \
            1 "List All Disks & Partitions" \
            2 "Create Partition" \
            3 "Delete Partition" \
            4 "Format Partition" \
            5 "Mount/Unmount Partition" \
            6 "Disk Clone (dd)" \
            7 "Create Disk Image" \
            8 "Restore Disk Image" \
            9 "SMART Health Check" \
            10 "Disk Performance Benchmark" \
            11 "LVM Management" \
            12 "RAID Management" \
            13 "Disk Encryption (LUKS)" \
            14 "Secure Erase Disk" \
            15 "Disk Usage Analysis" \
            16 "Find Large Files" \
            0 "Main Menu" \
            3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 || "$choice" == "0" ]] && break
        
        case "$choice" in
            1) disk_list_all ;;
            2) disk_create_partition ;;
            3) disk_delete_partition ;;
            4) disk_format_partition ;;
            5) disk_mount_unmount ;;
            6) disk_clone ;;
            7) disk_create_image ;;
            8) disk_restore_image ;;
            9) disk_smart_check ;;
            10) disk_benchmark ;;
            11) disk_lvm_manage ;;
            12) disk_raid_manage ;;
            13) disk_encryption ;;
            14) disk_secure_erase ;;
            15) disk_usage_analysis ;;
            16) disk_find_large_files ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

disk_list_all() {
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "                  COMPLETE DISK & PARTITION LIST"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "PHYSICAL DISKS:"
        echo "────────────────────────────────────────────────────────────────────────"
        lsblk -d -o NAME,SIZE,TYPE,MODEL,SERIAL,REV,ROTA,STATE 2>/dev/null
        echo ""
        echo "ALL BLOCK DEVICES:"
        echo "────────────────────────────────────────────────────────────────────────"
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL,PARTLABEL,PARTTYPE 2>/dev/null
        echo ""
        echo "PARTITION TABLES (fdisk):"
        echo "────────────────────────────────────────────────────────────────────────"
        if check_root; then
            sudo fdisk -l 2>/dev/null | head -100
        else
            sudo fdisk -l 2>/dev/null | head -100
        fi
        echo ""
        echo "DISK PARTITION TYPES:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   MBR (msdos): $(sudo fdisk -l 2>/dev/null | grep -c "Disklabel type: dos" || echo 0)"
        echo "   GPT: $(sudo fdisk -l 2>/dev/null | grep -c "Disklabel type: gpt" || echo 0)"
        echo ""
        echo "SCSI/ATA DISKS:"
        echo "────────────────────────────────────────────────────────────────────────"
        lsscsi -g 2>/dev/null || echo "lsscsi not available"
        echo ""
        echo "NVME DISKS:"
        echo "────────────────────────────────────────────────────────────────────────"
        nvme list 2>/dev/null || echo "nvme-cli not installed"
        echo ""
        echo "DISK STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total disks: $(lsblk -d | wc -l)"
        echo "   Total partitions: $(lsblk -l | grep -c part)"
        echo "   Mounted filesystems: $(findmnt -l | wc -l)"
        echo ""
        echo "DISK USAGE (df):"
        echo "────────────────────────────────────────────────────────────────────────"
        df -hT --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null
    } > "$TMP_FILE"
    show_text "Complete Disk List" "$TMP_FILE"
    log "Listed all disks and partitions"
}

disk_create_partition() {
    local disk=$(get_input "Create Partition" "Enter disk device (e.g., /dev/sda):" "/dev/sda")
    [[ -z "$disk" ]] && return
    
    if [[ ! -b "$disk" ]]; then
        show_msg "Error" "Device $disk does not exist!"
        return
    fi
    
    local size=$(get_input "Create Partition" "Enter partition size (e.g., 10G, 512M):" "10G")
    [[ -z "$size" ]] && return
    
    local type=$(d --title "Partition Type" --menu "\nSelect partition type:" 12 60 3 \
        "primary" "Primary partition" \
        "extended" "Extended partition" \
        "logical" "Logical partition" \
        3>&1 1>&2 2>&3)
    [[ -z "$type" ]] && return
    
    local fstype=$(d --title "Filesystem Type" --menu "\nSelect filesystem:" 14 60 5 \
        "ext4" "Linux ext4" \
        "ntfs" "Windows NTFS" \
        "fat32" "FAT32" \
        "xfs" "XFS" \
        "btrfs" "BTRFS" \
        3>&1 1>&2 2>&3)
    [[ -z "$fstype" ]] && return
    
    if ask_yesno "Create $type partition of size $size on $disk with $fstype filesystem?\n\nWARNING: This will modify disk!"; then
        {
            echo "Creating partition on $disk..."
            sudo parted -s "$disk" mklabel gpt 2>&1
            sudo parted -s "$disk" mkpart $type "$fstype" 0% $size 2>&1
            sudo partprobe "$disk" 2>&1
            echo ""
            echo "Partition created successfully!"
            echo "New partition table:"
            sudo parted -s "$disk" print
            echo ""
            echo "Formatting with $fstype..."
            local new_part=$(sudo parted -s "$disk" print | grep -E "^[0-9]" | tail -1 | awk '{print $1}')
            if [[ -n "$new_part" ]]; then
                sudo mkfs -t "$fstype" "${disk}${new_part}" 2>&1
                echo ""
                echo "Format complete!"
            fi
        } > "$TMP_FILE" 2>&1
        show_text "Partition Creation Result" "$TMP_FILE"
        log "Created partition on $disk with size $size type $type fstype $fstype"
    fi
}

disk_delete_partition() {
    local disk=$(get_input "Delete Partition" "Enter disk device (e.g., /dev/sda):" "/dev/sda")
    [[ -z "$disk" ]] && return
    
    if [[ ! -b "$disk" ]]; then
        show_msg "Error" "Device $disk does not exist!"
        return
    fi
    
    {
        echo "Current partitions on $disk:"
        sudo parted -s "$disk" print
        echo ""
    } > "$TMP_FILE"
    show_text "Current Partitions" "$TMP_FILE"
    
    local part_num=$(get_input "Delete Partition" "Enter partition number to delete (1, 2, 3...):")
    [[ -z "$part_num" ]] && return
    
    if ask_yesno "Delete partition $part_num on $disk?\n\nWARNING: All data will be lost!"; then
        {
            echo "Deleting partition $part_num on $disk..."
            sudo parted -s "$disk" rm $part_num 2>&1
            sudo partprobe "$disk" 2>&1
            echo ""
            echo "Partition deleted successfully!"
            echo "Updated partition table:"
            sudo parted -s "$disk" print
        } > "$TMP_FILE" 2>&1
        show_text "Partition Deletion Result" "$TMP_FILE"
        log "Deleted partition $part_num on $disk"
    fi
}

disk_format_partition() {
    local partition=$(get_input "Format Partition" "Enter partition device (e.g., /dev/sda1):" "/dev/sda1")
    [[ -z "$partition" ]] && return
    
    if [[ ! -b "$partition" ]]; then
        show_msg "Error" "Partition $partition does not exist!"
        return
    fi
    
    local fstype=$(d --title "Filesystem Type" --menu "\nSelect filesystem:" 14 60 6 \
        "ext4" "Linux ext4" \
        "ntfs" "Windows NTFS" \
        "fat32" "FAT32" \
        "xfs" "XFS" \
        "btrfs" "BTRFS" \
        "swap" "Linux Swap" \
        3>&1 1>&2 2>&3)
    [[ -z "$fstype" ]] && return
    
    local label=$(get_input "Format Partition" "Enter volume label (optional):" "")
    
    if ask_yesno "Format $partition as $fstype with label '$label'?\n\nWARNING: All data on $partition will be destroyed!"; then
        {
            echo "Formatting $partition as $fstype..."
            if [[ "$fstype" == "ext4" ]]; then
                sudo mkfs.ext4 -F -L "$label" "$partition" 2>&1
            elif [[ "$fstype" == "ntfs" ]]; then
                sudo mkfs.ntfs -Q -L "$label" "$partition" 2>&1
            elif [[ "$fstype" == "fat32" ]]; then
                sudo mkfs.fat -F 32 -n "$label" "$partition" 2>&1
            elif [[ "$fstype" == "xfs" ]]; then
                sudo mkfs.xfs -f -L "$label" "$partition" 2>&1
            elif [[ "$fstype" == "btrfs" ]]; then
                sudo mkfs.btrfs -f -L "$label" "$partition" 2>&1
            elif [[ "$fstype" == "swap" ]]; then
                sudo mkswap -L "$label" "$partition" 2>&1
            fi
            echo ""
            echo "Format complete!"
            echo "New filesystem info:"
            sudo blkid "$partition"
        } > "$TMP_FILE" 2>&1
        show_text "Format Result" "$TMP_FILE"
        log "Formatted $partition as $fstype with label $label"
    fi
}

disk_mount_unmount() {
    local choice=$(d --title "Mount/Unmount" --menu "\nSelect operation:" 12 60 2 \
        "mount" "Mount a partition" \
        "unmount" "Unmount a partition" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    if [[ "$choice" == "mount" ]]; then
        local partition=$(get_input "Mount Partition" "Enter partition device (e.g., /dev/sda1):" "/dev/sda1")
        [[ -z "$partition" ]] && return
        
        if [[ ! -b "$partition" ]]; then
            show_msg "Error" "Partition $partition does not exist!"
            return
        fi
        
        local mount_point=$(get_input "Mount Partition" "Enter mount point (e.g., /mnt/data):" "/mnt")
        [[ -z "$mount_point" ]] && return
        
        if ask_yesno "Mount $partition to $mount_point?"; then
            {
                sudo mkdir -p "$mount_point" 2>&1
                sudo mount "$partition" "$mount_point" 2>&1
                echo "Partition mounted successfully!"
                echo ""
                echo "Mount info:"
                findmnt "$mount_point" 2>/dev/null || mount | grep "$partition"
            } > "$TMP_FILE" 2>&1
            show_text "Mount Result" "$TMP_FILE"
            log "Mounted $partition to $mount_point"
        fi
    else
        local mount_point=$(get_input "Unmount Partition" "Enter mount point to unmount:" "/mnt")
        [[ -z "$mount_point" ]] && return
        
        if ask_yesno "Unmount $mount_point?"; then
            {
                sudo umount "$mount_point" 2>&1
                echo "Partition unmounted successfully!"
            } > "$TMP_FILE" 2>&1
            show_text "Unmount Result" "$TMP_FILE"
            log "Unmounted $mount_point"
        fi
    fi
}

disk_clone() {
    local source=$(get_input "Disk Clone" "Enter source disk (e.g., /dev/sda):" "/dev/sda")
    [[ -z "$source" ]] && return
    
    local target=$(get_input "Disk Clone" "Enter target disk (e.g., /dev/sdb):" "/dev/sdb")
    [[ -z "$target" ]] && return
    
    if [[ "$source" == "$target" ]]; then
        show_msg "Error" "Source and target must be different!"
        return
    fi
    
    {
        echo "Source disk: $source"
        lsblk "$source"
        echo ""
        echo "Target disk: $target"
        lsblk "$target"
    } > "$TMP_FILE"
    show_text "Disk Information" "$TMP_FILE"
    
    if ask_yesno "Clone $source to $target?\n\nWARNING: All data on $target will be destroyed!\nThis may take a long time."; then
        {
            echo "Starting disk clone from $source to $target..."
            echo "This may take a while. Please wait..."
            echo ""
            sudo dd if="$source" of="$target" bs=4M status=progress 2>&1
            echo ""
            echo "Clone completed successfully!"
            echo "Syncing disks..."
            sudo sync
        } > "$TMP_FILE" 2>&1
        show_text "Clone Result" "$TMP_FILE"
        log "Cloned $source to $target"
    fi
}

disk_create_image() {
    local source=$(get_input "Create Disk Image" "Enter source disk/partition (e.g., /dev/sda):" "/dev/sda")
    [[ -z "$source" ]] && return
    
    local image_path=$(get_input "Create Disk Image" "Enter image file path:" "/backup/disk_image.img")
    [[ -z "$image_path" ]] && return
    
    local compress=$(d --title "Compression" --menu "\nSelect compression:" 12 60 3 \
        "none" "No compression" \
        "gzip" "GZIP compression" \
        "xz" "XZ compression" \
        3>&1 1>&2 2>&3)
    [[ -z "$compress" ]] && return
    
    if ask_yesno "Create image of $source as $image_path with $compress compression?"; then
        {
            echo "Creating disk image from $source..."
            if [[ "$compress" == "none" ]]; then
                sudo dd if="$source" of="$image_path" bs=4M status=progress 2>&1
            elif [[ "$compress" == "gzip" ]]; then
                sudo dd if="$source" bs=4M | gzip > "${image_path}.gz" 2>&1
                echo "Image saved as ${image_path}.gz"
            elif [[ "$compress" == "xz" ]]; then
                sudo dd if="$source" bs=4M | xz > "${image_path}.xz" 2>&1
                echo "Image saved as ${image_path}.xz"
            fi
            echo ""
            echo "Image created successfully!"
            echo "File size:"
            if [[ "$compress" == "none" ]]; then
                ls -lh "$image_path"
            elif [[ "$compress" == "gzip" ]]; then
                ls -lh "${image_path}.gz"
            else
                ls -lh "${image_path}.xz"
            fi
        } > "$TMP_FILE" 2>&1
        show_text "Image Creation Result" "$TMP_FILE"
        log "Created disk image of $source as $image_path with $compress"
    fi
}

disk_restore_image() {
    local image_path=$(get_input "Restore Disk Image" "Enter image file path:" "/backup/disk_image.img")
    [[ -z "$image_path" ]] && return
    
    if [[ ! -f "$image_path" ]] && [[ ! -f "${image_path}.gz" ]] && [[ ! -f "${image_path}.xz" ]]; then
        show_msg "Error" "Image file not found!"
        return
    fi
    
    local target=$(get_input "Restore Disk Image" "Enter target disk (e.g., /dev/sdb):" "/dev/sdb")
    [[ -z "$target" ]] && return
    
    if ask_yesno "Restore image to $target?\n\nWARNING: All data on $target will be destroyed!"; then
        {
            echo "Restoring image to $target..."
            if [[ -f "$image_path" ]]; then
                sudo dd if="$image_path" of="$target" bs=4M status=progress 2>&1
            elif [[ -f "${image_path}.gz" ]]; then
                gunzip -c "${image_path}.gz" | sudo dd of="$target" bs=4M status=progress 2>&1
            elif [[ -f "${image_path}.xz" ]]; then
                xz -d -c "${image_path}.xz" | sudo dd of="$target" bs=4M status=progress 2>&1
            fi
            echo ""
            echo "Restore completed successfully!"
            sudo sync
        } > "$TMP_FILE" 2>&1
        show_text "Restore Result" "$TMP_FILE"
        log "Restored image $image_path to $target"
    fi
}

disk_smart_check() {
    if ! command -v smartctl &>/dev/null; then
        show_msg "Error" "smartctl not found.\n\nInstall: sudo apt install smartmontools"
        return
    fi
    
    local disk=$(get_input "SMART Check" "Enter disk device (e.g., /dev/sda):" "/dev/sda")
    [[ -z "$disk" ]] && return
    
    if [[ ! -b "$disk" ]]; then
        show_msg "Error" "Device $disk does not exist!"
        return
    fi
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              SMART HEALTH CHECK - $disk"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "BASIC SMART INFO:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo smartctl -i "$disk" 2>/dev/null
        echo ""
        echo "HEALTH STATUS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo smartctl -H "$disk" 2>/dev/null
        echo ""
        echo "SMART ATTRIBUTES (Selected):"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo smartctl -A "$disk" 2>/dev/null | grep -E "Reallocated|Pending|Uncorrectable|CRC|Temperature|Power_On|Spin_Retry"
        echo ""
        echo "SELF-TEST RESULTS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo smartctl -l selftest "$disk" 2>/dev/null | tail -20
        echo ""
        echo "TEMPERATURE:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo smartctl -A "$disk" 2>/dev/null | grep -i temperature | head -1
        echo ""
        echo "POWER ON HOURS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo smartctl -A "$disk" 2>/dev/null | grep -i "power_on" | head -1
        echo ""
        echo "COMPLETE SMART DATA:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo smartctl -a "$disk" 2>/dev/null | head -100
    } > "$TMP_FILE" 2>&1
    show_text "SMART Health Check" "$TMP_FILE"
    log "Performed SMART check on $disk"
}

disk_benchmark() {
    local choice=$(d --title "Disk Benchmark" --menu "\nSelect benchmark type:" 12 60 3 \
        "read" "Read speed test" \
        "write" "Write speed test" \
        "both" "Both read & write" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    local disk=$(get_input "Disk Benchmark" "Enter disk device to test (e.g., /dev/sda):" "/dev/sda")
    [[ -z "$disk" ]] && return
    
    if [[ ! -b "$disk" ]] && [[ ! -f "$disk" ]]; then
        show_msg "Error" "Device $disk does not exist!"
        return
    fi
    
    local size=$(get_input "Disk Benchmark" "Enter test size (e.g., 1G, 512M):" "1G")
    [[ -z "$size" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              DISK PERFORMANCE BENCHMARK"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "Testing $disk with size $size"
        echo ""
        
        if [[ "$choice" == "read" ]] || [[ "$choice" == "both" ]]; then
            echo "READ TEST:"
            echo "────────────────────────────────────────────────────────────────────────"
            sudo dd if="$disk" of=/dev/null bs=1M count=1024 2>&1 | grep -E "copied|MB/s"
            echo ""
        fi
        
        if [[ "$choice" == "write" ]] || [[ "$choice" == "both" ]]; then
            echo "WRITE TEST:"
            echo "────────────────────────────────────────────────────────────────────────"
            if [[ -f "$disk" ]]; then
                dd if=/dev/zero of="$disk" bs=1M count=1024 conv=fdatasync 2>&1 | grep -E "copied|MB/s"
            else
                sudo dd if=/dev/zero of="$disk" bs=1M count=1024 conv=fdatasync 2>&1 | grep -E "copied|MB/s"
            fi
            echo ""
        fi
        
        echo "DISK STATISTICS:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo iostat -x "$disk" 2>/dev/null | head -20 || echo "iostat not available"
        echo ""
        echo "DISK SCHEDULER:"
        echo "────────────────────────────────────────────────────────────────────────"
        if [[ -f "/sys/block/$(basename $disk)/queue/scheduler" ]]; then
            cat "/sys/block/$(basename $disk)/queue/scheduler"
        else
            echo "Scheduler info not available"
        fi
    } > "$TMP_FILE" 2>&1
    show_text "Disk Benchmark" "$TMP_FILE"
    log "Ran benchmark on $disk"
}

disk_lvm_manage() {
    if ! command -v lvm &>/dev/null; then
        show_msg "Error" "LVM not installed.\n\nInstall: sudo apt install lvm2"
        return
    fi
    
    local choice=$(d --title "LVM Management" --menu "\nSelect LVM operation:" 14 60 5 \
        "pv" "Physical Volumes" \
        "vg" "Volume Groups" \
        "lv" "Logical Volumes" \
        "create" "Create Volume Group" \
        "extend" "Extend Volume Group" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        pv)
            {
                echo "PHYSICAL VOLUMES:"
                echo "────────────────────────────────────────────────────────────────────────"
                sudo pvdisplay 2>/dev/null
                echo ""
                echo "PV List:"
                sudo pvs 2>/dev/null
            } > "$TMP_FILE"
            show_text "Physical Volumes" "$TMP_FILE"
            ;;
        vg)
            {
                echo "VOLUME GROUPS:"
                echo "────────────────────────────────────────────────────────────────────────"
                sudo vgdisplay 2>/dev/null
                echo ""
                echo "VG List:"
                sudo vgs 2>/dev/null
            } > "$TMP_FILE"
            show_text "Volume Groups" "$TMP_FILE"
            ;;
        lv)
            {
                echo "LOGICAL VOLUMES:"
                echo "────────────────────────────────────────────────────────────────────────"
                sudo lvdisplay 2>/dev/null
                echo ""
                echo "LV List:"
                sudo lvs 2>/dev/null
            } > "$TMP_FILE"
            show_text "Logical Volumes" "$TMP_FILE"
            ;;
        create)
            local vg_name=$(get_input "Create VG" "Enter volume group name:" "vg_data")
            [[ -z "$vg_name" ]] && return
            local pv_dev=$(get_input "Create VG" "Enter physical volume device:" "/dev/sdb1")
            [[ -z "$pv_dev" ]] && return
            
            if ask_yesno "Create volume group $vg_name with $pv_dev?"; then
                {
                    sudo pvcreate "$pv_dev" 2>&1
                    sudo vgcreate "$vg_name" "$pv_dev" 2>&1
                    echo "Volume group created successfully!"
                    sudo vgdisplay "$vg_name"
                } > "$TMP_FILE" 2>&1
                show_text "LVM Creation" "$TMP_FILE"
                log "Created LVM VG $vg_name"
            fi
            ;;
        extend)
            local vg_name=$(get_input "Extend VG" "Enter volume group name:" "vg_data")
            [[ -z "$vg_name" ]] && return
            local pv_dev=$(get_input "Extend VG" "Enter new physical volume device:" "/dev/sdc1")
            [[ -z "$pv_dev" ]] && return
            
            if ask_yesno "Extend $vg_name with $pv_dev?"; then
                {
                    sudo pvcreate "$pv_dev" 2>&1
                    sudo vgextend "$vg_name" "$pv_dev" 2>&1
                    echo "Volume group extended successfully!"
                    sudo vgdisplay "$vg_name"
                } > "$TMP_FILE" 2>&1
                show_text "LVM Extend" "$TMP_FILE"
                log "Extended LVM VG $vg_name"
            fi
            ;;
    esac
    log "LVM operation: $choice"
}

disk_raid_manage() {
    if ! command -v mdadm &>/dev/null; then
        show_msg "Error" "mdadm not installed.\n\nInstall: sudo apt install mdadm"
        return
    fi
    
    local choice=$(d --title "RAID Management" --menu "\nSelect RAID operation:" 12 60 3 \
        "status" "View RAID Status" \
        "create" "Create RAID Array" \
        "details" "Array Details" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        status)
            {
                echo "RAID STATUS:"
                echo "────────────────────────────────────────────────────────────────────────"
                sudo mdadm --detail /dev/md* 2>/dev/null || echo "No RAID arrays found"
                echo ""
                echo "RAID Monitor:"
                cat /proc/mdstat 2>/dev/null
            } > "$TMP_FILE"
            show_text "RAID Status" "$TMP_FILE"
            ;;
        create)
            local raid_name=$(get_input "Create RAID" "Enter RAID device name (e.g., md0):" "md0")
            [[ -z "$raid_name" ]] && return
            local raid_level=$(d --title "RAID Level" --menu "\nSelect RAID level:" 14 60 4 \
                "0" "RAID 0 - Striping" \
                "1" "RAID 1 - Mirroring" \
                "5" "RAID 5 - Parity" \
                "10" "RAID 10 - Mirror + Strip" \
                3>&1 1>&2 2>&3)
            [[ -z "$raid_level" ]] && return
            local devices=$(get_input "Create RAID" "Enter devices (space separated, e.g., /dev/sdb1 /dev/sdc1):" "/dev/sdb1 /dev/sdc1")
            [[ -z "$devices" ]] && return
            
            if ask_yesno "Create RAID $raid_level array /dev/$raid_name with devices: $devices?"; then
                {
                    sudo mdadm --create "/dev/$raid_name" --level=$raid_level --raid-devices=$(echo $devices | wc -w) $devices 2>&1
                    sudo mdadm --detail "/dev/$raid_name"
                    echo ""
                    echo "Update mdadm.conf:"
                    sudo mdadm --detail --scan >> /etc/mdadm/mdadm.conf
                } > "$TMP_FILE" 2>&1
                show_text "RAID Creation" "$TMP_FILE"
                log "Created RAID $raid_level array /dev/$raid_name"
            fi
            ;;
        details)
            local raid_dev=$(get_input "RAID Details" "Enter RAID device (e.g., md0):" "md0")
            [[ -z "$raid_dev" ]] && return
            {
                echo "RAID DETAILS for /dev/$raid_dev:"
                echo "────────────────────────────────────────────────────────────────────────"
                sudo mdadm --detail "/dev/$raid_dev" 2>/dev/null || echo "RAID array not found"
                echo ""
                echo "Current status:"
                cat /proc/mdstat | grep -A 2 "$raid_dev"
            } > "$TMP_FILE"
            show_text "RAID Details" "$TMP_FILE"
            ;;
    esac
    log "RAID operation: $choice"
}

disk_encryption() {
    if ! command -v cryptsetup &>/dev/null; then
        show_msg "Error" "cryptsetup not installed.\n\nInstall: sudo apt install cryptsetup"
        return
    fi
    
    local choice=$(d --title "Disk Encryption (LUKS)" --menu "\nSelect encryption operation:" 12 60 3 \
        "encrypt" "Encrypt partition" \
        "open" "Open encrypted partition" \
        "close" "Close encrypted partition" \
        3>&1 1>&2 2>&3)
    [[ -z "$choice" ]] && return
    
    case "$choice" in
        encrypt)
            local partition=$(get_input "Encrypt Partition" "Enter partition device:" "/dev/sda1")
            [[ -z "$partition" ]] && return
            local name=$(get_input "Encrypt Partition" "Enter mapper name:" "crypt_data")
            [[ -z "$name" ]] && return
            
            if ask_yesno "Encrypt $partition with LUKS?\n\nWARNING: All data will be destroyed!"; then
                {
                    echo "Setting up LUKS encryption on $partition..."
                    sudo cryptsetup luksFormat "$partition" 2>&1
                    echo ""
                    echo "Opening encrypted partition..."
                    sudo cryptsetup open "$partition" "$name" 2>&1
                    echo ""
                    echo "Encrypted device available at /dev/mapper/$name"
                    echo "Format with: sudo mkfs.ext4 /dev/mapper/$name"
                } > "$TMP_FILE" 2>&1
                show_text "Encryption Result" "$TMP_FILE"
                log "Encrypted $partition as $name"
            fi
            ;;
        open)
            local partition=$(get_input "Open Encrypted" "Enter encrypted partition:" "/dev/sda1")
            [[ -z "$partition" ]] && return
            local name=$(get_input "Open Encrypted" "Enter mapper name:" "crypt_data")
            [[ -z "$name" ]] && return
            
            {
                sudo cryptsetup open "$partition" "$name" 2>&1
                echo ""
                echo "Encrypted device opened at /dev/mapper/$name"
                lsblk | grep -A 1 "$name"
            } > "$TMP_FILE" 2>&1
            show_text "Open Encrypted" "$TMP_FILE"
            log "Opened encrypted device $partition as $name"
            ;;
        close)
            local name=$(get_input "Close Encrypted" "Enter mapper name:" "crypt_data")
            [[ -z "$name" ]] && return
            
            {
                sudo cryptsetup close "$name" 2>&1
                echo "Encrypted device closed."
            } > "$TMP_FILE" 2>&1
            show_text "Close Encrypted" "$TMP_FILE"
            log "Closed encrypted device $name"
            ;;
    esac
}

disk_secure_erase() {
    local disk=$(get_input "Secure Erase" "Enter disk device (e.g., /dev/sdb):" "/dev/sdb")
    [[ -z "$disk" ]] && return
    
    if [[ ! -b "$disk" ]]; then
        show_msg "Error" "Device $disk does not exist!"
        return
    fi
    
    local method=$(d --title "Erase Method" --menu "\nSelect erase method:" 12 60 3 \
        "zeros" "Write zeros (fast)" \
        "random" "Write random data (secure)" \
        "dd" "DD with /dev/urandom (very secure)" \
        3>&1 1>&2 2>&3)
    [[ -z "$method" ]] && return
    
    if ask_yesno "SECURELY ERASE $disk using $method method?\n\nWARNING: ALL DATA WILL BE DESTROYED PERMANENTLY!\nThis cannot be undone!"; then
        {
            echo "Starting secure erase of $disk using $method..."
            echo "This may take a long time. Please wait..."
            echo ""
            
            if [[ "$method" == "zeros" ]]; then
                sudo dd if=/dev/zero of="$disk" bs=1M status=progress 2>&1
            elif [[ "$method" == "random" ]]; then
                sudo dd if=/dev/urandom of="$disk" bs=1M status=progress 2>&1
            elif [[ "$method" == "dd" ]]; then
                sudo dd if=/dev/urandom of="$disk" bs=1M status=progress 2>&1
            fi
            
            echo ""
            echo "Secure erase completed!"
            echo "The disk is now empty."
        } > "$TMP_FILE" 2>&1
        show_text "Secure Erase Result" "$TMP_FILE"
        log "Securely erased $disk using $method"
    fi
}

disk_usage_analysis() {
    local path=$(get_input "Disk Usage Analysis" "Enter path to analyze:" "/")
    [[ -z "$path" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "            DISK USAGE ANALYSIS - $path"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "TOP 20 LARGEST DIRECTORIES:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo du -h "$path" 2>/dev/null | sort -rh | head -20
        echo ""
        echo "TOP 20 LARGEST FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo find "$path" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -20
        echo ""
        echo "DIRECTORY TREE SIZE:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo du -h --max-depth=1 "$path" 2>/dev/null | sort -rh
        echo ""
        echo "STORAGE SUMMARY:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Total size: $(sudo du -sh "$path" 2>/dev/null | cut -f1)"
        echo "   Number of files: $(sudo find "$path" -type f 2>/dev/null | wc -l)"
        echo "   Number of directories: $(sudo find "$path" -type d 2>/dev/null | wc -l)"
        echo ""
        echo "FILE TYPES DISTRIBUTION:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo find "$path" -type f 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
    } > "$TMP_FILE"
    show_text "Disk Usage Analysis" "$TMP_FILE"
    log "Analyzed disk usage at $path"
}

disk_find_large_files() {
    local path=$(get_input "Find Large Files" "Enter path to search:" "/")
    [[ -z "$path" ]] && return
    
    local size=$(get_input "Find Large Files" "Enter minimum size (e.g., 100M, 1G):" "100M")
    [[ -z "$size" ]] && return
    
    {
        echo "════════════════════════════════════════════════════════════════════════"
        echo "              LARGE FILES IN $path ( > $size )"
        echo "════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "LARGEST FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo find "$path" -type f -size +"$size" -exec ls -lh {} \; 2>/dev/null | awk '{print $9, $5}' | sort -k2 -hr | head -50
        echo ""
        echo "FIND BY SIZE:"
        echo "────────────────────────────────────────────────────────────────────────"
        echo "   Files > 1GB: $(sudo find "$path" -type f -size +1G 2>/dev/null | wc -l)"
        echo "   Files > 500MB: $(sudo find "$path" -type f -size +500M 2>/dev/null | wc -l)"
        echo "   Files > 100MB: $(sudo find "$path" -type f -size +100M 2>/dev/null | wc -l)"
        echo ""
        echo "TOTAL SPACE USED BY LARGE FILES:"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo find "$path" -type f -size +"$size" -exec du -ch {} + 2>/dev/null | tail -1
        echo ""
        echo "OLDER LARGE FILES (> 30 days):"
        echo "────────────────────────────────────────────────────────────────────────"
        sudo find "$path" -type f -size +"$size" -mtime +30 -exec ls -lh {} \; 2>/dev/null | head -20
    } > "$TMP_FILE"
    show_text "Large Files" "$TMP_FILE"
    log "Found large files in $path > $size"
}