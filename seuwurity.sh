#!/bin/bash
# Proxmox Security Hardening Script 
# Enhanced with AppArmor, Kernel Hardening, Auditd, and more
# Backup configs before running!

set -e

echo "=== Proxmox Security Hardening ==="
echo "Creating backup of configs..."
BACKUP_DIR="/root/security-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp /etc/ssh/sshd_config "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/default/grub "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/sysctl.conf "$BACKUP_DIR/" 2>/dev/null || true

# Show support message
show_support_message() {
    # Don't show banner if we're in a SSH session (remote execution)
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ "$TERM" = "dumb" ] || [ "$SHOW_BANNER" = "false" ]; then
        return
    fi
    
    echo "============================================================================"
    echo "  Proxmox VE Security Hardening Tool"
    echo "  Made by Nico Schmidt (baGStube_Nico)"
    echo ""
    echo "  Features: Hardens your Proxmox VE System with AppArmor, Kernel Hardening, Auditd, and more"
    echo ""
    echo "  Please consider supporting this script development:"
    echo "  💖 Ko-fi: ko-fi.com/bagstube_nico"
    echo "  🔗 Links: linktr.ee/bagstube_nico"
    echo "============================================================================"
    echo ""
}

# Show the Support message
show_support_message

# 0. Install sudo and create users
echo "Installing required packages..."
apt update && apt install -y sudo pwgen apparmor apparmor-utils auditd audispd-plugins unattended-upgrades apt-listchanges lynis git fail2ban

echo "Creating ServerAdmin user with random suffix..."
RAND=$(shuf -i 100000-999999 -n1)
SERVERADMIN="ServerAdmin_${RAND}"

# Generate secure 32-character password
SERVERADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 32)

# Create user with password
adduser --gecos "Server Administrator" --disabled-password "$SERVERADMIN"
echo "$SERVERADMIN:$SERVERADMIN_PASS" | chpasswd
usermod -aG sudo "$SERVERADMIN"

# Add ServerAdmin as Proxmox Administrator
pveum user add $SERVERADMIN@pam -comment "Proxmox Administrator"
pveum aclmod / -user $SERVERADMIN@pam -role Administrator

# Save credentials securely
cat > /root/serveradmin_credentials.txt <<EOF
===========================================
SERVER ADMIN CREDENTIALS
===========================================
Username: $SERVERADMIN
Password: $SERVERADMIN_PASS
Created:  $(date)
Role:     Proxmox Administrator
===========================================
KEEP THIS FILE SECURE AND DELETE AFTER SAVING TO PASSWORD MANAGER!
EOF
chmod 600 /root/serveradmin_credentials.txt

echo "✓ Created user: $SERVERADMIN with Proxmox Administrator role"
echo "✓ Credentials saved to: /root/serveradmin_credentials.txt"
echo ""

