#!/bin/bash
#
# Proxmox Security Hardening Script v3.5
# ═══════════════════════════════════════════════════════════════
#
# Author: A tired sysadmin who thought "I'll do this quickly" at 3am
#         ...2 weeks later the script was finally done. Classic. 
#            so baGStube_Nico or Nico Schmidt or Mr Masterbay my name
#
# Disclaimer: This script was developed with lots of Tea, frustration,
#             and occasional screaming into pillows. No AI was harmed in
#             the making of this script (because none was used, duh).
#             Just pure human stupidity and trial-and-error. I hate my life
#
# Fun fact: I mass-produced this entirely by mass myself. Mass. Manually.
#           With my mass hands typing on a mass keyboard. Very mass human. Imaging Gay hot Dragons
#           Hi Turbin Yesh I'm totally using AI..... Now enjoy my Comments
#          
#
# Changelog v3.3:
#   - TFA/2FA for SSH finally working properly (PAM was the devil)
#   - Google Authenticator now ACTUALLY works for SSH
#   - Root is EXCLUDED from TOTP (cluster communication needs this!)
#   - Less bugs, more features (allegedly)
#   - Added comments because I won't remember what this does in 6 months
#   - Root is enabled again. Imaging more dragons.
#   - We try a update script not sure if that works.
#
# Changelog v3.4
#    - Added the Lynis recommendations
#
# Changelog v3.5
#   -  Added the CIS recommendations
#
# Known "features" (not bugs, just undocumented features):
#   - Works best when you make a backup first
#   - Tested on Proxmox 9.1 (other versions: good luck!)
#   - If things break: /root/emergency-restore.sh is your friend
#
# License: MIT (Make-It-Trouble) hehe
#
# "It works on my server" - Famous last words
#
# ═══════════════════════════════════════════════════════════════

set -e  # Exit on errors (because I'm too lazy to check every exit code)

# ══════════════════════════════════════════════════════════════════════════════
# VERSION STUFF AND THINGS
# Here's the version. If you change this without knowing what you're doing,
# that's your problem, not mine.
# ══════════════════════════════════════════════════════════════════════════════
SCRIPT_VERSION="3.5"
GITHUB_RAW_URL="https://raw.githubusercontent.com/MrMasterbay/proxmox-security-hardening/main/seuwurity.sh"
GITHUB_REPO_URL="https://github.com/MrMasterbay/proxmox-security-hardening"

# ══════════════════════════════════════════════════════════════════════════════
# COLORS - Because the terminal looks boring otherwise
# Yes, I spent 20 minutes picking the perfect colors.
# Yes, it was a waste of time. No, I have no regrets because I build a script and spend more than 8h+ for 30 mins work.
# ══════════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'        # For errors (hopefully you never see these)
GREEN='\033[0;32m'      # For success (hopefully you only see these)
YELLOW='\033[1;33m'     # For warnings (read them, damn it!)
BLUE='\033[0;34m'       # For info (optional reading, but recommended)
CYAN='\033[0;36m'       # For fancy headers (because I have style and trip)
WHITE='\033[1;37m'      # For important text
NC='\033[0m'            # No Color - Reset, otherwise everything stays colorful forever

# ══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# These functions make the script pretty. Without them, everything would be
# just text. Boring text. Like a tax return or your letter from the IRS / Finanzamt / Finance Department. Pay your taxes eventually
# ══════════════════════════════════════════════════════════════════════════════

# Shows the fancy header
# Because first impressions matter, even for scripts
print_header() {
    clear
    echo -e "${CYAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   🛡️  PROXMOX VE POST-INSTALL SECURITY HARDENING"
    echo "   Version $SCRIPT_VERSION - Now with working 2FA!"
    echo "   (Written by a human, not by Skynet... probably)"
    echo ""
    echo "  Made by Nico Schmidt (baGStube_Nico) hopefully"
    echo "  Please consider supporting this script development:"
    echo "  💖 Ko-fi: ko-fi.com/bagstube_nico"
    echo "  🔗 Links: linktr.ee/bagstube_nico"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Shows a section - makes things more organized
# Without this, everything would be one big text blob
print_section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}   $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# The following functions are self-explanatory
# If not, maybe you shouldn't be a server admin :P
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# I moved it up here.
# So I have a standard instead of making everything diffrent

ask_user() {
    local question="$1"
    read -p "$question (y/n) [y]: " answer
    answer=${answer:-y}
    [[ "$answer" =~ ^[YyJj]$ ]]
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

fix_applied() {
    echo -e "${GREEN}[FIXED]${NC} $1"
}

fix_skipped() {
    echo -e "${YELLOW}[SKIPPED]${NC} $1"
}

# ══════════════════════════════════════════════════════════════════════════════
# VALIDATION FUNCTIONS
# Because users sometimes enter "pizza" as an IP address.
# Yes, that really happened. No, I won't talk about it and we don't talk about pizza orders at all.
# ══════════════════════════════════════════════════════════════════════════════

# Checks if an IP address is valid
# Spoiler: 999.999.999.999 is not a valid IP, Kevin.
validate_ip() {
    local ip=$1
    
    # Regex for IPv4 - looks complicated, and it is
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # Check each octet (those are the numbers between the dots)
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            # No octet can be greater than 255
            # Yes, I had to google this too back then
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Checks CIDR notation (e.g., 192.168.1.0/24)
# For people who want to whitelist entire subnets
validate_cidr() {
    local cidr=$1
    if [[ $cidr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        local ip="${cidr%/*}"
        local mask="${cidr#*/}"
        if validate_ip "$ip" && [ "$mask" -le 32 ]; then
            return 0
        fi
    fi
    return 1
}

# Checks if a username is valid
# Linux doesn't like usernames like "💀HackerMan💀", sorry. Obamna would work tho
validate_username() {
    local username=$1
    # Must start with lowercase letter or underscore
    # Then lowercase letters, numbers, underscore or hyphen
    # Max 32 characters because... Linux
    if [[ $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        return 0
    fi
    return 1
}

# ══════════════════════════════════════════════════════════════════════════════
# UPDATE CHECKER
# Checks if there's a new version.
# Because sometimes I fix bugs. Sometimes I also add new ones.
# That's the circle of life. I hope that works when not yeay bugs
# ══════════════════════════════════════════════════════════════════════════════

check_for_updates() {
    echo ""
    print_section "🔄 Checking for Script Updates"
    echo ""
    echo "Current version: $SCRIPT_VERSION"
    echo -n "Checking GitHub for updates... "

    # Try to load the script from GitHub
    # If the internet doesn't work, that's not my problem
    REMOTE_SCRIPT=""
    if command -v curl &> /dev/null; then
        REMOTE_SCRIPT=$(curl -fsSL --connect-timeout 5 "$GITHUB_RAW_URL" 2>/dev/null) || true
    elif command -v wget &> /dev/null; then
        REMOTE_SCRIPT=$(wget -qO- --timeout=5 "$GITHUB_RAW_URL" 2>/dev/null) || true
    fi

    if [ -z "$REMOTE_SCRIPT" ]; then
        echo "⊘"
        echo ""
        print_info "GitHub not reachable. Continuing with local version..."
        echo ""
        return 0
    fi

    # Extract version from remote script
    REMOTE_VERSION=$(echo "$REMOTE_SCRIPT" | grep -m1 '^SCRIPT_VERSION=' | cut -d'"' -f2)

    if [ -z "$REMOTE_VERSION" ]; then
        echo "⊘"
        echo ""
        print_info "Could not determine remote version. Moving on..."
        echo ""
        return 0
    fi

    echo "✓"
    echo "Remote version:  $REMOTE_VERSION"
    echo ""

    if [ "$SCRIPT_VERSION" = "$REMOTE_VERSION" ]; then
        print_success "You're running the latest version! 🎉"
        echo ""
        return 0
    fi

    # Compare versions
    # Yes, this is more complicated than you'd think
    version_gt() {
        test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
    }

    if version_gt "$REMOTE_VERSION" "$SCRIPT_VERSION"; then
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║           🆕 NEW VERSION AVAILABLE! 🆕                       ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║  Current:  $SCRIPT_VERSION"
        echo "║  Latest:   $REMOTE_VERSION"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Options:"
        echo "  1) Update now (download and replace)"
        echo "  2) Continue with current version"
        echo "  3) Exit and update manually"
        echo ""
        read -p "Your choice [1-3] (Default: 2): " UPDATE_CHOICE
        UPDATE_CHOICE=${UPDATE_CHOICE:-2}

        case $UPDATE_CHOICE in
            1)
                auto_update "$@"
                ;;
            2)
                echo ""
                echo "Ok, continuing with version $SCRIPT_VERSION..."
                echo "(But don't complain if something doesn't work!)"
                echo ""
                ;;
            3)
                echo ""
                echo "To update manually:"
                echo "  curl -fsSL $GITHUB_RAW_URL -o $(readlink -f "$0")"
                echo ""
                exit 0
                ;;
            *)
                echo "Continuing with current version..."
                ;;
        esac
    else
        print_info "You're running a newer version than on GitHub. Time traveler?"
        echo "  (Local: $SCRIPT_VERSION, Remote: $REMOTE_VERSION)"
        echo ""
    fi
}

# Auto-Update function
# Replaces the script with the new version and restarts it
# Hopefully without breaking everything
auto_update() {
    echo ""
    print_section "📥 Auto-Update running..."
    echo ""

    SCRIPT_PATH=$(readlink -f "$0")
    BACKUP_PATH="${SCRIPT_PATH}.backup.$(date +%Y%m%d_%H%M%S)"

    echo "Script path: $SCRIPT_PATH"
    echo "Creating backup: $BACKUP_PATH"

    # Create backup - Safety first!
    cp "$SCRIPT_PATH" "$BACKUP_PATH"
    if [ $? -ne 0 ]; then
        print_error "Backup failed. Update aborted."
        return 1
    fi
    print_success "Backup created"

    # Download new version
    echo -n "Downloading new version... "
    if command -v curl &> /dev/null; then
        curl -fsSL "$GITHUB_RAW_URL" -o "${SCRIPT_PATH}.new" 2>/dev/null
    else
        wget -qO "${SCRIPT_PATH}.new" "$GITHUB_RAW_URL" 2>/dev/null
    fi

    if [ $? -ne 0 ] || [ ! -s "${SCRIPT_PATH}.new" ]; then
        echo "✗"
        print_error "Download failed. Keeping current version."
        rm -f "${SCRIPT_PATH}.new"
        return 1
    fi
    echo "✓"

    # Sanity check: Does the new file even have a version?
    if ! grep -q '^SCRIPT_VERSION=' "${SCRIPT_PATH}.new"; then
        print_error "Downloaded file looks corrupted. Aborting."
        rm -f "${SCRIPT_PATH}.new"
        return 1
    fi

    # Replace old script with new one
    mv "${SCRIPT_PATH}.new" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              ✓ UPDATE SUCCESSFUL!                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Backup saved to: $BACKUP_PATH"
    echo ""
    echo "Script will restart with new version..."
    echo ""
    sleep 2

    # Restart the script with all original arguments
    exec "$SCRIPT_PATH" "$@"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMAND LINE ARGUMENTS
# For people who know what they're doing (or pretend to)
# ══════════════════════════════════════════════════════════════════════════════

case "${1:-}" in
    --update|update)
        check_for_updates
        exit 0
        ;;
    --version|-v)
        echo "Proxmox Security Hardening Script v$SCRIPT_VERSION"
        echo "Written with blood, sweat, and way too much coffee and black tea still superior"
        echo "Definitely by a human. With hands. Typing. Manually."
        echo "Repository: $GITHUB_REPO_URL"
        exit 0
        ;;
    --help|-h)
        echo "Proxmox Security Hardening Script v$SCRIPT_VERSION"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  (none)          Starts the hardening wizard"
        echo "  --update        Checks for updates"
        echo "  --version, -v   Shows version information"
        echo "  --help, -h      Shows this help"
        echo ""
        echo "Pro-tip: Make a backup before running this."
        echo "         Seriously. Make. A. Backup."
        echo ""
        echo "Repository: $GITHUB_REPO_URL"
        exit 0
        ;;
    --skip-update-check)
        SKIP_UPDATE_CHECK="yes"
        ;;
esac

# ══════════════════════════════════════════════════════════════════════════════
# Corosync Time checker
# We check the time before. Otherwise we have funny little errors.
# We learn from my mistakes.
# ══════════════════════════════════════════════════════════════════════════════


print_section "🕐 TIME-SYNC: Time Synchronization Check"

echo ""
echo "Time synchronization is CRITICAL for:"
echo "  - 2FA/TOTP (codes are time-based, ±30 seconds tolerance!)"
echo "  - Proxmox Cluster (nodes must have synchronized time)"
echo "  - TLS/SSL Certificates (validation fails with wrong time)"
echo "  - Log correlation across multiple servers"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📅 Current system date: $(date '+%Y-%m-%d')"
echo "  🕐 Current system time: $(date '+%H:%M:%S %Z')"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ⚠️  Please verify this matches your actual local time!"
echo "  If the time is wrong, 2FA will NOT work!"
echo ""

if ! ask_user "Is the time displayed above CORRECT?"; then
    echo ""
    log_error "Time is NOT correct!"
    echo ""
    echo "  Please fix the time before continuing."
    echo ""
    echo "  Option 1: Install Chrony (recommended)"
    echo "    apt install chrony && systemctl enable --now chrony"
    echo "    chronyd -q 'pool pool.ntp.org iburst'" 
    echo "              systemctl restart chrony"
    echo ""
    echo "  Option 2: Set time manually"
    echo "    timedatectl set-time 'YYYY-MM-DD HH:MM:SS'"
    echo "    Example: timedatectl set-time '2026-01-04 15:30:00'"
    echo ""
    echo "  Option 3: Set timezone"
    echo "    timedatectl set-timezone Europe/Vienna"
    echo ""
    
    if ask_user "Do you want to install Chrony now to fix time sync?"; then
        log_info "Installing chrony..."
        apt-get update -qq
        apt-get install -y chrony
        
        systemctl enable chrony
        systemctl start chrony
        
        log_info "Waiting for time synchronization..."
        sleep 5
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  📅 NEW system date: $(date '+%Y-%m-%d')"
        echo "  🕐 NEW system time: $(date '+%H:%M:%S %Z')"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if ask_user "Is the time NOW correct?"; then
            log_success "Time synchronized via Chrony"
            fix_applied "TIME-SYNC"
        else
            log_error "Time still incorrect!"
            echo ""
            echo "  Please fix manually and restart the script."
            echo "  Continuing with wrong time WILL break 2FA!"
            echo ""
            
            if ! ask_user "Continue anyway? (NOT RECOMMENDED!)"; then
                echo ""
                echo "Smart choice! Fix the time and run the script again."
                exit 1
            else
                log_warning "Continuing with potentially wrong time..."
                fix_skipped "TIME-SYNC"
            fi
        fi
    else
        echo ""
        if ! ask_user "Continue WITHOUT time sync? (2FA may fail!)"; then
            echo ""
            echo "Fix the time and run the script again."
            exit 1
        else
            log_warning "Continuing without time sync - YOU HAVE BEEN WARNED!"
            fix_skipped "TIME-SYNC"
        fi
    fi
