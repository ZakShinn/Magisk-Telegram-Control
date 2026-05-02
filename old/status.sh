#!/system/bin/sh
# send_net_info.sh - Hiển thị thông tin Mạng di động, Pin, Kết nối mạng, Bộ nhớ, Thời gian, Hiệu năng; gửi qua Telegram nếu cấu hình

TELEGRAM_TOKEN="8298693641:AAEnMY9EUmO0MO6VL1RK6q7ZFrUGZjuI0Ak"
TELEGRAM_CHAT_ID="1189961723"  

getprop_safe() { getprop "$1" 2>/dev/null || echo ""; }

# --- Mạng di động ---
OPERATOR="$(getprop_safe gsm.operator.alpha)"
[ -z "$OPERATOR" ] && OPERATOR="$(getprop_safe gsm.sim.operator.alpha)"
[ -z "$OPERATOR" ] && OPERATOR="Không xác định"

# Logic loại mạng giống script Telegram Device Bot
is_nr_connected() {
  out="$(dumpsys telephony 2>/dev/null || true)"
  reg="$(dumpsys telephony.registry 2>/dev/null || true)"
  all="$out
$reg"
  echo "$all" | grep -qiE 'nrState[:= ]+CONNECTED' && return 0
  echo "$all" | grep -qiE 'isNrConnected[:= ]+true' && return 0
  echo "$all" | grep -qiE 'mNrState[:= ]+CONNECTED' && return 0
  echo "$all" | tr '\n' ' ' | grep -qiE 'PhysicalChannelConfig.*(RAT|networkType)[:= ]*NR' && return 0
  echo "$all" | grep -qiE 'mDataNetworkType=20' && return 0
  getprop gsm.network.type 2>/dev/null | grep -qi 'NR' && return 0
  return 1
}

rat_num_to_name() {
  case "$1" in
    20) echo "5G";;
    13) echo "LTE";;
    8|9|10|15|3) echo "3G";;
    1|2) echo "2G";;
    *) echo "Không xác định";;
  esac
}

get_nettype() {
  NETTYPE_RAW="$(getprop_safe gsm.network.type)"
  REG="$(dumpsys telephony.registry 2>/dev/null || true)"
  DATA_NUM="$(echo "$REG" | grep -oE 'mDataNetworkType=[0-9]+' | head -n1 | cut -d= -f2)"

  if is_nr_connected; then
    if [ "$DATA_NUM" = "20" ] || echo "$NETTYPE_RAW" | grep -qi 'NR'; then
      echo "5G (SA)"
    else
      echo "LTE+NR (NSA)"
    fi
    return
  fi

  if echo "$DATA_NUM" | grep -qE '^[0-9]+$'; then
    rat="$(rat_num_to_name "$DATA_NUM")"
    [ "$rat" != "Không xác định" ] && { echo "$rat"; return; }
  fi

  if [ -n "$NETTYPE_RAW" ]; then
    up="$(echo "$NETTYPE_RAW" | tr '[:lower:]' '[:upper:]')"
    case "$up" in
      *NR*)  echo "5G";;
      *LTE*) echo "LTE";;
      *HSPA*|*UMTS*|*3G*) echo "3G";;
      *EDGE*|*GPRS*|*2G*) echo "2G";;
      *) echo "$NETTYPE_RAW";;
    esac
  else
    echo "Không xác định"
  fi
}

# Thêm mô tả giống script trước
get_nettype_with_desc() {
  base="$(get_nettype)"
  case "$base" in
    "5G (SA)")
      echo "5G (SA) – 5G độc lập (Standalone)"
      ;;
    "LTE+NR (NSA)")
      echo "LTE+NR (NSA) – 4G LTE + 5G (Non-Standalone)"
      ;;
    "5G")
      echo "5G – mạng 5G (kiểu kết nối không rõ)"
      ;;
    "LTE")
      echo "LTE – 4G LTE"
      ;;
    "3G")
      echo "3G – UMTS/HSPA (3G)"
      ;;
    "2G")
      echo "2G – GSM/EDGE (2G)"
      ;;
    *)
      echo "$base"
      ;;
  esac
}

NETTYPE="$(get_nettype_with_desc)"

