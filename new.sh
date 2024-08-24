#!/bin/bash

# تابع برای حذف تونل‌ها و پاک‌سازی فایل rc.local
remove_tunnels() {
    echo "Removing tunnels..."

    # حذف آدرس‌های IP و تونل‌ها
    sudo ip addr del 2002:480:1f10:e1f::2/64 dev 6to4_To_IR1 2>/dev/null
    sudo ip addr del 10.10.10.2/30 dev GRE6Tun_To_IR1 2>/dev/null
    sudo ip addr del 2002:480:1f10:e1f::3/64 dev 6to4_To_IR2 2>/dev/null
    sudo ip addr del 10.10.10.4/30 dev GRE6Tun_To_IR2 2>/dev/null

    # حذف تونل‌ها
    sudo ip tunnel del 6to4_To_IR1 2>/dev/null
    sudo ip -6 tunnel del GRE6Tun_To_IR1 2>/dev/null
    sudo ip tunnel del 6to4_To_IR2 2>/dev/null
    sudo ip -6 tunnel del GRE6Tun_To_IR2 2>/dev/null

    # پاک‌کردن محتوای فایل /etc/rc.local
    if [ -f /etc/rc.local ]; then
        echo -e "#! /bin/bash\n\nexit 0" | sudo tee /etc/rc.local > /dev/null
        sudo chmod +x /etc/rc.local
        echo "Content of /etc/rc.local replaced with the default script."
    else
        echo "/etc/rc.local does not exist."
    fi

    echo "Tunnels removed."
}

# تابع برای اضافه کردن دستورات به rc.local
setup_rc_local() {
    new_commands="$1"
    
    # خواندن محتوای فعلی فایل rc.local
    if [ -f /etc/rc.local ]; then
        current_content=$(cat /etc/rc.local)
        
        # بررسی وجود shebang و exit 0 در فایل
        if [[ "$current_content" == "#! /bin/bash" && "$current_content" == *"exit 0"* ]]; then
            # قرار دادن دستورات جدید بین shebang و exit 0
            echo -e "#! /bin/bash\n\n$new_commands\n\nexit 0" | sudo tee /etc/rc.local > /dev/null
        else
            # اگر فایل rc.local به درستی تنظیم نشده، آن را بازنویسی کنیم
            echo -e "#! /bin/bash\n\n$new_commands\n\nexit 0" | sudo tee /etc/rc.local > /dev/null
        fi
    else
        # اگر فایل rc.local وجود ندارد، آن را ایجاد و تنظیم کنیم
        echo -e "#! /bin/bash\n\n$new_commands\n\nexit 0" | sudo tee /etc/rc.local > /dev/null
    fi
    
    sudo chmod +x /etc/rc.local
    echo "Commands added to /etc/rc.local."
}

# Function to install x-ui
install_x_ui() {
    echo "Choose the version of x-ui to install:"
    echo "1) alireza"
    echo "2) MHSanaei"
    read -p "Select an option (1 or 2): " xui_choice

    if [ "$xui_choice" -eq 1 ]; then
        bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
        echo "alireza version of x-ui installed."
    elif [ "$xui_choice" -eq 2 ]; then
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        echo "MHSanaei version of x-ui installed."
    else
        echo "Invalid option. Please select 1 or 2."
    fi
}