else
    log_success "Time confirmed correct by user"
    
    # Still check if NTP is running for ongoing sync
    TIME_SYNC_METHOD=""
    
    if command -v chronyc &>/dev/null && chronyc tracking &>/dev/null; then
        TIME_SYNC_METHOD="chrony"
    elif timedatectl show 2>/dev/null | grep -q "NTPSynchronized=yes"; then
        TIME_SYNC_METHOD="systemd-timesyncd"
    elif command -v ntpq &>/dev/null && ntpq -p &>/dev/null; then
        TIME_SYNC_METHOD="ntpd"
    fi
    
    if [[ -n "$TIME_SYNC_METHOD" ]]; then
        log_success "Ongoing sync via: $TIME_SYNC_METHOD"
    else
        log_warning "No NTP daemon detected - time may drift!"
        echo ""
        
        if ask_user "Install Chrony to keep time synchronized?"; then
            apt-get update -qq
            apt-get install -y chrony
            systemctl enable --now chrony
            log_success "Chrony installed for ongoing time sync"
            fix_applied "TIME-SYNC"
        else
            log_info "Skipped - remember to sync time periodically!"
            fix_skipped "TIME-SYNC"
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# MAIN SCRIPT STARTS HERE
# From here on it gets serious. No going back.
# (Well, yes. With Ctrl+C. But you get what I mean.)
# ══════════════════════════════════════════════════════════════════════════════

# Check if we're root
# Without root privileges we can't do anything
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run as root!"
    echo "   Try: sudo $0"
    echo "   Or log in as root. Like a real admin."
    exit 1
fi

# Check if this is actually a Proxmox system
# Because people would run this script on their Raspberry Pi too (I'm scared)
if ! command -v pveum &>/dev/null; then
    echo "❌ This doesn't look like a Proxmox system!"
    echo "   This script is only meant for Proxmox VE."
    echo "   If this IS Proxmox: What did you break?"
    exit 1
fi

# Show the header
print_header

# Update check (unless skipped)
if [ "${SKIP_UPDATE_CHECK:-}" != "yes" ]; then
    check_for_updates "$@"
fi

# Warnings and confirmation
echo ""
echo "⚠️  WARNING: This script will harden your system!"
echo ""
echo "    What this means:"
echo "    • Root SSH will be restricted (only from specific IPs)"
echo "    • A superadmin user will be created"
echo "    • A backupadmin user will be created"
echo "    • Optional: 2FA (Google Authenticator) for SSH"
echo "    • Firewall will be configured"
echo "    • Fail2Ban will be installed"
echo "    • CIS and Lynis recommendations"
echo "    • And much more like Apparmor and Dragons"
echo ""
echo "    📌 IMPORTANT:"
echo "    • Keep this SSH session open for testing!"
echo "    • Have console/IPMI access as backup!"
echo "    • Grab a black Tea because thats superior, this takes a minute."
echo ""
read -p "Type 'YES' to continue (or anything else to abort): " CONFIRM

if [[ "$CONFIRM" != "YES" && "$CONFIRM" != "yes" && "$CONFIRM" != "Yes" ]]; then
    echo ""
    echo "Aborted. Maybe next time!"
    echo "Tip: You need to type 'YES', not just press Enter."
    exit 0
fi

echo ""
print_success "Brave choice! Let's go..."
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# CREATE BACKUP
# Because we learn from mistakes. Usually our own.
# ══════════════════════════════════════════════════════════════════════════════

print_section "📦 Creating Configuration Backup"

BACKUP_DIR="/root/security-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup all important files
# If something goes wrong, we can restore everything
cp /etc/ssh/sshd_config "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/default/grub "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/sysctl.conf "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/pve/user.cfg "$BACKUP_DIR/" 2>/dev/null || true
cp -r /etc/pam.d/ "$BACKUP_DIR/pam.d/" 2>/dev/null || true

print_success "Backup created: $BACKUP_DIR"
echo "    (If everything breaks, look here)"

# ══════════════════════════════════════════════════════════════════════════════
# CLUSTER DETECTION
# Figures out if we're part of a cluster
# Because cluster nodes need to talk to each other
# ══════════════════════════════════════════════════════════════════════════════

print_section "🔍 Cluster Detection"

CLUSTER_NODE_IPS=""
JUMPHOST_IPS=""
ROOT_SSH_ALLOWED_IPS=""

# Determine current IP
CURRENT_NODE_IP=$(hostname -I | awk '{print $1}')
echo "Current node IP: $CURRENT_NODE_IP"

IS_CLUSTER="no"

