#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Zephyrus G14 (GA402RJ / GA402RK) Linux Kernel Stability Fix
# ==============================================================================
# Fixes random idle freezes, sleep crashes, and hard-locks caused by:
# 1. AMD Zen 3+ (Rembrandt 6000 series) C-State voltage sag (processor.max_cstate=1)
# 2. PCIe Active State Power Management bus link drops (pcie_aspm=off)
# 3. NVMe controller autonomous power state transition timeouts (nvme_core.default_ps_max_latency_us=0)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR] This script must be run as root (use sudo).${NC}" >&2
   exit 1
fi

echo -e "${BLUE}=== ASUS Zephyrus G14 Linux Kernel Stability Patch ===${NC}"

GRUB_FILE="/etc/default/grub"
BACKUP_FILE="/etc/default/grub.bak.$(date +%Y%m%d_%H%M%S)"

if [[ ! -f "$GRUB_FILE" ]]; then
    echo -e "${RED}[ERROR] /etc/default/grub not found!${NC}" >&2
    exit 1
fi

echo -e "[*] Backing up current GRUB configuration to ${YELLOW}${BACKUP_FILE}${NC}..."
cp "$GRUB_FILE" "$BACKUP_FILE"

REQUIRED_PARAMS=(
    "processor.max_cstate=1"
    "pcie_aspm=off"
    "nvme_core.default_ps_max_latency_us=0"
)

CURRENT_LINE=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" || true)

if [[ -z "$CURRENT_LINE" ]]; then
    echo -e "${RED}[ERROR] Could not locate GRUB_CMDLINE_LINUX_DEFAULT in $GRUB_FILE${NC}" >&2
    exit 1
fi

CURRENT_PARAMS=$(echo "$CURRENT_LINE" | sed -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="//' -e 's/"$//')
UPDATED_PARAMS="$CURRENT_PARAMS"

for param in "${REQUIRED_PARAMS[@]}"; do
    if [[ "$UPDATED_PARAMS" =~ (^|[[:space:]])"$param"([[:space:]]|$) ]]; then
        echo -e "  [+] Parameter already present: ${GREEN}$param${NC}"
    else
        echo -e "  [+] Adding parameter: ${YELLOW}$param${NC}"
        UPDATED_PARAMS="$UPDATED_PARAMS $param"
    fi
done

# Clean up redundant spaces
UPDATED_PARAMS=$(echo "$UPDATED_PARAMS" | xargs)

sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$UPDATED_PARAMS\"|" "$GRUB_FILE"

echo -e "\n[*] Updated GRUB_CMDLINE_LINUX_DEFAULT to:"
echo -e "    ${GREEN}$UPDATED_PARAMS${NC}\n"

echo -e "[*] Updating GRUB bootloader..."
if command -v update-grub &>/dev/null; then
    update-grub
elif command -v grub2-mkconfig &>/dev/null; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
else
    echo -e "${YELLOW}[!] Warning: update-grub or grub2-mkconfig not found. Please regenerate GRUB manually.${NC}"
fi

# Optimize power profile if available
if command -v powerprofilesctl &>/dev/null; then
    echo -e "\n[*] Setting power profile to performance..."
    powerprofilesctl set performance || true
fi

echo -e "\n${GREEN}[SUCCESS] Kernel parameters applied successfully!${NC}"
echo -e "Please reboot your system for the kernel parameters to take effect."
echo -e "Run './verify.sh' after reboot to confirm.\n"
