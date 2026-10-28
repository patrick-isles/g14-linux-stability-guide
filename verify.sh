#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Zephyrus G14 (GA402) Stability Verification Diagnostic
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== ASUS Zephyrus G14 Kernel Parameter Audit ===${NC}\n"

CMDLINE=$(cat /proc/cmdline)
echo -e "[*] Active Kernel Commandline:\n    ${CMDLINE}\n"

PARAMS=(
    "processor.max_cstate=1:Disables deep C3/C6 idle voltage sag"
    "pcie_aspm=off:Prevents PCIe link state drops on dGPU/bus"
    "nvme_core.default_ps_max_latency_us=0:Prevents NVMe sleep timeouts"
)

ALL_PASSED=true

for item in "${PARAMS[@]}"; do
    param="${item%%:*}"
    desc="${item#*:}"
    if [[ "$CMDLINE" =~ (^|[[:space:]])"$param"([[:space:]]|$) ]]; then
        echo -e " [PASS] ${GREEN}${param}${NC} is ACTIVE"
        echo -e "        Reason: ${desc}"
    else
        echo -e " [FAIL] ${RED}${param}${NC} is NOT active in /proc/cmdline"
        echo -e "        Reason: ${desc}"
        ALL_PASSED=false
    fi
done

echo ""
if command -v powerprofilesctl &>/dev/null; then
    PROFILE=$(powerprofilesctl get || echo "unknown")
    echo -e "[*] Active Power Profile: ${YELLOW}${PROFILE}${NC}"
fi

echo ""
if [ "$ALL_PASSED" = true ]; then
    echo -e "${GREEN}>>> SYSTEM STABILITY AUDIT PASSED: Your Zephyrus G14 is protected against idle freezes. <<<${NC}\n"
else
    echo -e "${RED}>>> SYSTEM AUDIT FAILED: Missing stability parameters. Run 'sudo ./fix-g14.sh' and reboot. <<<${NC}\n"
    exit 1
fi
