#!/bin/bash

# ==========================================
# ð¥ NOC Interface Reaper (Final Bulletproof - Multi Format)
# ==========================================

# -------- Input --------
read -p "ð« Enter Ticket ID (CHG/INT/PRJTASK): " TICKET

echo ""
echo "ð Paste Ticket Description (press ENTER twice when done):"
echo "---------------------------------------------------------"

DESC=""
while IFS= read -r line; do
  [[ -z "$line" ]] && break
  DESC+="$line "
done

echo ""
echo "ð Parsing description..."

# -------- Normalize --------
DESC_CLEAN=$(echo "$DESC" | tr '[:upper:]' '[:lower:]')

# -------- Detect format --------
if echo "$DESC_CLEAN" | grep -q "nbr="; then
    # ----- FORMAT 1: nbr= -----
    DEVICE1=$(echo "$DESC_CLEAN" | grep -oE '^[a-z0-9.-]+')
    INTERFACE1=$(echo "$DESC_CLEAN" | grep -oE '\[(et|xe|ge)-[0-9/]+\]' | head -1 | tr -d '[]')

    REMOTE=$(echo "$DESC_CLEAN" | grep -o 'nbr=[^,]*' | cut -d'=' -f2)
    DEVICE2=$(echo "$REMOTE" | cut -d':' -f1)
    INTERFACE2=$(echo "$REMOTE" | cut -d':' -f2 | tr -d ' ')

elif echo "$DESC_CLEAN" | grep -q "link down between"; then
    # ----- FORMAT 2: Link down between -----
    SIDE1=$(echo "$DESC_CLEAN" | awk -F'between ' '{print $2}' | awk -F' and ' '{print $1}')
    INTERFACE1=$(echo "$SIDE1" | cut -d'.' -f1)
    DEVICE1=$(echo "$SIDE1" | cut -d'.' -f2-)

    SIDE2=$(echo "$DESC_CLEAN" | awk -F' and ' '{print $2}')
    INTERFACE2=$(echo "$SIDE2" | cut -d'.' -f1)
    DEVICE2=$(echo "$SIDE2" | cut -d'.' -f2-)

else
    echo "❌ Unknown ticket format"
    exit 1
fi

# -------- Cleanup --------
INTERFACE1=$(echo "$INTERFACE1" | tr -cd 'a-z0-9/-')
INTERFACE2=$(echo "$INTERFACE2" | tr -cd 'a-z0-9/-')

# -------- Validation --------
if [[ -z "$DEVICE1" || -z "$INTERFACE1" ]]; then
    echo "❌ Failed to extract LOCAL details"
    exit 1
fi
if [[ -z "$DEVICE2" || -z "$INTERFACE2" ]]; then
    echo "⚠ Remote details missing or invalid"
fi

echo ""
echo "==========================================="
echo "✅ Extracted (Normalized)"
echo "-------------------------------------------"
echo "DEVICE 1 : $DEVICE1"
echo "INTF 1   : $INTERFACE1"
echo "DEVICE 2 : $DEVICE2"
echo "INTF 2   : $INTERFACE2"
echo "==========================================="

# -------- Create TEMP CMD FILE --------
CMD_FILE="/tmp/reaper_cmds_$$.txt"

cat <<EOF > "$CMD_FILE"
echo "================ DEVICE 1 : $DEVICE1 ($INTERFACE1) ================"
show interfaces $INTERFACE1
show interfaces $INTERFACE1 extensive | match "Physical|Desc|flap|fpps|error|traffic|Input bytes|Output bytes|Input packets|Output packets"
show interfaces diagnostics optics $INTERFACE1 | match "dbm|lane" | except "thre|off"
show log messages | match snmp | match $INTERFACE1
show log messages | last 50
show interfaces $INTERFACE1 | match desc

echo "================ DEVICE 2 : $DEVICE2 ($INTERFACE2) ================"
show interfaces $INTERFACE2
show interfaces $INTERFACE2 extensive | match "Physical|Desc|flap|fpps|error|traffic|Input bytes|Output bytes|Input packets|Output packets"
show interfaces diagnostics optics $INTERFACE2 | match "dbm|lane" | except "thre|off"
show log messages | match snmp | match $INTERFACE2
show log messages | last 50
show interfaces $INTERFACE2 | match desc
EOF

echo ""
echo "ð¥ Running checks via REAPER..."

# -------- Run Reaper --------
reaper \
  -t "$DEVICE1,$DEVICE2" \
  -p junos \
  -o \
  -ts \
  -post "$TICKET" \
  -cfile "$CMD_FILE"

# -------- Cleanup --------
rm -f "$CMD_FILE"

echo ""
echo "==========================================="
echo "✔ Clean per-device output generated"
echo "✔ Single ticket update done"
echo "✔ Files saved under ~/REAPER/"
echo "==========================================="
