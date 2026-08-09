#!/usr/bin/env zsh

# ==============================================================================
# btfix.zsh - Intel BE200 Bluetooth "Manual Mimic" Fix
# ==============================================================================
# This script replicates the exact steps of manually toggling Bluetooth
# to clear RFKill states and reset the HCI interface.
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}  Intel BE200 Bluetooth "Manual Mimic" Fix${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}ERROR: Run with sudo.${NC}"
   exit 1
fi

# 1. Stop Service & Unblock RFKill
echo -e "${YELLOW}[1/6] Stopping service and clearing RFKill blocks...${NC}"
systemctl stop bluetooth.service
rfkill unblock bluetooth 2>/dev/null || true
echo -e "${GREEN}      ✓ Service stopped & RFKill cleared.${NC}"

# 2. Unload Modules
echo -e "${YELLOW}[2/6] Unloading modules...${NC}"
modprobe -r btintel_pcie 2>/dev/null || true
modprobe -r bluetooth 2>/dev/null || true
echo -e "${GREEN}      ✓ Modules unloaded.${NC}"

# 3. Hardware Reset Delay
echo -e "${YELLOW}[3/6] Waiting for hardware reset (2s)...${NC}"
sleep 2

# 4. Reload Modules
echo -e "${YELLOW}[4/6] Reloading modules...${NC}"
modprobe bluetooth
modprobe btintel_pcie
echo -e "${GREEN}      ✓ Modules reloaded.${NC}"

# 5. Start Service
echo -e "${YELLOW}[5/6] Starting bluetooth.service...${NC}"
systemctl start bluetooth.service
echo -e "${GREEN}      ✓ Service started.${NC}"

# 6. Force Power On (The "Manual Toggle" Step)
echo -e "${YELLOW}[6/6] Forcing controller power on (mimicking manual toggle)...${NC}"
sleep 1
# Use bluetoothctl to send the 'power on' command directly to the daemon
bluetoothctl --timeout 5 power on 2>/dev/null || true
echo -e "${GREEN}      ✓ Power on command sent.${NC}"

# Verification
echo ""
echo -e "${BLUE}-----------------------------------------------------------------${NC}"
echo -e "${GREEN}  Fix Applied! Verifying...${NC}"
echo -e "${BLUE}-----------------------------------------------------------------${NC}"

sleep 2
CONTROLLER=$(bluetoothctl list | grep "Controller")

if [[ -n "$CONTROLLER" ]]; then
    echo -e "${GREEN}  ✓ SUCCESS: Controller Detected!${NC}"
    echo -e "    ${CONTROLLER}"
    # Check if it's actually powered on
    POWERED=$(bluetoothctl show | grep "Powered: yes")
    if [[ -n "$POWERED" ]]; then
        echo -e "${GREEN}  ✓ Controller is Powered ON.${NC}"
    else
        echo -e "${YELLOW}  ⚠ Controller detected but OFF. Try 'bluetoothctl power on'.${NC}"
    fi
else
    echo -e "${RED}  ✗ FAILED: No controller found.${NC}"
    echo -e "${YELLOW}  Tip: Check 'dmesg | tail' for firmware errors.${NC}"
fi
echo -e "${BLUE}=================================================================${NC}"
