# Proxmox Security Hardening Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Debian](https://img.shields.io/badge/Debian-13%20(Trixie)-red.svg)
![Proxmox](https://img.shields.io/badge/Proxmox-VE%209.x-orange.svg)

A comprehensive security hardening script for Proxmox VE servers that implements industry-standard security best practices and automated protection mechanisms.

## 🛡️ Features

### User Management
- **Automated Admin User Creation**: Creates a secure Superadmin and BackupAdmin user with random suffix
- **Strong Password Generation**: 32-character passwords with special characters for superadmin and 128-characters passwords for BackupAdmin
- **Proxmox Integration**: Automatically grants Administrator role in Proxmox
- **Root Access Restriction**: Disables direct root login via SSH that IP is not whitelisted
- **2FA enabled for the Superadmin**: TOTP with Google Auth incase someones sneaks your superadmin Password

### Security Hardening
- **AppArmor**: Enforces mandatory access control policies
- **Kernel Hardening**: Implements sysctl security parameters
- **Auditd**: Comprehensive system auditing and logging
- **Service Minimization**: Disables unnecessary services (bluetooth, cups, avahi)
- **IPv6 Hardend this time not disabled again**: Complete IPv6 stack hardend like google recommends. Can also be deactivated

### Network Security
- **SSH Hardening**: 
  - Key-based authentication
  - Rate limiting
  - User restrictions
  - Root User disabled for non Cluster Communications (Allowed IP'S can still access it)
- **Firewall Configuration**:
  - iptables with rate limiting
  - Fail2Ban integration
  - Dynamic SSH whitelisting
- **DDoS Protection**: SYN flood protection and connection limits

### Monitoring & Maintenance
- **Automatic Updates**: Unattended security updates via apt
- **Fail2Ban**: Automatic IP blocking for brute force attempts
- **Audit Logging**: Monitors critical system files and configurations

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

### A new Node wants to join the Cluster?

1. **Download the script**:
```bash
wget https://raw.githubusercontent.com/MrMasterbay/proxmox-security-hardening/main/new-node-join.sh && chmod +x new-node-join.sh && ./new-node-join.sh
```

2. **Run This Script on every other Node in the Cluster that is hardend!**:
```bash
./new-node-join.sh
```

---

## CIS Benchmark Controls

Based on **CIS Debian Linux 13 Benchmark v1.0.0**

### CIS 1.1.1.1-1.1.1.5 - Disable Unused Filesystem Modules
- **What it does**: Prevents loading of rarely-used filesystem kernel modules (cramfs, freevxfs, hfs, hfsplus, jffs2)
- **Why it matters**: Vulnerabilities in unused modules can still be exploited if they're loadable
- **Proxmox Impact**: None - VMs and containers unaffected

### CIS 1.5.11-1.5.13 - Disable Core Dumps
- **What it does**: Prevents the system from creating memory dumps when programs crash
- **Why it matters**: Core dumps can contain passwords, encryption keys, and sensitive data
- **Proxmox Impact**: None - VM crashes still logged normally

### CIS 1.6.1 - Mount Options Hardening
- **What it does**: Applies security restrictions to filesystem mount points (/tmp, /var/tmp, /dev/shm) by preventing device files, SUID binaries, and code execution
- **Why it matters**: Without proper mount options, attackers can create device files to access hardware, place SUID binaries for privilege escalation, or execute malicious code from temporary directories
- **Proxmox Impact**: NO impact on cluster operations, VMs, backups, or web interface - only hardens temporary filesystem security against common attack vectors

### CIS 2.4.1.2-2.4.2.1 - Cron/At Access Hardening
- **What it does**: Restricts job scheduler access to root only
- **Why it matters**: Attackers can use cron for persistence or privilege escalation
- **Proxmox Impact**: None - Proxmox scheduled tasks (backups, etc.) run as root

### CIS 3.2.1-3.2.2 - Disable Unused Network Protocols
- **What it does**: Prevents loading of rarely-used network protocols (dccp, sctp, rds, tipc, atm, can)
- **Why it matters**: Known vulnerabilities exist in these rarely-used protocols
- **Proxmox Impact**: None - These protocols are not used by Proxmox

### CIS 4.2.1.1-4.2.1.4 - Journald Hardening
- **What it does**: Configures persistent, compressed logging that survives reboots
- **Why it matters**: Ensures logs are available for forensic analysis after incidents
- **Proxmox Impact**: Better forensic capabilities

### CIS 5.1.1-5.1.3 - SSH File Permissions
- **What it does**: Sets secure permissions on SSH config (600) and host keys
- **Why it matters**: Prevents unauthorized access to SSH configuration and private keys
- **Proxmox Impact**: None - SSH continues to work normally

### CIS 5.1.4-5.1.22 - SSH Cryptographic Hardening
- **What it does**: Configures SSH to use only strong ciphers, key exchange algorithms, and MACs
- **Why it matters**: Weak cryptographic algorithms can be broken by attackers
- **Settings**:
  - Strong Ciphers: AES-GCM, AES-CTR only
  - Secure Key Exchange: Curve25519, DH Group 16/18
  - Strong MACs: SHA2-512, SHA2-256 ETM
  - Disables: GSSAPI, Hostbased auth, Rhosts
- **Proxmox Impact**: Very old SSH clients may not connect (intended behavior)
- **⚠️ Note**: Banner only shown to admin users, NOT to root (breaks cluster operations otherwise)

### CIS 5.3.3.1 - Account Lockout (pam_faillock)
- **What it does**: Locks accounts after 5 failed login attempts, auto-unlocks after 10 minutes
- **Why it matters**: Protects against brute-force password attacks
- **Proxmox Impact**: Works alongside Fail2Ban for defense in depth
- **⚠️ Note**: Root is excluded to prevent total lockout

### CIS 5.3.3.2 - Password History (pam_pwhistory)
- **What it does**: Prevents users from reusing the last 24 passwords
- **Why it matters**: Stops the common pattern of cycling between 2-3 passwords
- **Proxmox Impact**: Only affects password changes on the host

### CIS 5.4.3.2 - Shell Timeout
- **What it does**: Automatically logs out inactive shell sessions after 15 minutes
- **Why it matters**: Prevents forgotten open terminals from being a security risk
- **Proxmox Impact**: Only interactive SSH sessions affected - NOT cluster communication, migrations, backups, or cron jobs

### CIS 6.1 - System File Permissions
- **What it does**: Sets correct permissions on critical system files (/etc/passwd, /etc/shadow, /etc/group, /etc/gshadow)
- **Why it matters**: Prevents unauthorized access to password hashes and user/group information that could enable privilege escalation attacks
- **Proxmox Impact**: NO impact - standard Linux filesystem hardening, does not affect Proxmox operations

---

## Lynis Recommendations

Based on **Lynis Security Auditing Tool**

### NETW-2705 - Backup Nameserver
- **What it does**: Ensures at least 2 DNS nameservers are configured
- **Why it matters**: DNS redundancy prevents service outages
- **Options**: Cloudflare (1.1.1.1), Google (8.8.8.8), Quad9 (9.9.9.9), or custom

### MAIL-8818 - Postfix Banner Hardening
- **What it does**: Removes software version information from mail server banner
- **Why it matters**: Version disclosure helps attackers identify vulnerable software

### AUTH-9230 - Password Hashing Rounds
- **What it does**: Increases SHA password hashing iterations (5000-500000 rounds)
- **Why it matters**: Makes brute-force attacks significantly slower
- **Note**: Only affects newly created or changed passwords

### AUTH-9262 - PAM Password Quality
- **What it does**: Enforces strong password policies (min 12 chars, uppercase, lowercase, digit, special char)
- **Why it matters**: Prevents users from setting weak passwords
- **Implementation**: Installs libpam-pwquality

### AUTH-9286 - Password Aging
- **What it does**: Forces password changes every 365 days with 14-30 day warning
- **Why it matters**: Limits the window of opportunity if a password is compromised
- **Optional**: Daily email notifications for expiring passwords

### AUTH-9328 - Default Umask
- **What it does**: Tightens default file permissions from 022 to 027
- **Why it matters**: New files are only readable by owner and group, not everyone

### PKGS-7346 - Old Package Cleanup
- **What it does**: Removes configuration files from uninstalled packages
- **Why it matters**: Residual configs can contain outdated/insecure settings

### PKGS-7370 - Package Verification (debsums)
- **What it does**: Installs tool to verify package file integrity
- **Why it matters**: Detects corrupted or tampered system files

### BANN-7126 & BANN-7130 - Login Banners
- **What it does**: Displays legal warning banner before login (local and SSH)
- **Why it matters**: Required by compliance frameworks (PCI-DSS, HIPAA, etc.)
- **⚠️ Note**: SSH banner only shown to admin users, NOT to root (breaks cluster operations otherwise)

### HRDN-7230 - Malware/Rootkit Scanner
- **What it does**: Installs rkhunter, chkrootkit, and/or ClamAV
- **Why it matters**: Detects hidden malware and system compromises
- **Proxmox-specific**: VM disk images (.qcow2, .raw, .vmdk) automatically excluded to prevent false positives

### FINT-4350 - File Integrity Monitoring (AIDE)
- **What it does**: Creates database of file checksums to detect unauthorized changes
- **Why it matters**: Detects modified system binaries, changed configs, new unexpected files

### ACCT-9622 - Process Accounting
- **What it does**: Logs information about every process execution
- **Why it matters**: Essential for forensic analysis after security incidents
- **Usage**: `lastcomm` to see recent commands

### ACCT-9626 - System Statistics (sysstat)
- **What it does**: Collects CPU, memory, disk I/O, and network statistics over time
- **Why it matters**: Helps diagnose performance issues and detect anomalies
- **Usage**: `sar` for historical data

### USB-1000 / STRG-1846 - Disable USB/Firewire Storage
- **What it does**: Prevents loading of USB and Firewire storage drivers
- **Why it matters**: Prevents data theft via USB drives and malware introduction
- **⚠️ Warning**: Completely disables USB storage - keyboards/mice still work

### HRDN-7222 - Restrict Compiler Access
- **What it does**: Limits compiler (gcc, g++, make) usage to root only
- **Why it matters**: Prevents attackers from compiling exploit code if they gain shell access

### PKGS-7394 - Patch Management Tools
- **What it does**: Installs `apt-show-versions` which provides a quick overview of installed packages and their update status. Run `apt-show-versions -u` to see all packages with available upgrades
- **Why it matters**: Simplifies patch management by making it easy to identify outdated packages at a glance. Essential for maintaining security hygiene and quickly identifying systems that need updates
- **Proxmox Impact**: NO impact - this is a read-only tool that only queries package status. Does not modify any system behavior or affect Proxmox operations
  
### DEB-0280 - Isolate /tmp per Session
- **What it does**: Installs `libpam-tmpdir` which creates isolated temporary directories for each user session. Instead of a shared `/tmp`, each session gets its own private `/tmp` directory
- **Why it matters**: Prevents /tmp race condition attacks where attackers exploit predictable temporary file names. Also prevents users from seeing or manipulating each other's temporary files, limiting lateral movement after a compromise
- **Proxmox Impact**: NO impact - this is a PAM module that only affects interactive sessions. Proxmox services, VMs, containers, and cluster operations are completely unaffected


### Lynis Whitelist for Proxmox
- **What it does**: Creates profile to skip false positive tests specific to Proxmox
- **Skipped tests**:
  - NETW-3015: Promiscuous interfaces (required for VM bridges)
  - KRNL-5788: Non-standard kernel (pve-kernel uses different paths)
  - FILE-6310: Separate partitions (difficult to change post-installation)
 
---

## STIG Recommendations

Based on the **DOD(Department of Defense) STIG Guidelines**

### STIG UBTU-24-200000 - Concurrent Session Limit
- **What it does**: Limits each user to maximum 10 concurrent login sessions
- **Why it matters**: Prevents resource exhaustion attacks and limits blast radius if an account is compromised - attackers can't open unlimited shells
- **Proxmox Impact**: NO impact on Proxmox operations - root is excluded and has unlimited sessions for cluster communication, migrations, and system operations

### STIG UBTU-24-200260 - Disable Inactive Accounts
- **What it does**: Automatically disables user accounts after 35 days without login
- **Why it matters**: Dormant accounts are prime targets for attackers - if credentials are leaked, unused accounts may never notice the breach
- **Proxmox Impact**: NO impact - root, superadmin, and backupadmin are explicitly excluded. Only affects additional user accounts that go unused for 35+ days

### STIG UBTU-24-100030/100040 - Remove Insecure Legacy Services
- **What it does**: Removes telnet, rsh-server, rsh-client, talk, ntalk, and nis packages
- **Why it matters**: These legacy protocols transmit ALL data including passwords in cleartext - any network sniffer can capture credentials
- **Proxmox Impact**: NO impact - Proxmox uses SSH exclusively for remote access. These packages are never needed in a modern environment

### STIG UBTU-24-102010 - Audit at Boot
- **What it does**: Adds `audit=1` kernel parameter to enable auditing from the very first moment of boot
- **Why it matters**: Without this, actions during early boot (before auditd starts) are not logged - attackers could exploit this gap to hide malicious activity
- **Proxmox Impact**: NO impact on functionality - slightly increases boot time by ~1-2 seconds. Provides complete audit trail from kernel initialization

### STIG Extended Audit Rules - Privileged Command Logging
- **What it does**: Comprehensive logging of security-relevant events including: privileged command execution (sudo, su, passwd), permission changes (chmod, chown), account modifications, cron changes, kernel module loading, network config changes, and Proxmox configuration changes
- **Why it matters**: Provides forensic evidence for incident response - know exactly what commands were run, by whom, and when. Essential for detecting insider threats and compromised accounts
- **Proxmox Impact**: MINIMAL impact - only audits actions by human users (auid>=1000), not system services. Log volume increases but modern systems handle this easily. Proxmox config changes (/etc/pve/) are specifically monitored

### STIG AIDE Audit Tool Protection
- **What it does**: Adds audit binaries (auditd, ausearch, aureport, etc.) to AIDE file integrity monitoring with SHA512 checksums
- **Why it matters**: If an attacker compromises the audit tools themselves, they can hide their tracks by modifying how logs are searched or reported. AIDE detects any tampering with these critical binaries
- **Proxmox Impact**: NO impact - only monitors audit tool binaries for unauthorized changes. Requires AIDE to be installed first (FINT-4350)

### STIG Memory Protection - Kernel Hardening
- **What it does**: Adds kernel parameters: `init_on_alloc=1` (zero memory on allocation), `init_on_free=1` (zero memory on free), `page_alloc.shuffle=1` (randomize page allocator), `slab_nomerge` (prevent slab cache merging)
- **Why it matters**: Hardens against common exploit techniques - prevents information leaks from uninitialized memory, use-after-free attacks, and heap spraying. Makes exploitation significantly harder
- **Proxmox Impact**: MINIMAL impact - approximately 1-3% performance overhead which is negligible for most workloads. VMs and containers are not affected as they have their own memory management according to proxmox docs
  
### STIG V-270832 - Audit Rules Immutable
- **What it does**: Adds `-e 2` flag to audit rules which locks the audit configuration. Once set, audit rules cannot be modified using `auditctl` - a system reboot is required to make any changes
- **Why it matters**: Prevents attackers from disabling or modifying audit rules to hide their tracks. Even if an attacker gains root access, they cannot turn off auditing without triggering a noticeable system reboot
- **Proxmox Impact**: MINIMAL impact - audit rules still function normally, only modification is blocked. Note that any legitimate audit rule changes will require a reboot. Plan audit rule changes during maintenance windows


### Optional Features
- **Proxmox Auto-Update Script**: Integration with automated cluster update system
- **Backup Creation**: Automatic backup of all modified configurations

## 📖 What Gets Modified

### System Configuration Files
- `/etc/ssh/sshd_config` - SSH daemon configuration
- `/etc/sysctl.conf` - Kernel parameters
- `/etc/default/grub` - Boot parameters
- `/etc/sudoers.d/hardening` - Sudo security settings
- `/etc/fail2ban/jail.local` - Fail2Ban configuration
- `/etc/iptables/rules.v4` - Firewall rules

### Services Modified
- SSH (moved to port 22)
- AppArmor (enabled and enforced)
- Auditd (enabled with rules)
- Fail2Ban (configured and enabled)
- Automatic updates (configured)

## 🔐 Security Measures Implemented

### Network Protection
| Feature | Description | Default Setting |
|---------|-------------|-----------------|
| SSH Port | SSH port | 22 |
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
- Root login disabled for nun cluster Communications
- Password authentication (with strong passwords)
- Public key authentication enabled
- Sudo timeout: 5 minutes
- Maximum sudo attempts: 3

## 📝 Post-Installation Steps

### 1. Save Credentials
After installation, immediately save the generated credentials:
```bash
cat /root/SuperAdmin_credentials.txt
```
Store these in your password manager!

### 2. Test SSH Access
Test the new SSH configuration:
```bash
ssh -p 22 SuperAdmin_XXXXXX@your-server-ip
```

### 3. Test Proxmox Web UI
Access the web interface:
```
https://your-server-ip:8006
Username: SuperAdmin_XXXXXX
Password: [from credentials file]
```

### 4. Secure Cleanup
After confirming access, remove the credentials file:
```bash
shred -u /root/SuperAdmin_credentials.txt
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
- **User access**: Only SuperAdmin_XXXXXX and BackupAdmin_XXXXXX allowed
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
3. Check `/root/SuperAdmin_credentials.txt` for credentials
4. Modify `/etc/ssh/sshd_config` if needed

## 🐛 Troubleshooting

### Cannot Connect via SSH
```bash
# From console, check SSH service
systemctl status sshd

# Verify port 22 is listening
ss -tlnp | grep 22

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
pveum aclmod / -user SuperAdmin_XXXXXX@pam -role Administrator
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
Port 22  # Change to your preferred port
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
