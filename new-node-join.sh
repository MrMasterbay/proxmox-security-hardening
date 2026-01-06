#!/bin/bash
#
# Proxmox Cluster Join Mode Script v1.0
# ═══════════════════════════════════════════════════════════════
#
# This script prepares EXISTING hardened nodes to accept a NEW node
# into the cluster. It temporarily relaxes security, guides through
# the join process, then re-hardens everything.
#
# Run this on ALL EXISTING hardened nodes before adding a new node!
#
# ═══════════════════════════════════════════════════════════════

set -e

SCRIPT_VERSION="1.0"

# ══════════════════════════════════════════════════════════════════════════════
# COLORS
# ══════════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

print_header() {
    clear
    echo -e "${CYAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   🛡️  PROXMOX VE Allow Cluster join for non hardend"
    echo "   Version $SCRIPT_VERSION "
    echo "   (Written by a human, not by Skynet... probably)"
    echo ""
    echo "  Made by Nico Schmidt (baGStube_Nico) hopefully"
    echo "  Please consider supporting this script development:"
    echo "  💖 Ko-fi: ko-fi.com/bagstube_nico"
    echo "  🔗 Links: linktr.ee/bagstube_nico"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}   $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

ask_user() {
    local question="$1"
    read -p "$question (y/n) [y]: " answer
    answer=${answer:-y}
    [[ "$answer" =~ ^[YyJj]$ ]]
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then return 1; fi
        done
        return 0
    fi
    return 1
}

# ══════════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# ══════════════════════════════════════════════════════════════════════════════

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run as root!"
    exit 1
fi

if ! command -v pvecm &>/dev/null; then
    echo "❌ This doesn't look like a Proxmox system!"
    exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# LOAD EXISTING CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

SUPERADMIN=""
BACKUPADMIN=""
CLUSTER_NODE_IPS=""

if [[ -f /etc/proxmox-security.conf ]]; then
    source /etc/proxmox-security.conf
fi

# Detect admin users from Proxmox if not in config
if [[ -z "$SUPERADMIN" ]] && [[ -f /etc/pve/user.cfg ]]; then
    SUPERADMIN=$(grep -oP 'user:\K(superadmin[_0-9]*)@pam' /etc/pve/user.cfg 2>/dev/null | head -1 | sed 's/@pam//')
fi
if [[ -z "$BACKUPADMIN" ]] && [[ -f /etc/pve/user.cfg ]]; then
    BACKUPADMIN=$(grep -oP 'user:\K(backupadmin[_0-9]*)@pam' /etc/pve/user.cfg 2>/dev/null | head -1 | sed 's/@pam//')
fi

CURRENT_IP=$(hostname -I | awk '{print $1}')
CURRENT_HOSTNAME=$(hostname)

# ══════════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ══════════════════════════════════════════════════════════════════════════════

print_header

echo ""
echo "This node: $CURRENT_HOSTNAME ($CURRENT_IP)"
echo ""

if [[ -n "$SUPERADMIN" ]]; then
    echo "Detected Superadmin: $SUPERADMIN"
fi
if [[ -n "$BACKUPADMIN" ]]; then
    echo "Detected Backupadmin: $BACKUPADMIN"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SELECT MODE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1) PREPARE FOR NEW NODE"
echo -e "  ${YELLOW}⚠️ YOU NEED TO RUN THIS ON EVERY NODE IN THE CLUSTER!${NC}"
echo "     → Temporarily allow root password auth"
echo "     → Whitelist new node IP in firewall"
echo "     → Add to Fail2Ban whitelist"
echo "     → Ready for 'pvecm add' from new node"
echo ""
echo "  2) COMPLETE JOIN (After new node joined)"
echo "     → Re-harden SSH (disable password auth)"
echo "     → Add permanent firewall rules"
echo "     → Exchange SSH keys"
echo "     → Update security config"
echo ""
echo "  3) EMERGENCY: Re-harden NOW"
echo "     → Immediately restore SSH hardening"
echo "     → Use if join was cancelled/failed"
echo ""
echo "  4) STATUS"
echo "     → Show current security status"
echo ""
echo "  5) EXIT"
echo ""