# Function to handle Optimize option
optimize() {
    USER_CONF="/etc/systemd/user.conf"
    SYSTEM_CONF="/etc/systemd/system.conf"
    LIMITS_CONF="/etc/security/limits.conf"
    SYSCTL_CONF="/etc/sysctl.d/local.conf"
    TEMP_USER_CONF=$(mktemp)
    TEMP_SYSTEM_CONF=$(mktemp)

    # Function to add line if not exists
    add_line_if_not_exists() {
        local file="$1"
        local line="$2"
        local temp_file="$3"

        if [ -f "$file" ];then
            cp "$file" "$temp_file"
            if ! grep -q "$line" "$file"; then
                sed -i '/^\[Manager\]/a '"$line" "$temp_file"
                sudo mv "$temp_file" "$file"
                echo "Added '$line' to $file"
            else
                echo "The line '$line' already exists in $file"
                rm "$temp_file"
            fi
        else
            echo "$file does not exist."
            rm "$temp_file"
        fi
    }

    # Optimize user.conf
    add_line_if_not_exists "$USER_CONF" "DefaultLimitNOFILE=1024000" "$TEMP_USER_CONF"

    # Optimize system.conf
    add_line_if_not_exists "$SYSTEM_CONF" "DefaultLimitNOFILE=1024000" "$TEMP_SYSTEM_CONF"

    # Optimize limits.conf
    if [ -f "$LIMITS_CONF" ];then
        cat <<EOF | sudo tee -a "$LIMITS_CONF"
* hard nofile 1024000
* soft nofile 1024000
root hard nofile 1024000
root soft nofile 1024000
EOF
        echo "Added limits to $LIMITS_CONF"
    else
        echo "$LIMITS_CONF does not exist."
    fi

    # Optimize sysctl.d/local.conf
    sudo bash -c "cat <<EOF > $SYSCTL_CONF
fs.file-max = 2097152
net.core.netdev_max_backlog = 262144
net.core.rmem_default = 8388608
net.core.rmem_max = 67108864
net.core.somaxconn = 4096
net.core.wmem_default = 8388608
net.core.wmem_max = 67108864
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_max_tw_buckets = 6000000
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_sack = 1
net.ipv4.tcp_syn_retries = 5
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
vm.min_free_kbytes = 65536
EOF"

    sudo systemctl daemon-reload
    sudo systemctl restart systemd-journald
    sudo systemctl restart systemd
    sudo sysctl --system

    echo "System optimized successfully."
}

# Function to disable IPv6
disable_ipv6() {
    commands=$(cat <<EOF
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1
EOF
)

    eval "$commands"
    echo "IPv6 has been disabled. This change is temporary and will revert after reboot."
}

# نمایش منوی اصلی
echo "1) 6to4 multi server (1 outside 2 Iran)"
echo "2) 6to4"
echo "3) Remove tunnels"
echo "4) Enable BBR"
echo "5) Fix Whatsapp Time"
echo "6) Optimize"
echo "7) Install x-ui"
echo "8) Change NameServer"
echo "9) Disable IPv6 - After server reboot IPv6 is activated"
read -p "Select an option (1-9): " server_choice

# اجرای گزینه انتخاب شده
case $server_choice in
    1)
        # 6to4 multi server
        echo "Which server is this?"
        echo "1) Outside"
        echo "2) Iran1"
        echo "3) Iran2"
        read -p "Select an option (1-3): " server_option

    if [ "$server_option" -eq 1 ]; then
        read -p "Enter the IP Outside: " ipkharej1
        read -p "Enter the IP Iran1: " ipiran1
        read -p "Enter the IP Iran2: " ipiran2

        commands=$(cat <<EOF
#!/bin/bash
		
ip tunnel add 6to4_To_IR1 mode sit remote $ipiran1 local $ipkharej1
ip -6 addr add 2002:480:1f10:e1f::2/64 dev 6to4_To_IR1
ip link set 6to4_To_IR1 mtu 1480
ip link set 6to4_To_IR1 up

ip -6 tunnel add GRE6Tun_To_IR1 mode ip6gre remote 2002:480:1f10:e1f::1 local 2002:480:1f10:e1f::2
ip addr add 10.10.10.2/30 dev GRE6Tun_To_IR1
ip link set GRE6Tun_To_IR1 mtu 1436
ip link set GRE6Tun_To_IR1 up

ip tunnel add 6to4_To_IR2 mode sit remote $ipiran2 local $ipkharej1
ip -6 addr add 2009:480:1f10:e1f::2/64 dev 6to4_To_IR2
ip link set 6to4_To_IR2 mtu 1480
ip link set 6to4_To_IR2 up

ip -6 tunnel add GRE6Tun_To_IR2 mode ip6gre remote 2009:480:1f10:e1f::1 local 2009:480:1f10:e1f::2
ip addr add 10.10.11.2/30 dev GRE6Tun_To_IR2
ip link set GRE6Tun_To_IR2 mtu 1436
ip link set GRE6Tun_To_IR2 up
EOF

            )

        chmod +x /etc/rc.local
        echo "Configuration for Outside saved to /etc/rc.local and the file has been made executable."

    elif [ "$server_option" -eq 2 ]; then
        # برای سرور Iran1
        read -p "Enter the IP Outside: " ipkharej1
        read -p "Enter the IP Iran1: " ipiran1

        # گرفتن پورت‌ها
        read -p "Enter the ports (comma separated, e.g., 443,8080): " ports
        IFS=',' read -r -a port_array <<< "$ports"

        # ایجاد محتوای جدید برای فایل rc.local
        cat <<EOL > /etc/rc.local
