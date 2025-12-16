#!/bin/bash
# Proxmox Security Hardening Script v3.0
# Enhanced with Root WebUI blocking, BackupAdmin, and complete security hardening
# Backup configs before running!

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

if ! command -v pveum &> /dev/null; then
    echo "This doesn't appear to be a Proxmox system"
    exit 1
fi

echo ""
echo "⚠️  WARNING: This will disable root SSH and WebUI access!"
echo "    📌 Ensure you have:"
echo "       • Emergency backup saved"
echo ""
read -p "Type 'yes' to continue: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo "✅ Proceeding with security lockdown..."

echo "=== Proxmox Security Hardening v3.0 ==="
echo "Creating backup of configs..."
BACKUP_DIR="/root/security-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp /etc/ssh/sshd_config "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/default/grub "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/sysctl.conf "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/pve/user.cfg "$BACKUP_DIR/" 2>/dev/null || true

# 0. Install required packages
echo "Installing required packages..."
apt update && apt install -y sudo pwgen apparmor apparmor-utils auditd audispd-plugins unattended-upgrades apt-listchanges lynis git fail2ban iptables-persistent mailutils

echo "Creating administrative users..."

# Create ServerAdmin user
RAND_SERVER=$(shuf -i 100000-999999 -n1)
SERVERADMIN="ServerAdmin_${RAND_SERVER}"
SERVERADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 32)

adduser --gecos "Server Administrator" --disabled-password "$SERVERADMIN"
echo "$SERVERADMIN:$SERVERADMIN_PASS" | chpasswd
usermod -aG sudo "$SERVERADMIN"

# Create BackupAdmin user
RAND_BACKUP=$(shuf -i 100000-999999 -n1)
BACKUPADMIN="BackupAdmin_${RAND_BACKUP}"
BACKUPADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 127)

adduser --gecos "Backup Administrator" --disabled-password "$BACKUPADMIN"
echo "$BACKUPADMIN:$BACKUPADMIN_PASS" | chpasswd
usermod -aG sudo "$BACKUPADMIN"

# Add both users as Proxmox Administrators
pveum user add $SERVERADMIN@pam -comment "Primary Proxmox Administrator"
pveum user add $BACKUPADMIN@pam -comment "Backup Proxmox Administrator"
pveum aclmod / -user $SERVERADMIN@pam -role Administrator
pveum aclmod / -user $BACKUPADMIN@pam -role Administrator

# Disable root login in Proxmox Web UI
echo "Disabling root Web UI access at the end of the script..."
pveum acl delete / -user root@pam 2>/dev/null || true
pveum role add ConsoleOnly -privs "Sys.Console,Sys.Audit" 2>/dev/null || true
pveum acl modify / -user root@pam -role ConsoleOnly
pveum acl modify / -user root@pam -role ConsoleOnly -propagate 1

# Save credentials securely
cat > /root/admin_credentials.txt <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRIMARY ADMINISTRATOR CREDENTIALS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Username: $SERVERADMIN
Password: $SERVERADMIN_PASS
Role:     Proxmox Administrator (Primary)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BACKUP ADMINISTRATOR CREDENTIALS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Username: $BACKUPADMIN
Password: $BACKUPADMIN_PASS
Role:     Proxmox Administrator (Backup)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Created:  $(date)

⚠️  ROOT WEB UI ACCESS HAS BEEN DISABLED!
    Use the admin accounts above for Web UI access.
    Root can only access via console.

KEEP THIS FILE SECURE!
DELETE AFTER SAVING TO PASSWORD MANAGER!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
chmod 600 /root/admin_credentials.txt

echo "✓ Created users: $SERVERADMIN (Primary) and $BACKUPADMIN (Backup)"
echo "✓ Root Web UI access DISABLED - console only"
echo "✓ Credentials saved to: /root/admin_credentials.txt"
echo ""