read -p "Your choice [1-5]: " MENU_CHOICE

case "$MENU_CHOICE" in

# ══════════════════════════════════════════════════════════════════════════════
# OPTION 1: PREPARE FOR NEW NODE
# ══════════════════════════════════════════════════════════════════════════════
1)
    print_section "🔓 PREPARE FOR NEW NODE"
    
    echo ""
    echo "This will temporarily relax security to allow a new node to join."
    echo ""
    
    # Get new node IP
    read -p "Enter IP address of the NEW node: " NEW_NODE_IP
    
    if ! validate_ip "$NEW_NODE_IP"; then
        log_error "Invalid IP address: $NEW_NODE_IP"
        exit 1
    fi
    
    read -p "Enter hostname of the NEW node (optional): " NEW_NODE_HOSTNAME
    NEW_NODE_HOSTNAME=${NEW_NODE_HOSTNAME:-"new-node"}
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  CHANGES TO BE MADE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  New Node: $NEW_NODE_HOSTNAME ($NEW_NODE_IP)"
    echo ""
    echo "  1. SSH: Temporarily allow root password login"
    echo "  2. Firewall: Open ports for $NEW_NODE_IP"
    echo "  3. Fail2Ban: Whitelist $NEW_NODE_IP"
    echo ""
    echo -e "  ${YELLOW}⚠️  IMPORTANT: Run 'Option 2' after the node has joined!${NC}"
    echo ""
    
    if ! ask_user "Proceed?"; then
        echo "Aborted."
        exit 0
    fi
    
    # ─────────────────────────────────────────────────────────────────────────
    # Backup current state
    # ─────────────────────────────────────────────────────────────────────────
    
    BACKUP_DIR="/root/cluster-join-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    cp /etc/ssh/sshd_config "$BACKUP_DIR/" 2>/dev/null || true
    cp /etc/fail2ban/jail.local "$BACKUP_DIR/" 2>/dev/null || true
    iptables-save > "$BACKUP_DIR/iptables.rules" 2>/dev/null || true
    
    # Save new node info for later
    echo "NEW_NODE_IP=$NEW_NODE_IP" > "$BACKUP_DIR/new_node_info"
    echo "NEW_NODE_HOSTNAME=$NEW_NODE_HOSTNAME" >> "$BACKUP_DIR/new_node_info"
    echo "BACKUP_DIR=$BACKUP_DIR" >> "$BACKUP_DIR/new_node_info"
    cp "$BACKUP_DIR/new_node_info" /tmp/pending_cluster_join
    
    log_success "Backup created: $BACKUP_DIR"
    
    # ─────────────────────────────────────────────────────────────────────────
    # 1. SSH: Enable temporary root password auth
    # ─────────────────────────────────────────────────────────────────────────
    
    print_section "🔐 Configuring SSH (Temporary)"
    
    # Add temporary Match block for new node with password auth
    if ! grep -q "# TEMPORARY CLUSTER JOIN" /etc/ssh/sshd_config; then
        cat >> /etc/ssh/sshd_config << EOF

# ═══════════════════════════════════════════════════════════════
# TEMPORARY CLUSTER JOIN - $NEW_NODE_HOSTNAME ($NEW_NODE_IP)
# Added: $(date)
# REMOVE AFTER JOIN COMPLETE! (Run new-node-join.sh option 2)
# ═══════════════════════════════════════════════════════════════
Match Address $NEW_NODE_IP
    PermitRootLogin yes
    PasswordAuthentication yes
    PubkeyAuthentication yes
    AuthenticationMethods password publickey
    AcceptEnv LC_*
    AllowUsers root $SUPERADMIN $BACKUPADMIN