#!/bin/bash

ip tunnel add 6to4_To_KH mode sit remote $ipkharej1 local $ipiran1
ip -6 addr add 2002:480:1f10:e1f::1/64 dev 6to4_To_KH
ip link set 6to4_To_KH mtu 1480
ip link set 6to4_To_KH up

ip -6 tunnel add GRE6Tun_To_KH mode ip6gre remote 2002:480:1f10:e1f::2 local 2002:480:1f10:e1f::1
ip addr add 10.10.10.1/30 dev GRE6Tun_To_KH
ip link set GRE6Tun_To_KH mtu 1436
ip link set GRE6Tun_To_KH up

# فعال کردن فورواردینگ IPv4
sysctl net.ipv4.ip_forward=1
EOL

        # اضافه کردن قوانین iptables بر اساس تعداد پورت‌ها
        for i in "${!port_array[@]}"; do
            echo "iptables -t nat -A PREROUTING -p tcp --dport ${port_array[$i]} -j DNAT --to-destination 10.10.10.1" >> /etc/rc.local
        done

        # اضافه کردن دستور POSTROUTING و خروج
        cat <<EOL >> /etc/rc.local
iptables -t nat -A POSTROUTING -j MASQUERADE 

exit 0
EOL

        chmod +x /etc/rc.local
        echo "Configuration for Iran1 saved to /etc/rc.local and the file has been made executable."

    elif [ "$server_option" -eq 3 ]; then
        # برای سرور Iran2
        read -p "Enter the IP Outside: " ipkharej1
        read -p "Enter the IP Iran2: " ipiran2

        # گرفتن پورت‌ها
        read -p "Enter the ports (comma separated, e.g., 443,8080): " ports
        IFS=',' read -r -a port_array <<< "$ports"

        # ایجاد محتوای جدید برای فایل rc.local
        cat <<EOL > /etc/rc.local
#!/bin/bash

ip tunnel add 6to4_To_KH mode sit remote $ipkharej1 local $ipiran2
ip -6 addr add 2009:480:1f10:e1f::1/64 dev 6to4_To_KH
ip link set 6to4_To_KH mtu 1480
ip link set 6to4_To_KH up

ip -6 tunnel add GRE6Tun_To_KH mode ip6gre remote 2009:480:1f10:e1f::2 local 2009:480:1f10:e1f::1
ip addr add 10.10.11.1/30 dev GRE6Tun_To_KH
ip link set GRE6Tun_To_KH mtu 1436
ip link set GRE6Tun_To_KH up

# فعال کردن فورواردینگ IPv4
sysctl net.ipv4.ip_forward=1
EOL

        # اضافه کردن قوانین iptables بر اساس تعداد پورت‌ها
        for i in "${!port_array[@]}"; do
            echo "iptables -t nat -A PREROUTING -p tcp --dport ${port_array[$i]} -j DNAT --to-destination 10.10.11.1" >> /etc/rc.local
        done

        # اضافه کردن دستور POSTROUTING و خروج
        cat <<EOL >> /etc/rc.local