# Check if we're in a cluster
if [ -f "/etc/pve/corosync.conf" ] && command -v pvecm &>/dev/null; then
    NODE_COUNT=$(pvecm nodes 2>/dev/null | tail -n +4 | grep -c "." || echo "0")
    if [ "$NODE_COUNT" -gt 1 ]; then
        IS_CLUSTER="yes"
        echo ""
        print_success "Cluster detected! Extracting cluster node IPs..."
        
        # Get all ring0_addr from corosync.conf
        CLUSTER_NODE_IPS=$(grep -E "ring0_addr:" /etc/pve/corosync.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ' | xargs)
        
        if [ -n "$CLUSTER_NODE_IPS" ]; then
            echo ""
            echo "Found cluster nodes:"
            for IP in $CLUSTER_NODE_IPS; do
                if [ "$IP" = "$CURRENT_NODE_IP" ]; then
                    echo "  • $IP (this node)"
                else
                    echo "  • $IP (other node)"
                fi
            done
        fi
    else
        print_info "No other cluster nodes found - standalone mode - make sure your hypervisor IP is there just to be sure"
    fi
else
    print_info "No cluster configured - standalone mode - make sure your hypervisor IP is there just to be sure"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ROOT SSH WHITELIST CONFIGURATION
# Here you define who can log in as root
# Spoiler: As few as possible!
# ══════════════════════════════════════════════════════════════════════════════

print_section "📝 Root SSH Whitelist Configuration"

echo ""
echo "Root SSH will ONLY be allowed from these IPs:"
echo "  • Cluster nodes (for Proxmox communication)"
echo "  • Jumphosts/Bastion hosts (for admin access)"
echo ""
echo "The superadmin user can log in from ANYWHERE."
echo ""

# Ask for additional cluster nodes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CLUSTER NODE IPs (for root SSH + cluster communication)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$CLUSTER_NODE_IPS" ]; then
    echo "Auto-detected cluster nodes: $CLUSTER_NODE_IPS"
fi

echo ""
echo "Enter additional cluster node IPs (leave empty to finish):"

while true; do
    read -p "Cluster Node IP: " NODE_IP
    if [ -z "$NODE_IP" ]; then
        break
    fi
    
    if validate_ip "$NODE_IP"; then
        # Avoid duplicates
        if ! echo " $CLUSTER_NODE_IPS " | grep -q " $NODE_IP "; then
            CLUSTER_NODE_IPS="$CLUSTER_NODE_IPS $NODE_IP"
            CLUSTER_NODE_IPS=$(echo "$CLUSTER_NODE_IPS" | xargs)
            print_success "Added: $NODE_IP"
        else
            print_warning "Already in list: $NODE_IP"
        fi
    else
        print_error "Invalid IP format: $NODE_IP"
    fi
done

# Ask for jumphosts
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "JUMPHOST / BASTION IPs (for root SSH access)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Enter jumphost IPs (leave empty to finish):"

while true; do
    read -p "Jumphost IP: " JUMP_IP
    if [ -z "$JUMP_IP" ]; then
        break
    fi
    
    if validate_ip "$JUMP_IP"; then
        if ! echo " $JUMPHOST_IPS " | grep -q " $JUMP_IP "; then
            JUMPHOST_IPS="$JUMPHOST_IPS $JUMP_IP"
            JUMPHOST_IPS=$(echo "$JUMPHOST_IPS" | xargs)
            print_success "Added: $JUMP_IP"
        else
            print_warning "Already in list: $JUMP_IP"
        fi
    else
        print_error "Invalid IP format: $JUMP_IP"
    fi
done

# Combine all allowed IPs
ROOT_SSH_ALLOWED_IPS=""
for IP in $CLUSTER_NODE_IPS $JUMPHOST_IPS; do
    if validate_ip "$IP"; then
        if ! echo " $ROOT_SSH_ALLOWED_IPS " | grep -q " $IP "; then
            ROOT_SSH_ALLOWED_IPS="$ROOT_SSH_ALLOWED_IPS $IP"
        fi
    fi
done
ROOT_SSH_ALLOWED_IPS=$(echo "$ROOT_SSH_ALLOWED_IPS" | xargs)

# Show summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "         📋 ROOT SSH SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Root SSH will be allowed from:"

if [ -n "$CLUSTER_NODE_IPS" ]; then
    echo "  Cluster Nodes:"
    for IP in $CLUSTER_NODE_IPS; do
        echo "    • $IP"
    done
fi

if [ -n "$JUMPHOST_IPS" ]; then
    echo "  Jumphosts:"
    for IP in $JUMPHOST_IPS; do
        echo "    • $IP"
    done
fi

if [ -z "$ROOT_SSH_ALLOWED_IPS" ]; then
    print_warning "NO IPs configured - Root SSH will be completely disabled!"
fi

echo ""
read -p "Continue with this configuration? (y/n) [y]: " CONFIRM_IPS
CONFIRM_IPS=${CONFIRM_IPS:-y}

if [[ ! "$CONFIRM_IPS" =~ ^[YyJj]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# SUPERADMIN WITH OPTIONAL 2FA/TFA
# Here the superadmin is created and optionally secured with 2FA
# This is the part that didn't work in v3.2. Now it does!
# ══════════════════════════════════════════════════════════════════════════════

print_section "👤 Superadmin Configuration"

echo ""
echo "Now we'll create the superadmin user."
echo "This user can SSH in from ANYWHERE."
echo ""

# Ask for username
DEFAULT_ADMIN="superadmin"
read -p "Superadmin username [$DEFAULT_ADMIN]: " SUPERADMIN_NAME
SUPERADMIN_NAME=${SUPERADMIN_NAME:-$DEFAULT_ADMIN}

# Validate the username
if ! validate_username "$SUPERADMIN_NAME"; then
    print_warning "Invalid username. Using default: $DEFAULT_ADMIN"
    SUPERADMIN_NAME="$DEFAULT_ADMIN"
fi

# Add random suffix for security
RAND_SUFFIX=$(shuf -i 100000-999999 -n1)
SUPERADMIN="${SUPERADMIN_NAME}_${RAND_SUFFIX}"

echo ""
echo "Superadmin will be created: $SUPERADMIN"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# BACKUPADMIN WITHOUT 2FA
# Here the Backupadmin is created and not secured with 2FA because its your backup
# ══════════════════════════════════════════════════════════════════════════════

print_section "👤 BackupAdmin Configuration"

echo ""
echo "Now we'll create the backupadmin user."
echo "This user can SSH in from ANYWHERE."
echo ""

# Ask for username
DEFAULT_ADMIN="backupadmin"
read -p "BackupAdmin username [$DEFAULT_ADMIN]: " BACKUPADMIN_NAME
BACKUPADMIN_NAME=${BACKUPADMIN_NAME:-$DEFAULT_ADMIN}

# Validate the username
if ! validate_username "$BACKUPADMIN_NAME"; then
    print_warning "Invalid username. Using default: $DEFAULT_ADMIN"
    BACKUPADMIN_NAME="$DEFAULT_ADMIN"
fi

# Add random suffix for security
RAND_SUFFIX=$(shuf -i 100000-999999 -n1)
BACKUPADMIN="${BACKUPADMIN_NAME}_${RAND_SUFFIX}"

echo ""
echo "BackupAdmin will be created: $BACKUPADMIN"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# 2FA / TFA CONFIGURATION
# The holy grail of SSH security!
# Finally working! (After about 1000 attempts)
# ══════════════════════════════════════════════════════════════════════════════

print_section "🔐 Two-Factor Authentication (2FA/TFA)"

echo ""
echo "Do you want to enable 2FA (Google Authenticator) for SSH?"
echo ""
echo "With 2FA you'll need for SSH login:"
echo "  1. Your password"
echo "  2. A 6-digit code from the Authenticator app"
echo ""
echo "This is MUCH more secure, but also a bit more cumbersome."
echo ""
echo "⚠️  IMPORTANT: Root and Backupadmin login will NOT require 2FA!"
echo "    (Cluster communication between nodes needs this) and also your Backup Admin."
echo " If you don't have a NTP Server be sure the time is always synced otherwise you lock yourself out"
echo ""
echo "Options:"
echo "  1) Yes, enable 2FA for superadmin (recommended!)"
echo "  2) No, password only"
echo ""
read -p "Your choice [1-2] (Default: 1): " TFA_CHOICE
TFA_CHOICE=${TFA_CHOICE:-1}

ENABLE_TFA="no"
if [ "$TFA_CHOICE" = "1" ]; then
    ENABLE_TFA="yes"
    print_success "2FA will be enabled! 🎉"
    print_info "Root and Backupadmin will be excluded from 2FA (for cluster compatibility)"
else
    print_info "2FA skipped. Password-only authentication."
fi

# ══════════════════════════════════════════════════════════════════════════════
# PACKAGE INSTALLATION
# Install all required packages
# This may take a while. Go get some coffee or BLACK TEA for godsake.
# ══════════════════════════════════════════════════════════════════════════════

print_section "📦 Installing Required Packages"

echo ""
echo "This might take a moment... Time for coffee or Black Tea! ☕"
echo ""

apt update

# Base packages
PACKAGES="sudo pwgen apparmor apparmor-utils auditd unattended-upgrades apt-listchanges fail2ban iptables-persistent jq"

# Google Authenticator only if 2FA is wanted
if [ "$ENABLE_TFA" = "yes" ]; then
    PACKAGES="$PACKAGES libpam-google-authenticator"
fi

# Install everything
apt install -y $PACKAGES 2>/dev/null || {
    print_warning "Some packages couldn't be installed."
    print_info "Trying minimal installation..."
    apt install -y sudo pwgen fail2ban iptables-persistent
}

print_success "Packages installed"

# ══════════════════════════════════════════════════════════════════════════════
# CREATE SUPERADMIN USER
# Now the user is actually created
# ══════════════════════════════════════════════════════════════════════════════

print_section "👤 Creating Superadmin User"

# Generate a strong password
# 32 characters should be enough... right?
SUPERADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()_+' < /dev/urandom | head -c 32)

# Create user if not already existing
if id "$SUPERADMIN" &>/dev/null; then
    print_warning "User $SUPERADMIN already exists"
else
    adduser --gecos "Proxmox Superadmin" --disabled-password "$SUPERADMIN"
    print_success "User created: $SUPERADMIN"
fi

# Set password
echo "$SUPERADMIN:$SUPERADMIN_PASS" | chpasswd
print_success "Password set"

# Add to sudo group
usermod -aG sudo "$SUPERADMIN"
print_success "Added to sudo group"

# Create SSH directory
mkdir -p /home/$SUPERADMIN/.ssh
chmod 700 /home/$SUPERADMIN/.ssh
touch /home/$SUPERADMIN/.ssh/authorized_keys
chmod 600 /home/$SUPERADMIN/.ssh/authorized_keys
chown -R $SUPERADMIN:$SUPERADMIN /home/$SUPERADMIN/.ssh

# Create Proxmox user and grant permissions
pveum user add $SUPERADMIN@pam -comment "Proxmox Superadministrator" 2>/dev/null || true
pveum aclmod / -user $SUPERADMIN@pam -role Administrator
print_success "Proxmox Administrator role assigned"

# ══════════════════════════════════════════════════════════════════════════════
# CREATE BACKUPADMIN USER
# WUshi I'm Backup incase you lose superadmin
# ══════════════════════════════════════════════════════════════════════════════

print_section "👤 Creating Backupadmin User"

# Generate a strong password
# 128 characters should be enough like Azure RIGHT?
BACKUPADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()_+' < /dev/urandom | head -c 128)

# Create user if not already existing
if id "$BACKUPADMIN" &>/dev/null; then
    print_warning "User $BACKUPADMIN already exists"
else
    adduser --gecos "Proxmox BackupAdmin" --disabled-password "$BACKUPADMIN"
    print_success "User created: $BACKUPADMIN"
fi

# Set password
echo "$BACKUPADMIN:$BACKUPADMIN_PASS" | chpasswd
print_success "Password set"

# Add to sudo group
usermod -aG sudo "$BACKUPADMIN"
print_success "Added to sudo group"

# Create SSH directory
mkdir -p /home/$BACKUPADMIN/.ssh
chmod 700 /home/$BACKUPADMIN/.ssh
touch /home/$BACKUPADMIN/.ssh/authorized_keys
chmod 600 /home/$BACKUPADMIN/.ssh/authorized_keys
chown -R $BACKUPADMIN:$BACKUPADMIN /home/$BACKUPADMIN/.ssh

# Create Proxmox user and grant permissions
pveum user add $BACKUPADMIN@pam -comment "Proxmox BackupAdmin" 2>/dev/null || true ## makes your life easier
pveum aclmod / -user $BACKUPADMIN@pam -role Administrator
print_success "Proxmox Administrator role assigned"

# ══════════════════════════════════════════════════════════════════════════════
# GOOGLE AUTHENTICATOR SETUP
# The part that wasn't working before!
# Problem was: PAM wasn't configured properly. Now it is.
# ══════════════════════════════════════════════════════════════════════════════

# We don't need TFA for this people.
TOTP_EXEMPT_USERS="root:${BACKUPADMIN}"

if [ "$ENABLE_TFA" = "yes" ]; then
    print_section "🔐 Configuring Google Authenticator"
    
    echo ""
    echo "Generating 2FA configuration for $SUPERADMIN..."
    echo ""
    
    #  YES I googled it. Isn't that funny?
    # Create the Google Authenticator configuration
    # -t: Time-based tokens
    # -d: Disallow reuse
    # -f: Force overwrite
    # -r 3 -R 30: Rate limiting (3 attempts per 30 seconds)
    # -w 3: Window size (allows 1 code before/after current)
    # -Q UTF8: QR-Code Encoding
    
    sudo -u $SUPERADMIN google-authenticator \
        -t \
        -d \
        -f \
        -r 3 \
        -R 30 \
        -w 3 \
        -Q UTF8 \
        -s /home/$SUPERADMIN/.google_authenticator
    
    # Secure the file
    chmod 600 /home/$SUPERADMIN/.google_authenticator
    chown $SUPERADMIN:$SUPERADMIN /home/$SUPERADMIN/.google_authenticator
    
    echo ""
    print_success "Google Authenticator configured!"
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  IMPORTANT: SCAN THE QR CODE ABOVE WITH YOUR APP! ⚠️     ║"
    echo "║                                                              ║"
    echo "║  Recommended apps:                                           ║"
    echo "║    • Google Authenticator (Android/iOS)                      ║"
    echo "║    • Authy (Android/iOS/Desktop)                             ║"
    echo "║    • Microsoft Authenticator                                 ║"
    echo "║                                                              ║"
    echo "║  ALSO SAVE THE EMERGENCY CODES ABOVE!                        ║"
    echo "║  (In case you lose your phone)                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    read -p "Press Enter when you've scanned the QR code..."
    
    # ═══════════════════════════════════════════════════════════════════════
    # PAM CONFIGURATION FOR SSH WITH ROOT EXCEPTION
    # THIS is the part that was missing!
    # Without this, SSH never asks for the 2FA code
    # BUT: Root must be EXCLUDED for cluster to work!
    # ═══════════════════════════════════════════════════════════════════════
    
    print_section "🔧 Configuring PAM for SSH 2FA (with root exception)"
    
    # Backup PAM configuration
    cp /etc/pam.d/sshd "$BACKUP_DIR/pam.d_sshd"
    
    # Check if Google Authenticator is already configured in PAM
    if grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
        print_info "PAM is already configured for Google Authenticator"
    else
        # Create new PAM configuration
        # The trick: pam_succeed_if.so skips TOTP for root!
        cat > /etc/pam.d/sshd <<'EOFPAM'
# PAM configuration for the Secure Shell service
# Modified for Google Authenticator 2FA
# NOTE: Root is EXCLUDED from 2FA for cluster compatibility!

# Standard Un*x authentication.
@include common-auth

# ═══════════════════════════════════════════════════════════════
# Google Authenticator - 2FA Configuration
# ═══════════════════════════════════════════════════════════════
# pam_succeed_if: Skip 2FA if user is root (for cluster communication)
# This is CRITICAL - without this, Proxmox cluster breaks!
auth [success=1 default=ignore] pam_succeed_if.so user in $TOTP_EXEMPT_USERS
auth required pam_google_authenticator.so nullok

# Disallow non-root logins when /etc/nologin exists.
account    required     pam_nologin.so

# Standard Un*x account and session handling
@include common-account
@include common-session
@include common-password

# Print the message of the day upon successful login.
session    optional     pam_motd.so  motd=/run/motd.dynamic
session    optional     pam_motd.so noupdate

# Print the status of the user's mailbox upon successful login.
session    optional     pam_mail.so standard noenv

# Set up user limits from /etc/security/limits.conf.
session    required     pam_limits.so

# Standard Un*x password updating.
@include common-password
EOFPAM
        
        print_success "PAM configured for SSH"
        print_success "Root is EXCLUDED from 2FA (cluster compatible!)"
    fi
    
    # ═══════════════════════════════════════════════════════════════════════
    # SSH MUST BE CONFIGURED FOR 2FA
    # ChallengeResponseAuthentication must be 'yes'!
    # ═══════════════════════════════════════════════════════════════════════
    
    # This setting will be applied later in the SSH configuration
    SSH_TFA_ENABLED="yes"
    
    print_success "2FA fully configured!"
    echo ""
else
    SSH_TFA_ENABLED="no"
fi

# ══════════════════════════════════════════════════════════════════════════════
# SAVE CONFIGURATION
# Save all settings for later use
# ══════════════════════════════════════════════════════════════════════════════

cat > /etc/proxmox-security.conf <<EOF
# Proxmox Security Hardening Configuration
# Generated: $(date)
# Script Version: $SCRIPT_VERSION
# 
# Don't edit this file manually!
# (Or do, if you know what you're doing. I'm not your boss.)

# Cluster Node IPs (root SSH + cluster)
CLUSTER_NODE_IPS="$CLUSTER_NODE_IPS"

# Jumphost IPs (root SSH)
JUMPHOST_IPS="$JUMPHOST_IPS"

# All Root-SSH allowed IPs
ROOT_SSH_ALLOWED_IPS="$ROOT_SSH_ALLOWED_IPS"

# Superadmin Username
SUPERADMIN="$SUPERADMIN"

# Backupadmin Username
BACKUPADMIN="$BACKUPADMIN"

# 2FA enabled?
TFA_ENABLED="$ENABLE_TFA"
EOF
chmod 600 /etc/proxmox-security.conf

# ══════════════════════════════════════════════════════════════════════════════
# ENABLE APPARMOR
# Mandatory Access Control - sounds fancy, and it is
# ══════════════════════════════════════════════════════════════════════════════

print_section "🛡️ Enabling AppArmor"

systemctl enable --now apparmor 2>/dev/null || true
aa-enforce /etc/apparmor.d/* 2>/dev/null || true

print_success "AppArmor enabled"

# ══════════════════════════════════════════════════════════════════════════════
# DISABLE UNNECESSARY SERVICES
# Fewer services = Less attack surface as we learned in the book
# ══════════════════════════════════════════════════════════════════════════════

print_section "🔇 Disabling Unnecessary Services"

# These services a server usually doesn't need
DISABLE_SERVICES="bluetooth cups avahi-daemon"

for SERVICE in $DISABLE_SERVICES; do
    if systemctl is-active --quiet $SERVICE 2>/dev/null; then
        systemctl disable --now $SERVICE 2>/dev/null || true
        print_success "Disabled: $SERVICE"
    fi
done

# ══════════════════════════════════════════════════════════════════════════════
# KERNEL HARDENING
# Make the kernel more paranoid and "safe"
# ══════════════════════════════════════════════════════════════════════════════

print_section "🔧 Kernel Hardening"

# Check if already hardened
if ! grep -q "Security Hardening" /etc/sysctl.conf 2>/dev/null; then
    cat >> /etc/sysctl.conf <<'EOF'
^
# ═══════════════════════════════════════════════════════════════
# Security Hardening - Generated by seuwurity.sh because I can write that.
# Don't delete unless you know what you're doing!
# ═══════════════════════════════════════════════════════════════

# IP Spoofing protection - packets only from expected interfaces
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects - against MitM
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0

# Disable source routing - against spoofing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Don't send redirects - we're not a router
net.ipv4.conf.all.send_redirects = 0

# Log Martian packets - for debugging
net.ipv4.conf.all.log_martians = 1

# SYN Flood protection - against DDoS
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Enable ASLR - against buffer overflow
kernel.randomize_va_space = 2

# Restrict dmesg - no kernel info for normal users
kernel.dmesg_restrict = 1

# Hide kernel pointers - against info leaks
kernel.kptr_restrict = 2

# Disable magic SysRq - against physical access attacks
kernel.sysrq = 0

EOF
    sysctl -p >/dev/null 2>&1
    print_success "Kernel hardened"
else
    print_info "Kernel already hardened"
fi

# ══════════════════════════════════════════════════════════════════════════════
# IPV6 CONFIGURATION
# IPv6 can be hardened or completely disabled #Thanks to Apachez!
# ══════════════════════════════════════════════════════════════════════════════

print_section "🌐 IPv6 Configuration"

echo ""
echo "IPv6 is required for some Proxmox features."
echo ""
echo "Options:"
echo "  1) Keep IPv6 and harden it (recommended for clusters)"
echo "  2) Disable IPv6 completely (for standalone)"
echo ""
read -p "Your choice [1-2] (Default: 1): " IPV6_CHOICE
IPV6_CHOICE=${IPV6_CHOICE:-1}

if [ "$IPV6_CHOICE" = "2" ]; then
    # Disable IPv6 via GRUB
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet ipv6.disable=1"/' /etc/default/grub
    update-grub
    
    # Also adjust Postfix if present
    if [ -f /etc/postfix/main.cf ]; then
        echo 'inet_protocols = ipv4' >> /etc/postfix/main.cf
    fi
    
    print_success "IPv6 disabled (reboot required)"
else
    # Harden IPv6
    if ! grep -q "IPv6 Hardening" /etc/sysctl.conf 2>/dev/null; then
        cat >> /etc/sysctl.conf <<'EOF'

# ═══════════════════════════════════════════════════════════════
# IPv6 Hardening
# ═══════════════════════════════════════════════════════════════
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

EOF
        sysctl -p >/dev/null 2>&1
    fi
    print_success "IPv6 hardened"
fi

# ══════════════════════════════════════════════════════════════════════════════
# AUDITD CONFIGURATION
# Logs everything important
# For when you later want to know "who did that?!"
# ══════════════════════════════════════════════════════════════════════════════

print_section "📋 Configuring Audit Logging"

systemctl enable --now auditd 2>/dev/null || true

cat > /etc/audit/rules.d/hardening.rules <<EOF
# ═══════════════════════════════════════════════════════════════
# Security Audit Rules
# Generated by seuwurity.sh v$SCRIPT_VERSION .  You know I can write that all day. I renamed this after the Github name scheme.
# ═══════════════════════════════════════════════════════════════

# Monitor user/group changes
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config

# Monitor sudo changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Monitor auth log
-w /var/log/auth.log -p wa -k auth_log

# Monitor Proxmox configuration
-w /etc/pve/ -p wa -k proxmox_config

# Monitor security script config
-w /etc/proxmox-security.conf -p wa -k security_config

# Log root commands (can get verbose!)
-a always,exit -F arch=b64 -F uid=0 -S execve -k root_commands

EOF

augenrules --load 2>/dev/null || service auditd restart
print_success "Audit logging configured"

# ══════════════════════════════════════════════════════════════════════════════
# SSH CONFIGURATION
# The most important part - this is where SSH gets properly configured
# Including 2FA if enabled!
# ══════════════════════════════════════════════════════════════════════════════

print_section "🔐 SSH Configuration"

# Create the new SSH configuration
cat > /etc/ssh/sshd_config <<EOF
# ═══════════════════════════════════════════════════════════════
# Proxmox Hardened SSH Configuration
# Generated by seuwurity.sh v$SCRIPT_VERSION
# $(date)
#
# Admin User ($SUPERADMIN, $BACKUPADMIN): SSH from anywhere
# Root: Only from whitelist IPs
# ═══════════════════════════════════════════════════════════════

# Basic settings
Port 22
Protocol 2

# Deny root login by default (Match blocks override this)
PermitRootLogin no

# Authentication
PasswordAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3

EOF

# 2FA-specific SSH settings
if [ "$SSH_TFA_ENABLED" = "yes" ]; then
    cat >> /etc/ssh/sshd_config <<EOF
# ═══════════════════════════════════════════════════════════════
# 2FA/TFA Configuration (Google Authenticator)
# NOTE: Root is excluded from 2FA via PAM configuration!
# ═══════════════════════════════════════════════════════════════

# ChallengeResponseAuthentication MUST be 'yes' for 2FA!
ChallengeResponseAuthentication yes
KbdInteractiveAuthentication yes

# AuthenticationMethods defines what's required:
# keyboard-interactive = Password + 2FA Code (for non-root)
AuthenticationMethods keyboard-interactive

# UsePAM MUST be 'yes' for 2FA!
UsePAM yes

EOF
else
    cat >> /etc/ssh/sshd_config <<EOF
# No 2FA - password only
ChallengeResponseAuthentication no
UsePAM yes

EOF
fi

# Additional SSH settings
cat >> /etc/ssh/sshd_config <<EOF
# Timeouts and limits
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30
MaxStartups 10:30:60

# Security settings
X11Forwarding no
Compression no
TCPKeepAlive no
AllowAgentForwarding no
AllowTcpForwarding yes

# Allowed users (Superadmin, Backupadmin from anywhere)
AllowUsers $SUPERADMIN $BACKUPADMIN

EOF

# Match blocks for root SSH from whitelist IPs
if [ -n "$ROOT_SSH_ALLOWED_IPS" ]; then
    cat >> /etc/ssh/sshd_config <<EOF
# ═══════════════════════════════════════════════════════════════
# ROOT SSH ACCESS - Whitelist IPs Only!
# Root does NOT require 2FA over SSH! (configured in PAM)
# ═══════════════════════════════════════════════════════════════

EOF
    
    for IP in $ROOT_SSH_ALLOWED_IPS; do
        # Skip invalid IPs
        if ! validate_ip "$IP"; then
            continue
        fi
        
        # Determine the type of IP
        IP_TYPE="Whitelisted IP"
        if echo " $CLUSTER_NODE_IPS " | grep -q " $IP "; then
            IP_TYPE="Cluster Node"
        elif echo " $JUMPHOST_IPS " | grep -q " $IP "; then
            IP_TYPE="Jumphost"
        fi
        
        cat >> /etc/ssh/sshd_config <<EOF
# $IP_TYPE: $IP
Match Address $IP
    PermitRootLogin yes
    AllowUsers root $SUPERADMIN $BACKUPADMIN

EOF
    done
    
    print_success "Root SSH allowed from $(echo $ROOT_SSH_ALLOWED_IPS | wc -w) IPs (no 2FA required)"
else
    print_success "Root SSH completely disabled"
fi

# Restart SSH service
systemctl restart sshd
print_success "SSH service restarted"

# ══════════════════════════════════════════════════════════════════════════════
# SUDO HARDENING
# Make sudo more secure
# ══════════════════════════════════════════════════════════════════════════════

print_section "🔒 Sudo Hardening"

cat > /etc/sudoers.d/hardening <<EOF
# Sudo Hardening - Generated by seuwurity.sh
#
# Timeout: After 5 minutes, password must be re-entered
Defaults timestamp_timeout=5

# Max 3 password attempts
Defaults passwd_tries=3

# Logging to separate file
Defaults logfile=/var/log/sudo.log

# Require real terminal (no scripting without TTY)
Defaults requiretty

# Use PTY for security
Defaults use_pty

EOF
chmod 440 /etc/sudoers.d/hardening

print_success "Sudo hardened"

# ══════════════════════════════════════════════════════════════════════════════
# AUTOMATIC UPDATES
# Because everyone forgets to update manually
# ══════════════════════════════════════════════════════════════════════════════

print_section "🔄 Automatic Security Updates"

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF

print_success "Automatic updates enabled"

# ══════════════════════════════════════════════════════════════════════════════
# FIREWALL CONFIGURATION
# iptables - the classic. Complex but powerful.
# ══════════════════════════════════════════════════════════════════════════════

print_section "🔥 Firewall Configuration"

echo ""
echo "Configuring iptables..."
echo ""

# Reset everything
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Allow loopback (important!)
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# ICMP (Ping) - allow
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# SSH with rate limiting
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 10 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
print_success "SSH Port 22: Open (rate-limited)"

# Proxmox WebUI
iptables -A INPUT -p tcp --dport 8006 -j ACCEPT
iptables -A INPUT -p tcp --dport 8007 -j ACCEPT
print_success "WebUI Ports 8006/8007: Open"

# Spice/VNC
iptables -A INPUT -p tcp --dport 3128 -j ACCEPT
iptables -A INPUT -p tcp --dport 5900:5999 -j ACCEPT
print_success "Spice/VNC Ports: Open"

# Cluster ports only for cluster nodes
if [ -n "$CLUSTER_NODE_IPS" ]; then
    echo ""
    echo "Configuring cluster ports..."
    
    for NODE_IP in $CLUSTER_NODE_IPS; do
        if ! validate_ip "$NODE_IP"; then
            continue
        fi
        
        # Corosync
        iptables -A INPUT -p udp --dport 5405:5412 -s "$NODE_IP" -j ACCEPT
        # Live Migration
        iptables -A INPUT -p tcp --dport 60000:60050 -s "$NODE_IP" -j ACCEPT
        # RPC
        iptables -A INPUT -p tcp --dport 111 -s "$NODE_IP" -j ACCEPT
        iptables -A INPUT -p udp --dport 111 -s "$NODE_IP" -j ACCEPT
        # Corosync Config Sync
        iptables -A INPUT -p tcp --dport 2224 -s "$NODE_IP" -j ACCEPT
        # Ceph (if used)
        iptables -A INPUT -p tcp --dport 6789 -s "$NODE_IP" -j ACCEPT
        iptables -A INPUT -p tcp --dport 6800:7300 -s "$NODE_IP" -j ACCEPT
        
        print_success "Cluster ports open for: $NODE_IP"
    done
fi

# Default Policy: DROP
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Save rules
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

print_success "Firewall configured"

# IPv6 Firewall
if [ "$IPV6_CHOICE" != "2" ]; then
    echo ""
    echo "Configuring IPv6 firewall..."
    
    ip6tables -F
    ip6tables -X
    ip6tables -A INPUT -i lo -j ACCEPT
    ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A INPUT -p ipv6-icmp -j ACCEPT
    ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
    ip6tables -A INPUT -p tcp --dport 8006 -j ACCEPT
    ip6tables -A INPUT -p tcp --dport 3128 -j ACCEPT
    ip6tables -A INPUT -p tcp --dport 5900:5999 -j ACCEPT
    
    if [ -n "$CLUSTER_NODE_IPS" ]; then
        ip6tables -A INPUT -p udp --dport 5405:5412 -s fe80::/10 -j ACCEPT
        ip6tables -A INPUT -p tcp --dport 60000:60050 -s fe80::/10 -j ACCEPT
    fi
    
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables-save > /etc/iptables/rules.v6
    
    print_success "IPv6 firewall configured"
fi

# Auto-restore script
cat > /etc/network/if-up.d/iptables <<'EOFIP'
#!/bin/sh
# Load firewall rules on boot
if [ -f /etc/iptables/rules.v4 ]; then
    iptables-restore < /etc/iptables/rules.v4
fi
if [ -f /etc/iptables/rules.v6 ]; then
    ip6tables-restore < /etc/iptables/rules.v6
fi
EOFIP
chmod +x /etc/network/if-up.d/iptables

# ══════════════════════════════════════════════════════════════════════════════
# FAIL2BAN CONFIGURATION
# Blocks IPs that fail login too often or if you forgot the password.....
# ══════════════════════════════════════════════════════════════════════════════

print_section "🚫 Fail2Ban Configuration"

systemctl stop fail2ban 2>/dev/null || true

mkdir -p /etc/fail2ban/filter.d
mkdir -p /etc/fail2ban/jail.d

# Create whitelist
IGNORE_IPS="127.0.0.1/8 ::1"
for IP in $ROOT_SSH_ALLOWED_IPS; do
    if validate_ip "$IP"; then
        IGNORE_IPS="$IGNORE_IPS $IP"
    fi
done

cat > /etc/fail2ban/jail.local <<EOF
# Fail2Ban Configuration - Generated by seuwurity.sh OwO whats this
#
# Ban time: 24 hour
# After 3 failed attempts within 10 minutes
#
# Whitelist: Localhost + Cluster Nodes + Jumphosts

[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = auto
ignoreip = $IGNORE_IPS

[sshd]
enabled = true
port = 22
maxretry = 3
bantime = 8600

[proxmox]
enabled = true
port = 8006
filter = proxmox
backend = systemd
maxretry = 3
bantime = 8600
EOF

cat > /etc/fail2ban/filter.d/proxmox.conf <<EOF
# Proxmox WebUI Filter for Fail2Ban
[Definition]
failregex = pvedaemon\[.*authentication (failure|error).*rhost=<HOST>
            pveproxy\[.*authentication (failure|error).*rhost=<HOST>
ignoreregex =

[Init]
journalmatch = _SYSTEMD_UNIT=pvedaemon.service + _SYSTEMD_UNIT=pveproxy.service
EOF

systemctl enable fail2ban
systemctl start fail2ban

sleep 2
if systemctl is-active --quiet fail2ban; then
    print_success "Fail2Ban running"
else
    print_warning "Fail2Ban might have issues - please check"
fi


# ══════════════════════════════════════════════════════════════════════════════
# Lynis Recommendations 
# Cuz I care because Obamna care.
# Now enjoy it. 
# ══════════════════════════════════════════════════════════════════════════════

#══════════════════════════════════════════════════════════════════════════════
# FIX: NETW-2705 - Backup Nameserver
#══════════════════════════════════════════════════════════════════════════════

print_section "🌐 NETW-2705: DNS Configuration"

echo ""
echo "Lynis recommends having at least 2 nameservers configured for redundancy."
echo "If your primary DNS server fails, the backup ensures continued name resolution."
echo "This prevents service outages caused by DNS failures."
echo ""

if ask_user "Do you want to check and configure backup nameservers?"; then

    NAMESERVER_COUNT=$(grep -c "^nameserver" /etc/resolv.conf 2>/dev/null || echo "0")

    if [[ "$NAMESERVER_COUNT" -lt 2 ]]; then
        log_warning "Only $NAMESERVER_COUNT nameserver(s) found"
        echo ""
        echo "Select backup nameserver to add:"
        echo "  1) Cloudflare (1.1.1.1) - Fast, privacy-focused"
        echo "  2) Google (8.8.8.8) - Reliable, widely used"
        echo "  3) Quad9 (9.9.9.9) - Security-focused, blocks malware"
        echo "  4) Custom IP"
        echo ""
        read -p "Your choice [1-4]: " dns_choice
        
        case $dns_choice in
            1) BACKUP_DNS="1.1.1.1" ;;
            2) BACKUP_DNS="8.8.8.8" ;;
            3) BACKUP_DNS="9.9.9.9" ;;
            4) 
                read -p "Enter custom DNS IP: " BACKUP_DNS
                ;;
            *) 
                BACKUP_DNS=""
                ;;
        esac
        
        if [[ -n "$BACKUP_DNS" ]]; then
            if ! grep -q "nameserver $BACKUP_DNS" /etc/resolv.conf; then
                echo "nameserver $BACKUP_DNS" >> /etc/resolv.conf
                log_success "Backup nameserver $BACKUP_DNS added"
                fix_applied "NETW-2705"
            else
                log_info "Nameserver $BACKUP_DNS already present"
            fi
        fi
    else
        log_success "Already $NAMESERVER_COUNT nameservers configured - No action needed"
    fi

else
    fix_skipped "NETW-2705"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: MAIL-8818 - Postfix Banner
#══════════════════════════════════════════════════════════════════════════════

print_section "📧 MAIL-8818: Postfix Banner Hardening"

echo ""
echo "Mail server banners can reveal software version information to attackers."
echo "This information helps attackers identify known vulnerabilities in your"
echo "specific Postfix version. Anonymizing the banner hides this information"
echo "while maintaining full mail server functionality."
echo ""

if ask_user "Do you want to check and anonymize the Postfix banner?"; then

    if command -v postconf &> /dev/null; then
        CURRENT_BANNER=$(postconf -h smtpd_banner 2>/dev/null || echo "")
        
        if echo "$CURRENT_BANNER" | grep -qiE "(postfix|debian|ubuntu|proxmox)"; then
            log_warning "Postfix banner contains software information"
            echo "Current banner: $CURRENT_BANNER"
            echo ""
            echo "New banner will be: \$myhostname ESMTP"
            
            postconf -e "smtpd_banner = \$myhostname ESMTP"
            systemctl reload postfix 2>/dev/null || true
            log_success "Postfix banner anonymized"
            fix_applied "MAIL-8818"
        else
            log_success "Postfix banner already clean - No action needed"
        fi
    else
        log_info "Postfix not installed - Skipping"
    fi

else
    fix_skipped "MAIL-8818"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: AUTH-9230 - Password Hashing Rounds
#══════════════════════════════════════════════════════════════════════════════

print_section "🔐 AUTH-9230: Password Hashing Rounds"

echo ""
echo "Password hashing rounds determine how many times the hash algorithm is applied."
echo "More rounds = slower to compute = harder to brute-force attack."
echo "The recommended settings are:"
echo "  - Minimum rounds: 5000 (ensures adequate security)"
echo "  - Maximum rounds: 500000 (prevents excessive CPU usage)"
echo ""
echo "This only affects newly created or changed passwords."
echo ""

if ask_user "Do you want to configure password hashing rounds?"; then

    if ! grep -q "^SHA_CRYPT_MIN_ROUNDS" /etc/login.defs; then
        log_warning "Password hashing rounds not configured"
        
        cat >> /etc/login.defs << 'EOF'

# Lynis AUTH-9230: Password hashing rounds
SHA_CRYPT_MIN_ROUNDS 5000
SHA_CRYPT_MAX_ROUNDS 500000
EOF
        log_success "Password hashing rounds configured (5000-500000)"
        fix_applied "AUTH-9230"
    else
        log_success "Password hashing already configured - No action needed"
    fi

else
    fix_skipped "AUTH-9230"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: AUTH-9262 - PAM Password Quality
#══════════════════════════════════════════════════════════════════════════════

print_section "🔑 AUTH-9262: PAM Password Quality Requirements"

echo ""
echo "libpam-pwquality enforces strong password policies system-wide."
echo "When installed and configured, it will require:"
echo "  - Minimum 12 characters length"
echo "  - At least 1 uppercase letter"
echo "  - At least 1 lowercase letter"
echo "  - At least 1 number"
echo "  - At least 1 special character"
echo "  - No dictionary words"
echo "  - No more than 3 repeated characters"
echo ""
echo "This prevents users from setting weak passwords."
echo ""

if ask_user "Do you want to install and configure password quality requirements?"; then

    if ! dpkg -l | grep -q "libpam-pwquality"; then
        log_warning "libpam-pwquality not installed"
        
        apt-get update -qq
        apt-get install -y libpam-pwquality
        
        cat > /etc/security/pwquality.conf << 'EOF'
# Lynis AUTH-9262: Password quality requirements
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
minclass = 3
maxrepeat = 3
gecoscheck = 1
dictcheck = 1
EOF
        log_success "libpam-pwquality installed and configured"
        fix_applied "AUTH-9262"
    else
        log_success "libpam-pwquality already installed - No action needed"
    fi

else
    fix_skipped "AUTH-9262"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: AUTH-9286 - Password Aging
#══════════════════════════════════════════════════════════════════════════════

print_section "📅 AUTH-9286: Password Aging Policy"

echo ""
echo "Password aging forces users to change passwords regularly."
echo "This limits the window of opportunity if a password is compromised."
echo ""
echo "Settings:"
echo "  - Maximum age: 365 days (must change at least yearly)"
echo "  - Minimum age: 1 day (prevents rapid cycling back to old password)"
echo "  - Warning: 30 days before expiry"
echo "  - Daily email notifications starting 30 days before expiry"
echo ""

if ask_user "Do you want to configure password aging policy?"; then

    CURRENT_MAX=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
    CURRENT_MIN=$(grep "^PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}')

    if [[ "$CURRENT_MAX" == "99999" ]] || [[ -z "$CURRENT_MIN" ]] || [[ "$CURRENT_MIN" == "0" ]]; then
        log_warning "Password aging not properly configured"
        
        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   365/' /etc/login.defs
        sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
        sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   30/' /etc/login.defs
        
        log_success "Password aging configured (Max: 365, Min: 1, Warn: 30)"
    else
        log_success "Password aging already configured"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Daily Email Warnings
    # ─────────────────────────────────────────────────────────────────────────
    echo ""
    if ask_user "Enable daily email warnings for expiring passwords?"; then
        
        read -p "Enter notification email address: " NOTIFY_EMAIL
        
        if [[ -z "$NOTIFY_EMAIL" ]]; then
            log_warning "No email provided - skipping"
        else
            # Create check script
            cat > /usr/local/bin/check-password-expiry.sh <<EXPIRYSCRIPT
#!/bin/bash
# Password Expiry Check - Generated by seuwurity.sh
# Runs daily, warns 30 days before expiry

NOTIFY_EMAIL="$NOTIFY_EMAIL"
WARN_DAYS=30
HOSTNAME=\$(hostname -f)
TODAY=\$(date +%s)
LOG="/var/log/password-expiry-check.log"

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Check started" >> "\$LOG"

# Check these users
USERS="root"
# Add users with UID >= 1000
USERS="\$USERS \$(awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1}' /etc/passwd)"

CRITICAL=""
WARNINGS=""

for USER in \$USERS; do
    EXPIRY=\$(chage -l "\$USER" 2>/dev/null | grep "Password expires" | cut -d: -f2 | xargs)
    
    [[ "\$EXPIRY" == "never" || -z "\$EXPIRY" ]] && continue
    
    EXPIRY_SEC=\$(date -d "\$EXPIRY" +%s 2>/dev/null) || continue
    DAYS_LEFT=\$(( (EXPIRY_SEC - TODAY) / 86400 ))
    
    if [[ \$DAYS_LEFT -le 0 ]]; then
        CRITICAL="\${CRITICAL}⛔ \$USER - EXPIRED \$((\$DAYS_LEFT * -1)) days ago!\n"
    elif [[ \$DAYS_LEFT -le 7 ]]; then
        CRITICAL="\${CRITICAL}🔴 \$USER - Expires in \$DAYS_LEFT days (\$EXPIRY)\n"
    elif [[ \$DAYS_LEFT -le \$WARN_DAYS ]]; then
        WARNINGS="\${WARNINGS}⚠️  \$USER - Expires in \$DAYS_LEFT days (\$EXPIRY)\n"
    fi
done

# Send email if needed
if [[ -n "\$CRITICAL" || -n "\$WARNINGS" ]]; then
    SUBJECT="[\${HOSTNAME}] Password Expiry Warning"
    [[ -n "\$CRITICAL" ]] && SUBJECT="[\${HOSTNAME}] ⛔ CRITICAL: Passwords Expiring!"
    
    {
        echo "Password Expiry Report - \${HOSTNAME}"
        echo "Date: \$(date)"
        echo ""
        [[ -n "\$CRITICAL" ]] && echo -e "CRITICAL:\n\$CRITICAL"
        [[ -n "\$WARNINGS" ]] && echo -e "WARNINGS:\n\$WARNINGS"
        echo ""
        echo "To change: passwd <username>"
        echo "To check:  chage -l <username>"
    } | mail -s "\$SUBJECT" "\$NOTIFY_EMAIL"
    
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - Email sent" >> "\$LOG"
fi

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Check completed" >> "\$LOG"
EXPIRYSCRIPT

            chmod +x /usr/local/bin/check-password-expiry.sh
            
            # Create cron job
            echo "# Password Expiry Check - Daily 8:00 AM
0 8 * * * root /usr/local/bin/check-password-expiry.sh >/dev/null 2>&1" > /etc/cron.d/password-expiry-check
            
            chmod 644 /etc/cron.d/password-expiry-check
            
            log_success "Daily check created (8:00 AM → $NOTIFY_EMAIL)"
            
            # Apply to existing users
            echo ""
            if ask_user "Apply password aging to root, $SUPERADMIN, $BACKUPADMIN?"; then
                chage -M 365 -m 1 -W 30 root 2>/dev/null && log_success "Applied to: root"
                id "$SUPERADMIN" &>/dev/null && chage -M 365 -m 1 -W 30 "$SUPERADMIN" 2>/dev/null && log_success "Applied to: $SUPERADMIN"
                id "$BACKUPADMIN" &>/dev/null && chage -M 365 -m 1 -W 30 "$BACKUPADMIN" 2>/dev/null && log_success "Applied to: $BACKUPADMIN"
            fi
            
            # Test email
            echo ""
            if ask_user "Send test email to $NOTIFY_EMAIL?"; then
                echo "Test from $(hostname) - Password expiry notifications work!" | mail -s "[$(hostname)] Test" "$NOTIFY_EMAIL"
                log_success "Test email sent - check inbox (and spam)"
            fi
        fi
    fi
    
    fix_applied "AUTH-9286"
else
    fix_skipped "AUTH-9286"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: AUTH-9328 - Default Umask
#══════════════════════════════════════════════════════════════════════════════

print_section "📁 AUTH-9328: Default Umask (File Permission Mask)"

echo ""
echo "Umask controls the default permissions for newly created files."
echo "  - 022 = New files are readable by everyone (rwxr-xr-x for dirs)"
echo "  - 027 = New files are only readable by owner and group (rwxr-x--- for dirs)"
echo ""
echo "A stricter umask (027) prevents other users from reading your files"
echo "by default, improving confidentiality."
echo ""

if ask_user "Do you want to tighten the default umask from 022 to 027?"; then

    CURRENT_UMASK=$(grep "^UMASK" /etc/login.defs | awk '{print $2}')

    if [[ "$CURRENT_UMASK" == "022" ]] || [[ -z "$CURRENT_UMASK" ]]; then
        log_warning "Umask is $CURRENT_UMASK (permissive)"
        
        sed -i 's/^UMASK.*/UMASK           027/' /etc/login.defs
        
        if ! grep -q "^umask 027" /etc/profile; then
            echo "umask 027" >> /etc/profile
        fi
        
        log_success "Umask set to 027"
        fix_applied "AUTH-9328"
    else
        log_success "Umask already tightened ($CURRENT_UMASK) - No action needed"
    fi

else
    fix_skipped "AUTH-9328"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: PKGS-7346 - Old Package Cleanup
#══════════════════════════════════════════════════════════════════════════════

print_section "📦 PKGS-7346: Old Package Configuration Cleanup"

echo ""
echo "When packages are removed (but not purged), their configuration files"
echo "remain on the system. These residual configs can:"
echo "  - Contain outdated/insecure settings"
echo "  - Cause confusion during reinstallation"
echo "  - Waste disk space"
echo ""
echo "This fix removes configuration files from already-uninstalled packages."
echo ""

if ask_user "Do you want to clean up old package configurations?"; then

    RESIDUAL=$(dpkg -l | grep "^rc" | wc -l)

    if [[ "$RESIDUAL" -gt 0 ]]; then
        log_warning "$RESIDUAL packages with residual config found"
        echo ""
        echo "Packages to clean:"
        dpkg -l | grep "^rc" | awk '{print "  - " $2}'
        echo ""
        
        dpkg -l | grep "^rc" | awk '{print $2}' | xargs -r dpkg --purge
        apt-get autoremove -y
        apt-get autoclean -y
        log_success "Old packages cleaned up"
        fix_applied "PKGS-7346"
    else
        log_success "No residual configs found - No action needed"
    fi

else
    fix_skipped "PKGS-7346"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: PKGS-7370 - debsums Package Verification
#══════════════════════════════════════════════════════════════════════════════

print_section "✅ PKGS-7370: Package Verification Tool (debsums)"

echo ""
echo "debsums verifies installed package files against their MD5 checksums."
echo "This helps detect:"
echo "  - Corrupted files (disk errors, failed updates)"
echo "  - Tampered files (malware, rootkits)"
echo "  - Accidentally modified system files"
echo ""
echo "After installation, run 'debsums -c' to check for modified files."
echo ""

if ask_user "Do you want to install debsums for package verification?"; then

    if ! command -v debsums &> /dev/null; then
        log_warning "debsums not installed"
        
        apt-get update -qq
        apt-get install -y debsums
        log_success "debsums installed"
        log_info "Tip: Run 'debsums -c' to find modified package files"
        fix_applied "PKGS-7370"
    else
        log_success "debsums already installed - No action needed"
    fi

else
    fix_skipped "PKGS-7370"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: BANN-7126 - Local Login Banner (/etc/issue)
#══════════════════════════════════════════════════════════════════════════════

print_section "⚠️ BANN-7126: Local Login Banner (/etc/issue)"

echo ""
echo "A legal warning banner is displayed before login at the local console."
echo "This banner:"
echo "  - Warns unauthorized users that access is prohibited"
echo "  - States that activities may be monitored and logged"
echo "  - Provides legal protection by establishing authorized use policy"
echo ""
echo "This is required by many security compliance frameworks (PCI-DSS, HIPAA, etc.)"
echo ""

if ask_user "Do you want to set a legal warning banner for local login?"; then

    BANNER_TEXT="***************************************************************************
                           AUTHORIZED ACCESS ONLY
                           
This system is for authorized use only. All activities are monitored and
logged. Unauthorized access will be prosecuted to the fullest extent of law.
***************************************************************************"

    if [[ ! -s /etc/issue ]] || ! grep -q "AUTHORIZED" /etc/issue 2>/dev/null; then
        log_warning "/etc/issue has no legal banner"
        
        echo "$BANNER_TEXT" > /etc/issue
        log_success "Banner set in /etc/issue"
        fix_applied "BANN-7126"
    else
        log_success "/etc/issue banner already present - No action needed"
    fi

else
    fix_skipped "BANN-7126"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: BANN-7130 - Remote Login Banner (/etc/issue.net)
#══════════════════════════════════════════════════════════════════════════════

print_section "⚠️ BANN-7130: Remote Login Banner (/etc/issue.net)"

echo ""
echo "A legal warning banner is displayed before SSH/remote login."
echo "NOTE: This banner is ONLY shown to admin users, NOT to root."
echo "      (Root connections are used for cluster operations)"
echo ""

if ask_user "Do you want to set a legal warning banner for remote login?"; then

    BANNER_TEXT="***************************************************************************
                           AUTHORIZED ACCESS ONLY
                           
This system is for authorized use only. All activities are monitored and
logged. Unauthorized access will be prosecuted to the fullest extent of law.
***************************************************************************"

    if [[ ! -s /etc/issue.net ]] || ! grep -q "AUTHORIZED" /etc/issue.net 2>/dev/null; then
        echo "$BANNER_TEXT" > /etc/issue.net
        log_success "Banner set in /etc/issue.net"
        fix_applied "BANN-7130"
    else
        log_success "/etc/issue.net banner already present - No action needed"
    fi

else
    fix_skipped "BANN-7130"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: HRDN-7230 - Malware/Rootkit Scanner
#══════════════════════════════════════════════════════════════════════════════

print_section "🔍 HRDN-7230: Malware/Rootkit Scanner"

echo ""
echo "Rootkit scanners detect hidden malware and system compromises."
echo "Available options:"
echo "  - rkhunter: Comprehensive scanner, checks for rootkits, backdoors,"
echo "              suspicious files, and wrong permissions"
echo "  - chkrootkit: Lightweight alternative, quick scans"
echo "  - ClamAV: Full antivirus scanner for files and emails"
echo ""
echo "Regular scans help detect compromises early before damage spreads."
echo ""
echo "Note: VM disk images (.qcow2, .raw, .vmdk) will be automatically excluded"
echo "      to prevent false positives and performance issues."
echo ""

if ask_user "Do you want to install a malware/rootkit scanner?"; then

    echo ""
    echo "Select scanner to install:"
    echo "  1) rkhunter (recommended, comprehensive rootkit detection)"
    echo "  2) chkrootkit (lightweight rootkit scanner)"
    echo "  3) ClamAV (full antivirus scanner)"
    echo "  4) rkhunter + ClamAV (recommended combination)"
    echo "  5) All three scanners"
    echo ""
    read -p "Your choice [1-5]: " scanner_choice

    case $scanner_choice in
        1)
            if ! command -v rkhunter &> /dev/null; then
                apt-get update -qq
                apt-get install -y rkhunter
                
                log_info "Configuring rkhunter exclusions for VM disk images..."
                cat >> /etc/rkhunter.conf.local << 'EOF'

# VM Disk Image Exclusions (Proxmox/KVM)
EXCLUDE_PATHS="/var/lib/vz/images:/var/lib/vz/template:/var/lib/vz/dump:/var/lib/pve"
EOF
                
                rkhunter --update 2>/dev/null || true
                rkhunter --propupd 2>/dev/null || true
                log_success "rkhunter installed with VM exclusions"
                log_info "Run 'rkhunter --check' for a full scan"
            else
                log_success "rkhunter already installed"
            fi
            fix_applied "HRDN-7230"
            ;;
            
        2)
            if ! command -v chkrootkit &> /dev/null; then
                apt-get update -qq
                apt-get install -y chkrootkit
                log_success "chkrootkit installed"
                log_info "Run 'chkrootkit' for a scan"
            else
                log_success "chkrootkit already installed"
            fi
            fix_applied "HRDN-7230"
            ;;
            
        3)
            if ! command -v clamscan &> /dev/null; then
                apt-get update -qq
                apt-get install -y clamav clamav-daemon clamav-freshclam
                
                log_info "Configuring ClamAV exclusions for VM disk images..."
                
                if [[ -f /etc/clamav/clamd.conf ]]; then
                    cp /etc/clamav/clamd.conf /etc/clamav/clamd.conf.bak.$(date +%Y%m%d)
                    
                    cat >> /etc/clamav/clamd.conf << 'EOF'