EOF
        log_success "SSH: Temporary root password auth enabled for $NEW_NODE_IP"
    else
        log_warning "SSH: Temporary block already exists - updating..."
        # Remove old temp block and add new
        sed -i '/# TEMPORARY CLUSTER JOIN/,/^Match\|^$/d' /etc/ssh/sshd_config
        cat >> /etc/ssh/sshd_config << EOF

# ═══════════════════════════════════════════════════════════════
# TEMPORARY CLUSTER JOIN - $NEW_NODE_HOSTNAME ($NEW_NODE_IP)
# Added: $(date)
# REMOVE AFTER JOIN COMPLETE! (Run new-node-join.sh option 2)
# ═══════════════════════════════════════════════════════════════
Match Address $NEW_NODE_IP
    PermitRootLogin yes
    PasswordAuthentication yes
    PubkeyAuthentication yes
    AuthenticationMethods password publickey
    AcceptEnv LC_*
    AllowUsers root $SUPERADMIN $BACKUPADMIN

EOF
        log_success "SSH: Temporary block updated for $NEW_NODE_IP"
    fi
    
    # Test and restart SSH
    if sshd -t 2>/dev/null; then
        systemctl restart sshd
        log_success "SSH service restarted"
    else
        log_error "SSH config test failed!"
        cp "$BACKUP_DIR/sshd_config" /etc/ssh/sshd_config
        systemctl restart sshd
        exit 1
    fi
    
    # ─────────────────────────────────────────────────────────────────────────
    # 2. Firewall: Open cluster ports
    # ─────────────────────────────────────────────────────────────────────────
    
    print_section "🔥 Configuring Firewall"
    
    # Add rules for new node (insert at top so they take effect immediately)
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 22 -j ACCEPT -m comment --comment "TEMP:SSH:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 8006 -j ACCEPT -m comment --comment "TEMP:WebUI:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p udp --dport 5405:5412 -j ACCEPT -m comment --comment "TEMP:Corosync:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 60000:60050 -j ACCEPT -m comment --comment "TEMP:Migration:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 111 -j ACCEPT -m comment --comment "TEMP:RPC:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p udp --dport 111 -j ACCEPT -m comment --comment "TEMP:RPC:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 2224 -j ACCEPT -m comment --comment "TEMP:Corosync-Sync:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 6789 -j ACCEPT -m comment --comment "TEMP:Ceph-Mon:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 6800:7300 -j ACCEPT -m comment --comment "TEMP:Ceph-OSD:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 3128 -j ACCEPT -m comment --comment "TEMP:Spice:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 5900:5999 -j ACCEPT -m comment --comment "TEMP:VNC:$NEW_NODE_HOSTNAME"
    
    log_success "Firewall: All cluster ports opened for $NEW_NODE_IP"
    
    # ─────────────────────────────────────────────────────────────────────────
    # 3. Fail2Ban: Whitelist new node
    # ─────────────────────────────────────────────────────────────────────────
    
    print_section "🚫 Configuring Fail2Ban"
    
    if [[ -f /etc/fail2ban/jail.local ]]; then
        if ! grep -q "$NEW_NODE_IP" /etc/fail2ban/jail.local; then
            sed -i "s/^ignoreip = \(.*\)/ignoreip = \1 $NEW_NODE_IP/" /etc/fail2ban/jail.local
            systemctl restart fail2ban 2>/dev/null || true
            log_success "Fail2Ban: $NEW_NODE_IP added to whitelist"
        else
            log_info "Fail2Ban: $NEW_NODE_IP already whitelisted"
        fi
    else
        log_warning "Fail2Ban config not found - skipping"
    fi
    
    # ─────────────────────────────────────────────────────────────────────────
    # Summary
    # ─────────────────────────────────────────────────────────────────────────
    
    echo ""
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                          ║"
    echo "║              ✅ READY FOR CLUSTER JOIN!                                  ║"
    echo "║                                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📋 NEXT STEPS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. On the NEW node ($NEW_NODE_IP), run:"
    echo ""
    echo -e "     ${CYAN}pvecm add $CURRENT_IP${NC}"
    echo ""
    echo "     You will be asked for the root password of THIS node."
    echo ""
    echo "  2. After the join is SUCCESSFUL, come back here and run:"
    echo ""
    echo -e "     ${CYAN}$0${NC}  → Select Option 2 (Complete Join)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  ${YELLOW}⚠️  SECURITY WARNING${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Root password authentication is now TEMPORARILY enabled!"
    echo "  This is a security risk - complete the join ASAP!"
    echo ""
    echo "  Backup saved to: $BACKUP_DIR"
    echo ""
    ;;