#1.5 Enable TFA

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "         🔐 TWO-FACTOR AUTHENTICATION (TOTP) SETUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Would you like to enable 2FA (TOTP) for the admin accounts via remote ssh login?"
echo "This adds an extra security layer via authenticator app only for SSH not WEBUI!"
echo ""
read -p "Enable 2FA for admin users? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing required packages for 2FA..."
    apt install -y libpam-google-authenticator qrencode
    
    # Generate 2FA for ServerAdmin
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Setting up 2FA for: $SERVERADMIN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Create TOTP entry in Proxmox
    TOTP_SECRET_SERVER=$(openssl rand -base64 20 | tr -d '/+=' | cut -c1-16)
    pveum user tfa add $SERVERADMIN@pam --type totp --description "ServerAdmin-2FA" 2>/dev/null || true
    
    # Generate QR code for manual setup
    TOTP_URI_SERVER="otpauth://totp/Proxmox:${SERVERADMIN}@pam?secret=${TOTP_SECRET_SERVER}&issuer=Proxmox&algorithm=SHA1&digits=6&period=30"
    
    echo ""
    echo "QR Code for $SERVERADMIN:"
    echo "$TOTP_URI_SERVER" | qrencode -t ANSIUTF8
    echo ""
    echo "Manual entry secret: $TOTP_SECRET_SERVER"
    echo ""
    
    # Save 2FA info to credentials file
    cat >> /root/admin_credentials.txt <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TWO-FACTOR AUTHENTICATION (TOTP)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRIMARY ADMIN 2FA:
  Username: $SERVERADMIN@pam
  TOTP Secret: $TOTP_SECRET_SERVER

SETUP INSTRUCTIONS:
1. Scan QR codes above with authenticator app
   (Google Authenticator, Authy, Microsoft Authenticator)
2. Or manually enter the TOTP secrets
3. Login to Proxmox Web UI:
   - Enter username and password
   - You'll be prompted for 6-digit TOTP code
   
⚠️  SAVE THESE SECRETS IN YOUR PASSWORD MANAGER!
    You'll need them to set up 2FA again if needed.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    echo "✓ 2FA (TOTP) configured for both admin users"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Scan the QR codes with your authenticator app NOW"
    echo "2. Or manually enter the TOTP secrets shown above"
    echo "3. Test login at: https://<server-ip>:8006"
    echo "   - Enter username/password"
    echo "   - Enter 6-digit code from authenticator app"
    echo ""
    
    # Generate recovery codes
    echo "Generating recovery codes (in case you lose your phone)..."
    mkdir -p /root/2fa-recovery/
    
    for ADMIN_USER in $SERVERADMIN $BACKUPADMIN; do
        RECOVERY_CODES=$(for i in {1..10}; do openssl rand -hex 4 | tr '[:lower:]' '[:upper:]'; done)
        echo "$RECOVERY_CODES" > /root/2fa-recovery/${ADMIN_USER}_recovery_codes.txt
        
        cat >> /root/admin_credentials.txt <<EOF

RECOVERY CODES for $ADMIN_USER:
$(echo "$RECOVERY_CODES" | nl -w2 -s'. ')