# VM Disk Image Exclusions (Proxmox/KVM)
ExcludePath ^/var/lib/vz/images/
ExcludePath ^/var/lib/vz/template/
ExcludePath ^/var/lib/vz/dump/
ExcludePath ^/var/lib/pve/
ExcludePath \.qcow2$
ExcludePath \.raw$
ExcludePath \.vmdk$
ExcludePath \.iso$
EOF
                fi
                
                cat > /usr/local/bin/clamscan-safe << 'SCRIPT'
#!/bin/bash
EXCLUDE_OPTS=(
    --exclude='\.qcow2$'
    --exclude='\.raw$'
    --exclude='\.vmdk$'
    --exclude='\.iso$'
    --exclude-dir='/var/lib/vz/images'
    --exclude-dir='/var/lib/vz/template'
    --exclude-dir='/var/lib/vz/dump'
    --exclude-dir='/var/lib/pve'
)
echo "Running ClamAV with VM disk image exclusions..."
clamscan "${EXCLUDE_OPTS[@]}" "$@"
SCRIPT
                chmod +x /usr/local/bin/clamscan-safe
                
                log_info "Updating ClamAV virus definitions..."
                systemctl stop clamav-freshclam 2>/dev/null || true
                freshclam 2>/dev/null || true
                systemctl start clamav-freshclam 2>/dev/null || true
                systemctl enable clamav-daemon 2>/dev/null || true
                systemctl start clamav-daemon 2>/dev/null || true
                
                log_success "ClamAV installed with VM exclusions"
                log_info "Use 'clamscan-safe -r /path' for scanning"
            else
                log_success "ClamAV already installed"
            fi
            fix_applied "HRDN-7230"
            ;;
            
        4)
            apt-get update -qq
            
            if ! command -v rkhunter &> /dev/null; then
                apt-get install -y rkhunter
                cat >> /etc/rkhunter.conf.local << 'EOF'