get_dbm() {
  v="$(getprop_safe sm.signalstrength)"
  if echo "$v" | grep -qE '^-?[0-9]+'; then echo "$v"; return; fi
  v="$(getprop_safe gsm.signalstrength)"
  if echo "$v" | grep -qE '^-?[0-9]+'; then echo "$v"; return; fi
  out="$(dumpsys telephony.registry 2>/dev/null || dumpsys telephony 2>/dev/null || true)"
  for key in lteRsrp mLteRsrp rsrp mSignalStrengthDbm cdmaDbm dbm; do
    v="$(echo "$out" | grep -oE "${key}=[-]?[0-9]+" | head -n1 | sed 's/[^-0-9]//g')"
    [ -n "$v" ] && { echo "$v"; return; }
  done
  sigblock="$(echo "$out" | tr '\n' ' ' | sed -n 's/.*SignalStrength{/\n&/p' | head -n1)"
  if [ -n "$sigblock" ]; then
    v="$(echo "$sigblock" | grep -oE '-[0-9]{1,3}' | head -n1 | sed 's/[^-0-9]//g')"
    [ -n "$v" ] && { echo "$v"; return; }
  fi
  asu="$(echo "$out" | grep -oE 'gsmSignalStrength=[0-9]+' | head -n1 | cut -d= -f2)"
  if [ -n "$asu" ]; then echo $(( -113 + 2 * asu )); return; fi
  echo "N/A"
}

DBM="$(get_dbm)"

map_sig_quality() {
  val="$1"
  if echo "$val" | grep -qE '^-?[0-9]+'; then
    n=$(printf "%d" "$val" 2>/dev/null || echo "")
    if [ -n "$n" ]; then
      if [ "$n" -ge -85 ]; then echo "Rất tốt"
      elif [ "$n" -ge -100 ]; then echo "Trung bình"
      else echo "Xấu"
      fi
    else
      echo "N/A"
    fi
  else
    echo "N/A"
  fi
}

sigqual="$(map_sig_quality "$DBM")"
if [ "$sigqual" = "Rất tốt" ]; then
  BARS="📶📶📶📶"
elif [ "$sigqual" = "Trung bình" ]; then
  BARS="📶📶📶"
elif [ "$sigqual" = "Xấu" ]; then
  BARS="📶"
else
  BARS="N/A"
fi

# Dòng tín hiệu gọn gàng
if echo "$DBM" | grep -qE '^-?[0-9]+'; then
  SIG_TEXT="${DBM} dBm ${BARS} (${sigqual})"
else
  SIG_TEXT="${DBM}"
fi

# --- Pin ---
get_batt_level() { dumpsys battery 2>/dev/null | awk -F: '/level/ {gsub(/ /,"",$2); print $2; exit}' || echo "N/A"; }
get_batt_status() {
  s=$(dumpsys battery 2>/dev/null | awk -F: '/status/ {gsub(/ /,"",$2); print $2; exit}' || echo "")
  case "$s" in
    2) echo "Sạc" ;;
    3) echo "Sử dụng (Không sạc)" ;;
    4) echo "Không sạc" ;;
    5) echo "Đầy" ;;
    1) echo "Không xác định" ;;
    *) echo "${s:-N/A}" ;;
  esac
}
get_batt_temp() {
  t=$(dumpsys battery 2>/dev/null | awk -F: '/temperature/ {gsub(/ /,"",$2); print $2; exit}' || echo "")
  if echo "$t" | grep -qE '^[0-9]+'; then awk "BEGIN{printf \"%.1f\", $t/10}"; else echo "N/A"; fi
}
get_batt_voltage() {
  v=$(dumpsys battery 2>/dev/null | awk -F: '/voltage/ {gsub(/ /,"",$2); print $2; exit}' || echo "")
  [ -n "$v" ] && echo "${v} mV" || echo "N/A"
}
get_batt_health() {
  h=$(dumpsys battery 2>/dev/null | awk -F: '/health/ {gsub(/ /,"",$2); print $2; exit}' || echo "")
  case "$h" in
    2) echo "Tốt ✅" ;;
    3|4|5|6|7) echo "Xấu ❌" ;;
    1) echo "Không xác định" ;;
    *) echo "${h:-N/A}" ;;
  esac
}

BATT_LEVEL="$(get_batt_level)"
BATT_STATUS="$(get_batt_status)"
BATT_TEMP="$(get_batt_temp)"
BATT_VOLTAGE="$(get_batt_voltage)"
BATT_HEALTH="$(get_batt_health)"

# --- KẾT NỐI MẠNG ---
get_mobile_data_status() {
  md="$(settings get global mobile_data 2>/dev/null || true)"
  if [ "$md" = "1" ]; then echo "Bật ✅"; return; fi
  if [ "$md" = "0" ]; then echo "Tắt ❌"; return; fi
  state="$(dumpsys telephony.registry 2>/dev/null | egrep -o 'mDataConnectionState=[0-9]+' | head -n1 | cut -d= -f2 || true)"
  if [ -n "$state" ]; then
    if [ "$state" -eq 0 ]; then echo "Tắt ❌"; else echo "Bật ✅"; fi
    return
  fi
  conn="$(dumpsys connectivity 2>/dev/null | egrep -i 'NetworkAgentInfo.*MOBILE|NetworkAgentInfo.*CELLULAR' | head -n1)"
  if [ -n "$conn" ]; then echo "Bật ✅"; else echo "Không xác định"; fi
}

