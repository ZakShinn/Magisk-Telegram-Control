# shellcheck shell=sh
# RAM, ROM, Wi‑Fi, hotspot, SIM data, CPU — dùng cho status.sh

get_mobile_data_status() {
  md="$(settings get global mobile_data 2>/dev/null || true)"
  if [ "$md" = "1" ]; then echo "Bật ✅"; return; fi
  if [ "$md" = "0" ]; then echo "Tắt ❌"; return; fi
  state="$(dumpsys telephony.registry 2>/dev/null | grep -oE 'mDataConnectionState=[0-9]+' | head -n1 | cut -d= -f2 || true)"
  if [ -n "$state" ]; then
    if [ "$state" -eq 0 ]; then echo "Tắt ❌"; else echo "Bật ✅"; fi
    return
  fi
  conn="$(dumpsys connectivity 2>/dev/null | grep -iE 'NetworkAgentInfo.*MOBILE|NetworkAgentInfo.*CELLULAR' | head -n1)"
  if [ -n "$conn" ]; then echo "Bật ✅"; else echo "Không xác định"; fi
}

get_hotspot_status() {
  if command -v settings >/dev/null 2>&1; then
    apstate=$(settings get global wifi_ap_state 2>/dev/null || settings get secure wifi_ap_state 2>/dev/null || true)
    case "$apstate" in
      13) echo "Bật ✅ (ENABLED)"; return ;;
      12) echo "Đang bật (ENABLING)"; return ;;
      10|11) echo "Tắt ❌"; return ;;
    esac
  fi

  ds_wifi="$(dumpsys wifi 2>/dev/null || true)"
  line="$(echo "$ds_wifi" | grep -i 'isWifiApEnabled' | tail -n1)"
  if [ -n "$line" ]; then
    if echo "$line" | grep -qi 'true'; then
      ssid="$(echo "$ds_wifi" | grep -m1 -oE 'SSID: "[^"]+"' | sed 's/SSID: "//; s/"//' 2>/dev/null)"
      [ -n "$ssid" ] && echo "Bật ✅ (SSID: ${ssid})" && return
      echo "Bật ✅"; return
    else
      echo "Tắt ❌"; return
    fi
  fi

  for ifc in swlan0 ap0 softap0 wlan1; do
    if ip -4 addr show "$ifc" 2>/dev/null | grep -q 'inet '; then
      ipinfo=$(ip -4 addr show "$ifc" 2>/dev/null | awk '/inet /{print $2; exit}')
      echo "Bật ✅ (iface $ifc, IP ${ipinfo:-no-ip})"
      return
    fi
  done

  echo "Tắt ❌"
}

get_wifi_status() {
  if dumpsys wifi 2>/dev/null | grep -q "Wi-Fi is enabled"; then echo "Bật ✅"; return; fi
  if ip -f inet addr show wlan0 2>/dev/null | grep -q "inet "; then echo "Bật ✅"; return; fi
  if command -v settings >/dev/null 2>&1; then
    w=$(settings get global wifi_on 2>/dev/null || settings get secure wifi_on 2>/dev/null || true)
    if [ "$w" = "1" ]; then echo "Bật ✅"; return; fi
    if [ "$w" = "0" ]; then echo "Tắt ❌"; return; fi
  fi
  echo "Tắt ❌"
}

get_bluetooth_status() {
  if command -v settings >/dev/null 2>&1; then
    val=$(settings get global bluetooth_on 2>/dev/null || true)
    if [ "$val" = "1" ]; then echo "Bật ✅"; return; fi
    if [ "$val" = "0" ]; then echo "Tắt ❌"; return; fi
  fi
  if service call bluetooth_manager 6 >/dev/null 2>&1; then echo "Bật ✅"; else echo "Tắt ❌"; fi
}

get_storage() {
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

  out2="$(df -h 2>/dev/null | sed -n '2p')"
  if [ -n "$out2" ]; then
    used="$(echo "$out2" | awk '{print $3}')"
    total="$(echo "$out2" | awk '{print $2}')"
    pct="$(echo "$out2" | awk '{print $5}')"
    echo "${used}/${total} (${pct})"
    return
  fi

  echo "N/A"
}

get_ram() {
  if command -v free >/dev/null 2>&1; then
    used_total="$(free -h | awk '/Mem:/{print $3"/"$2}')"
    [ -n "$used_total" ] && { echo "$used_total"; return; }
  fi
  if [ -f /proc/meminfo ]; then
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

weekday_vi() {
  d=$(date +%u 2>/dev/null)
  case "$d" in
    1) echo "Thứ Hai";;
    2) echo "Thứ Ba";;
    3) echo "Thứ Tư";;
    4) echo "Thứ Năm";;
    5) echo "Thứ Sáu";;
    6) echo "Thứ Bảy";;
    7) echo "Chủ Nhật";;
    *) echo "$(date +%A 2>/dev/null)";;
  esac
}

get_uptime_long() {
  if [ -r /proc/uptime ]; then
    up=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
    days=$(( up / 86400 ))
    hours=$(( (up % 86400) / 3600 ))
    mins=$(( (up % 3600) / 60 ))
    echo "${days} ngày ${hours} giờ ${mins} phút"
    return
  fi
  echo "N/A"
}

get_cpu_temp() {
  for f in /sys/class/thermal/thermal_zone*/temp; do
    if [ -f "$f" ]; then
      t=$(cat "$f" 2>/dev/null)
      if [ -n "$t" ]; then
        if [ ${#t} -gt 3 ]; then
          echo "$((t / 1000))°C"
        else
          echo "${t}°C"
        fi
        return
      fi
    fi
  done
  echo "N/A"
}

get_cpu_freq() {
  if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
    f=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    if [ -n "$f" ]; then
      echo "$((f / 1000))MHz"
      return
    fi
  fi
  echo "N/A"
}

get_batt_status_label() {
  s=$(dumpsys battery 2>/dev/null | awk -F: '/status/ {gsub(/ /,"",$2); print $2; exit}' || echo "")
  case "$s" in
    2) echo "Đang sạc" ;;
    3) echo "Đang xả" ;;
    4) echo "Không sạc" ;;
    5) echo "Đầy" ;;
    *) echo "${s:-N/A}" ;;
  esac
}

get_batt_temp_c() {
  t=$(dumpsys battery 2>/dev/null | awk -F: '/temperature/ {gsub(/ /,"",$2); print $2; exit}' || echo "")
  if echo "$t" | grep -qE '^[0-9]+'; then awk "BEGIN{printf \"%.1f\", $t/10}"; else echo "N/A"; fi
}

get_batt_voltage_mv() {
  v=$(dumpsys battery 2>/dev/null | awk -F: '/voltage/ {gsub(/ /,"",$2); print $2; exit}' || echo "")
  [ -n "$v" ] && echo "${v} mV" || echo "N/A"
}

get_batt_health_label() {
  h=$(dumpsys battery 2>/dev/null | awk -F: '/health/ {gsub(/ /,"",$2); print $2; exit}' || echo "")
  case "$h" in
    2) echo "Tốt ✅" ;;
    3|4|5|6|7) echo "Cần chú ý ❌" ;;
    *) echo "${h:-N/A}" ;;
  esac
}
