# shellcheck shell=sh
# Status report

_status_weekday_vi() {
  d=$(date +%u 2>/dev/null)
  case "$d" in
    1) echo "Monday" ;;
    2) echo "Tuesday" ;;
    3) echo "Wednesday" ;;
    4) echo "Thursday" ;;
    5) echo "Friday" ;;
    6) echo "Saturday" ;;
    7) echo "Sunday" ;;
    *) date +%A 2>/dev/null || echo "N/A" ;;
  esac
}

_status_get_uptime_long_vi() {
  if [ -r /proc/uptime ]; then
    up=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
    days=$(( up / 86400 ))
    hours=$(( (up % 86400) / 3600 ))
    mins=$(( (up % 3600) / 60 ))
    echo "${days}d ${hours}h ${mins}m"
    return
  fi
  echo "N/A"
}

_status_get_storage_line() {
  for mount in /data /storage/emulated/0 /sdcard; do
    if df -h "$mount" >/dev/null 2>&1; then
      line="$(df -h "$mount" 2>/dev/null | tail -n 1)"
      used="$(echo "$line" | awk '{print $3}')"
      total="$(echo "$line" | awk '{print $2}')"
      pct="$(echo "$line" | awk '{print $5}')"
      if [ -n "$used" ] && [ -n "$total" ] && [ -n "$pct" ]; then
        echo "${used}/${total} (${pct})"
        return
      fi
    fi
  done
  echo "N/A"
}

_status_get_ram_line() {
  if command -v free >/dev/null 2>&1; then
    used_total="$(free -h | awk '/Mem:/{print $3\"/\"$2}')"
    [ -n "$used_total" ] && { echo "$used_total"; return; }
  fi
  if [ -r /proc/meminfo ]; then
    mem_total_k=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "")
    mem_avail_k=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo "")
    if [ -n "$mem_total_k" ] && [ -n "$mem_avail_k" ]; then
      total_g=$(awk "BEGIN{printf \"%.1f\", $mem_total_k/1024/1024}")
      avail_g=$(awk "BEGIN{printf \"%.1f\", $mem_avail_k/1024/1024}")
      used_g=$(awk "BEGIN{printf \"%.1f\", $total_g - $avail_g}")
      echo "${used_g}G/${total_g}G"
      return
    fi
  fi
  echo "N/A"
}

_status_get_cpu_temp() {
  for f in /sys/class/thermal/thermal_zone*/temp; do
    [ -f "$f" ] || continue
    t="$(cat "$f" 2>/dev/null || true)"
    [ -n "$t" ] || continue
    case "$t" in *[!0-9]*)
      continue
      ;;
    esac
    if [ ${#t} -gt 3 ]; then
      echo "$((t/1000))°C"
    else
      echo "${t}°C"
    fi
    return
  done
  echo "N/A"
}

_status_get_cpu_freq() {
  f="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
  if [ -r "$f" ]; then
    v="$(cat "$f" 2>/dev/null || true)"
    case "$v" in ''|*[!0-9]*) echo "N/A" ;;
      *) echo "$((v/1000))MHz" ;;
    esac
    return
  fi
  echo "N/A"
}

_status_get_mobile_data_status() {
  md="$(settings get global mobile_data 2>/dev/null || true)"
  [ "$md" = "1" ] && { echo "ON ✅"; return; }
  [ "$md" = "0" ] && { echo "OFF ❌"; return; }
  state="$(dumpsys telephony.registry 2>/dev/null | egrep -o 'mDataConnectionState=[0-9]+' | head -n1 | cut -d= -f2 || true)"
  if [ -n "$state" ]; then
    if [ "$state" -eq 0 ] 2>/dev/null; then echo "OFF ❌"; else echo "ON ✅"; fi
    return
  fi
  conn="$(dumpsys connectivity 2>/dev/null | egrep -i 'NetworkAgentInfo.*MOBILE|NetworkAgentInfo.*CELLULAR' | head -n1)"
  [ -n "$conn" ] && echo "ON ✅" || echo "Unknown"
}

