#!/bin/bash
# Proxmox Security Hardening Script with User Setup
# Backup configs before running!

set -e

echo "=== Proxmox Security Hardening ==="
echo "Creating backup of configs..."
mkdir -p /root/security-backup-$(date +%Y%m%d)
cp /etc/ssh/sshd_config /root/security-backup-$(date +%Y%m%d)/ 2>/dev/null || true
cp /etc/default/grub /root/security-backup-$(date +%Y%m%d)/ 2>/dev/null || true

# 0. Install sudo and create users
echo "Installing sudo..."
apt update && apt install -y sudo pwgen

echo "Creating pveadmin user..."
adduser --gecos "Proxmox Admin" pveadmin
usermod -aG sudo pveadmin

echo "Creating ServerAdmin user with random suffix..."
RAND=$(shuf -i 100000-999999 -n1)
SERVERADMIN="ServerAdmin_${RAND}"

# Generate secure 32-character password
SERVERADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 32)

# Create user with password
adduser --gecos "Server Administrator" --disabled-password "$SERVERADMIN"
echo "$SERVERADMIN:$SERVERADMIN_PASS" | chpasswd
usermod -aG sudo "$SERVERADMIN"

# Save credentials securely
cat > /root/serveradmin_credentials.txt <<EOF
===========================================
SERVER ADMIN CREDENTIALS
===========================================
Username: $SERVERADMIN
Password: $SERVERADMIN_PASS
Created:  $(date)
===========================================
KEEP THIS FILE SECURE AND DELETE AFTER SAVING TO PASSWORD MANAGER!
EOF
chmod 600 /root/serveradmin_credentials.txt

echo "✓ Created users: pveadmin and $SERVERADMIN"
echo "✓ Credentials saved to: /root/serveradmin_credentials.txt"
echo ""

# 1. Disable rpcbind
echo "Disabling rpcbind..."
systemctl disable --now rpcbind.target rpcbind.socket rpcbind.service 2>/dev/null || true
update-rc.d rpcbind disable 2>/dev/null || true

# 2. Disable IPv6
echo "Disabling IPv6..."
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="nomodeset ipv6.disable=1 quiet"/' /etc/default/grub
update-grub
echo 'inet_protocols = ipv4' >> /etc/postfix/main.cf

# 3. Secure SSH
echo "Hardening SSH..."
cat >> /etc/ssh/sshd_config <<EOF

# Security Hardening
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
Port 2222
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
Protocol 2
EOF

# Setup SSH keys for new users
echo "Setting up SSH directories for new users..."
for USER in pveadmin "$SERVERADMIN"; do
    mkdir -p /home/$USER/.ssh
    chmod 700 /home/$USER/.ssh
    touch /home/$USER/.ssh/authorized_keys
    chmod 600 /home/$USER/.ssh/authorized_keys
    chown -R $USER:$USER /home/$USER/.ssh
done

systemctl restart sshd

# 4. Setup basic iptables firewall
echo "Configuring iptables..."
iptables -F
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p tcp --dport 2222 -m state --state NEW -j ACCEPT  # SSH
iptables -A INPUT -p tcp --dport 8006 -j ACCEPT  # Proxmox Web UI
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Save iptables rules
iptables-save > /etc/iptables.rules

# Auto-load iptables on boot
cat > /etc/network/if-up.d/iptables <<EOF
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF
chmod +x /etc/network/if-up.d/iptables

# 5. Install and configure Fail2Ban
echo "Installing Fail2Ban..."
apt install fail2ban -y

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
EOF

cat > /etc/fail2ban/filter.d/proxmox.conf <<EOF
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST>
ignoreregex =
EOF

systemctl enable --now fail2ban

# 6. Bind Proxmox services to localhost
echo "Binding Proxmox services to localhost..."
echo 'LISTEN_IP="127.0.0.1"' >> /etc/default/pveproxy
systemctl restart pveproxy

# Mask spiceproxy if not needed
systemctl mask --now spiceproxy

# 7. Enable Proxmox firewall
echo "Enabling Proxmox firewall..."
pvesh set /cluster/firewall/options --enable 1

# 8. SSH dynamic whitelist
echo "Setting up SSH dynamic whitelist..."
for USER in pveadmin "$SERVERADMIN"; do
    cat >> /home/$USER/.bash_profile <<'PROFILEEOF'
# Auto-whitelist SSH source
if [ -n "$SSH_CLIENT" ]; then
    sudo iptables -I INPUT -s ${SSH_CLIENT%% *}/32 -j ACCEPT 2>/dev/null || true
fi
PROFILEEOF

    cat >> /home/$USER/.bash_logout <<'LOGOUTEOF'
# Remove SSH whitelist on logout
if [ -n "$SSH_CLIENT" ]; then
    sudo iptables -D INPUT -s ${SSH_CLIENT%% *}/32 -j ACCEPT 2>/dev/null || true
fi
LOGOUTEOF

    chown $USER:$USER /home/$USER/.bash_profile /home/$USER/.bash_logout
done

echo ""
echo "=== Hardening Complete ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CREATED USERS:"
echo "  • pveadmin (set password with: passwd pveadmin)"
echo "  • $SERVERADMIN"
echo ""
echo "CREDENTIALS:"
echo "  → /root/serveradmin_credentials.txt"
echo ""
cat /root/serveradmin_credentials.txt
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. SAVE the ServerAdmin credentials to your password manager"
echo "2. Set password for pveadmin: passwd pveadmin"
echo "3. Test SSH connection on NEW PORT:"
echo "   ssh -p 2222 $SERVERADMIN@host"
echo "   ssh -p 2222 pveadmin@host"
echo ""
echo "4. After successful test, delete credentials file:"
echo "   shred -u /root/serveradmin_credentials.txt"
echo ""
echo "Backup: /root/security-backup-$(date +%Y%m%d)/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
