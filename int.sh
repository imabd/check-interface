#!/bin/bash

while true; do

echo ""
echo "==========================================="
echo "ð¥ NOC TOOLKIT - SELECT OPTION"
echo "-------------------------------------------"
echo "1) Interface Checker"
echo "2) OSPF Check"
echo "3) BGP Check"
echo "4) PSU / Power Check"
echo "5) Exit"
echo "==========================================="

read -p "ð Enter your choice: " CHOICE

case $CHOICE in

# =========================================================
# 1️⃣ INTERFACE CHECKER
# =========================================================
1)
read -p "ð« Enter Ticket ID: " TICKET

echo ""
echo "ð Paste Ticket Description (ENTER twice):"
DESC=""
while IFS= read -r line; do
  [[ -z "$line" ]] && break
  DESC+="$line "
done

echo ""
echo "ð Parsing description..."

DESC_CLEAN=$(echo "$DESC" | tr '[:upper:]' '[:lower:]')

if echo "$DESC_CLEAN" | grep -q "nbr="; then

    DEVICE1=$(echo "$DESC_CLEAN" | grep -oE '^[a-z0-9.-]+')
    INTERFACE1=$(echo "$DESC_CLEAN" | grep -oE '(et|xe|ge)-[0-9/]+(:[0-9]+)?' | head -1)

    REMOTE=$(echo "$DESC_CLEAN" | grep -o 'nbr=[^,]*' | cut -d'=' -f2)
    DEVICE2=$(echo "$REMOTE" | cut -d':' -f1)
    INTERFACE2=$(echo "$REMOTE" | grep -oE '(et|xe|ge)-[0-9/]+(:[0-9]+)?')

elif echo "$DESC_CLEAN" | grep -q "link down between"; then

    SIDE1=$(echo "$DESC_CLEAN" | awk -F'between ' '{print $2}' | awk -F' and ' '{print $1}')
    INTERFACE1=$(echo "$SIDE1" | cut -d'.' -f1)
    DEVICE1=$(echo "$SIDE1" | cut -d'.' -f2-)

    SIDE2=$(echo "$DESC_CLEAN" | awk -F' and ' '{print $2}')
    INTERFACE2=$(echo "$SIDE2" | cut -d'.' -f1)
    DEVICE2=$(echo "$SIDE2" | cut -d'.' -f2-)

else
    echo "❌ Unknown ticket format"
    continue
fi

# Cleanup
INTERFACE1=$(echo "$INTERFACE1" | tr -cd 'a-z0-9/:-')
INTERFACE2=$(echo "$INTERFACE2" | tr -cd 'a-z0-9/:-')

if [[ -z "$DEVICE1" || -z "$INTERFACE1" ]]; then
    echo "❌ Failed to extract LOCAL details"
    continue
fi

echo ""
echo "DEVICE1: $DEVICE1 $INTERFACE1"
echo "DEVICE2: $DEVICE2 $INTERFACE2"

CMD_FILE="/tmp/reaper_intf_$$.txt"

cat <<EOF > "$CMD_FILE"
show interfaces $INTERFACE1
show interfaces terse | match $INTERFACE1
show interfaces $INTERFACE1 extensive | match "Physical|Desc|flap|fpps|error|traffic|bps|pps|desc"
show interfaces diagnostics optics $INTERFACE1 | match "dbm|lane" | except "thre|off"
show log messages | match snmp | match $INTERFACE1
show log messages | last 10

show interfaces $INTERFACE2
show interfaces terse | match $INTERFACE2
show interfaces $INTERFACE2 extensive | match "Physical|Desc|flap|fpps|error|traffic|bps|pps|desc"
show interfaces diagnostics optics $INTERFACE2 | match "dbm|lane" | except "thre|off"
show log messages | match snmp | match $INTERFACE2
show log messages | last 10
EOF

echo ""
echo "ð Running Interface Check..."

reaper -t "$DEVICE1,$DEVICE2" -p junos -o -ts -post "$TICKET" -cfile "$CMD_FILE"

rm -f "$CMD_FILE"

echo "✅ Interface check completed"
;;

# =========================================================
# 2️⃣ OSPF CHECK
# =========================================================
2)
read -p "Enter details (Device;OSPF_IP;Ticket): " INPUT
IFS=';' read -r DEVICE OSPF_IP TICKET <<< "$INPUT"

if [[ -z "$DEVICE" || -z "$OSPF_IP" || -z "$TICKET" ]]; then
    echo "❌ Missing input. Format: Device;OSPF_IP;Ticket"
    continue
fi

CMD_FILE="/tmp/reaper_ospf_$$.txt"

cat <<EOF > "$CMD_FILE"
show ospf neighbor detail | match $OSPF_IP
show configuration | display set | match deac
EOF

reaper -t "$DEVICE" -p junos -o -ts -post "$TICKET" -cfile "$CMD_FILE"

rm -f "$CMD_FILE"

echo "✅ OSPF check completed"
;;

# =========================================================
# 3️⃣ BGP CHECK
# =========================================================
3)
read -p "Enter details (Device;BGP_IP;Ticket): " INPUT
IFS=';' read -r DEVICE BGP_IP TICKET <<< "$INPUT"

if [[ -z "$DEVICE" || -z "$BGP_IP" || -z "$TICKET" ]]; then
    echo "❌ Missing input. Format: Device;BGP_IP;Ticket"
    continue
fi

CMD_FILE="/tmp/reaper_bgp_$$.txt"

cat <<EOF > "$CMD_FILE"
show bgp summary | match $BGP_IP
show configuration | display set | match deac
EOF

reaper -t "$DEVICE" -p junos -o -ts -post "$TICKET" -cfile "$CMD_FILE"

rm -f "$CMD_FILE"

echo "✅ BGP check completed"
;;

# =========================================================
# 4️⃣ PSU / FAN CHECK
# =========================================================
4)
read -p "Enter details (Device;Ticket): " INPUT
IFS=';' read -r DEVICE TICKET <<< "$INPUT"

if [[ -z "$DEVICE" || -z "$TICKET" ]]; then
    echo "❌ Missing input. Format: Device;Ticket"
    continue
fi

CMD_FILE="/tmp/reaper_psu_$$.txt"

cat <<EOF > "$CMD_FILE"
show chassis environment | match "pem|fan"
show log messages | match "fan|power"
EOF

reaper -t "$DEVICE" -p junos -o -ts -post "$TICKET" -cfile "$CMD_FILE"

rm -f "$CMD_FILE"

echo "✅ PSU/FAN check completed"
;;

# =========================================================
# EXIT
# =========================================================
5)
echo "ð Exiting..."
exit 0
;;

*)
echo "❌ Invalid choice"
;;

esac

done