_status_get_hotspot_status() {
  hs="$(get_hotspot_state_simple 2>/dev/null || echo "")"
  case "$hs" in
    on) echo "ON ✅" ;;
    off) echo "OFF ❌" ;;
    *) echo "Unknown" ;;
  esac
}

_status_get_wifi_status() {
  if dumpsys wifi 2>/dev/null | grep -q "Wi-Fi is enabled"; then echo "ON ✅"; return; fi
  if ip -f inet addr show wlan0 2>/dev/null | grep -q "inet "; then echo "ON ✅"; return; fi
  if command -v settings >/dev/null 2>&1; then
    w=$(settings get global wifi_on 2>/dev/null || settings get secure wifi_on 2>/dev/null || true)
    [ "$w" = "1" ] && { echo "ON ✅"; return; }
    [ "$w" = "0" ] && { echo "OFF ❌"; return; }
  fi
  echo "OFF ❌"
}

_status_get_bluetooth_status() {
  if command -v settings >/dev/null 2>&1; then
    val=$(settings get global bluetooth_on 2>/dev/null || true)
    [ "$val" = "1" ] && { echo "ON ✅"; return; }
    [ "$val" = "0" ] && { echo "OFF ❌"; return; }
  fi
  if service call bluetooth_manager 6 >/dev/null 2>&1; then echo "ON ✅"; else echo "OFF ❌"; fi
}

handle_status_send() {
  operator="$(get_operator_name)"
  nettype="$(get_nettype_with_desc)"
  dbm="$(get_dbm)"
  sigqual="$(map_sig_quality "$dbm")"

  if [ "$sigqual" = "Excellent" ]; then
    bars="📶📶📶📶"
  elif [ "$sigqual" = "Fair" ]; then
    bars="📶📶📶"
  elif [ "$sigqual" = "Poor" ]; then
    bars="📶"
  else
    bars="N/A"
  fi

  if echo "$dbm" | grep -qE '^-?[0-9]+'; then
    sig_text="${dbm} dBm ${bars} (${sigqual})"
  else
    sig_text="${dbm}"
  fi

  batt_block="$(get_batt_info_text)"

  storage="$(_status_get_storage_line)"
  ram="$(_status_get_ram_line)"
  cpu_temp="$(_status_get_cpu_temp)"
  cpu_freq="$(_status_get_cpu_freq)"

  mobile_data="$(_status_get_mobile_data_status)"
  hotspot="$(_status_get_hotspot_status)"
  wifi="$(_status_get_wifi_status)"
  bt="$(_status_get_bluetooth_status)"

  today="$(date +'%d/%m/%Y')"
  now_time="$(date +'%H:%M:%S')"
  weekday="$(_status_weekday_vi)"
  uptime="$(_status_get_uptime_long_vi)"

  message="$(cat <<EOF
<b>📋 System status</b>
<code>────────────────────────</code>

<b>📡 Cellular</b>
• Operator: <code>${operator}</code>
• Signal: <code>${sig_text}</code>
• Network: <code>${nettype}</code>

<b>🔋 Battery</b>
$(printf '%s\n' "$batt_block" | sed 's/^/• /' | sed 's/• 🔋/🔋/' | sed 's/• ⚡/⚡/' | sed 's/• 🌡️/🌡️/' | sed 's/• 🔌/🔌/' | sed 's/• ❤️/❤️/')

<b>💾 Storage</b>
• RAM: <code>${ram}</code>
• Disk: <code>${storage}</code>

<b>⚙️ Performance</b>
• CPU temp: <code>${cpu_temp}</code>
• CPU freq: <code>${cpu_freq}</code>

<b>🌐 Connectivity</b>
• Mobile data: <code>${mobile_data}</code>
• Hotspot: <code>${hotspot}</code>
• Wi‑Fi: <code>${wifi}</code>
• Bluetooth: <code>${bt}</code>

<b>⏰ Time / Uptime</b>
• Date: <code>${weekday}, ${today}</code>
• Time: <code>${now_time}</code>
• Uptime: <code>${uptime}</code>
EOF
)"

  send_code "$message"
}

