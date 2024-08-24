#!/bin/bash

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

# تابع بهینه‌سازی
optimize() {
    USER_CONF="/etc/systemd/user.conf"
    SYSTEM_CONF="/etc/systemd/system.conf"
    LIMITS_CONF="/etc/security/limits.conf"
    SYSCTL_CONF="/etc/sysctl.d/local.conf"
    TEMP_USER_CONF=$(mktemp)
    TEMP_SYSTEM_CONF=$(mktemp)

    # تابع اضافه کردن خط در صورت عدم وجود
    add_line_if_not_exists() {
        local file="$1"
        local line="$2"
        local temp_file="$3"

        if [ -f "$file" ]; then
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

    # بهینه‌سازی user.conf
    add_line_if_not_exists "$USER_CONF" "DefaultLimitNOFILE=1024000" "$TEMP_USER_CONF"

    # بهینه‌سازی system.conf
    add_line_if_not_exists "$SYSTEM_CONF" "DefaultLimitNOFILE=1024000" "$TEMP_SYSTEM_CONF"

    # بهینه‌سازی limits.conf
    if [ -f "$LIMITS_CONF" ]; then
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

    # بهینه‌سازی sysctl.d/local.conf
    cat <<EOF | sudo tee "$SYSCTL_CONF"
# max open files
fs.file-max = 1024000
EOF
    echo "Added sysctl settings to $SYSCTL_CONF"

    # اعمال تغییرات sysctl
    sudo sysctl --system
    echo "Sysctl changes applied."
}

# تابع نصب x-ui
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

# تابع غیرفعال‌سازی IPv6
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

# اجرای گزینه انتخاب شده
case $server_choice in
    1)
        # 6to4 multi server
        echo "Which server is this?"
        echo "1) Outside"
        echo "2) Iran1"
        echo "3) Iran2"
        read -p "Select an option (1, 2, or 3): " server_option

        if [ "$server_option" -eq 1 ]; then
            read -p "Enter the IP Outside: " ipkharej1
            read -p "Enter the IP Iran1: " ipiran1
            read -p "Enter the IP Iran2: " ipiran2

            cat <<EOL > /etc/rc.local
#!/bin/bash
# تنظیمات تونل برای اولین سرور ایران
ip tunnel add 6to4_To_IR1 mode sit remote $ipiran1 local $ipkharej1
ip -6 addr add 2002:480:1f10:e1f::2/64 dev 6to4_To_IR1
ip link set 6to4_To_IR1 mtu 1480
ip link set 6to4_To_IR1 up

ip -6 tunnel add GRE6Tun_To_IR1 mode ip6gre remote 2002:480:1f10:e1f::1 local 2002:480:1f10:e1f::2
ip addr add 10.10.10.2/30 dev GRE6Tun_To_IR1
ip link set GRE6Tun_To_IR1 mtu 1436
ip link set GRE6Tun_To_IR1 up

# تنظیمات تونل برای دومین سرور ایران
ip tunnel add 6to4_To_IR2 mode sit remote $ipiran2 local $ipkharej1
ip -6 addr add 2002:480:1f10:e1f::3/64 dev 6to4_To_IR2
ip link set 6to4_To_IR2 mtu 1480
ip link set 6to4_To_IR2 up

ip -6 tunnel add GRE6Tun_To_IR2 mode ip6gre remote 2002:480:1f10:e1f::4 local 2002:480:1f10:e1f::3
ip addr add 10.10.10.4/30 dev GRE6Tun_To_IR2
ip link set GRE6Tun_To_IR2 mtu 1436
ip link set GRE6Tun_To_IR2 up
EOL

            echo "Commands executed for the outside server with Iran1 and Iran2."
        elif [ "$server_option" -eq 2 ]; then
            echo "Iran1 server selected."
        elif [ "$server_option" -eq 3 ]; then
            echo "Iran2 server selected."
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

            eval "$commands"
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
EOF
            )

            eval "$commands"
            setup_rc_local "$commands"
            echo "Commands executed for the Iran server."
        else
            echo "Invalid option. Please select 1 or 2."
        fi
        ;;
    3)
        # حذف تونل‌ها
        echo "Removing tunnels..."
        sudo ip tunnel del 6to4_To_IR
        sudo ip -6 tunnel del GRE6Tun_To_IR
        echo "Tunnels removed."
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
