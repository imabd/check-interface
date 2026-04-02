#!/bin/bash

while true; do

echo ""
echo "==========================================="
echo "ð¥ NOC TOOLKIT - SELECT OPTION"
echo "-------------------------------------------"
echo "1) Interface Checker"
echo "2) OSPF Check"
echo "3) BGP Check"
echo "4) PSU / FAN Check"
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

INTERFACE1=$(echo "$INTERFACE1" | tr -cd 'a-z0-9/:-')
INTERFACE2=$(echo "$INTERFACE2" | tr -cd 'a-z0-9/:-')

if [[ -z "$DEVICE1" || -z "$INTERFACE1" ]]; then
    echo "❌ Failed to extract details"
    continue
fi

echo ""
echo "DEVICE1: $DEVICE1 $INTERFACE1"
echo "DEVICE2: $DEVICE2 $INTERFACE2"

CMD_FILE="/tmp/reaper_intf_$$.txt"

cat <<EOF > "$CMD_FILE"
show interfaces $INTERFACE1
show interfaces terse | match $INTERFACE1
show interfaces $INTERFACE1 extensive | match "Physical|Desc|flap|error|traffic|bps|pps"
show interfaces diagnostics optics $INTERFACE1 | match "dbm|lane"
show log messages | match $INTERFACE1 | last 10

show interfaces $INTERFACE2
show interfaces terse | match $INTERFACE2
show interfaces $INTERFACE2 extensive | match "Physical|Desc|flap|error|traffic|bps|pps"
show interfaces diagnostics optics $INTERFACE2 | match "dbm|lane"
show log messages | match $INTERFACE2 | last 10
EOF

echo "ð Running Interface Check..."

reaper -t "$DEVICE1,$DEVICE2" -p junos -o -ts -post "$TICKET" -cfile "$CMD_FILE"

rm -f "$CMD_FILE"

echo "✅ Interface check completed"
;;

# =========================================================
# 2️⃣ OSPF CHECK (AUTO + SUMMARY)
# =========================================================
2)
read -p "ð« Enter Ticket ID: " TICKET

echo ""
echo "ð Paste Ticket Description (ENTER twice):"
DESC=""
while IFS= read -r line; do
  [[ -z "$line" ]] && break
  DESC+="$line "
done

DESC_CLEAN=$(echo "$DESC" | tr '[:upper:]' '[:lower:]')

DEVICE=$(echo "$DESC_CLEAN" | grep -oE '[a-z0-9.-]+\.service-now\.com' | head -1)
OSPF_IP=$(echo "$DESC_CLEAN" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)

if [[ -z "$DEVICE" || -z "$OSPF_IP" ]]; then
    echo "❌ Failed to extract OSPF details"
    continue
fi

echo "DEVICE: $DEVICE"
echo "OSPF IP: $OSPF_IP"

CMD_FILE="/tmp/reaper_ospf_$$.txt"

cat <<EOF > "$CMD_FILE"
show ospf neighbor detail | match $OSPF_IP
show log messages | match ospf | last 20
EOF

echo "ð Running OSPF Check..."

reaper -t "$DEVICE" -p junos -o -ts -post "$TICKET" -cfile "$CMD_FILE"

rm -f "$CMD_FILE"

LATEST_FILE=$(ls -t /home/users/$USER/REAPER/* | head -1)

if grep -qi "full" "$LATEST_FILE"; then
    STATUS="ð¢ OSPF UP (FULL)"
elif grep -qi "down\|init\|2-way" "$LATEST_FILE"; then
    STATUS="ð´ OSPF NOT FULL"
else
    STATUS="ð¡ OSPF UNKNOWN"
fi

echo ""
echo "========== ð SUMMARY =========="
echo "$STATUS"
echo "================================"
;;

# =========================================================
# 3️⃣ BGP CHECK (AUTO + SUMMARY)
# =========================================================
3)
read -p "ð« Enter Ticket ID: " TICKET

echo ""
echo "ð Paste Ticket Description (ENTER twice):"
DESC=""
while IFS= read -r line; do
  [[ -z "$line" ]] && break
  DESC+="$line "
done

DESC_CLEAN=$(echo "$DESC" | tr '[:upper:]' '[:lower:]')

DEVICE=$(echo "$DESC_CLEAN" | grep -oE '[a-z0-9.-]+\.service-now\.com' | head -1)
BGP_IP=$(echo "$DESC_CLEAN" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)

if [[ -z "$DEVICE" || -z "$BGP_IP" ]]; then
    echo "❌ Failed to extract BGP details"
    continue
fi

echo "DEVICE: $DEVICE"
echo "BGP IP: $BGP_IP"

CMD_FILE="/tmp/reaper_bgp_$$.txt"

cat <<EOF > "$CMD_FILE"
show bgp summary | match $BGP_IP
show log messages | match bgp | last 20
EOF

echo "ð Running BGP Check..."

reaper -t "$DEVICE" -p junos -o -ts -post "$TICKET" -cfile "$CMD_FILE"

rm -f "$CMD_FILE"

LATEST_FILE=$(ls -t /home/users/$USER/REAPER/* | head -1)

if grep -qi "establ" "$LATEST_FILE"; then
    STATUS="ð¢ BGP UP (ESTABLISHED)"
elif grep -qi "idle\|active\|connect" "$LATEST_FILE"; then
    STATUS="ð´ BGP DOWN"
else
    STATUS="ð¡ BGP UNKNOWN"
fi

echo ""
echo "========== ð SUMMARY =========="
echo "$STATUS"
echo "================================"
;;

# =========================================================
# 4️⃣ PSU CHECK
# =========================================================
4)
read -p "Enter details (Device;Ticket): " INPUT
IFS=';' read -r DEVICE TICKET <<< "$INPUT"

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
