#!/bin/bash
# system_health.sh
# Checks CPU, Memory and Disk usage and appends a timestamped
# entry to health_log.txt. Prints a warning if disk usage exceeds 80%.

LOG_FILE="health_log.txt"
DISK_THRESHOLD="${DISK_THRESHOLD:-80}"   # default 80; can be overridden for testing

# --- Timestamp ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# --- CPU usage (%): sample /proc/stat twice, 1 second apart ---
read -r _ u1 n1 s1 i1 w1 irq1 sirq1 st1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 w2 irq2 sirq2 st2 _ < /proc/stat

idle1=$((i1 + w1))
idle2=$((i2 + w2))
total1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1 + st1))
total2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2 + st2))

total_diff=$((total2 - total1))
idle_diff=$((idle2 - idle1))

if [ "$total_diff" -gt 0 ]; then
    CPU_USAGE=$(awk -v t="$total_diff" -v i="$idle_diff" 'BEGIN { printf "%.1f", (t - i) * 100 / t }')
else
    CPU_USAGE="0.0"
fi

# --- Memory usage (%) ---
MEM_USAGE=$(free | awk '/^Mem:/ { printf "%.1f", $3 * 100 / $2 }')

# --- Disk usage (%) of the root filesystem ---
DISK_USAGE=$(df / --output=pcent | tail -n 1 | tr -dc '0-9')

# --- Append timestamped entry to the log (always) ---
echo "[$TIMESTAMP] CPU: ${CPU_USAGE}% | Memory: ${MEM_USAGE}% | Disk: ${DISK_USAGE}%" >> "$LOG_FILE"

# --- Warning if disk usage exceeds 80% ---
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    echo "[WARNING] Disk space high!"
    echo "[$TIMESTAMP] [WARNING] Disk space high! (${DISK_USAGE}% used)" >> "$LOG_FILE"
fi

echo "Health check logged to $LOG_FILE"