iptables -t nat -A POSTROUTING -j MASQUERADE 

exit 0
EOL

        chmod +x /etc/rc.local
        echo "Configuration for Iran2 saved to /etc/rc.local and the file has been made executable."

    else
            echo "Invalid option. Please select 1, 2, or 3."
        fi
        ;;
    2)
        # اجرای 6to4
        echo "Choose the type of server:"
        echo "1) Outside"
        echo "2) Iran"
        read -p "Select an option (1 or 2): " six_to_four_choice

        if [ "$six_to_four_choice" -eq 1 ]; then
            read -p "Enter the IP outside: " ipkharej
            read -p "Enter the IP Iran: " ipiran

            commands=$(cat <<EOF
ip tunnel add 6to4_To_IR mode sit remote $ipiran local $ipkharej
ip -6 addr add 2009:499:1d10:e1d::2/64 dev 6to4_To_IR
ip link set 6to4_To_IR mtu 1480
ip link set 6to4_To_IR up

ip -6 tunnel add GRE6Tun_To_IR mode ip6gre remote 2009:499:1d10:e1d::1 local 2009:499:1d10:e1d::2
ip addr add 180.18.18.2/30 dev GRE6Tun_To_IR
ip link set GRE6Tun_To_IR mtu 1436
ip link set GRE6Tun_To_IR up
EOF
            )

            setup_rc_local "$commands"
            echo "Commands executed for the outside server."

        elif [ "$six_to_four_choice" -eq 2 ]; then
            read -p "Enter the IP Iran: " ipiran
            read -p "Enter the IP outside: " ipkharej

            commands=$(cat <<EOF
ip tunnel add 6to4_To_KH mode sit remote $ipkharej local $ipiran
ip -6 addr add 2009:499:1d10:e1d::1/64 dev 6to4_To_KH
ip link set 6to4_To_KH mtu 1480
ip link set 6to4_To_KH up

ip -6 tunnel add GRE6Tun_To_KH mode ip6gre remote 2009:499:1d10:e1d::2 local 2009:499:1d10:e1d::1
ip addr add 180.18.18.1/30 dev GRE6Tun_To_KH
ip link set GRE6Tun_To_KH mtu 1436
ip link set GRE6Tun_To_KH up

sysctl net.ipv4.ip_forward=1
iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination 180.18.18.1
iptables -t nat -A PREROUTING -j DNAT --to-destination 180.18.18.2
iptables -t nat -A POSTROUTING -j MASQUERADE
EOF
            )

            setup_rc_local "$commands"
            echo "Commands executed for the Iran server."
        else
            echo "Invalid option. Please select 1 or 2."
        fi
        ;;
    3)
        # حذف تونل‌ها
        remove_tunnels
        ;;
    4)
        # فعال‌سازی BBR
        echo "Activating BBR..."
        sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
        echo "BBR activated."
        ;;
    5)
        # رفع مشکل زمان Whatsapp
        echo "Fixing Whatsapp time issue..."
        sudo timedatectl set-ntp true
        echo "Whatsapp time issue fixed."
        ;;
    6)
        # بهینه‌سازی
        optimize
        ;;
    7)
        # نصب x-ui
        install_x_ui
        ;;
    8)
        # تغییر NameServer
        echo "Current DNS: $(cat /etc/resolv.conf | grep nameserver)"
        read -p "Enter the new DNS IP address: " new_dns
        echo "nameserver $new_dns" | sudo tee /etc/resolv.conf > /dev/null
        echo "DNS updated to $new_dns."
        ;;
    9)
        # غیرفعال‌سازی IPv6
        disable_ipv6
        ;;
    *)
        echo "Invalid option. Please select a number between 1 and 9."
        ;;
esac