# ══════════════════════════════════════════════════════════════════════════════
# OPTION 2: COMPLETE JOIN
# ══════════════════════════════════════════════════════════════════════════════
2)
    print_section "🔒 COMPLETE CLUSTER JOIN"
    
    # Check if there's a pending join
    if [[ ! -f /tmp/pending_cluster_join ]]; then
        echo ""
        log_warning "No pending cluster join found!"
        echo ""
        echo "Did you run Option 1 first?"
        echo ""
        read -p "Enter the NEW node IP manually: " NEW_NODE_IP
        read -p "Enter the NEW node hostname: " NEW_NODE_HOSTNAME
        NEW_NODE_HOSTNAME=${NEW_NODE_HOSTNAME:-"new-node"}
    else
        source /tmp/pending_cluster_join
        echo ""
        echo "Found pending join for: $NEW_NODE_HOSTNAME ($NEW_NODE_IP)"
        echo ""
    fi
    
    if ! validate_ip "$NEW_NODE_IP"; then
        log_error "Invalid IP: $NEW_NODE_IP"
        exit 1
    fi
    
    # Verify node is in cluster
    echo "Checking if $NEW_NODE_IP is in the cluster..."
    
    if grep -q "$NEW_NODE_IP" /etc/pve/corosync.conf 2>/dev/null; then
        log_success "Node $NEW_NODE_IP found in cluster config!"
    else
        log_warning "Node $NEW_NODE_IP not found in corosync.conf"
        if ! ask_user "Continue anyway?"; then
            exit 0
        fi
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  CHANGES TO BE MADE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. SSH: Remove temporary password auth"
    echo "  2. SSH: Add permanent PublicKey-only access for $NEW_NODE_IP"
    echo "  3. SSH: Exchange keys with new node"
    echo "  4. Firewall: Convert temp rules to permanent"
    echo "  5. Config: Update /etc/proxmox-security.conf"
    echo ""
    
    if ! ask_user "Proceed?"; then
        exit 0
    fi
    
    # ─────────────────────────────────────────────────────────────────────────
    # 1. SSH: Remove temporary block, add permanent hardened block
    # ─────────────────────────────────────────────────────────────────────────
    
    print_section "🔐 Hardening SSH"
    
    # Remove temporary block
    sed -i '/# TEMPORARY CLUSTER JOIN/,/^Match\|^# ═/{ /# ═/!d }' /etc/ssh/sshd_config
    sed -i '/# TEMPORARY CLUSTER JOIN/d' /etc/ssh/sshd_config
    
    # Remove any empty lines at end
    sed -i -e :a -e '/^\s*$/{ $d; N; ba; }' /etc/ssh/sshd_config
    
    # Add permanent hardened block
    cat >> /etc/ssh/sshd_config << EOF

# ═══════════════════════════════════════════════════════════════
# Cluster Node: $NEW_NODE_HOSTNAME ($NEW_NODE_IP)
# Added: $(date)
# ═══════════════════════════════════════════════════════════════
Match User root Address $NEW_NODE_IP
    PermitRootLogin prohibit-password
    PubkeyAuthentication yes
    PasswordAuthentication no
    AuthenticationMethods publickey
    AcceptEnv LC_*
    AllowUsers root $SUPERADMIN $BACKUPADMIN