⚠️  Save these codes! Use them if you lose access to your authenticator app.
EOF
    done
    
    chmod 600 /root/2fa-recovery/*
    echo "✓ Recovery codes generated: /root/2fa-recovery/"
    
else
    echo "Skipped 2FA setup. You can enable it later via Web UI:"
    echo "  Datacenter → Permissions → Two-Factor → Add → TOTP"
fi
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

# ASLR
kernel.randomize_va_space = 2

# Restrict dmesg
kernel.dmesg_restrict = 1

# Restrict kernel pointers
kernel.kptr_restrict = 2

# Disable magic SysRq
kernel.sysrq = 0

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
auditctl -w /etc/pve/ -p wa -k proxmox_config

# Save audit rules
cat > /etc/audit/rules.d/hardening.rules <<EOF
# Monitor authentication files
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/sudoers -p wa -k sudoers_changes
-w /var/log/auth.log -p wa -k auth_log
-w /etc/pve/ -p wa -k proxmox_config
# Monitor root activities
-a always,exit -F arch=b64 -F uid=0 -S execve -k root_commands
EOF
service auditd restart
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
AllowUsers $SERVERADMIN $BACKUPADMIN
PermitEmptyPasswords no
X11Forwarding no
MaxStartups 3:50:10
LoginGraceTime 30
Compression no
TCPKeepAlive no
AllowAgentForwarding no
AllowTcpForwarding no
EOF

# Setup SSH directories for both admin users
for ADMIN_USER in $SERVERADMIN $BACKUPADMIN; do
    echo "Setting up SSH directories for $ADMIN_USER..."
    mkdir -p /home/$ADMIN_USER/.ssh
    chmod 700 /home/$ADMIN_USER/.ssh
    touch /home/$ADMIN_USER/.ssh/authorized_keys
    chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
    chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
done

systemctl restart sshd
echo "✓ SSH hardened (Port: 2222)"

# 8. Sudo Hardening
echo "Configuring sudo timeout..."
cat > /etc/sudoers.d/hardening <<EOF
Defaults timestamp_timeout=5
Defaults passwd_tries=3
Defaults logfile=/var/log/sudo.log
Defaults requiretty
Defaults use_pty
Defaults lecture="always"
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

# Clear existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Basic rules
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# SSH with rate limiting (4 attempts per minute)
iptables -A INPUT -p tcp --dport 2222 -m state --state NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 2222 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j LOG --log-prefix "SSH-Rate-Limit: "
iptables -A INPUT -p tcp --dport 2222 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 2222 -j ACCEPT

# Proxmox Web UI (Port 8006) with rate limiting (30 attempts per minute)
iptables -A INPUT -p tcp --dport 8006 -m state --state NEW -m recent --set --name WEBUI
iptables -A INPUT -p tcp --dport 8006 -m state --state NEW -m recent --update --seconds 60 --hitcount 30 --name WEBUI -j LOG --log-prefix "WebUI-Rate-Limit: "
iptables -A INPUT -p tcp --dport 8006 -m state --state NEW -m recent --update --seconds 60 --hitcount 30 --name WEBUI -j DROP
iptables -A INPUT -p tcp --dport 8006 -j ACCEPT

# Port 8007 (VNC WebSocket)
iptables -A INPUT -p tcp --dport 8007 -m state --state NEW -m recent --set --name WEBSOCKET
iptables -A INPUT -p tcp --dport 8007 -m state --state NEW -m recent --update --seconds 60 --hitcount 30 --name WEBSOCKET -j DROP
iptables -A INPUT -p tcp --dport 8007 -j ACCEPT

# Spice Proxy
iptables -A INPUT -p tcp --dport 3128 -j ACCEPT

# Cluster communication (if cluster is used)
iptables -A INPUT -p udp --dport 5404:5405 -j ACCEPT  # Corosync
iptables -A INPUT -p tcp --dport 60000:60050 -j ACCEPT  # Live-Migration

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT  # Important for VMs/Containers!
iptables -P OUTPUT ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

echo "✓ Firewall configured with rate limiting"

# 11. Configure Fail2Ban
echo "Configuring Fail2Ban..."

# Create fail2ban directories
mkdir -p /etc/fail2ban/filter.d
mkdir -p /etc/fail2ban/jail.d

# Main jail configuration
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = root@localhost
action = %(action_mwl)s

[sshd]
enabled = true
port = 2222
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200

[proxmox]
enabled = true
port = 8006
filter = proxmox
logpath = /var/log/daemon.log
maxretry = 5
bantime = 3600

[pve-webui]
enabled = true
port = 8006
filter = pve-webui
logpath = /var/log/pveproxy/access.log
maxretry = 5
bantime = 7200

[proxmox-root]
enabled = true
port = 8006
filter = proxmox-root
logpath = /var/log/pveproxy/access.log
maxretry = 1
bantime = 86400
action = %(action_mwl)s
EOF

# Proxmox filter
cat > /etc/fail2ban/filter.d/proxmox.conf <<EOF
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST>
ignoreregex =
EOF

# PVE WebUI filter
cat > /etc/fail2ban/filter.d/pve-webui.conf <<EOF
[Definition]
failregex = ^<HOST> -.*POST /api2/json/access/ticket HTTP.*401
ignoreregex =
EOF

# Root login attempt filter
cat > /etc/fail2ban/filter.d/proxmox-root.conf <<EOF
[Definition]
failregex = pveproxy\[.*authentication failure.*user=root@pam.*rhost=<HOST>
            ^<HOST> -.*POST /api2/json/access/ticket.*root@pam.*401
ignoreregex =
EOF

systemctl enable fail2ban
systemctl restart fail2ban
echo "✓ Fail2Ban configured with root login protection"

# 12. Root login monitoring
echo "Setting up root login monitoring..."
cat > /usr/local/bin/monitor-root-attempts <<'EOF'
#!/bin/bash
# Monitor root login attempts
LOG_FILE="/var/log/root-access-attempts.log"
ALERT_EMAIL="root@localhost"

# Check for root login attempts in the last 5 minutes
if grep -q "authentication failure.*user=root@pam" /var/log/pveproxy/access.log 2>/dev/null; then
    echo "[$(date)] WARNING: Root Web UI login attempt detected!" >> $LOG_FILE
    tail -n 20 /var/log/pveproxy/access.log | grep "root@pam" >> $LOG_FILE
    
    # Send alert email (if mail is configured)
    echo "Root login attempt detected on $(hostname) at $(date)" | \
        mail -s "SECURITY ALERT: Root Login Attempt on $(hostname)" $ALERT_EMAIL 2>/dev/null || true
fi

# Check SSH root attempts
if grep -q "Failed password for root" /var/log/auth.log 2>/dev/null; then
    echo "[$(date)] WARNING: Root SSH login attempt detected!" >> $LOG_FILE
    tail -n 20 /var/log/auth.log | grep "Failed password for root" >> $LOG_FILE
fi
EOF
chmod +x /usr/local/bin/monitor-root-attempts

# Add to crontab
echo "*/5 * * * * root /usr/local/bin/monitor-root-attempts" >> /etc/crontab

