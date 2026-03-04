#!/bin/bash
# ============================================
# UNIDA MODED - MODERN DNSTT INSTALLER
# Made with ❤️ for Tanzania
# Version: MODED-FINAL
# ============================================

# Modern Colors & Design
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Animation Functions
show_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

print_step() {
    echo -e "\n${BLUE}┌─${NC} ${CYAN}${BOLD}STEP $1${NC}"
    echo -e "${BLUE}│${NC}"
}

print_step_end() {
    echo -e "${BLUE}└─${NC} ${GREEN}✓${NC} Completed"
}

print_success() {
    echo -e "  ${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "  ${RED}${BOLD}✗${NC} ${RED}$1${NC}"
}

print_warning() {
    echo -e "  ${YELLOW}${BOLD}!${NC} ${YELLOW}$1${NC}"
}

print_info() {
    echo -e "  ${CYAN}${BOLD}ℹ${NC} ${CYAN}$1${NC}"
}

# Banner
clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║   ██╗   ██╗███╗   ██╗██╗██████╗  █████╗                     ║"
echo "║   ██║   ██║████╗  ██║██║██╔══██╗██╔══██╗                    ║"
echo "║   ██║   ██║██╔██╗ ██║██║██║  ██║███████║                    ║"
echo "║   ██║   ██║██║╚██╗██║██║██║  ██║██╔══██║                    ║"
echo "║   ╚██████╔╝██║ ╚████║██║██████╔╝██║  ██║                    ║"
echo "║    ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═════╝ ╚═╝  ╚═╝                    ║"
echo "║                                                              ║"
echo "║              🔥 MODED VERSION 🔥                             ║"
echo "║         \"MODED IKO NA STYLE - INAFANYA KAZI\"                 ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# AUTO-ROOT CHECK
# ============================================
if [ "$EUID" -ne 0 ]; then 
    print_warning "Script inahitaji root access..."
    print_info "Re-running with sudo..."
    sudo bash "$0" "$@"
    exit
fi

# ============================================
# AUTO-SYSTEM DETECTION
# ============================================
print_step "1 - SYSTEM DETECTION"
print_info "Detecting system specifications..."

# OS Detection
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

# Architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
    *) ARCH="unknown" ;;
esac

print_success "OS: $OS $VER"
print_success "Architecture: $ARCH"

# Check compatibility
if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "arm64" ]; then
    print_error "Architecture not supported!"
    exit 1
fi
print_step_end

# ============================================
# AUTO-IP DETECTION
# ============================================
print_step "2 - IP DETECTION"
print_info "Detecting server IP address..."

echo -ne "  ${CYAN}Checking IP...${NC}"
SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || \
            curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null || \
            hostname -I | awk '{print $1}')

if [ -z "$SERVER_IP" ]; then
    echo -e "\r  ${YELLOW}Could not detect IP automatically${NC}"
    read -p "$(echo -e "${WHITE}Ingiza IP yako manually: ${NC}")" SERVER_IP
else
    echo -e "\r  ${GREEN}Server IP: ${WHITE}${BOLD}$SERVER_IP${NC}"
fi
print_step_end

# ============================================
# DOMAIN SETUP
# ============================================
print_step "3 - DOMAIN CONFIGURATION"

# Generate default domain
DEFAULT_DOMAIN="tunnel.$SERVER_IP.nip.io"

print_info "Default domain: $DEFAULT_DOMAIN"
echo -e "${WHITE}Unaweza kutumia domain yako mwenyewe au default${NC}"
read -p "$(echo -e "${CYAN}Ingiza domain (Enter kutumia default): ${NC}")" TDOMAIN
TDOMAIN=${TDOMAIN:-$DEFAULT_DOMAIN}

# Validate domain
if ! echo "$TDOMAIN" | grep -q "\."; then
    print_warning "Domain invalid! Using default."
    TDOMAIN=$DEFAULT_DOMAIN
fi

print_success "Domain: $TDOMAIN"
print_step_end

# ============================================
# PORT AUTO-CONFIGURATION
# ============================================
print_step "4 - PORT CONFIGURATION"
print_info "Checking available ports..."

# Function to check if port is available
check_port() {
    if ss -lun 2>/dev/null | grep -q ":$1 "; then
        return 1
    else
        return 0
    fi
}