EOF
    
    log_success "SSH: Temporary block removed"
    log_success "SSH: Permanent hardened block added for $NEW_NODE_IP"
    
    # Test and restart
    if sshd -t 2>/dev/null; then
        systemctl restart sshd
        log_success "SSH service restarted"
    else
        log_error "SSH config test failed! Check /etc/ssh/sshd_config"
        exit 1
    fi
    
    # ─────────────────────────────────────────────────────────────────────────
    # 2. SSH Key Exchange
    # ─────────────────────────────────────────────────────────────────────────
    
    print_section "🔑 SSH Key Exchange"
    
    # Ensure we have a key
    if [[ ! -f /root/.ssh/id_rsa ]]; then
        log_info "Generating SSH key..."
        ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -C "root@$CURRENT_HOSTNAME"
    fi
    
    echo ""
    echo "Attempting to exchange SSH keys with $NEW_NODE_IP..."
    echo ""
    
    # Try to copy our key to new node
    if ssh -o BatchMode=yes -o ConnectTimeout=5 root@$NEW_NODE_IP /bin/true 2>/dev/null; then
        log_success "SSH key authentication already working!"
    else
        log_info "Copying SSH key to $NEW_NODE_IP (may ask for password)..."
        
        if ssh-copy-id -o StrictHostKeyChecking=no root@$NEW_NODE_IP 2>/dev/null; then
            log_success "SSH key copied to $NEW_NODE_IP"
        else
            log_warning "Could not copy key automatically"
            echo ""
            echo "Manual key exchange needed:"
            echo ""
            echo "1. Copy this key to $NEW_NODE_IP:"
            echo "   $(cat /root/.ssh/id_rsa.pub)"
            echo ""
            echo "2. On $NEW_NODE_IP, add it to /root/.ssh/authorized_keys"
            echo ""
        fi
    fi
    
    # Get key from new node
    echo ""
    log_info "Fetching SSH key from $NEW_NODE_IP..."
    
    REMOTE_KEY=$(ssh -o BatchMode=yes -o ConnectTimeout=5 root@$NEW_NODE_IP cat /root/.ssh/id_rsa.pub 2>/dev/null) || true
    
    if [[ -n "$REMOTE_KEY" ]]; then
        if ! grep -q "$REMOTE_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
            echo "$REMOTE_KEY" >> /root/.ssh/authorized_keys
            log_success "Added $NEW_NODE_IP's key to authorized_keys"
        else
            log_info "Key from $NEW_NODE_IP already in authorized_keys"
        fi
    else
        log_warning "Could not fetch key from $NEW_NODE_IP"
        echo ""
        echo "After the new node is hardened, manually exchange keys:"
        echo "  ssh root@$NEW_NODE_IP cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys"
        echo ""
    fi
    
    # ─────────────────────────────────────────────────────────────────────────
    # 3. Firewall: Make rules permanent
    # ─────────────────────────────────────────────────────────────────────────
    
    print_section "🔥 Finalizing Firewall"
    
    # Remove temporary rules (by comment)
    iptables -S | grep "TEMP:.*$NEW_NODE_HOSTNAME" | while read -r rule; do
        # Convert -A to -D for deletion
        delete_rule=$(echo "$rule" | sed 's/^-A/-D/')
        iptables $delete_rule 2>/dev/null || true
    done
    
    # Add permanent rules (without TEMP prefix)
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 22 -j ACCEPT -m comment --comment "Cluster:SSH:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p udp --dport 5405:5412 -j ACCEPT -m comment --comment "Cluster:Corosync:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 60000:60050 -j ACCEPT -m comment --comment "Cluster:Migration:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 111 -j ACCEPT -m comment --comment "Cluster:RPC:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p udp --dport 111 -j ACCEPT -m comment --comment "Cluster:RPC:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 2224 -j ACCEPT -m comment --comment "Cluster:Corosync-Sync:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 6789 -j ACCEPT -m comment --comment "Cluster:Ceph-Mon:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 6800:7300 -j ACCEPT -m comment --comment "Cluster:Ceph-OSD:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 3128 -j ACCEPT -m comment --comment "Cluster:Spice:$NEW_NODE_HOSTNAME"
    iptables -I INPUT -s "$NEW_NODE_IP" -p tcp --dport 5900:5999 -j ACCEPT -m comment --comment "Cluster:VNC:$NEW_NODE_HOSTNAME"
    
    # Save rules
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    
    log_success "Firewall: Permanent rules saved"
    
    # ─────────────────────────────────────────────────────────────────────────
    # 4. Update security config
    # ─────────────────────────────────────────────────────────────────────────
    
    print_section "📝 Updating Configuration"
    
    if [[ -f /etc/proxmox-security.conf ]]; then
        source /etc/proxmox-security.conf
        
        # Add new IP to cluster nodes
        if ! echo "$CLUSTER_NODE_IPS" | grep -q "$NEW_NODE_IP"; then
            NEW_CLUSTER_IPS="$CLUSTER_NODE_IPS $NEW_NODE_IP"
            sed -i "s|^CLUSTER_NODE_IPS=.*|CLUSTER_NODE_IPS=\"$NEW_CLUSTER_IPS\"|" /etc/proxmox-security.conf
            log_success "Added $NEW_NODE_IP to CLUSTER_NODE_IPS"
        fi
        
        # Add to root allowed IPs
        if ! echo "$ROOT_SSH_ALLOWED_IPS" | grep -q "$NEW_NODE_IP"; then
            NEW_ROOT_IPS="$ROOT_SSH_ALLOWED_IPS $NEW_NODE_IP"
            sed -i "s|^ROOT_SSH_ALLOWED_IPS=.*|ROOT_SSH_ALLOWED_IPS=\"$NEW_ROOT_IPS\"|" /etc/proxmox-security.conf
            log_success "Added $NEW_NODE_IP to ROOT_SSH_ALLOWED_IPS"
        fi
    else
        log_warning "/etc/proxmox-security.conf not found"
    fi
    
    # Cleanup
    rm -f /tmp/pending_cluster_join
    
    # ─────────────────────────────────────────────────────────────────────────
    # Summary
    # ─────────────────────────────────────────────────────────────────────────
    
    echo ""
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                          ║"
    echo "║              ✅ CLUSTER JOIN COMPLETE!                                   ║"
    echo "║                                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📋 SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ✓ SSH hardened (PublicKey only for root)"
    echo "  ✓ SSH keys exchanged"
    echo "  ✓ Firewall rules permanent"
    echo "  ✓ Config updated"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📋 NEXT STEPS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Run this script on ALL OTHER existing nodes"
    echo ""
    echo "  2. On the NEW node ($NEW_NODE_IP), run the main hardening script:"
    echo "     seuwurity.sh → Select 'Cluster Mode'"
    echo ""
    echo "  3. Test cluster communication:"
    echo "     ssh -o BatchMode=yes root@$NEW_NODE_IP echo 'OK'"
    echo ""
    echo "  4. Test VNC/Migration in WebUI"
    echo ""
    ;;