# VM Disk Image Exclusions (Proxmox/KVM)
EXCLUDE_PATHS="/var/lib/vz/images:/var/lib/vz/template:/var/lib/vz/dump:/var/lib/pve"
EOF
                rkhunter --update 2>/dev/null || true
                rkhunter --propupd 2>/dev/null || true
                log_success "rkhunter installed"
            fi
            
            if ! command -v clamscan &> /dev/null; then
                apt-get install -y clamav clamav-daemon clamav-freshclam
                
                if [[ -f /etc/clamav/clamd.conf ]]; then
                    cat >> /etc/clamav/clamd.conf << 'EOF'

# VM Disk Image Exclusions (Proxmox/KVM)
ExcludePath ^/var/lib/vz/images/
ExcludePath ^/var/lib/vz/template/
ExcludePath ^/var/lib/vz/dump/
ExcludePath ^/var/lib/pve/
ExcludePath \.qcow2$
ExcludePath \.raw$
ExcludePath \.vmdk$
ExcludePath \.iso$
EOF
                fi
                
                cat > /usr/local/bin/clamscan-safe << 'SCRIPT'
#!/bin/bash
EXCLUDE_OPTS=(
    --exclude='\.qcow2$'
    --exclude='\.raw$'
    --exclude='\.vmdk$'
    --exclude='\.iso$'
    --exclude-dir='/var/lib/vz/images'
    --exclude-dir='/var/lib/vz/template'
    --exclude-dir='/var/lib/vz/dump'
    --exclude-dir='/var/lib/pve'
)
clamscan "${EXCLUDE_OPTS[@]}" "$@"
SCRIPT
                chmod +x /usr/local/bin/clamscan-safe
                
                systemctl stop clamav-freshclam 2>/dev/null || true
                freshclam 2>/dev/null || true
                systemctl start clamav-freshclam 2>/dev/null || true
                systemctl enable clamav-daemon 2>/dev/null || true
                
                log_success "ClamAV installed"
            fi
            
            log_success "rkhunter + ClamAV installed"
            fix_applied "HRDN-7230"
            ;;
            
        5)
            apt-get update -qq
            apt-get install -y rkhunter chkrootkit clamav clamav-daemon clamav-freshclam
            
            cat >> /etc/rkhunter.conf.local << 'EOF'