# Hotspot Wi-Fi: dựa vào wifi_ap_state / dumpsys wifi / ip addr
get_hotspot_status() {
  # 1. wifi_ap_state (ưu tiên)
  if command -v settings >/dev/null 2>&1; then
    apstate=$(settings get global wifi_ap_state 2>/dev/null || settings get secure wifi_ap_state 2>/dev/null || true)
    case "$apstate" in
      13) echo "Bật ✅ (ENABLED)"; return ;;
      12) echo "Đang bật (ENABLING)"; return ;;
      10|11) echo "Tắt ❌"; return ;;
    esac
  fi

  # 2. dumpsys wifi isWifiApEnabled
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

  # 3. Fallback: nếu có IP trên các iface softap phổ biến
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

MOBILE_DATA_STATUS="$(get_mobile_data_status)"
HOTSPOT_STATUS="$(get_hotspot_status)"
WIFI_STATUS="$(get_wifi_status)"
BLUETOOTH_STATUS="$(get_bluetooth_status)"

# --- Bộ nhớ (storage + RAM) ---
get_storage() {
  # Thử lần lượt /data, /storage/emulated/0, /sdcard để lấy bộ nhớ "nội bộ"
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

  # Fallback: dòng thứ 2 của df -h tổng
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
    # chỉ lấy used/total, không thêm "Khả dụng"
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


STORAGE="$(get_storage)"
RAM="$(get_ram)"

# --- Thời gian / Uptime ---
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

get_uptime() {
  if [ -r /proc/uptime ]; then
    up=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
    days=$(( up/86400 ))
    hours=$(( (up%86400)/3600 ))
    mins=$(( (up%3600)/60 ))
    echo "${days} ngày ${hours} giờ ${mins} phút"
    return
  fi
  echo "N/A"
}

TODAY="$(date +'%d/%m/%Y')"
NOW_TIME="$(date +'%H:%M:%S')"
WEEKDAY="$(weekday_vi)"
UPTIME_STR="$(get_uptime)"

# --- Hiệu năng: CPU temp + freq ---
get_cpu_temp() {
  for f in /sys/class/thermal/thermal_zone*/temp; do
    if [ -f "$f" ]; then
      t=$(cat "$f" 2>/dev/null)
      if [ -n "$t" ]; then
        if [ ${#t} -gt 3 ]; then
          echo "$((t/1000))°C"
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
      echo "$((f/1000))MHz"
      return
    fi
  fi
  echo "N/A"
}

CPU_TEMP="$(get_cpu_temp)"
CPU_FREQ="$(get_cpu_freq)"

# --- Tạo message hoàn chỉnh (thời gian ở cuối) ---
MESSAGE="$(cat <<EOF
<b>📋 Thông tin hệ thống</b>
<code>────────────────────────</code>

<b>📡 Mạng di động</b>
• Nhà mạng: <code>${OPERATOR}</code>
• Cường độ tín hiệu: <code>${SIG_TEXT}</code>
• Loại mạng: <code>${NETTYPE}</code>

<b>🔋 Pin</b>
• Mức pin: <code>${BATT_LEVEL}%</code>
• Trạng thái: <code>${BATT_STATUS}</code>
• Nhiệt độ: <code>${BATT_TEMP} °C</code>
• Điện áp: <code>${BATT_VOLTAGE}</code>
• Sức khỏe: <code>${BATT_HEALTH}</code>

<b>💾 Bộ nhớ</b>
• RAM: <code>${RAM}</code>
• ROM: <code>${STORAGE}</code>

<b>⚙️ Hiệu năng</b>
• Nhiệt độ CPU: <code>${CPU_TEMP}</code>
• Tần số CPU: <code>${CPU_FREQ}</code>

<b>🌐 Kết nối</b>
• Dữ liệu di động: <code>${MOBILE_DATA_STATUS}</code>
• Hotspot Wi-Fi: <code>${HOTSPOT_STATUS}</code>
• Wi-Fi: <code>${WIFI_STATUS}</code>
• Bluetooth: <code>${BLUETOOTH_STATUS}</code>

<b>⏰ Thời gian / Uptime</b>
• Ngày: <code>${WEEKDAY}, ${TODAY}</code>
• Giờ: <code>${NOW_TIME}</code>
• Đã hoạt động: <code>${UPTIME_STR}</code>
EOF
)"


# In ra màn hình
printf "%s\n" "$MESSAGE"

# Gửi Telegram nếu có token/chat_id hoặc chạy với tham số "send"
if [ "$1" = "send" ] || { [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; }; then
  if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "TELEGRAM_TOKEN hoặc TELEGRAM_CHAT_ID chưa được cấu hình. Bỏ qua gửi."
    exit 0
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
	  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
	  --data-urlencode "parse_mode=HTML" \
	  --data-urlencode "text=${MESSAGE}" >/dev/null 2>&1 && echo "Đã gửi Telegram."
  else
    echo "Không tìm thấy curl. Không thể gửi Telegram."
  fi
fi

exit 0