# ══════════════════════════════════════════════════════════════════════════════
# OPTION 3: EMERGENCY RE-HARDEN
# ══════════════════════════════════════════════════════════════════════════════
3)
    print_section "🚨 EMERGENCY RE-HARDEN"
    
    echo ""
    echo "This will immediately remove all temporary cluster join settings."
    echo ""
    
    if ! ask_user "Are you sure? This may break an in-progress join!"; then
        exit 0
    fi
    
    # Remove temporary SSH block
    if grep -q "# TEMPORARY CLUSTER JOIN" /etc/ssh/sshd_config; then
        sed -i '/# TEMPORARY CLUSTER JOIN/,/^Match\|^# ═/{ /# ═/!d }' /etc/ssh/sshd_config
        sed -i '/# TEMPORARY CLUSTER JOIN/d' /etc/ssh/sshd_config
        log_success "SSH: Temporary block removed"
        
        if sshd -t 2>/dev/null; then
            systemctl restart sshd
            log_success "SSH service restarted"
        fi
    else
        log_info "No temporary SSH block found"
    fi
    
    # Remove temporary firewall rules
    TEMP_RULES=$(iptables -S | grep "TEMP:" | wc -l)
    if [[ $TEMP_RULES -gt 0 ]]; then
        iptables -S | grep "TEMP:" | while read -r rule; do
            delete_rule=$(echo "$rule" | sed 's/^-A/-D/')
            iptables $delete_rule 2>/dev/null || true
        done
        iptables-save > /etc/iptables/rules.v4
        log_success "Firewall: Removed $TEMP_RULES temporary rules"
    else
        log_info "No temporary firewall rules found"
    fi
    
    # Cleanup
    rm -f /tmp/pending_cluster_join
    
    echo ""
    log_success "Emergency re-hardening complete!"
    echo ""
    ;;