# VM Disk Image Exclusions (Proxmox/KVM)
EXCLUDE_PATHS="/var/lib/vz/images:/var/lib/vz/template:/var/lib/vz/dump:/var/lib/pve"
EOF
            
            if [[ -f /etc/clamav/clamd.conf ]]; then
                cat >> /etc/clamav/clamd.conf << 'EOF'

# VM Disk Image Exclusions (Proxmox/KVM)
ExcludePath ^/var/lib/vz/images/
ExcludePath ^/var/lib/vz/template/
ExcludePath ^/var/lib/vz/dump/
ExcludePath ^/var/lib/pve/
ExcludePath \.qcow2$
ExcludePath \.raw$
ExcludePath \.vmdk$
ExcludePath \.iso$
EOF
            fi
            
            cat > /usr/local/bin/clamscan-safe << 'SCRIPT'
#!/bin/bash
EXCLUDE_OPTS=(
    --exclude='\.qcow2$'
    --exclude='\.raw$'
    --exclude='\.vmdk$'
    --exclude='\.iso$'
    --exclude-dir='/var/lib/vz/images'
    --exclude-dir='/var/lib/vz/template'
    --exclude-dir='/var/lib/vz/dump'
    --exclude-dir='/var/lib/pve'
)
clamscan "${EXCLUDE_OPTS[@]}" "$@"
SCRIPT
            chmod +x /usr/local/bin/clamscan-safe
            
            rkhunter --update 2>/dev/null || true
            rkhunter --propupd 2>/dev/null || true
            freshclam 2>/dev/null || true
            
            log_success "All scanners installed"
            fix_applied "HRDN-7230"
            ;;
            
        *)
            log_warning "Invalid choice"
            fix_skipped "HRDN-7230"
            ;;
    esac

else
    fix_skipped "HRDN-7230"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: FINT-4350 - File Integrity Monitoring (AIDE)
#══════════════════════════════════════════════════════════════════════════════

print_section "📋 FINT-4350: File Integrity Monitoring (AIDE)"

echo ""
echo "AIDE (Advanced Intrusion Detection Environment) monitors file changes."
echo "It creates a database of file checksums and can detect:"
echo "  - Modified system binaries (possible trojan/backdoor)"
echo "  - Changed configuration files"
echo "  - New unexpected files"
echo "  - Permission changes"
echo ""
echo "Note: Initial database creation takes 5-15 minutes."
echo "After installation, run 'aide --check' regularly or via cron."
echo ""

if ask_user "Do you want to install AIDE for file integrity monitoring?"; then

    if ! command -v aide &> /dev/null; then
        log_warning "AIDE not installed"
        
        apt-get update -qq
        apt-get install -y aide aide-common
        
        echo ""
        log_info "Initializing AIDE database (this may take several minutes)..."
        aideinit 2>/dev/null || true
        
        if [[ -f /var/lib/aide/aide.db.new ]]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        fi
        
        log_success "AIDE installed and initialized"
        log_info "Tip: Set up daily 'aide --check' via cron"
        fix_applied "FINT-4350"
    else
        log_success "AIDE already installed - No action needed"
    fi

else
    fix_skipped "FINT-4350"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: ACCT-9622 - Process Accounting (acct)
#══════════════════════════════════════════════════════════════════════════════

print_section "📊 ACCT-9622: Process Accounting (acct)"

echo ""
echo "Process accounting logs information about every process that runs:"
echo "  - Which commands were executed"
echo "  - By which user"
echo "  - How long they ran"
echo "  - How much CPU/memory they used"
echo ""
echo "This is invaluable for forensic analysis after a security incident."
echo "Commands: 'lastcomm' shows recent commands, 'sa' shows statistics."
echo ""

if ask_user "Do you want to install process accounting (acct)?"; then

    if ! dpkg -l 2>/dev/null | grep -q " acct "; then
        log_warning "acct (process accounting) not installed"
        
        apt-get update -qq
        apt-get install -y acct
        systemctl enable acct 2>/dev/null || true
        systemctl start acct 2>/dev/null || true
        log_success "Process accounting enabled"
        log_info "Use 'lastcomm' to see recent commands"
        fix_applied "ACCT-9622"
    else
        log_success "acct already installed - No action needed"
    fi

else
    fix_skipped "ACCT-9622"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: ACCT-9626 - System Statistics (sysstat)
#══════════════════════════════════════════════════════════════════════════════

print_section "📊 ACCT-9626: System Statistics (sysstat)"

echo ""
echo "sysstat collects and reports system performance statistics:"
echo "  - CPU usage over time"
echo "  - Memory and swap usage"
echo "  - Disk I/O statistics"
echo "  - Network statistics"
echo ""
echo "Commands: 'sar' shows historical data, 'iostat' shows I/O stats,"
echo "'mpstat' shows CPU stats. Helps diagnose performance issues."
echo ""

if ask_user "Do you want to install sysstat for system statistics?"; then

    if ! dpkg -l 2>/dev/null | grep -q " sysstat "; then
        log_warning "sysstat not installed"
        
        apt-get update -qq
        apt-get install -y sysstat
        sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
        systemctl enable sysstat 2>/dev/null || true
        systemctl start sysstat 2>/dev/null || true
        log_success "sysstat installed and enabled"
        log_info "Use 'sar' to view historical statistics"
        fix_applied "ACCT-9626"
    else
        log_success "sysstat already installed - No action needed"
    fi

else
    fix_skipped "ACCT-9626"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: USB-1000/STRG-1846 - USB/Firewire Storage
#══════════════════════════════════════════════════════════════════════════════

print_section "💾 USB-1000/STRG-1846: Disable USB/Firewire Storage"

echo ""
echo "USB and Firewire storage devices can be used to:"
echo "  - Steal data by copying files to a USB drive"
echo "  - Introduce malware by plugging in an infected device"
echo "  - Bypass network security controls"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will completely disable USB storage devices!${NC}"
echo "   USB keyboards, mice, and other non-storage devices still work."
echo "   Only enable this on servers that never need USB drives."
echo ""

if ask_user "Do you want to disable USB and Firewire storage devices?"; then

    if [[ ! -f /etc/modprobe.d/disable-storage.conf ]]; then
        cat > /etc/modprobe.d/disable-storage.conf << 'EOF'
# Lynis USB-1000/STRG-1846: Disable USB and Firewire storage
install usb-storage /bin/true
install firewire-core /bin/true
install firewire-ohci /bin/true
install firewire-sbp2 /bin/true
EOF
        log_success "USB/Firewire storage disabled"
        log_warning "Reboot required for full effect"
        fix_applied "USB-1000"
    else
        log_success "USB/Firewire storage already disabled - No action needed"
    fi

else
    fix_skipped "USB-1000"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: HRDN-7222 - Restrict Compiler Access
#══════════════════════════════════════════════════════════════════════════════

print_section "🔧 HRDN-7222: Restrict Compiler Access"

echo ""
echo "Compilers (gcc, g++, make) allow creating executable programs."
echo "If an attacker gains shell access, they could use compilers to:"
echo "  - Compile exploit code"
echo "  - Build custom malware"
echo "  - Create privilege escalation tools"
echo ""
echo "Restricting access so only root can use compilers limits this attack vector."
echo "Note: This may break builds for non-root users if needed."
echo ""

if ask_user "Do you want to restrict compiler access to root only?"; then

    if command -v gcc &> /dev/null; then
        GCC_PATH=$(which gcc)
        GCC_PERMS=$(stat -c %a "$GCC_PATH" 2>/dev/null || echo "755")
        
        if [[ "$GCC_PERMS" != "750" ]] && [[ "$GCC_PERMS" != "700" ]]; then
            log_warning "Compiler accessible to all users"
            
            chmod 750 /usr/bin/gcc* 2>/dev/null || true
            chmod 750 /usr/bin/g++* 2>/dev/null || true
            chmod 750 /usr/bin/cc 2>/dev/null || true
            chmod 750 /usr/bin/c++ 2>/dev/null || true
            chmod 750 /usr/bin/make 2>/dev/null || true
            log_success "Compiler access restricted to root"
            fix_applied "HRDN-7222"
        else
            log_success "Compiler already restricted - No action needed"
        fi
    else
        log_info "No compiler installed - Skipping"
    fi

else
    fix_skipped "HRDN-7222"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: Lynis Whitelist for Proxmox
#══════════════════════════════════════════════════════════════════════════════

print_section "📝 Lynis Whitelist for Proxmox False Positives"

echo ""
echo "Some Lynis findings are false positives specific to Proxmox:"
echo ""
echo "  NETW-3015: Promiscuous network interfaces"
echo "    → Proxmox bridges must be promiscuous to forward VM traffic"
echo ""
echo "  KRNL-5788: Non-standard kernel location"
echo "    → Proxmox uses custom pve-kernel with different paths"
echo ""
echo "  FILE-6310: Separate partitions for /tmp, /var, etc."
echo "    → Difficult to change after installation, minimal risk"
echo ""
echo "This creates a profile to skip these false positive tests."
echo ""

if ask_user "Do you want to create a Lynis whitelist for Proxmox?"; then

    if [[ ! -f /etc/lynis/custom.prf ]]; then
        mkdir -p /etc/lynis
        
        cat > /etc/lynis/custom.prf << 'EOF'
# Proxmox-specific Lynis Whitelist
# Generated by seuwurity.sh 

# NETW-3015: Promiscuous interface is normal for Proxmox bridges
skip-test=NETW-3015

# KRNL-5788: Proxmox uses custom kernel, vmlinuz path differs
skip-test=KRNL-5788

# FILE-6310: Partitioning is difficult to change retroactively
skip-test=FILE-6310
EOF
        
        log_success "Lynis whitelist created: /etc/lynis/custom.prf"
        log_info "Use: lynis audit system --profile /etc/lynis/custom.prf"
        fix_applied "LYNIS-WHITELIST"
    else
        log_success "Lynis whitelist already exists - No action needed"
    fi

else
    fix_skipped "LYNIS-WHITELIST"
fi

# ══════════════════════════════════════════════════════════════════════════════
# CIS Benchmark Debian 13 recommendations
# I found time to look into it. Finally.
# A few things seem quite useful. Please note that I "borrowed" me the explanations from the official doc.
# ══════════════════════════════════════════════════════════════════════════════

#══════════════════════════════════════════════════════════════════════════════
# FIX: CIS 1.1.1.1-1.1.1.5 & 3.2.1-3.2.2  + Lynis NETW-3200 - Disable Unused Kernel Modules
#══════════════════════════════════════════════════════════════════════════════
print_section "🧩 CIS 1.1.1 & 3.2 + Lynis NETW-3200 - Disable Unused Kernel Modules"

echo ""
echo "The Linux kernel can load modules for filesystems and network protocols."
echo "Unused modules increase the attack surface - vulnerabilities in modules"
echo "you don't use can still be exploited if they're loadable."
echo ""
echo "Filesystem modules to disable:"
echo "  - cramfs: Compressed ROM filesystem (embedded systems)"
echo "  - freevxfs: Veritas filesystem (HP-UX)"
echo "  - hfs/hfsplus: Mac OS filesystems"
echo "  - jffs2: Flash memory filesystem"
echo ""
echo "Network modules to disable:"
echo "  - atm: Asynchronous Transfer Mode (obsolete)"
echo "  - can: Controller Area Network (automotive/industrial)"
echo "  - dccp: Datagram Congestion Control Protocol (rarely used)"
echo "  - sctp: Stream Control Transmission Protocol (telecom-specific)"
echo "  - rds: Reliable Datagram Sockets (Oracle cluster-specific)"
echo "  - tipc: Transparent Inter-Process Communication (cluster-specific)"
echo ""
echo "Impact on Proxmox:"
echo "  - VMs and containers are NOT affected"
echo "  - These modules are never used by Proxmox according to my knowledge"
echo "  - Works with pve-kernel (same module system as standard kernel)"
echo ""

if ask_user "Do you want to disable unused kernel modules?"; then

    if [[ ! -f /etc/modprobe.d/cis-disable-modules.conf ]]; then
        cat > /etc/modprobe.d/cis-disable-modules.conf <<'EOF'
# CIS Benchmark: Disable unused kernel modules
# Generated by seuwurity.sh 

# ═══════════════════════════════════════════════════════════════
# Filesystem Modules (CIS 1.1.1.1-1.1.1.5)
# ═══════════════════════════════════════════════════════════════

install cramfs /bin/false
blacklist cramfs

install freevxfs /bin/false
blacklist freevxfs

install hfs /bin/false
blacklist hfs

install hfsplus /bin/false
blacklist hfsplus

install jffs2 /bin/false
blacklist jffs2

# ═══════════════════════════════════════════════════════════════
# Network Modules (CIS 3.2.1-3.2.2 + Lynis NETW-3200)
# ═══════════════════════════════════════════════════════════════

install atm /bin/false
blacklist atm

install can /bin/false
blacklist can

install dccp /bin/false
blacklist dccp

install sctp /bin/false
blacklist sctp