PUBLIC_PORT=53
INTERNAL_PORT=5300

# Check public port
echo -ne "  ${CYAN}Checking port 53...${NC}"
if ! check_port 53; then
    echo -e "\r  ${YELLOW}Port 53 inatumika${NC}"
    for port in 5353 1053 2053 4053 8053; do
        if check_port $port; then
            PUBLIC_PORT=$port
            print_success "Using port $port"
            break
        fi
    done
else
    echo -e "\r  ${GREEN}Port 53 iko free${NC}"
fi

# Check internal port
echo -ne "  ${CYAN}Checking port 5300...${NC}"
if ! check_port 5300; then
    echo -e "\r  ${YELLOW}Port 5300 inatumika${NC}"
    INTERNAL_PORT=5301
    print_success "Using internal port 5301"
else
    echo -e "\r  ${GREEN}Port 5300 iko free${NC}"
fi
print_step_end

# ============================================
# INSTALL DEPENDENCIES
# ============================================
print_step "5 - INSTALLING DEPENDENCIES"
print_info "Updating system and installing packages..."

echo -ne "  ${CYAN}Installing required packages...${NC}"
apt update -y > /dev/null 2>&1 &
show_progress $!
apt install -y curl wget python3 ufw net-tools dnsutils iptables openssl > /dev/null 2>&1 &
show_progress $!
echo -e "\r  ${GREEN}Dependencies installed successfully${NC}"
print_step_end

# ============================================
# CREATE SERVICES
# ============================================
print_step "9 - CREATING SERVICES"
print_info "Setting up system services..."

# DNSTT Service
cat >/etc/systemd/system/dnstt-unida.service <<EOF
[Unit]
Description=Unida DNSTT Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-server --listen :$INTERNAL_PORT --mtu 1300 --key /etc/dnstt/server.key $TDOMAIN 127.0.0.1:22
Restart=always
RestartSec=3
User=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# EDNS Proxy Script
cat >/usr/local/bin/dnstt-edns-proxy.py <<'EOF'
#!/usr/bin/env python3
import socket
import threading
import struct
import sys
import time
import os

def find_port():
    try:
        with open('/etc/systemd/system/dnstt-unida.service', 'r') as f:
            content = f.read()
            if ':5300' in content:
                return 5300
            elif ':5301' in content:
                return 5301
    except:
        pass
    return 5300

LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 53
UPSTREAM_PORT = find_port()
EXTERNAL_EDNS = 512
INTERNAL_EDNS = 1800

def patch_edns(data, new_size):
    if len(data) < 12:
        return data
    try:
        _, _, qdcount, ancount, nscount, arcount = struct.unpack("!HHHHHH", data[:12])
    except:
        return data
    
    offset = 12
    
    def skip_name(buf, off):
        while off < len(buf):
            l = buf[off]
            off += 1
            if l == 0:
                break
            if l & 0xC0 == 0xC0:
                off += 1
                break
            off += l
        return off
    
    for _ in range(qdcount):
        offset = skip_name(data, offset)
        offset += 4
    
    for _ in range(ancount + nscount):
        offset = skip_name(data, offset)
        if offset + 10 > len(data):
            return data
        rdlen = struct.unpack("!H", data[offset+8:offset+10])[0]
        offset += 10 + rdlen
    
    new_data = bytearray(data)
    for _ in range(arcount):
        offset = skip_name(data, offset)
        if offset + 10 > len(data):
            return data
        rtype = struct.unpack("!H", data[offset:offset+2])[0]
        if rtype == 41:
            new_data[offset+2:offset+4] = struct.pack("!H", new_size)
            return bytes(new_data)
        rdlen = struct.unpack("!H", data[offset+8:offset+10])[0]
        offset += 10 + rdlen
    return data

def handle(server, data, addr):
    upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    upstream.settimeout(3)
    try:
        upstream.sendto(patch_edns(data, INTERNAL_EDNS), ('127.0.0.1', UPSTREAM_PORT))
        resp, _ = upstream.recvfrom(4096)
        server.sendto(patch_edns(resp, EXTERNAL_EDNS), addr)
    except:
        pass
    finally:
        upstream.close()