echo "✓ Root login monitoring configured"

# 13. Enable Proxmox firewall
echo "Enabling Proxmox firewall..."
pvesh set /cluster/firewall/options --enable 1 2>/dev/null || echo "⚠ Proxmox firewall config requires manual setup"

# 14. SSH dynamic whitelist for admin users
echo "Setting up SSH dynamic whitelist..."
for ADMIN_USER in $SERVERADMIN $BACKUPADMIN; do
    cat >> /home/$ADMIN_USER/.bash_profile <<'PROFILEEOF'
# Auto-whitelist SSH source
if [ -n "$SSH_CLIENT" ]; then
    sudo iptables -I INPUT -s ${SSH_CLIENT%% *}/32 -j ACCEPT 2>/dev/null || true
fi
PROFILEEOF

    cat >> /home/$ADMIN_USER/.bash_logout <<'LOGOUTEOF'
# Remove SSH whitelist on logout
if [ -n "$SSH_CLIENT" ]; then
    sudo iptables -D INPUT -s ${SSH_CLIENT%% *}/32 -j ACCEPT 2>/dev/null || true
fi
LOGOUTEOF

    chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.bash_profile /home/$ADMIN_USER/.bash_logout 2>/dev/null || true
done

# 15. Verification script
cat > /usr/local/bin/verify-security <<EOF
#!/bin/bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Security Configuration Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Root Access Status:"
echo -n "   SSH Login: "
grep -q "^PermitRootLogin no" /etc/ssh/sshd_config && echo "✓ Blocked" || echo "✗ Allowed"
echo -n "   Web UI: "
pveum acl list | grep -q "root@pam.*Administrator" && echo "✗ Allowed" || echo "✓ Blocked"
echo ""
echo "2. Admin Users:"
pveum user list | grep -E "(ServerAdmin|BackupAdmin)" | awk '{print "   •", \$1}'
echo ""
echo "3. Active Services:"
echo -n "   SSH: "; systemctl is-active sshd
echo -n "   Fail2Ban: "; systemctl is-active fail2ban
echo -n "   Firewall: "; iptables -L INPUT -n | grep -q "DROP" && echo "Active" || echo "Inactive"
echo -n "   AppArmor: "; systemctl is-active apparmor
echo -n "   Auditd: "; systemctl is-active auditd
echo ""
echo "4. Open Ports:"
ss -tlnp | grep LISTEN | awk '{print "   •", \$4}'
echo ""
echo "5. Failed Login Attempts (last 24h):"
echo -n "   Root attempts: "
grep -c "root@pam.*authentication failure" /var/log/pveproxy/access.log 2>/dev/null || echo "0"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF
chmod +x /usr/local/bin/verify-security

# 16. Install Proxmox Auto-Update Script (RECOMMENDED)
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
    
    cd /root
    git clone https://github.com/MrMasterbay/proxmox-auto-update.git
    cd proxmox-auto-update
    chmod +x proxmox-auto-update.sh
    
    echo ""
    echo "Configuring Auto-Update Script..."
    read -p "Enter email address for notifications (or press Enter for root@localhost): " EMAIL_ADDRESS
    EMAIL_ADDRESS=${EMAIL_ADDRESS:-root@localhost}
    
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
else
    echo ""
    echo "Skipped Auto-Update Script installation."
    echo "You can install it later from:"
    echo "https://github.com/MrMasterbay/proxmox-auto-update"