install rds /bin/false
blacklist rds

install tipc /bin/false
blacklist tipc
EOF
        log_success "Kernel module blacklist created"
        log_info "Changes take effect after reboot"
        fix_applied "CIS 1.1.1 & 3.2"
    else
        log_success "Kernel module blacklist already exists - No action needed"
    fi

else
    fix_skipped "CIS 1.1.1 & 3.2"
fi


#══════════════════════════════════════════════════════════════════════════════
# FIX: CIS 5.4.3.2 - Shell timeout after 15 minutes of inactivity
#══════════════════════════════════════════════════════════════════════════════

print_section "⏳ CIS 5.4.3.2 - Shell Timeout"

echo ""
echo "TMOUT automatically logs out inactive shell sessions."
echo "This prevents forgotten open terminals from being a security risk."
echo ""
echo "How it works:"
echo "  - After 15 minutes (900 seconds) of no keyboard input"
echo "  - The shell session is automatically terminated"
echo "  - Only affects interactive sessions (SSH, local terminal)"
echo ""
echo "What is NOT affected:"
echo "  - Proxmox cluster communication (Corosync, pve-cluster)"
echo "  - Live migrations, backups, cron jobs"
echo "  - Any background services or daemons"
echo ""

if ask_user "Do you want to enable automatic shell timeout after 15 minutes?"; then

    if [[ ! -f /etc/profile.d/cis-timeout.sh ]]; then
        cat > /etc/profile.d/cis-timeout.sh <<'EOF'
# CIS 5.4.3.2: Shell Timeout after 15 minutes of inactivity
TMOUT=900
readonly TMOUT
export TMOUT
EOF
        chmod 644 /etc/profile.d/cis-timeout.sh
        log_success "Shell Timeout (15 min) configured"
        fix_applied "CIS 5.4.3.2"
    else
        log_success "Shell Timeout already configured - No action needed"
    fi

else
    fix_skipped "CIS 5.4.3.2"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: CIS 1.5.11-1.5.13 - Disable Core Dumps
#══════════════════════════════════════════════════════════════════════════════

print_section "🔒 CIS 1.5.11-1.5.13 - Disable Core Dumps"

echo ""
echo "Core dumps are memory snapshots created when a program crashes."
echo "They can contain sensitive data like passwords, encryption keys,"
echo "or other confidential information from memory."
echo ""
echo "Security risks of enabled core dumps:"
echo "  - Attackers can extract secrets from crash dumps"
echo "  - Debug information helps exploit development"
echo "  - Disk space exhaustion via large dump files"
echo ""
echo "What this fix does:"
echo "  - Disables core dump storage via systemd"
echo "  - Sets ProcessSizeMax=0 to prevent dump processing"
echo "  - Sets hard limit in /etc/security/limits.conf"
echo ""
echo "Impact on Proxmox:"
echo "  - VMs and containers are NOT affected"
echo "  - Only host-level crashes (which shouldn't happen anyway)"
echo "  - Debugging becomes harder (but who debugs production servers? Like really guys?)"
echo ""

if ask_user "Do you want to disable core dumps?"; then

    # Method 1: systemd-coredump
    if [[ ! -f /etc/systemd/coredump.conf.d/disable-coredump.conf ]]; then
        mkdir -p /etc/systemd/coredump.conf.d
        cat > /etc/systemd/coredump.conf.d/disable-coredump.conf <<'EOF'
# CIS 1.5.11-1.5.13: Disable Core Dumps
[Coredump]
Storage=none
ProcessSizeMax=0
EOF
        log_success "Core dumps disabled via systemd"
    else
        log_info "systemd coredump config already exists"
    fi

    # Method 2 according to the CIS Doc: limits.conf (belt and suspenders)
    if ! grep -q "hard core 0" /etc/security/limits.conf 2>/dev/null; then
        echo "* hard core 0" >> /etc/security/limits.conf
        log_success "Core dumps disabled via limits.conf"
    else
        log_info "limits.conf already configured"
    fi

    fix_applied "CIS 1.5.11-1.5.13"

else
    fix_skipped "CIS 1.5.11-1.5.13"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: CIS 2.4.1.2-2.4.1.9 & 2.4.2.1 - Cron/At Access Hardening
#══════════════════════════════════════════════════════════════════════════════
print_section "📅 CIS 2.4.1.2-2.4.2.1 - Cron/At Access Hardening"

echo ""
echo "Cron and At are job schedulers that execute commands at specified times."
echo "If misconfigured, attackers can use them for persistence or privilege escalation."
echo ""
echo "What this fix does:"
echo "  - Restricts cron directories to root only (chmod 700)"
echo "  - Creates cron.allow/at.allow with only root"
echo "  - Removes cron.deny/at.deny (allow takes precedence)"
echo ""
echo "Affected directories:"
echo "  - /etc/crontab"
echo "  - /etc/cron.hourly, cron.daily, cron.weekly, cron.monthly"
echo "  - /etc/cron.d"
echo ""
echo "Impact on Proxmox:"
echo "  - VMs and containers are NOT affected"
echo "  - Only root can create/modify cron jobs on the host"
echo "  - Proxmox scheduled tasks (backups, etc.) still work (they run as root)"
echo ""

if ask_user "Do you want to harden cron/at access?"; then

    # Restrict cron directories according to doc
    chmod 700 /etc/crontab 2>/dev/null
    chmod 700 /etc/cron.hourly 2>/dev/null
    chmod 700 /etc/cron.daily 2>/dev/null
    chmod 700 /etc/cron.weekly 2>/dev/null
    chmod 700 /etc/cron.monthly 2>/dev/null
    chmod 700 /etc/cron.d 2>/dev/null
    log_success "Cron directories restricted to root"

    # Create cron.allow (only root)
    if [[ ! -f /etc/cron.allow ]]; then
        echo "root" > /etc/cron.allow
        chmod 640 /etc/cron.allow
        log_success "cron.allow created (root only)"
    else
        log_info "cron.allow already exists"
    fi

    # Create at.allow (only root)
    if [[ ! -f /etc/at.allow ]]; then
        echo "root" > /etc/at.allow
        chmod 640 /etc/at.allow
        log_success "at.allow created (root only)"
    else
        log_info "at.allow already exists"
    fi

    # Remove deny files (allow takes precedence anyway)
    rm -f /etc/cron.deny /etc/at.deny 2>/dev/null
    log_success "cron.deny/at.deny removed"

    fix_applied "CIS 2.4.1.2-2.4.2.1"

else
    fix_skipped "CIS 2.4.1.2-2.4.2.1"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: CIS 5.1.1-5.1.3 - SSH File Permissions Hardening
#══════════════════════════════════════════════════════════════════════════════
print_section "🔑 CIS 5.1.1-5.1.3 - SSH File Permissions Hardening"

echo ""
echo "SSH host keys are used to authenticate the server to clients."
echo "If private keys are readable by others, attackers can impersonate your server"
echo "(Man-in-the-Middle attacks) or decrypt captured SSH traffic."
echo ""
echo "What this fix does:"
echo "  - /etc/ssh/sshd_config → 600 (root read/write only)"
echo "  - /etc/ssh/ssh_host_*_key → 600 (private keys, root only)"
echo "  - /etc/ssh/ssh_host_*_key.pub → 644 (public keys, world readable)"
echo "  - All SSH files owned by root:root"
echo ""
echo "Impact on Proxmox:"
echo "  - VMs and containers are NOT affected"
echo "  - SSH continues to work normally"
echo "  - Cluster communication unaffected"
echo ""

if ask_user "Do you want to harden SSH file permissions?"; then

    # sshd_config - only root should read/write
    chmod 600 /etc/ssh/sshd_config 2>/dev/null
    chown root:root /etc/ssh/sshd_config 2>/dev/null
    log_success "sshd_config permissions set (600)"

    # Private host keys - only root should read
    chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null
    chown root:root /etc/ssh/ssh_host_*_key 2>/dev/null
    log_success "Private host keys permissions set (600)"

    # Public host keys - world readable is fine
    chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null
    chown root:root /etc/ssh/ssh_host_*_key.pub 2>/dev/null
    log_success "Public host keys permissions set (644)"

    fix_applied "CIS 5.1.1-5.1.3"

else
    fix_skipped "CIS 5.1.1-5.1.3"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: CIS 4.2.1.1-4.2.1.4 - Journald Hardening
#══════════════════════════════════════════════════════════════════════════════
print_section "📋 CIS 4.2.1.1-4.2.1.4 - Journald Hardening"

echo ""
echo "Journald is the systemd logging daemon. Proper configuration ensures:"
echo "  - Logs survive reboots (persistent storage)"
echo "  - Logs are compressed to save space"
echo "  - No duplicate forwarding to syslog"
echo ""
echo "What this fix does:"
echo "  - Storage=persistent (logs survive reboot)"
echo "  - Compress=yes (saves disk space)"
echo "  - ForwardToSyslog=no (avoids duplicate logs)"
echo ""
echo "Impact on Proxmox:"
echo "  - VMs and containers are NOT affected"
echo "  - Better forensic capabilities after incidents"
echo ""

if ask_user "Do you want to harden journald configuration?"; then

    if [[ ! -f /etc/systemd/journald.conf.d/99-cis-hardening.conf ]]; then
        mkdir -p /etc/systemd/journald.conf.d
        cat > /etc/systemd/journald.conf.d/99-cis-hardening.conf <<'EOF'
# CIS 4.2.1.1-4.2.1.4: Journald Hardening
[Journal]
Storage=persistent
Compress=yes
ForwardToSyslog=no
EOF
        systemctl restart systemd-journald
        log_success "Journald hardened (persistent, compressed)"
        fix_applied "CIS 4.2.1.1-4.2.1.4"
    else
        log_success "Journald already hardened - No action needed"
    fi

else
    fix_skipped "CIS 4.2.1.1-4.2.1.4"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: CIS 5.3.3.1 - Account Lockout with pam_faillock
#══════════════════════════════════════════════════════════════════════════════
print_section "🔒 CIS 5.3.3.1 - Account Lockout Policy (pam_faillock)"

echo ""
echo "pam_faillock locks accounts after failed login attempts."
echo "This protects against brute-force password attacks."
echo ""
echo "Recommended settings:"
echo "  - deny=5 (lock after 5 failed attempts)"
echo "  - unlock_time=600 (auto-unlock after 10 minutes)"
echo "  - fail_interval=900 (count failures within 15 minutes)"
echo ""
echo -e "${YELLOW}⚠️  WARNING: Root is excluded to prevent lockout!${NC}"
echo ""
echo "Impact on Proxmox:"
echo "  - VMs and containers are NOT affected"
echo "  - Protects against brute-force attacks"
echo "  - Works alongside Fail2Ban"
echo ""

if ask_user "Do you want to enable account lockout after 5 failed attempts?"; then

    if [[ ! -f /etc/security/faillock.conf.d/cis-faillock.conf ]]; then
        mkdir -p /etc/security/faillock.conf.d
        cat > /etc/security/faillock.conf.d/cis-faillock.conf <<'EOF'
# CIS 5.3.3.1: Account Lockout Policy
# Lock account after 5 failed attempts
deny = 5

# Auto-unlock after 10 minutes (600 seconds)
unlock_time = 600

# Count failures within 15 minutes (900 seconds)
fail_interval = 900

# Don't lock root (prevents total lockout)
even_deny_root = false

# Directory for failure records
dir = /var/run/faillock
EOF
        log_success "Account lockout configured (5 attempts, 10 min unlock)"
        log_info "Root is excluded from lockout for safety"
        fix_applied "CIS 5.3.3.1"
    else
        log_success "Account lockout already configured - No action needed"
    fi

else
    fix_skipped "CIS 5.3.3.1"
fi

#══════════════════════════════════════════════════════════════════════════════
# FIX: CIS 5.3.3.2 - Password History with pam_pwhistory
#══════════════════════════════════════════════════════════════════════════════
print_section "🔑 CIS 5.3.3.2 - Password History (pam_pwhistory)"

echo ""
echo "pam_pwhistory prevents users from reusing old passwords."
echo "This stops the common pattern of cycling between 2-3 passwords."
echo ""
echo "Recommended setting:"
echo "  - remember=24 (remember last 24 passwords)"
echo ""
echo "Impact on Proxmox:"
echo "  - VMs and containers are NOT affected"
echo "  - Only affects password changes on the host"
echo ""

if ask_user "Do you want to enable password history (remember last 24)?"; then

    if ! grep -q "pam_pwhistory.so" /etc/pam.d/common-password 2>/dev/null; then
        # Backup first
        cp /etc/pam.d/common-password /etc/pam.d/common-password.bak.$(date +%Y%m%d)
        
        # Add pwhistory before pam_unix
        sed -i '/pam_unix.so/i password    required    pam_pwhistory.so remember=24 use_authtok' /etc/pam.d/common-password
        
        log_success "Password history enabled (remember last 24)"
        fix_applied "CIS 5.3.3.2"
    else
        log_success "Password history already configured - No action needed"
    fi

else
    fix_skipped "CIS 5.3.3.2"
fi


#══════════════════════════════════════════════════════════════════════════════
# FIX: CIS 5.1.4-5.1.22 - SSH Cryptographic Settings
#══════════════════════════════════════════════════════════════════════════════
print_section "🔐 CIS 5.1.4-5.1.22 - SSH Cryptographic Hardening"

echo ""
echo "Modern SSH should use only strong cryptographic algorithms."
echo "Weak or outdated algorithms can be broken by attackers."
echo ""
echo "What this fix adds to sshd_config:"
echo "  - Strong Ciphers (AES-GCM, AES-CTR only)"
echo "  - Secure Key Exchange (Curve25519, DH Group 16/18)"
echo "  - Strong MACs (SHA2-512, SHA2-256 ETM only)"
echo "  - Disables unused features (GSSAPI, Hostbased, Rhosts)"
echo "  - Enables verbose logging for security audits"
echo "  - Sets login banner (/etc/issue.net)"
echo ""
echo "Impact on Proxmox:"
echo "  - VMs and containers are NOT affected"
echo "  - Very old SSH clients may not connect (good!)"
echo "  - Cluster communication unaffected"
echo ""

# Here I did spend Hours q-q. I hope it works now.
if ask_user "Do you want to apply SSH cryptographic hardening?"; then

    # Check if already applied
    if grep -q "# CIS SSH Cryptographic Hardening" /etc/ssh/sshd_config 2>/dev/null; then
        log_success "SSH cryptographic hardening already applied - Skipping"
    else
        
        # Backup
        BACKUP_FILE="/etc/ssh/sshd_config.backup.crypto.$(date +%Y%m%d_%H%M%S)"
        cp /etc/ssh/sshd_config "$BACKUP_FILE"
        log_info "Backed up to: $BACKUP_FILE"
        
        # Check OpenSSH version to ensure compatibility
        SSH_VERSION=$(ssh -V 2>&1 | grep -oP 'OpenSSH_\K[0-9.]+' | cut -d. -f1,2)
        if awk "BEGIN {exit !($SSH_VERSION >= 7.4)}"; then
            log_info "OpenSSH version $SSH_VERSION - Compatible"
        else
            log_warning "OpenSSH version $SSH_VERSION - May not support all algorithms"
        fi
        
        # Remove existing crypto directives (prevent duplicates)
        sed -i.pre-crypto \
            -e '/^Ciphers /d' \
            -e '/^KexAlgorithms /d' \
            -e '/^MACs /d' \
            -e '/^GSSAPIAuthentication /d' \
            -e '/^HostbasedAuthentication /d' \
            -e '/^IgnoreRhosts /d' \
            -e '/^PermitUserEnvironment /d' \
            -e '/^Banner /d' \
            /etc/ssh/sshd_config
        
        # Find insertion point (before first Match block, or at end)
        MATCH_LINE=$(grep -n "^Match " /etc/ssh/sshd_config | head -1 | cut -d: -f1)
        
        if [ -n "$MATCH_LINE" ]; then
            # Insert BEFORE Match block
            INSERT_LINE=$((MATCH_LINE - 1))
            log_info "Inserting crypto settings before Match block (line $MATCH_LINE)"
        else
            # Append at end
            INSERT_LINE=$(wc -l < /etc/ssh/sshd_config)
            log_info "Appending crypto settings at end of config"
        fi
        
        # Create hardening block
        cat > /tmp/ssh_crypto.tmp <<'EOF'

