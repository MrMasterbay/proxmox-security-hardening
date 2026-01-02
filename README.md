# Proxmox Security Hardening Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Debian](https://img.shields.io/badge/Debian-13%20(Trixie)-red.svg)
![Proxmox](https://img.shields.io/badge/Proxmox-VE%209.x-orange.svg)

A comprehensive security hardening script for Proxmox VE servers that implements industry-standard security best practices and automated protection mechanisms.

## 🛡️ Features

### User Management
- **Automated Admin User Creation**: Creates a secure ServerAdmin user with random suffix
- **Strong Password Generation**: 32-character passwords with special characters
- **Proxmox Integration**: Automatically grants Administrator role in Proxmox
- **Root Access Restriction**: Disables direct root login via SSH

### Security Hardening
- **AppArmor**: Enforces mandatory access control policies
- **Kernel Hardening**: Implements sysctl security parameters
- **Auditd**: Comprehensive system auditing and logging
- **Service Minimization**: Disables unnecessary services (bluetooth, cups, avahi)
- **IPv6 Disabled**: Complete IPv6 stack deactivation

### Network Security
- **SSH Hardening**: 
  - Custom port (2222)
  - Key-based authentication
  - Rate limiting
  - User restrictions
- **Firewall Configuration**:
  - iptables with rate limiting
  - Fail2Ban integration
  - Dynamic SSH whitelisting
- **DDoS Protection**: SYN flood protection and connection limits

### Monitoring & Maintenance
- **Automatic Updates**: Unattended security updates via apt
- **Lynis Security Audit**: Generates comprehensive security report
- **Fail2Ban**: Automatic IP blocking for brute force attempts
- **Audit Logging**: Monitors critical system files and configurations

### Optional Features
- **Proxmox Auto-Update Script**: Integration with automated cluster update system
- **Backup Creation**: Automatic backup of all modified configurations

## 📋 Requirements

- Proxmox VE 9.x
- Root access to the server
- Internet connection for package installation
- At least 100MB free disk space

## 🚀 Quick Start

### One-Line Installation

```bash
wget https://raw.githubusercontent.com/MrMasterbay/proxmox-security-hardening/main/seuwurity.sh && chmod +x seuwurity.sh && ./seuwurity.sh
```

### Manual Installation

1. **Download the script**:
```bash
wget https://raw.githubusercontent.com/MrMasterbay/proxmox-security-hardening/main/seuwurity.sh
```

2. **Make it executable**:
```bash
chmod +x seuwurity.sh
```

3. **Run the script**:
```bash
./seuwurity.sh
```

## 📖 What Gets Modified

### System Configuration Files
- `/etc/ssh/sshd_config` - SSH daemon configuration
- `/etc/sysctl.conf` - Kernel parameters
- `/etc/default/grub` - Boot parameters
- `/etc/sudoers.d/hardening` - Sudo security settings
- `/etc/fail2ban/jail.local` - Fail2Ban configuration
- `/etc/iptables/rules.v4` - Firewall rules

### Services Modified
- SSH (moved to port 2222)
- AppArmor (enabled and enforced)
- Auditd (enabled with rules)
- Fail2Ban (configured and enabled)
- Automatic updates (configured)

## 🔐 Security Measures Implemented

### Network Protection
| Feature | Description | Default Setting |
|---------|-------------|-----------------|
| SSH Port | Custom SSH port | 2222 |
| SSH Max Auth Tries | Maximum login attempts | 3 |
| Proxmox Max Auth Tries | Maximum login attempts | 3 |
| Fail2Ban SSH | Ban duration for SSH failures | 24 hours |
| Fail2Ban Proxmox | Ban duration for web UI failures | 24 hours |
| Firewall Rate Limit | SSH connection limit | 4/min |

### Kernel Hardening
- IP spoofing protection
- ICMP redirect blocking
- Source packet routing disabled
- SYN flood protection
- TCP syncookies enabled
- Martian packet logging

### Access Control
- Root login disabled
- Password authentication (with strong passwords)
- Public key authentication enabled
- Sudo timeout: 5 minutes
- Maximum sudo attempts: 3

## 📝 Post-Installation Steps

### 1. Save Credentials
After installation, immediately save the generated credentials:
```bash
cat /root/serveradmin_credentials.txt
```
Store these in your password manager!

### 2. Test SSH Access
Test the new SSH configuration:
```bash
ssh -p 2222 ServerAdmin_XXXXXX@your-server-ip
```

### 3. Test Proxmox Web UI
Access the web interface:
```
https://your-server-ip:8006
Username: ServerAdmin_XXXXXX
Password: [from credentials file]
```

### 4. Secure Cleanup
After confirming access, remove the credentials file:
```bash
shred -u /root/serveradmin_credentials.txt
```

### 5. Configure Auto-Updates (Optional)
If you installed the auto-update script:
```bash
crontab -e
# Add this line for weekly updates on Sunday at 3 AM:
0 3 * * 0 /root/proxmox-auto-update/proxmox-auto-update.sh
```

### 6. Review Security Audit
Check the Lynis security report:
```bash
less /root/security-backup-*/lynis-report.txt
```

### 7. Reboot System
A reboot is required to apply all changes:
```bash
reboot
```

## 🔄 Backup and Recovery

### Automatic Backup
The script automatically creates backups before making changes:
```
/root/security-backup-YYYYMMDD-HHMMSS/
```

### Manual Restoration
To restore original configurations:
```bash
cp /root/security-backup-*/sshd_config /etc/ssh/sshd_config
cp /root/security-backup-*/grub /etc/default/grub
cp /root/security-backup-*/sysctl.conf /etc/sysctl.conf
update-grub
sysctl -p
systemctl restart sshd
```

## ⚠️ Important Notes

### SSH Access
- **NEW SSH PORT**:  22
- **User access**: Only ServerAdmin_XXXXXX and BackupAdmin_XXXXXX allowed
- Always test SSH access before closing your current session!

### Firewall Rules
The script implements strict firewall rules. Only these ports are open:
- **22**: SSH
- **8006**: Proxmox Web UI
- **ICMP**: Ping responses

### Recovery Access
If you lose access:
1. Use Proxmox console (via IPMI/iDRAC/physical access)
2. Login as root directly on the console
3. Check `/root/serveradmin_credentials.txt` for credentials
4. Modify `/etc/ssh/sshd_config` if needed

## 🐛 Troubleshooting

### Cannot Connect via SSH
```bash
# From console, check SSH service
systemctl status sshd

# Verify port 2222 is listening
ss -tlnp | grep 2222

# Check firewall rules
iptables -L -n
```

### Fail2Ban Issues
```bash
# Check Fail2Ban status
systemctl status fail2ban

# View banned IPs
fail2ban-client status sshd
fail2ban-client status proxmox

# Unban an IP
fail2ban-client set sshd unbanip YOUR.IP.ADD.RESS
```

### Web UI Access Problems
```bash
# Check Proxmox proxy
systemctl status pveproxy

# Verify user exists
pveum user list

# Reset user permissions
pveum aclmod / -user ServerAdmin_XXXXXX@pam -role Administrator
```

## 📊 Monitoring

### Check Security Status
```bash
# Run Lynis audit
lynis audit system

# Check audit logs
aureport --summary

# View sudo usage
cat /var/log/sudo.log

# Check failed login attempts
grep "Failed password" /var/log/auth.log
```

### Service Status
```bash
# Check all security services
systemctl status apparmor
systemctl status auditd
systemctl status fail2ban
systemctl status unattended-upgrades
```

## 🔧 Customization

### Modify SSH Port
Edit `/etc/ssh/sshd_config`:
```bash
Port 2222  # Change to your preferred port
```

### Adjust Fail2Ban Settings
Edit `/etc/fail2ban/jail.local`:
```ini
[DEFAULT]
bantime = 3600    # Ban duration in seconds
findtime = 600    # Time window for failures
maxretry = 3      # Max attempts before ban
```

### Firewall Rules
Add custom rules to `/etc/iptables/rules.v4`:
```bash
# Example: Allow port 443
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables-save > /etc/iptables/rules.v4
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This script makes significant changes to your system configuration. Always:
- Test in a non-production environment first
- Maintain physical/console access during implementation
- Keep backups of your system
- Review the script before running

## 📞 Support

For issues, questions, or contributions, please:
- Open an issue on [GitHub](https://github.com/MrMasterbay/proxmox-security-hardening/issues)
- Check existing issues before creating a new one
- Provide detailed information about your environment and error messages

## 🙏 Acknowledgments

- Proxmox VE Team for their excellent virtualization platform
- Security community for best practices and recommendations
- Contributors and testers who help improve this script

---

**Note**: This script is provided as-is. Always review and understand security changes before implementing them in production environments.