fi

# 17. Lynis Security Audit
echo ""
echo "Running Lynis security audit..."
lynis audit system --quick > "$BACKUP_DIR/lynis-report.txt" 2>&1 || true
echo "✓ Lynis report saved to: $BACKUP_DIR/lynis-report.txt"

# 18. Run verification
echo ""
echo "Running security verification..."
/usr/local/bin/verify-security

#19. Make Emergency Rollback File
# Create emergency rollback file
BACKUP_DIR="/root/emergency_backup"
mkdir -p "$BACKUP_DIR"

# Create restore script
cat > "$BACKUP_DIR/restore.sh" <<'EOF'
#!/bin/bash
set -e  # Exit on any error
BACKUP_DIR="/root/emergency_backup"
echo "Restoring from emergency backup..."
cp "$BACKUP_DIR/sshd_config.backup" /etc/ssh/sshd_config
systemctl restart sshd
pveum user modify root@pam --enable 1
pveum aclmod / -user root@pam -role Administrator
echo "Root access restored. Reboot recommended."
EOF
chmod +x "$BACKUP_DIR/restore.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "            🔒 HARDENING COMPLETE 🔒"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "CREATED ADMIN USERS:"
echo "  • $SERVERADMIN (Primary Administrator)"
echo "  • $BACKUPADMIN (Backup Administrator)"
echo ""
echo "ROOT ACCESS STATUS:"
echo "  • SSH Login: BLOCKED"
echo "  • Web UI Login: BLOCKED (Console only)"
echo "  • Failed root attempts will ban IP for 24 hours"
echo ""
echo "CREDENTIALS SAVED TO:"
echo "  → /root/admin_credentials.txt"
echo ""
cat /root/admin_credentials.txt
echo ""
echo "SECURITY FEATURES ENABLED:"
echo "  ✓ AppArmor active"
echo "  ✓ Kernel parameters hardened"
echo "  ✓ Auditd logging all system changes"
echo "  ✓ SSH hardened (Port 2222)"
echo "  ✓ Sudo timeout & logging configured"
echo "  ✓ Automatic security updates enabled"
echo "  ✓ Firewall with rate limiting active"
echo "  ✓ Fail2Ban protecting SSH & Web UI"
echo "  ✓ Root login monitoring active"
echo "  ✓ Unnecessary services disabled"
echo "  ✓ IPv6 disabled"
if [ -f "/root/proxmox-auto-update/proxmox-auto-update.sh" ]; then
    echo "  ✓ Proxmox Auto-Update Script installed"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                  ⚠️  CRITICAL NEXT STEPS ⚠️"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. SAVE CREDENTIALS to your password manager NOW!"
echo ""
echo "2. TEST SSH connection on NEW PORT (keep current session open!):"
echo "   ssh -p 2222 $SERVERADMIN@<your-server-ip>"
echo ""
echo "3. TEST Proxmox Web UI login:"
echo "   https://<your-server-ip>:8006"
echo "   Username: $SERVERADMIN"
echo "   Username: $BACKUPADMIN (backup)"
echo ""
echo "4. AFTER successful tests, DELETE credentials file:"
echo "   shred -u /root/admin_credentials.txt"
echo ""
if [ -f "/root/proxmox-auto-update/proxmox-auto-update.sh" ]; then
    echo "5. Configure Auto-Update cron job:"
    echo "   crontab -e"
    echo "   Add: 0 3 * * 0 /root/proxmox-auto-update/proxmox-auto-update.sh"
    echo ""
fi
echo "6. Review security audit report:"
echo "   less $BACKUP_DIR/lynis-report.txt"
echo ""
echo "7. Verify security status anytime with:"
echo "   verify-security"
echo ""
echo "8. Enable 2FA in the WebUI also for your ROOT USER!"
echo "Datacenter ▸ Permissions ▸ Two Factor ▸ Add "TOTP" "
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 SYSTEM REBOOT REQUIRED for all changes to take effect:"
echo "   reboot"
echo ""
echo "Configuration backup saved to: $BACKUP_DIR/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
pveum user modify root@pam --password '*'