# ══════════════════════════════════════════════════════════════════════════════
# OPTION 4: STATUS
# ══════════════════════════════════════════════════════════════════════════════
4)
    print_section "📊 SECURITY STATUS"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  SSH CONFIGURATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check for temporary block
    if grep -q "# TEMPORARY CLUSTER JOIN" /etc/ssh/sshd_config; then
        echo -e "  ${YELLOW}⚠️  TEMPORARY CLUSTER JOIN ACTIVE!${NC}"
        echo ""
        grep -A5 "# TEMPORARY CLUSTER JOIN" /etc/ssh/sshd_config | head -10
    else
        echo -e "  ${GREEN}✓ No temporary blocks - SSH is hardened${NC}"
    fi
    
    echo ""
    echo "  Root Match Blocks:"
    grep -E "^Match.*root|^Match Address" /etc/ssh/sshd_config | head -10 || echo "  (none found)"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  FIREWALL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    TEMP_RULES=$(iptables -S | grep -c "TEMP:" 2>/dev/null || echo "0")
    PERM_RULES=$(iptables -S | grep -c "Cluster:" 2>/dev/null || echo "0")
    
    if [[ $TEMP_RULES -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠️  $TEMP_RULES TEMPORARY rules active${NC}"
    else
        echo -e "  ${GREEN}✓ No temporary firewall rules${NC}"
    fi
    echo "  Permanent cluster rules: $PERM_RULES"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  FAIL2BAN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if systemctl is-active --quiet fail2ban; then
        echo -e "  ${GREEN}✓ Fail2Ban running${NC}"
        echo "  Whitelisted IPs:"
        grep "^ignoreip" /etc/fail2ban/jail.local 2>/dev/null | sed 's/ignoreip = /    /' || echo "    (default)"
    else
        echo -e "  ${YELLOW}⚠️  Fail2Ban not running${NC}"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  CLUSTER NODES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [[ -f /etc/pve/corosync.conf ]]; then
        echo "  From corosync.conf:"
        grep "ring0_addr:" /etc/pve/corosync.conf | awk '{print "    • " $2}'
    else
        echo "  Not in a cluster"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  PENDING JOIN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [[ -f /tmp/pending_cluster_join ]]; then
        source /tmp/pending_cluster_join
        echo -e "  ${YELLOW}⚠️  Pending join for: $NEW_NODE_HOSTNAME ($NEW_NODE_IP)${NC}"
    else
        echo -e "  ${GREEN}✓ No pending joins${NC}"
    fi
    
    echo ""
    ;;

# ══════════════════════════════════════════════════════════════════════════════
# OPTION 5: EXIT
# ══════════════════════════════════════════════════════════════════════════════
5)
    echo ""
    echo "Bye! 👋"
    exit 0
    ;;

*)
    echo "Invalid option"
    exit 1
    ;;

esac