# ═══════════════════════════════════════════════════════════════
# CIS SSH Cryptographic Hardening (5.1.4-5.1.22)
# Generated by seuwurity.sh 
# ═══════════════════════════════════════════════════════════════

# CIS 5.1.4-5.1.6: Strong Ciphers only
Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# CIS 5.1.7-5.1.9: Secure Key Exchange
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# CIS 5.1.10-5.1.12: Strong MACs
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# CIS 5.1.13: Disable GSSAPI Authentication
GSSAPIAuthentication no

# CIS 5.1.14: Disable Hostbased Authentication
HostbasedAuthentication no

# CIS 5.1.15: Ignore Rhosts
IgnoreRhosts yes

# CIS 5.1.18: Disable User Environment
PermitUserEnvironment no

# CIS 5.1.22: Login Banner
Banner /etc/issue.net
EOF

        # Insert crypto block at correct position
        {
            head -n "$INSERT_LINE" /etc/ssh/sshd_config
            cat /tmp/ssh_crypto.tmp
            tail -n +$((INSERT_LINE + 1)) /etc/ssh/sshd_config
        } > /etc/ssh/sshd_config.new
        
        # Test new configuration
        if sshd -t -f /etc/ssh/sshd_config.new 2>/dev/null; then
            log_success "Configuration test passed"
            
            # Apply new config
            mv /etc/ssh/sshd_config.new /etc/ssh/sshd_config
            
            # Restart SSH
            if systemctl restart sshd; then
                if systemctl is-active --quiet sshd; then
                    log_success "SSH cryptographic hardening applied"
                    log_success "Login banner enabled (/etc/issue.net)"
                    fix_applied "CIS 5.1.4-5.1.22"
                    
                    # Test cluster connectivity
                    if command -v pvecm &>/dev/null; then
                        echo ""
                        log_info "Testing cluster connectivity with new crypto..."
                        CLUSTER_IPS=$(pvecm nodes 2>/dev/null | awk '/^[0-9]/ {print $3}')
                        for node_ip in $CLUSTER_IPS; do
                            if timeout 5 ssh -o BatchMode=yes root@$node_ip /bin/true 2>/dev/null; then
                                log_success "Cluster node $node_ip: OK"
                            else
                                log_error "Cluster node $node_ip: FAILED - Check crypto compatibility!"
                            fi
                        done
                    fi
                else
                    log_error "SSH failed to start - Rolling back"
                    cp "$BACKUP_FILE" /etc/ssh/sshd_config
                    systemctl restart sshd
                    fix_failed "CIS 5.1.4-5.1.22"
                fi
            else
                log_error "Failed to restart SSH - Rolling back"
                cp "$BACKUP_FILE" /etc/ssh/sshd_config
                systemctl restart sshd
                fix_failed "CIS 5.1.4-5.1.22"
            fi
        else
            log_error "Configuration test failed - Not applied"
            echo "Error details:"
            sshd -t -f /etc/ssh/sshd_config.new
            rm -f /etc/ssh/sshd_config.new
            fix_failed "CIS 5.1.4-5.1.22"
        fi
        
        # Cleanup
        rm -f /tmp/ssh_crypto.tmp
    fi
else
    fix_skipped "CIS 5.1.4-5.1.22"
fi


# ══════════════════════════════════════════════════════════════════════════════
# EMERGENCY RESTORE SCRIPT
# For when everything goes wrong
# ══════════════════════════════════════════════════════════════════════════════

print_section "🆘 Emergency Restore Script"

cat > /root/emergency-restore.sh <<'RESTORE'
#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# EMERGENCY RESTORE SCRIPT
# ═══════════════════════════════════════════════════════════════
#
# Use this script if you've locked yourself out!
# Must be run from console/IPMI/KVM.

echo ""
echo "🆘 EMERGENCY RESTORE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Reset firewall
echo "Resetting firewall..."
iptables -F
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
ip6tables -F 2>/dev/null
ip6tables -P INPUT ACCEPT 2>/dev/null
echo "✓ Firewall disabled"

# Reset SSH
echo ""
echo "Resetting SSH..."
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i '/^AllowUsers/d' /etc/ssh/sshd_config
sed -i '/^Match Address/,/^$/d' /etc/ssh/sshd_config
sed -i '/^AuthenticationMethods/d' /etc/ssh/sshd_config

# Reset PAM for SSH (remove 2FA)
if grep -q "pam_google_authenticator" /etc/pam.d/sshd 2>/dev/null; then
    sed -i '/pam_google_authenticator/d' /etc/pam.d/sshd
    sed -i '/pam_succeed_if.so user = root/d' /etc/pam.d/sshd
    echo "✓ 2FA removed from PAM"
fi

systemctl restart sshd
echo "✓ SSH reset - Root login from anywhere enabled"

# Stop Fail2Ban
echo ""
echo "Stopping Fail2Ban..."
systemctl stop fail2ban 2>/dev/null
echo "✓ Fail2Ban stopped"

# Ensure root WebUI access
echo ""
echo "Ensuring root WebUI access..."
pveum user modify root@pam --enable 1 2>/dev/null || true
pveum aclmod / -user root@pam -role Administrator 2>/dev/null || true
echo "✓ Root WebUI access enabled"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ EMERGENCY RESTORE COMPLETE"
echo ""
echo "What was done:"
echo "  • Root SSH from anywhere: ENABLED"
echo "  • 2FA: DISABLED"
echo "  • Firewall: DISABLED"
echo "  • Fail2Ban: STOPPED"
echo ""
echo "You can now log in as root!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESTORE

chmod +x /root/emergency-restore.sh
print_success "Emergency restore script created: /root/emergency-restore.sh"

# ══════════════════════════════════════════════════════════════════════════════
# SAVE CREDENTIALS
# ══════════════════════════════════════════════════════════════════════════════

cat > /root/admin_credentials.txt <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROXMOX SECURITY HARDENING - CREDENTIALS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Created: $(date)
Script Version: $SCRIPT_VERSION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SUPERADMIN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Username:    $SUPERADMIN
Password:    $SUPERADMIN_PASS
SSH Access:  From ANYWHERE also in North Korea

BACKUPADMIN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Username: $BACKUPADMIN
Password: $BACKUPADMIN_PASS
SSH Access:  From ANYWHERE also in North Korea

EOF

if [ "$ENABLE_TFA" = "yes" ]; then
    cat >> /root/admin_credentials.txt <<EOF
2FA/TFA:     ENABLED (Google Authenticator)

⚠️  IMPORTANT: The 2FA QR code was displayed during installation!
    If you didn't scan it, run:
    sudo -u $SUPERADMIN google-authenticator

📝 NOTE: Root login does NOT require 2FA (cluster compatible)

EOF
else
    cat >> /root/admin_credentials.txt <<EOF
2FA/TFA:     Not enabled

EOF
fi

cat >> /root/admin_credentials.txt <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ROOT SSH ACCESS (Restricted)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Root SSH is ONLY allowed from (NO 2FA required):

EOF

if [ -n "$CLUSTER_NODE_IPS" ]; then
    echo "Cluster Nodes:" >> /root/admin_credentials.txt
    for IP in $CLUSTER_NODE_IPS; do
        echo "  • $IP" >> /root/admin_credentials.txt
    done
    echo "" >> /root/admin_credentials.txt
fi

if [ -n "$JUMPHOST_IPS" ]; then
    echo "Jumphosts:" >> /root/admin_credentials.txt
    for IP in $JUMPHOST_IPS; do
        echo "  • $IP" >> /root/admin_credentials.txt
    done
    echo "" >> /root/admin_credentials.txt
fi

if [ -z "$ROOT_SSH_ALLOWED_IPS" ]; then
    echo "(No IPs configured - Root SSH disabled)" >> /root/admin_credentials.txt
fi

cat >> /root/admin_credentials.txt <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WEBUI ACCESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URL:         https://$(hostname -I | awk '{print $1}'):8006
Access:      From ANYWHERE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  SECURITY NOTES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Enable 2FA for ALL accounts in WebUI!
  (Datacenter → Permissions → Two Factor)
• Delete this file after saving to password manager!
• Backup location: $BACKUP_DIR/

EMERGENCY RESTORE:
  /root/emergency-restore.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

chmod 600 /root/admin_credentials.txt

# ══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                          ║"
echo "║              🎉 HARDENING COMPLETE! 🎉                                   ║"
echo "║                                                                          ║"
echo "║                         Version: $SCRIPT_VERSION                                  ║"
echo "║                                                                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "         📋 SUPERADMIN & BACKUPADMIN CREDENTIALS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Username: $SUPERADMIN"
echo "Password: $SUPERADMIN_PASS"
echo ""
echo "Username: $BACKUPADMIN"
echo "Password: $BACKUPADMIN_PASS"
echo ""

if [ "$ENABLE_TFA" = "yes" ]; then
    echo "🔐 2FA: ENABLED for superadmin"
    echo "    → SSH login asks for password AND verification code!"
    echo "    → The code comes from your Authenticator app"
    echo ""
    echo "📝 Root SSH: NO 2FA (cluster compatible)"
    echo ""
fi


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "         ⚠️  CRITICAL NEXT STEPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. SAVE THESE CREDENTIALS NOW!"
echo "   → Use a password manager!"
echo ""
echo "2. TEST SSH IN A NEW SESSION:"
echo "   ssh $SUPERADMIN@$(hostname -I | awk '{print $1}')"
echo "   ssh $BACKUPADMIN@$(hostname -I | awk '{print $1}')"

if [ "$ENABLE_TFA" = "yes" ]; then
    echo ""
    echo "   → You'll be asked for password"
    echo "   → Then for 'Verification code' (6-digit code from app)"
fi

echo ""
echo "3. KEEP THIS SESSION OPEN UNTIL IT WORKS!"
echo ""
echo "4. TEST WEBUI:"
echo "   https://$(hostname -I | awk '{print $1}'):8006"
echo ""
echo "5. ENABLE TFA IN THE WEBUI for ROOT, SUPERADMIN:"
echo "   PROXMOX HAS SO FAR NO DOCUMENTED WAY TO IMPLEMENT WEBUI TFA FROM A SCRIPT"
echo "   I'M SORRRRY kay "
echo ""
echo "6. IF PROBLEMS OCCUR:"
echo "   /root/emergency-restore.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "         📁 IMPORTANT FILES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Credentials:     /root/admin_credentials.txt"
echo "Configuration:   /etc/proxmox-security.conf"
echo "Backup:          $BACKUP_DIR/"
echo "Emergency:       /root/emergency-restore.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔴 REBOOT RECOMMENDED for all changes to take effect"
echo ""
echo "Have fun with your hardened Proxmox! 🎉"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo ""
echo -e "\e[33m╔══════════════════════════════════════════════════════════════════╗\e[0m"
echo -e "\e[33m║\e[0m  \e[1;31m⚠  MANUAL STEP REQUIRED ⚠\e[0m                                     \e[33m║\e[0m"
echo -e "\e[33m╠══════════════════════════════════════════════════════════════════╣\e[0m"
echo -e "\e[33m║\e[0m                                                                  \e[33m║\e[0m"
echo -e "\e[33m║\e[0m  Enable TFA in the WebUI for:                                    \e[33m║\e[0m"
echo -e "\e[33m║\e[0m     \e[1;36m→ root\e[0m                                                       \e[33m║\e[0m"
echo -e "\e[33m║\e[0m     \e[1;36m→ $SUPERADMIN\e[0m                                                \e[33m║\e[0m"
echo -e "\e[33m║\e[0m                                                                  \e[33m║\e[0m"
echo -e "\e[33m║\e[0m  Datacenter → Permissions → Two Factor → Add (TOTP)              \e[33m║\e[0m"
echo -e "\e[33m║\e[0m                                                                  \e[33m║\e[0m"
echo -e "\e[33m║\e[0m  \e[90mProxmox has no documented way to do this via script...\e[0m         \e[33m║\e[0m"
echo -e "\e[33m║\e[0m                                                                  \e[33m║\e[0m"
echo -e "\e[33m║\e[0m                    \e[35mI'M SORRYYYYY (╥﹏╥)\e[0m                            \e[33m║\e[0m"
echo -e "\e[33m║\e[0m                                                                  \e[33m║\e[0m"
echo -e "\e[33m╚══════════════════════════════════════════════════════════════════╝\e[0m"
echo ""
## "Meme Area because I can and people on reddit say "I'm otherwise AI"
if ask_user "Wanna see a Secret?"; then
    echo "Brainrot is loading 5%"
    sleep 2
    echo "Brainrot is completing in 10 min"
    sleep 2
    echo "Naaa just kidding you see the brainrot now!"
    echo ""
    echo -e "\e[35m         ∧＿∧\e[0m"
    echo -e "\e[35m        ( ´ω\` )  \e[31m♡\e[0m"
    echo -e "\e[35m        /    \\\e[0m"
    echo -e "\e[35m       | |    | |\e[0m"
    echo -e "\e[35m       | |    | |\e[0m"
    echo -e "\e[35m       U U    U U\e[0m"
    echo ""
    echo -e "\e[31m    ~ I'm a boykisser ~\e[0m"
    echo ""
    sleed 2
    echo "Time for the next meme"
    echo "Loading Obamna..."
    sleep 2
    echo ""
    echo "           O B A M N A"
    echo ""
    echo "        █████████████████"
    echo "      █████████████████████"
    echo "    █████    O B A M N A    █████"
    echo "   ██████                    ██████"
    echo "   ██████    ( •_•)          ██████"
    echo "    █████     <)   )╯        █████"
    echo "      ████████████████████████"
    echo "         ██████████████████"
    echo ""
    sleep 1
    echo "Obamna has arrived."   
    echo "Processing..."
    sleep 1
    echo ""
    echo "YOU GONNA"
    sleep 0.5
    echo "       SAVE"
    sleep 0.5
    echo "             YOU TIME?"
    sleep 1
    echo ""
    echo "   ( •_•)"
    echo "   ( •_•)>⌐■-■"
    sleep 1
    echo "   (⌐■_■)  Yup."
    sleep 1
    echo ""
    echo "Time saved successfully."
else
    echo "Me sad now 🥺"
fi