def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        sock.bind(('0.0.0.0', LISTEN_PORT))
        print(f"✅ Proxy on port {LISTEN_PORT}")
    except:
        sock.bind(('0.0.0.0', 5353))
        print(f"✅ Proxy on port 5353")
    
    while True:
        try:
            data, addr = sock.recvfrom(4096)
            threading.Thread(target=handle, args=(sock, data, addr), daemon=True).start()
        except:
            continue

if __name__ == "__main__":
    main()
EOF

chmod +x /usr/local/bin/dnstt-edns-proxy.py

# Proxy Service
cat >/etc/systemd/system/dnstt-unida-proxy.service <<EOF
[Unit]
Description=Unida DNSTT Proxy
After=network-online.target dnstt-unida.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/dnstt-edns-proxy.py $PUBLIC_PORT
Restart=always
RestartSec=1
User=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

print_success "Services created successfully"
print_step_end

# ============================================
# START SERVICES
# ============================================
print_step "10 - STARTING SERVICES"
print_info "Starting all services..."

echo -ne "  ${CYAN}Starting DNSTT server...${NC}"
systemctl daemon-reload
systemctl enable dnstt-unida.service > /dev/null 2>&1
systemctl start dnstt-unida.service 2>/dev/null &
show_progress $!
echo -e "\r  ${GREEN}DNSTT server started${NC}"

echo -ne "  ${CYAN}Starting EDNS proxy...${NC}"
systemctl enable dnstt-unida-proxy.service > /dev/null 2>&1
systemctl start dnstt-unida-proxy.service 2>/dev/null &
show_progress $!
echo -e "\r  ${GREEN}EDNS proxy started${NC}"
print_step_end

# ============================================
# VERIFY
# ============================================
print_step "11 - VERIFICATION"
print_info "Verifying installation..."

sleep 3

if systemctl is-active --quiet dnstt-unida.service; then
    print_success "DNSTT Server: RUNNING"
else
    print_error "DNSTT Server: FAILED"
fi

if systemctl is-active --quiet dnstt-unida-proxy.service; then
    print_success "Proxy: RUNNING"
else
    print_error "Proxy: FAILED"
fi
print_step_end

# ============================================
# FINAL OUTPUT
# ============================================
clear
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║         🎉 INSTALLATION COMPLETE! 🎉                         ║"
echo "║                                                              ║"
echo "║              UNIDA MODED - IKO NA STYLE                     ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}${BOLD}CLIENT CONFIGURATION${NC}                                   ${CYAN}│${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Domain    : ${GREEN}$TDOMAIN${NC}                     ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Port      : ${GREEN}$PUBLIC_PORT${NC}                           ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IP Server : ${GREEN}$SERVER_IP${NC}                     ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Public Key: ${GREEN}$PUBKEY${NC} ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}${BOLD}USEFUL COMMANDS${NC}                                       ${CYAN}│${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC} ${GREEN}systemctl status dnstt-unida${NC}                         ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${GREEN}systemctl status dnstt-unida-proxy${NC}                   ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${GREEN}journalctl -u dnstt-unida -f${NC}                         ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${GREEN}cat /etc/dnstt/server.pub${NC}                             ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}${BOLD}TROUBLESHOOTING${NC}                                       ${CYAN}│${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC} ${YELLOW}Check ports:${NC} ss -ulpn | grep -E ':53|:5300|:5301'       ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${YELLOW}Restart all:${NC} systemctl restart dnstt-unida*             ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${YELLOW}View logs:${NC}  journalctl -u dnstt-unida -n 50             ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║${NC}    ${WHITE}🇹🇿 UNIDA MODED - INAFANYA KAZI KWA STYLE${NC}        ${GREEN}${BOLD}║${NC}"
echo -e "${GREEN}${BOLD}║${NC}    ${WHITE}📞 Support: @esimfreegb${NC}                          ${GREEN}${BOLD}║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"

# Save config
cat >~/dnstt-config.txt <<EOF
========================================
UNIDA MODED CONFIGURATION
========================================
Domain    : $TDOMAIN
Port      : $PUBLIC_PORT
IP Server : $SERVER_IP
Public Key: $PUBKEY
========================================
EOF

echo -e "\n${YELLOW}⚠️ Config imehifadhiwa kwenye: ~/dnstt-config.txt${NC}"
echo -e "${WHITE}Press Enter to continue...${NC}"
read -r