# 1. Enable AppArmor
echo "Enabling AppArmor..."
systemctl enable --now apparmor
aa-enforce /etc/apparmor.d/* 2>/dev/null || true
echo "✓ AppArmor enabled"

# 2. Disable unnecessary services
echo "Disabling unnecessary services..."
systemctl disable --now bluetooth cups avahi-daemon 2>/dev/null || true
echo "✓ Unnecessary services disabled"

# 3. Disable rpcbind
echo "Disabling rpcbind..."
systemctl disable --now rpcbind.target rpcbind.socket rpcbind.service 2>/dev/null || true
update-rc.d rpcbind disable 2>/dev/null || true

# 4. Kernel Hardening
echo "Hardening kernel parameters..."
cat >> /etc/sysctl.conf <<'EOF'

# === Security Hardening ===
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
EOF
sysctl -p
echo "✓ Kernel hardened"

# 5. Disable IPv6
echo "Disabling IPv6..."
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="nomodeset ipv6.disable=1 quiet"/' /etc/default/grub
update-grub
echo 'inet_protocols = ipv4' >> /etc/postfix/main.cf

# 6. Auditd for Logging
echo "Configuring auditd..."
systemctl enable --now auditd
auditctl -w /etc/passwd -p wa -k passwd_changes
auditctl -w /etc/shadow -p wa -k shadow_changes
auditctl -w /etc/ssh/sshd_config -p wa -k sshd_config
auditctl -w /etc/sudoers -p wa -k sudoers_changes
auditctl -w /var/log/auth.log -p wa -k auth_log
echo "✓ Auditd configured"

# 7. Secure SSH
echo "Hardening SSH..."
cat >> /etc/ssh/sshd_config <<EOF

# === Security Hardening ===
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
Port 2222
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
Protocol 2
AllowUsers $SERVERADMIN
PermitEmptyPasswords no
X11Forwarding no
MaxStartups 3:50:10
LoginGraceTime 30
Compression no
TCPKeepAlive no
AllowAgentForwarding no
AllowTcpForwarding no
EOF

# Setup SSH keys for new user
echo "Setting up SSH directories for ServerAdmin..."
mkdir -p /home/$SERVERADMIN/.ssh
chmod 700 /home/$SERVERADMIN/.ssh
touch /home/$SERVERADMIN/.ssh/authorized_keys
chmod 600 /home/$SERVERADMIN/.ssh/authorized_keys
chown -R $SERVERADMIN:$SERVERADMIN /home/$SERVERADMIN/.ssh

systemctl restart sshd
echo "✓ SSH hardened (Port: 2222)"

# 8. Sudo Hardening
echo "Configuring sudo timeout..."
cat > /etc/sudoers.d/hardening <<EOF
Defaults timestamp_timeout=5
Defaults passwd_tries=3
Defaults logfile=/var/log/sudo.log
EOF
chmod 440 /etc/sudoers.d/hardening
echo "✓ Sudo hardened"

# 9. Automatic Updates
echo "Configuring unattended-upgrades..."
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF
echo "✓ Automatic updates enabled"

# 10. Setup iptables firewall with rate limiting
echo "Configuring iptables..."
# Install iptables-persistent to save rules
DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent

iptables -F
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# SSH with rate limiting
iptables -A INPUT -p tcp --dport 2222 -m state --state NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 2222 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 2222 -m state --state NEW -j ACCEPT

# Proxmox Web UI with rate limiting
iptables -A INPUT -p tcp --dport 8006 -m state --state NEW -m recent --set --name WEBUI
iptables -A INPUT -p tcp --dport 8006 -m state --state NEW -m recent --update --seconds 60 --hitcount 10 --name WEBUI -j DROP
iptables -A INPUT -p tcp --dport 8006 -j ACCEPT

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Save iptables rules
iptables-save > /etc/iptables/rules.v4
echo "✓ Firewall configured with rate limiting"

# 11. Configure Fail2Ban
echo "Configuring Fail2Ban..."

# Create fail2ban directory if it doesn't exist
mkdir -p /etc/fail2ban/filter.d

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 2222

[proxmox]
enabled = true
port = 8006
filter = proxmox
logpath = /var/log/daemon.log

[pve-dashboard]
enabled = true
port = 8006
filter = pve-dashboard
logpath = /var/log/pveproxy/access.log
maxretry = 5
bantime = 7200
EOF

cat > /etc/fail2ban/filter.d/proxmox.conf <<EOF
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST>
ignoreregex =
EOF

cat > /etc/fail2ban/filter.d/pve-dashboard.conf <<EOF
[Definition]
failregex = ^<HOST> -.*POST /api2/json/access/ticket HTTP.*401
ignoreregex =
EOF

systemctl enable --now fail2ban
systemctl restart fail2ban
echo "✓ Fail2Ban configured"

# 12. Bind Proxmox services to localhost (optional - commented out)
# echo "Binding Proxmox services to localhost..."
# echo 'LISTEN_IP="127.0.0.1"' >> /etc/default/pveproxy
# systemctl restart pveproxy
# systemctl mask --now spiceproxy

# 13. Enable Proxmox firewall
echo "Enabling Proxmox firewall..."
pvesh set /cluster/firewall/options --enable 1 2>/dev/null || echo "⚠ Proxmox firewall config requires manual setup"

# 14. SSH dynamic whitelist
echo "Setting up SSH dynamic whitelist..."
cat >> /home/$SERVERADMIN/.bash_profile <<'PROFILEEOF'
# Auto-whitelist SSH source
if [ -n "$SSH_CLIENT" ]; then
    sudo iptables -I INPUT -s ${SSH_CLIENT%% *}/32 -j ACCEPT 2>/dev/null || true
fi
PROFILEEOF

cat >> /home/$SERVERADMIN/.bash_logout <<'LOGOUTEOF'
# Remove SSH whitelist on logout
if [ -n "$SSH_CLIENT" ]; then
    sudo iptables -D INPUT -s ${SSH_CLIENT%% *}/32 -j ACCEPT 2>/dev/null || true
fi
LOGOUTEOF

chown $SERVERADMIN:$SERVERADMIN /home/$SERVERADMIN/.bash_profile /home/$SERVERADMIN/.bash_logout 2>/dev/null || true

# 15. Install Proxmox Auto-Update Script (RECOMMENDED)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 RECOMMENDED: Proxmox Auto-Update Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Would you like to install the Proxmox Auto-Update Script?"
echo "This script will automate system updates and notify you when reboots are required."
echo ""
echo "Features:"
echo "  • Automatic sequential updates of all cluster nodes"
echo "  • Email notifications with update status"
echo "  • Reboot requirement detection"
echo "  • Detailed logging of all actions"
echo "  • No automatic reboots - you maintain control"
echo ""
read -p "Install Proxmox Auto-Update Script? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing Proxmox Auto-Update Script..."
    
    # Clone the repository
    cd /root
    git clone https://github.com/MrMasterbay/proxmox-auto-update.git
    cd proxmox-auto-update
    chmod +x proxmox-auto-update.sh
    
    # Basic configuration
    echo ""
    echo "Configuring Auto-Update Script..."
    read -p "Enter email address for notifications (or press Enter for root@localhost): " EMAIL_ADDRESS
    EMAIL_ADDRESS=${EMAIL_ADDRESS:-root@localhost}
    
    # Update email in script
    sed -i "s/MAIL_TO=\"root@localhost\"/MAIL_TO=\"$EMAIL_ADDRESS\"/" /root/proxmox-auto-update/proxmox-auto-update.sh
    
    echo ""
    echo "✓ Proxmox Auto-Update Script installed!"
    echo ""
    echo "To schedule automatic updates, add to crontab:"
    echo "  Daily at 3 AM:   0 3 * * * /root/proxmox-auto-update/proxmox-auto-update.sh"
    echo "  Weekly Sunday:   0 3 * * 0 /root/proxmox-auto-update/proxmox-auto-update.sh"
    echo ""
    echo "Test with: /root/proxmox-auto-update/proxmox-auto-update.sh"
    echo "Logs at:   /var/log/proxmox-cluster-auto-update.log"
    echo ""
    echo "More info: https://github.com/MrMasterbay/proxmox-auto-update"
else
    echo ""
    echo "Skipped Auto-Update Script installation."
    echo "You can install it later from:"
    echo "https://github.com/MrMasterbay/proxmox-auto-update"
fi

# 16. Lynis Security Audit
echo ""
echo "Running Lynis security audit..."
lynis audit system --quick > "$BACKUP_DIR/lynis-report.txt" 2>&1 || true
echo "✓ Lynis report saved to: $BACKUP_DIR/lynis-report.txt"

echo ""
echo "=== Hardening Complete ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CREATED USER:"
echo "  • $SERVERADMIN (Proxmox Administrator)"
echo ""
echo "CREDENTIALS:"
echo "  → /root/serveradmin_credentials.txt"
echo ""
cat /root/serveradmin_credentials.txt
echo ""
echo "HARDENING APPLIED:"
echo "  ✓ AppArmor enabled"
echo "  ✓ Kernel parameters hardened"
echo "  ✓ Auditd configured"
echo "  ✓ SSH hardened (Port 2222)"
echo "  ✓ Sudo timeout configured"
echo "  ✓ Automatic updates enabled"
echo "  ✓ Firewall with rate limiting"
echo "  ✓ Fail2Ban configured"
echo "  ✓ Unnecessary services disabled"
echo "  ✓ IPv6 disabled"
echo "  ✓ ServerAdmin configured as Proxmox Administrator"
if [ -f "/root/proxmox-auto-update/proxmox-auto-update.sh" ]; then
    echo "  ✓ Proxmox Auto-Update Script installed"
fi
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. SAVE the ServerAdmin credentials to your password manager"
echo ""
echo "2. Test SSH connection on NEW PORT:"
echo "   ssh -p 2222 $SERVERADMIN@<your-server-ip>"
echo ""
echo "3. Test Proxmox Web UI login:"
echo "   https://<your-server-ip>:8006"
echo "   Username: $SERVERADMIN"
echo ""
echo "4. After successful test, delete credentials file:"
echo "   shred -u /root/serveradmin_credentials.txt"
echo ""
if [ -f "/root/proxmox-auto-update/proxmox-auto-update.sh" ]; then
    echo "5. Configure Auto-Update cron job:"
    echo "   crontab -e"
    echo "   Add: 0 3 * * 0 /root/proxmox-auto-update/proxmox-auto-update.sh"
    echo ""
    echo "6. Review Lynis report:"
else
    echo "5. Review Lynis report:"
fi
echo "   less $BACKUP_DIR/lynis-report.txt"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 REBOOT REQUIRED for IPv6 and kernel changes:"
echo "   reboot"
echo ""
echo "Backup: $BACKUP_DIR/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Backup: $BACKUP_DIR/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
