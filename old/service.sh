#!/system/bin/sh


TELEGRAM_TOKEN="8298693641:AAEnMY9EUmO0MO6VL1RK6q7ZFrUGZjuI0Ak"
TELEGRAM_CHAT_ID="1189961723"  

BOT_API="https://api.telegram.org/bot${TELEGRAM_TOKEN}"

# Thư mục chứa script (dùng để gọi ./status.sh)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# File lưu OFFSET + LOCK để tránh ăn lại lệnh cũ và tránh chạy nhiều instance
BOT_OFFSET_FILE="/data/local/tmp/tg_device_bot_offset"




########################
# HÀM TIỆN ÍCH CHUNG
########################

getprop_safe() { getprop "$1" 2>/dev/null || echo ""; }

send_msg() {
  text="$1"
  [ -z "$TELEGRAM_TOKEN" ] && { echo "TELEGRAM_TOKEN chưa được cấu hình"; return; }
  [ -z "$TELEGRAM_CHAT_ID" ] && { echo "TELEGRAM_CHAT_ID chưa được cấu hình"; return; }

  curl -s "${BOT_API}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "parse_mode=HTML" \
    --data-urlencode "text=${text}" >/dev/null 2>&1
}

send_code() { # tương thích
  raw="$1"
  text="$(printf '%b' "$raw")"
  send_msg "$text"
}

# Kiểm tra có mạng + API Telegram sẵn sàng
has_network() {
  curl -s --max-time 5 "${BOT_API}/getMe" | grep -q '"ok":true'
}

########################
# PIN
########################

get_batt_level() {
  dumpsys battery 2>/dev/null | awk -F: '/level/ {gsub(/ /,"",$2); print $2; exit}'
}

get_batt_status_code() {
  dumpsys battery 2>/dev/null | awk -F: '/status/ {gsub(/ /,"",$2); print $2; exit}'
}

get_batt_info_text() {
  level="$(get_batt_level)"
  status_code="$(get_batt_status_code)"

  temp="$(dumpsys battery 2>/dev/null | awk -F: '/temperature/ {gsub(/ /,"",$2); print $2/10; exit}')"
  [ -z "$temp" ] && temp_text="N/A" || temp_text="${temp}°C"

  voltage_raw="$(dumpsys battery 2>/dev/null | awk -F: '/voltage/ {gsub(/ /,"",$2); print $2; exit}')"
  if echo "$voltage_raw" | grep -qE '^[0-9]+$'; then
    voltage_mv="${voltage_raw} mV"
    voltage_v="$(awk "BEGIN {printf \"%.2f\", $voltage_raw / 1000}")"
    voltage_text="${voltage_mv} (~${voltage_v} V)"
  else
    voltage_text="N/A"
  fi

  health_code="$(dumpsys battery 2>/dev/null | awk -F: '/health/ {gsub(/ /,"",$2); print $2; exit}')"
  case "$health_code" in
    2) health_txt="Tốt" ;;
    3) health_txt="Quá nóng" ;;
    4) health_txt="Pin chết" ;;
    5) health_txt="Quá áp" ;;
    6) health_txt="Lỗi không xác định" ;;
    7) health_txt="Quá lạnh" ;;
    *) health_txt="Không xác định" ;;
  esac

  case "$status_code" in
    2) status_txt="Đang sạc" ;;
    3) status_txt="Đang xả (không sạc)" ;;
    4) status_txt="Không sạc" ;;
    5) status_txt="Đầy" ;;
    *) status_txt="Không xác định" ;;
  esac

  cat <<EOF
🔋 Pin: ${level}%
⚡ Trạng thái sạc: ${status_txt}
🌡️ Nhiệt độ: ${temp_text}
🔌 Điện áp: ${voltage_text}
❤️ Health: ${health_txt} (${health_code})
EOF
}

########################
# THEO DÕI THAY ĐỔI (mỗi 5s) -> gửi Telegram khi có thay đổi
########################

get_charge_state_simple() {
  # dumpsys battery: status 2=CHARGING, 5=FULL, 3=DISCHARGING, 4=NOT_CHARGING
  sc="$(get_batt_status_code)"
  case "$sc" in
    2|5) echo "charging" ;;
    3|4) echo "not_charging" ;;
    *)   echo "unknown" ;;
  esac
}

get_rndis_state_simple() {
  usb_state="$(getprop_safe sys.usb.state)"
  usb_cfg="$(getprop_safe sys.usb.config)"
  echo "$usb_state $usb_cfg" | grep -qi 'rndis' && echo "on" || echo "off"
}

# ✅ FIX: Check Hotspot theo iface SoftAP + ip link state UP (đúng theo lệnh bạn test)
get_hotspot_state_simple() {
  iface="$(dumpsys wifi 2>/dev/null | sed -n 's/.*SoftApManager{id=[^}]* iface=\([^ ]*\) .*/\1/p' | head -n1)"
  if [ -n "$iface" ] && ip link show "$iface" 2>/dev/null | grep -q "state UP"; then
    echo "on"
  else
    echo "off"
  fi
}

handle_monitor_changes() {
  # Baseline (không spam lúc start)
  last_charge="$(get_charge_state_simple)"
  last_rndis="$(get_rndis_state_simple)"
  last_hotspot="$(get_hotspot_state_simple)"

  while true; do
    cur_charge="$(get_charge_state_simple)"
    cur_rndis="$(get_rndis_state_simple)"
    cur_hotspot="$(get_hotspot_state_simple)"

    if [ "$cur_charge" != "$last_charge" ]; then
      case "$cur_charge" in
        charging)     send_code "⚡ Pin: <b>BẮT ĐẦU SẠC</b> (level: $(get_batt_level)%)" ;;
        not_charging) send_code "🔋 Pin: <b>NGỪNG SẠC</b> (level: $(get_batt_level)%)" ;;
        *)            send_code "🔋 Pin: <b>TRẠNG THÁI KHÔNG RÕ</b>" ;;
      esac
      last_charge="$cur_charge"
    fi

    if [ "$cur_rndis" != "$last_rndis" ]; then
      if [ "$cur_rndis" = "on" ]; then
        send_code "🔌 RNDIS: <b>ĐÃ BẬT</b>"
      else
        send_code "🔌 RNDIS: <b>ĐÃ TẮT</b>"
      fi
      last_rndis="$cur_rndis"
    fi

    if [ "$cur_hotspot" != "$last_hotspot" ]; then
      if [ "$cur_hotspot" = "on" ]; then
        send_code "📡 Hotspot: <b>ĐÃ BẬT</b>"
      elif [ "$cur_hotspot" = "off" ]; then
        send_code "📡 Hotspot: <b>ĐÃ TẮT</b>"
      else
        send_code "📡 Hotspot: <b>KHÔNG RÕ</b>"
      fi
      last_hotspot="$cur_hotspot"
    fi

    sleep 5
  done
}

########################
# RNDIS (bật/tắt theo lệnh)
########################

handle_rndis_on() {
  send_code "🔌 Bật RNDIS (USB tether)..."
  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions rndis,adb 2>/dev/null || svc usb setFunctions rndis 2>/dev/null || true
  fi
  setprop sys.usb.config rndis,adb 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

handle_rndis_off() {
  send_code "🔌 Tắt RNDIS (USB tether)..."
  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions mtp,adb 2>/dev/null || svc usb setFunctions mtp 2>/dev/null || true
  fi
  setprop sys.usb.config mtp,adb 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

########################
# ... (các phần còn lại của script của bạn giữ nguyên)
# Vì đoạn bạn gửi quá dài, mình không thay đổi gì ngoài get_hotspot_state_simple().
########################


########################
# SÓNG (đã fix nhận diện 5G/NSA) + BAND
########################

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

map_sig_quality() {
  val="$1"
  if echo "$val" | grep -qE '^-?[0-9]+'; then
    n=$(printf "%d" "$val" 2>/dev/null || echo "")
    if [ -n "$n" ]; then
      if   [ "$n" -ge -85 ]; then echo "Rất tốt"
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

# Vẫn giữ hàm get_signal_bars nếu sau này muốn dùng, nhưng hiện tại không in ra nữa
get_signal_bars() {
  dbm="$1"
  ql="$(map_sig_quality "$dbm")"
  if   [ "$ql" = "Rất tốt" ]; then echo "📶📶📶 (${ql})"
  elif [ "$ql" = "Trung bình" ]; then echo "📶📶 (${ql})"
  elif [ "$ql" = "Kém" ]; then echo "📶 (${ql})"
  else echo "N/A"
  fi
}

# Phát hiện 5G đã kết nối (ưu tiên NSA)
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

# Thêm mô tả cho loại mạng
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

# Lấy tên nhà mạng
get_operator_name() {
  # Ưu tiên tên nhà mạng đang đăng ký mạng
  op="$(getprop_safe gsm.operator.alpha)"
  if [ -n "$op" ] && [ "$op" != "null" ]; then
    echo "$op"
    return
  fi

  # Thử từ SIM
  op="$(getprop_safe gsm.sim.operator.alpha)"
  if [ -n "$op" ] && [ "$op" != "null" ]; then
    echo "$op"
    return
  fi

  # Fallback: từ dumpsys
  out="$(dumpsys telephony.registry 2>/dev/null || dumpsys telephony 2>/dev/null || true)"
  op="$(echo "$out" \
    | grep -oE 'operatorAlpha(Long|Short)=[^,]+' \
    | head -n1 \
    | sed 's/.*=//')"

  if [ -n "$op" ]; then
    echo "$op"
  else
    echo "Không rõ"
  fi
}

# Cố gắng lấy band NR/LTE bằng nhiều mẫu hơn
get_band_info() {
  out="$(dumpsys telephony 2>/dev/null || true; dumpsys telephony.registry 2>/dev/null || true)"

  # NR band
  nr_band="$(
    echo "$out" | grep -oiE 'nr[Bb]and[: =][nN]?[0-9]+' | head -n1 | sed -E 's/.*[=: ]//; s/^n?([0-9]+)$/n\1/'
  )"
  if [ -n "$nr_band" ]; then
    echo "NR band ${nr_band}"
    return
  fi

  # PhysicalChannelConfig có 'band' (có thể là NR)
  pcc_nr_band="$(
    echo "$out" | tr '\n' ' ' | sed -n 's/.*PhysicalChannelConfig{/&\n/p' | head -n1 | grep -oiE 'band[:= ][nN]?[0-9]+' | head -n1 | sed -E 's/.*[ =]//; s/^n?([0-9]+)$/n\1/'
  )"
  if [ -n "$pcc_nr_band" ]; then
    echo "NR band ${pcc_nr_band}"
    return
  fi

  # LTE band
  lte_band="$(
    echo "$out" | grep -oiE '(lte[Bb]and|mLteBand|bandLTE|eutranBand)[: =][0-9]+' | head -n1 | grep -oE '[0-9]+'
  )"
  if [ -n "$lte_band" ]; then
    echo "LTE band ${lte_band}"
    return
  fi

  # PhysicalChannelConfig (LTE)
  pcc_lte_band="$(
    echo "$out" | tr '\n' ' ' | sed -n 's/.*PhysicalChannelConfig{/&\n/p' | head -n1 | grep -oiE 'band[:= ][0-9]+' | head -n1 | grep -oE '[0-9]+'
  )"
  if [ -n "$pcc_lte_band" ]; then
    echo "LTE band ${pcc_lte_band}"
    return
  fi

  # Không tìm được thì trả rỗng để khỏi in "Band : N/A"
  echo ""
}

########################
# IP: nội bộ + public (đẹp hơn)
########################

get_public_ip() {
  for url in "https://api.ipify.org" "https://ifconfig.me" "https://ipinfo.io/ip"; do
    ip="$(curl -s --max-time 5 "$url" 2>/dev/null | tr -d '\n\r ')"
    echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|^[0-9a-fA-F:]+$' && { echo "$ip"; return; }
  done
  echo ""
}

########################
# HÀM XỬ LÝ LỆNH
########################

handle_help() {
  msg="$(cat <<'EOF'
<b>Lệnh hỗ trợ:</b>

/help                 - Hiển thị danh sách lệnh
/status             - Hiển thị thông tin cơ bản của thiết bị
/signal              - Sóng: loại mạng, băng tần, tín hiệu
/ip                      - Hiển thị toàn bộ IP + Public IP
/battery           - Thông tin pin hiện tại
/datausage     - Dung lượng data đã dùng

/rndis_on        - Bật RNDIS (USB tether)
/rndis_off        - Tắt RNDIS (USB tether)
/hotspot_on  - Bật Hotspot (Phát wifi)
/hotspot_off  - Tắt Hotspot (Phát wifi)

/shutdown     - Tắt máy
/restart            - Khởi động lại
<i>Không được spam /shutdown và /restart vì sẽ gây tình trạng tắt và khởi động liên tục do tồn tại yêu cầu chưa được thực hiện.</i>
EOF
)"
  send_code "$msg"
}


handle_shutdown() {
  send_code "🛑 Đang tắt máy..."

  # Lấy dump netstats
  NETS=$(dumpsys netstats 2>/dev/null)

  # Hàm chuyển bytes -> MB (2 chữ số thập phân)
  hr_mb() {
    bytes="$1"
    [ -z "$bytes" ] && bytes=0
    awk -v b="$bytes" 'BEGIN{printf "%.2f MB", b/1024/1024}'
  }

  DEBUG=${DEBUG:-0}

  # Nếu dumpsys rỗng, fallback sang /proc/net/dev (realtime counters)
  if [ -z "$NETS" ]; then
    if [ -r /proc/net/dev ]; then
      totals=$(awk -v dbg="$DEBUG" '
        NR>2 {
          line=$0
          sub(/^[ \t]+/, "", line)
          split(line, parts, ":")
          iface=parts[1]
          split(parts[2], a)
          rx = (a[1] + 0)
          tx = (a[9] + 0)

          if(iface=="wlan0"){ w_rx+=rx; w_tx+=tx; next }
          if(iface ~ /^rmnet/ || iface ~ /^ccmni/ || iface ~ /^rmnet_data/){ m_rx+=rx; m_tx+=tx; next }

          # RNDIS explicit
          if(iface ~ /^rndis/){
            r_rx+=rx; r_tx+=tx
            if(dbg==1) printf("DEBUG_RNDIS %s %d %d\n", iface, rx, tx) > "/dev/stderr"
            next
          }

          # Hotspot candidates
          if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
            h_rx+=rx; h_tx+=tx
            if(dbg==1) printf("DEBUG_HOTSPOT %s %d %d\n", iface, rx, tx) > "/dev/stderr"
            next
          }
        }
        END{
          if(w_rx=="") w_rx=0; if(w_tx=="") w_tx=0;
          if(m_rx=="") m_rx=0; if(m_tx=="") m_tx=0;
          if(r_rx=="") r_rx=0; if(r_tx=="") r_tx=0;
          if(h_rx=="") h_rx=0; if(h_tx=="") h_tx=0;
          printf "%d %d %d %d %d %d %d %d\n", w_rx, w_tx, m_rx, m_tx, r_rx, r_tx, h_rx, h_tx
        }
      ' /proc/net/dev)
    else
      send_code "⚠️ Không lấy được dumpsys netstats và /proc/net/dev không đọc được. Tiến hành tắt."
      if command -v svc >/dev/null 2>&1; then
        svc power shutdown 2>/dev/null || reboot -p
      else
        reboot -p
      fi
      return 1
    fi
  else
    # Parse mIfaceStatsMap từ dumpsys netstats (1 awk, tránh subshell issues)
    totals=$(printf '%s\n' "$NETS" | awk -v dbg="$DEBUG" '
      /mIfaceStatsMap:/{in=1; next}
      /mStatsMapB:/{in=0}
      in && NF>=6 {
        iface=$2; rx=$3; tx=$5
        if(iface=="wlan0"){w_rx+=rx; w_tx+=tx; next}
        else if(iface ~ /^rmnet/ || iface ~ /^ccmni/ || iface ~ /^rmnet_data/){m_rx+=rx; m_tx+=tx; next}
        else if(iface ~ /^rndis/){r_rx+=rx; r_tx+=tx; if(dbg==1) printf("DEBUG_RNDIS %s %d %d\n", iface, rx, tx) > "/dev/stderr"; next}
        else if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){h_rx+=rx; h_tx+=tx; if(dbg==1) printf("DEBUG_HOTSPOT %s %d %d\n", iface, rx, tx) > "/dev/stderr"; next}
      }
      END{
        if(w_rx=="") w_rx=0; if(w_tx=="") w_tx=0;
        if(m_rx=="") m_rx=0; if(m_tx=="") m_tx=0;
        if(r_rx=="") r_rx=0; if(r_tx=="") r_tx=0;
        if(h_rx=="") h_rx=0; if(h_tx=="") h_tx=0;
        printf "%d %d %d %d %d %d %d %d\n", w_rx, w_tx, m_rx, m_tx, r_rx, r_tx, h_rx, h_tx
      }
    ')
  fi

  # Nếu totals rỗng (rất hiếm), fallback đọc sysfs cho các interface phổ biến
  if [ -z "$totals" ]; then
    W_RX=$(cat /sys/class/net/wlan0/statistics/rx_bytes 2>/dev/null || echo 0)
    W_TX=$(cat /sys/class/net/wlan0/statistics/tx_bytes 2>/dev/null || echo 0)

    M_RX=0; M_TX=0
    for ifn in rmnet0 rmnet_data0 ccmni0; do
      if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
        M_RX=$((M_RX + $(cat /sys/class/net/$ifn/statistics/rx_bytes)))
        M_TX=$((M_TX + $(cat /sys/class/net/$ifn/statistics/tx_bytes)))
      fi
    done

    R_RX=0; R_TX=0
    for ifn in rndis0 rndis1; do
      if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
        R_RX=$((R_RX + $(cat /sys/class/net/$ifn/statistics/rx_bytes)))
        R_TX=$((R_TX + $(cat /sys/class/net/$ifn/statistics/tx_bytes)))
      fi
    done

    HS_RX=0; HS_TX=0
    for ifn in p2p0 wlan1 ap0 br0 usb0; do
      if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
        HS_RX=$((HS_RX + $(cat /sys/class/net/$ifn/statistics/rx_bytes)))
        HS_TX=$((HS_TX + $(cat /sys/class/net/$ifn/statistics/tx_bytes)))
      fi
    done
  else
    set -- $totals
    W_RX=${1:-0}; W_TX=${2:-0}
    M_RX=${3:-0}; M_TX=${4:-0}
    R_RX=${5:-0}; R_TX=${6:-0}
    HS_RX=${7:-0}; HS_TX=${8:-0}
  fi

  # Ensure numeric defaults
  W_RX=${W_RX:-0}; W_TX=${W_TX:-0}
  M_RX=${M_RX:-0}; M_TX=${M_TX:-0}
  R_RX=${R_RX:-0}; R_TX=${R_TX:-0}
  HS_RX=${HS_RX:-0}; HS_TX=${HS_TX:-0}

  # Chuyển sang MB
  W_RX_H=$(hr_mb "$W_RX"); W_TX_H=$(hr_mb "$W_TX")
  M_RX_H=$(hr_mb "$M_RX"); M_TX_H=$(hr_mb "$M_TX")
  R_RX_H=$(hr_mb "$R_RX"); R_TX_H=$(hr_mb "$R_TX")
  HS_RX_H=$(hr_mb "$HS_RX"); HS_TX_H=$(hr_mb "$HS_TX")

  # Tạo thông điệp tóm tắt (HTML)
  SUMMARY="📊 <b>Tổng lưu lượng trước tắt máy:</b>\n\n"
  SUMMARY="${SUMMARY}🔵 <b>Wi‑Fi (wlan0):</b> <code>RX ${W_RX_H} | TX ${W_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📶 <b>Mobile (rmnet*):</b> <code>RX ${M_RX_H} | TX ${M_TX_H}</code>\n"
  SUMMARY="${SUMMARY}🔌 <b>RNDIS (rndis*):</b> <code>RX ${R_RX_H} | TX ${R_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📡 <b>Hotspot (p2p0/wlan1/ap0/br0/usb*):</b> <code>RX ${HS_RX_H} | TX ${HS_TX_H}</code>\n"

  # Nếu DEBUG=1, thêm phần debug
  if [ "${DEBUG:-0}" = "1" ]; then
    debug_list=$(awk '
      NR>2 {
        line=$0; sub(/^[ \t]+/, "", line)
        split(line, parts, ":"); iface=parts[1]; split(parts[2], a)
        rx=a[1]+0; tx=a[9]+0
        if(iface ~ /^rndis/){ printf("RNDIS %s: RX=%d TX=%d\n", iface, rx, tx) }
        if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
          printf("HOTSPOT %s: RX=%d TX=%d\n", iface, rx, tx)
        }
      }
    ' /proc/net/dev)
    SUMMARY="${SUMMARY}\n<code>DEBUG interfaces:\n${debug_list}</code>"
  fi

  # Gửi/hiện thông điệp
  send_code "$SUMMARY"

  # Đợi ngắn để đảm bảo send_code kịp xử lý
  sleep 1

  # Thực hiện tắt máy
  if command -v svc >/dev/null 2>&1; then
    svc power shutdown 2>/dev/null || reboot -p
  else
    reboot -p
  fi

  return 0
}




handle_restart() {
  send_code "🔁 Đang khởi động lại..."

  # Lấy dump netstats
  NETS=$(dumpsys netstats 2>/dev/null)

  # Hàm chuyển bytes -> MB (2 chữ số thập phân)
  hr_mb() {
    bytes="$1"
    [ -z "$bytes" ] && bytes=0
    awk -v b="$bytes" 'BEGIN{printf "%.2f MB", b/1024/1024}'
  }

  DEBUG=${DEBUG:-0}

  # Nếu dumpsys rỗng, fallback sang /proc/net/dev (realtime counters)
  if [ -z "$NETS" ]; then
    if [ -r /proc/net/dev ]; then
      totals=$(awk -v dbg="$DEBUG" '
        NR>2 {
          line=$0
          sub(/^[ \t]+/, "", line)
          split(line, parts, ":")
          iface=parts[1]
          split(parts[2], a)
          rx = (a[1] + 0)
          tx = (a[9] + 0)

          if(iface=="wlan0"){ w_rx+=rx; w_tx+=tx; next }
          if(iface ~ /^rmnet/ || iface ~ /^ccmni/ || iface ~ /^rmnet_data/){ m_rx+=rx; m_tx+=tx; next }

          # RNDIS explicit
          if(iface ~ /^rndis/){
            r_rx+=rx; r_tx+=tx
            if(dbg==1) printf("DEBUG_RNDIS %s %d %d\n", iface, rx, tx) > "/dev/stderr"
            next
          }

          # Hotspot candidates
          if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
            h_rx+=rx; h_tx+=tx
            if(dbg==1) printf("DEBUG_HOTSPOT %s %d %d\n", iface, rx, tx) > "/dev/stderr"
            next
          }
        }
        END{
          if(w_rx=="") w_rx=0; if(w_tx=="") w_tx=0;
          if(m_rx=="") m_rx=0; if(m_tx=="") m_tx=0;
          if(r_rx=="") r_rx=0; if(r_tx=="") r_tx=0;
          if(h_rx=="") h_rx=0; if(h_tx=="") h_tx=0;
          printf "%d %d %d %d %d %d %d %d\n", w_rx, w_tx, m_rx, m_tx, r_rx, r_tx, h_rx, h_tx
        }
      ' /proc/net/dev)
    else
      send_code "⚠️ Không lấy được dumpsys netstats và /proc/net/dev không đọc được. Tiến hành khởi động lại."
      if command -v svc >/dev/null 2>&1; then
        svc power reboot 2>/dev/null || reboot
      else
        reboot
      fi
      return 1
    fi
  else
    # Parse mIfaceStatsMap từ dumpsys netstats (1 awk, tránh subshell issues)
    totals=$(printf '%s\n' "$NETS" | awk -v dbg="$DEBUG" '
      /mIfaceStatsMap:/{in=1; next}
      /mStatsMapB:/{in=0}
      in && NF>=6 {
        iface=$2; rx=$3; tx=$5
        if(iface=="wlan0"){w_rx+=rx; w_tx+=tx; next}
        else if(iface ~ /^rmnet/ || iface ~ /^ccmni/ || iface ~ /^rmnet_data/){m_rx+=rx; m_tx+=tx; next}
        else if(iface ~ /^rndis/){r_rx+=rx; r_tx+=tx; if(dbg==1) printf("DEBUG_RNDIS %s %d %d\n", iface, rx, tx) > "/dev/stderr"; next}
        else if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){h_rx+=rx; h_tx+=tx; if(dbg==1) printf("DEBUG_HOTSPOT %s %d %d\n", iface, rx, tx) > "/dev/stderr"; next}
      }
      END{
        if(w_rx=="") w_rx=0; if(w_tx=="") w_tx=0;
        if(m_rx=="") m_rx=0; if(m_tx=="") m_tx=0;
        if(r_rx=="") r_rx=0; if(r_tx=="") r_tx=0;
        if(h_rx=="") h_rx=0; if(h_tx=="") h_tx=0;
        printf "%d %d %d %d %d %d %d %d\n", w_rx, w_tx, m_rx, m_tx, r_rx, r_tx, h_rx, h_tx
      }
    ')
  fi

  # Nếu totals rỗng (rất hiếm), fallback đọc sysfs cho các interface phổ biến
  if [ -z "$totals" ]; then
    W_RX=$(cat /sys/class/net/wlan0/statistics/rx_bytes 2>/dev/null || echo 0)
    W_TX=$(cat /sys/class/net/wlan0/statistics/tx_bytes 2>/dev/null || echo 0)

    M_RX=0; M_TX=0
    for ifn in rmnet0 rmnet_data0 ccmni0; do
      if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
        M_RX=$((M_RX + $(cat /sys/class/net/$ifn/statistics/rx_bytes)))
        M_TX=$((M_TX + $(cat /sys/class/net/$ifn/statistics/tx_bytes)))
      fi
    done

    R_RX=0; R_TX=0
    for ifn in rndis0 rndis1; do
      if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
        R_RX=$((R_RX + $(cat /sys/class/net/$ifn/statistics/rx_bytes)))
        R_TX=$((R_TX + $(cat /sys/class/net/$ifn/statistics/tx_bytes)))
      fi
    done

    HS_RX=0; HS_TX=0
    for ifn in p2p0 wlan1 ap0 br0 usb0; do
      if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
        HS_RX=$((HS_RX + $(cat /sys/class/net/$ifn/statistics/rx_bytes)))
        HS_TX=$((HS_TX + $(cat /sys/class/net/$ifn/statistics/tx_bytes)))
      fi
    done
  else
    set -- $totals
    W_RX=${1:-0}; W_TX=${2:-0}
    M_RX=${3:-0}; M_TX=${4:-0}
    R_RX=${5:-0}; R_TX=${6:-0}
    HS_RX=${7:-0}; HS_TX=${8:-0}
  fi

  # Ensure numeric defaults
  W_RX=${W_RX:-0}; W_TX=${W_TX:-0}
  M_RX=${M_RX:-0}; M_TX=${M_TX:-0}
  R_RX=${R_RX:-0}; R_TX=${R_TX:-0}
  HS_RX=${HS_RX:-0}; HS_TX=${HS_TX:-0}

  # Chuyển sang MB
  W_RX_H=$(hr_mb "$W_RX"); W_TX_H=$(hr_mb "$W_TX")
  M_RX_H=$(hr_mb "$M_RX"); M_TX_H=$(hr_mb "$M_TX")
  R_RX_H=$(hr_mb "$R_RX"); R_TX_H=$(hr_mb "$R_TX")
  HS_RX_H=$(hr_mb "$HS_RX"); HS_TX_H=$(hr_mb "$HS_TX")

  # Tạo thông điệp tóm tắt (HTML)
  SUMMARY="📊 <b>Tổng lưu lượng trước khởi động lại:</b>\n\n"
  SUMMARY="${SUMMARY}🔵 <b>Wi‑Fi (wlan0):</b> <code>RX ${W_RX_H} | TX ${W_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📶 <b>Mobile (rmnet*):</b> <code>RX ${M_RX_H} | TX ${M_TX_H}</code>\n"
  SUMMARY="${SUMMARY}🔌 <b>RNDIS (rndis*):</b> <code>RX ${R_RX_H} | TX ${R_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📡 <b>Hotspot (p2p0/wlan1/ap0/br0/usb*):</b> <code>RX ${HS_RX_H} | TX ${HS_TX_H}</code>\n"

  # Nếu DEBUG=1, thêm phần debug
  if [ "${DEBUG:-0}" = "1" ]; then
    debug_list=$(awk '
      NR>2 {
        line=$0; sub(/^[ \t]+/, "", line)
        split(line, parts, ":"); iface=parts[1]; split(parts[2], a)
        rx=a[1]+0; tx=a[9]+0
        if(iface ~ /^rndis/){ printf("RNDIS %s: RX=%d TX=%d\n", iface, rx, tx) }
        if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
          printf("HOTSPOT %s: RX=%d TX=%d\n", iface, rx, tx)
        }
      }
    ' /proc/net/dev)
    SUMMARY="${SUMMARY}\n<code>DEBUG interfaces:\n${debug_list}</code>"
  fi

  send_code "$SUMMARY"

  # Đợi ngắn để đảm bảo send_code xử lý xong
  sleep 1

  # Thực hiện khởi động lại
  if command -v svc >/dev/null 2>&1; then
    svc power reboot 2>/dev/null || reboot
  else
    reboot
  fi

  return 0
}



handle_status() {
  if [ -f "${SCRIPT_DIR}/status.sh" ]; then
    ( sh "${SCRIPT_DIR}/status.sh" >/dev/null 2>&1 & )
    send_code "✅ Đang thu thập thông tin"
  else
    send_code "❌ Không tìm thấy status.sh trong ${SCRIPT_DIR}"
  fi
}

handle_status_on_boot() {

  if [ -f "${SCRIPT_DIR}/status.sh" ]; then
    # Chạy status.sh ở chế độ nền (background)
    ( sh "${SCRIPT_DIR}/status.sh" >/dev/null 2>&1 & )
    
    # Gửi thông báo khởi động thành công
    send_code "✅ Hệ thống khởi động thành công. Đang thu thập thông tin hệ thống"
  else
    # Gửi thông báo lỗi nếu status.sh không tồn tại
    send_code "❌ Không tìm thấy status.sh trong ${SCRIPT_DIR}"
  fi
}

handle_signal() {
  dbm="$(get_dbm)"
  nettypedesc="$(get_nettype_with_desc)"
  bandinfo="$(get_band_info)"
  quality="$(map_sig_quality "$dbm")"
  operator="$(get_operator_name)"

  msg="📶 Thông tin sóng:\n\n"
  msg="${msg}• Nhà mạng  : ${operator}\n"
  msg="${msg}• Network   : ${nettypedesc}\n"

  # Chỉ in Band nếu lấy được
  if [ -n "$bandinfo" ]; then
    msg="${msg}• Band      : ${bandinfo}\n"
  fi

  msg="${msg}• Tín hiệu  : ${dbm} dBm\n"
  msg="${msg}• Chất lượng: ${quality}"

  send_code "$msg"
}

handle_ip() {
  # Nếu có lệnh ip: format đẹp, tách IPv4 / IPv6
  if command -v ip >/dev/null 2>&1; then
    ipv4="$(
      ip -o -4 addr show 2>/dev/null \
        | awk '!/127\.0\.0\.1/ {print "- " $2 ": " $4}'
    )"

    ipv6="$(
      ip -o -6 addr show 2>/dev/null \
        | awk '!/ ::1\/128/ && !/ scope host / {print "- " $2 ": " $4}'
    )"

    if [ -z "$ipv4$ipv6" ]; then
      local_ips="(Không lấy được IP nội bộ)"
    else
      local_ips="IP nội bộ:"
      [ -n "$ipv4" ] && local_ips="$local_ips\n[IPv4]\n$ipv4"
      [ -n "$ipv6" ] && local_ips="$local_ips\n[IPv6]\n$ipv6"
    fi

  else
    # Fallback: ifconfig
    out="$(ifconfig 2>/dev/null)"
    [ -z "$out" ] && out="Không lấy được IP nội bộ"
    local_ips="$out"
  fi

  # Lấy Public IP
  pub="$(get_public_ip)"
  if [ -n "$pub" ]; then
    out="${local_ips}

Public IP: ${pub}"
  else
    out="${local_ips}

Public IP: (không lấy được)"
  fi

  send_code "$out"
}

handle_battery() {
  info="$(get_batt_info_text)"
  send_code "$info"
}


# handle_datausage: tổng hợp realtime từ /proc/net/dev, tách RNDIS và Hotspot riêng
# DEBUG=1 để bật debug (liệt kê interface được tính)
# Ghi chú: send_code nên gửi với parse_mode=HTML để <b> và <code> hiển thị đúng
handle_datausage() {
  send_code "📡 Đang tổng hợp số liệu mạng (realtime)..."

  if [ ! -r /proc/net/dev ]; then
    send_code "⚠️ Không thể đọc /proc/net/dev (quyền hoặc file không tồn tại)."
    return 1
  fi

  hr_mb() {
    bytes="$1"
    [ -z "$bytes" ] && bytes=0
    awk -v b="$bytes" 'BEGIN{printf "%.2f MB", b/1024/1024}'
  }

  DEBUG=${DEBUG:-0}

  # Tính totals: w_rx w_tx m_rx m_tx r_rx r_tx h_rx h_tx
  totals=$(awk -v dbg="$DEBUG" '
    NR>2 {
      line=$0
      sub(/^[ \t]+/, "", line)
      split(line, parts, ":")
      iface=parts[1]
      # fields after colon: a[1]=rx_bytes ... a[9]=tx_bytes
      split(parts[2], a)
      rx = (a[1] + 0)
      tx = (a[9] + 0)

      # wifi
      if(iface=="wlan0"){ w_rx+=rx; w_tx+=tx; next }

      # mobile candidates
      if(iface ~ /^rmnet/ || iface ~ /^ccmni/ || iface ~ /^rmnet_data/){ m_rx+=rx; m_tx+=tx; next }

      # RNDIS explicit
      if(iface ~ /^rndis/){
        r_rx+=rx; r_tx+=tx
        if(dbg==1) printf("DEBUG_RNDIS %s %d %d\n", iface, rx, tx) > "/dev/stderr"
        next
      }

      # Hotspot candidates
      if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
        h_rx+=rx; h_tx+=tx
        if(dbg==1) printf("DEBUG_HOTSPOT %s %d %d\n", iface, rx, tx) > "/dev/stderr"
        next
      }
    }
    END{
      if(w_rx=="") w_rx=0; if(w_tx=="") w_tx=0;
      if(m_rx=="") m_rx=0; if(m_tx=="") m_tx=0;
      if(r_rx=="") r_rx=0; if(r_tx=="") r_tx=0;
      if(h_rx=="") h_rx=0; if(h_tx=="") h_tx=0;
      printf "%d %d %d %d %d %d %d %d\n", w_rx, w_tx, m_rx, m_tx, r_rx, r_tx, h_rx, h_tx
    }
  ' /proc/net/dev 2>/dev/null)

  # Nếu awk không trả totals (rất hiếm), fallback đọc sysfs
  if [ -z "$totals" ]; then
    W_RX=$(cat /sys/class/net/wlan0/statistics/rx_bytes 2>/dev/null || echo 0)
    W_TX=$(cat /sys/class/net/wlan0/statistics/tx_bytes 2>/dev/null || echo 0)

    M_RX=0; M_TX=0
    for ifn in rmnet0 rmnet_data0 ccmni0; do
      if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
        M_RX=$((M_RX + $(cat /sys/class/net/$ifn/statistics/rx_bytes)))
        M_TX=$((M_TX + $(cat /sys/class/net/$ifn/statistics/tx_bytes)))
      fi
    done

    R_RX=0; R_TX=0
    for ifn in rndis0 rndis1; do
      if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
        R_RX=$((R_RX + $(cat /sys/class/net/$ifn/statistics/rx_bytes)))
        R_TX=$((R_TX + $(cat /sys/class/net/$ifn/statistics/tx_bytes)))
      fi
    done

    HS_RX=0; HS_TX=0
    for ifn in p2p0 wlan1 ap0 br0 usb0; do
      if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
        HS_RX=$((HS_RX + $(cat /sys/class/net/$ifn/statistics/rx_bytes)))
        HS_TX=$((HS_TX + $(cat /sys/class/net/$ifn/statistics/tx_bytes)))
      fi
    done
  else
    set -- $totals
    W_RX=${1:-0}; W_TX=${2:-0}
    M_RX=${3:-0}; M_TX=${4:-0}
    R_RX=${5:-0}; R_TX=${6:-0}
    HS_RX=${7:-0}; HS_TX=${8:-0}
  fi

  # đảm bảo numeric
  W_RX=${W_RX:-0}; W_TX=${W_TX:-0}
  M_RX=${M_RX:-0}; M_TX=${M_TX:-0}
  R_RX=${R_RX:-0}; R_TX=${R_TX:-0}
  HS_RX=${HS_RX:-0}; HS_TX=${HS_TX:-0}

  # human readable
  W_RX_H=$(hr_mb "$W_RX"); W_TX_H=$(hr_mb "$W_TX")
  M_RX_H=$(hr_mb "$M_RX"); M_TX_H=$(hr_mb "$M_TX")
  R_RX_H=$(hr_mb "$R_RX"); R_TX_H=$(hr_mb "$R_TX")
  HS_RX_H=$(hr_mb "$HS_RX"); HS_TX_H=$(hr_mb "$HS_TX")

  # build summary (HTML)
  SUMMARY="<b>📊 Báo cáo lưu lượng realtime:</b>\n\n"
  SUMMARY="${SUMMARY}🔵 <b>Wi‑Fi (wlan0):</b> <code>RX ${W_RX_H} | TX ${W_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📶 <b>Mobile (rmnet*):</b> <code>RX ${M_RX_H} | TX ${M_TX_H}</code>\n"
  SUMMARY="${SUMMARY}🔌 <b>RNDIS (rndis*):</b> <code>RX ${R_RX_H} | TX ${R_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📡 <b>Hotspot (p2p0/wlan1/ap0/br0/usb*):</b> <code>RX ${HS_RX_H} | TX ${HS_TX_H}</code>\n"

  # debug list (nếu bật)
  if [ "${DEBUG:-0}" = "1" ]; then
    debug_list=$(awk '
      NR>2 {
        line=$0; sub(/^[ \t]+/, "", line)
        split(line, parts, ":"); iface=parts[1]; split(parts[2], a)
        rx=a[1]+0; tx=a[9]+0
        if(iface ~ /^rndis/){ printf("RNDIS %s: RX=%d TX=%d\n", iface, rx, tx) }
        if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
          printf("HOTSPOT %s: RX=%d TX=%d\n", iface, rx, tx)
        }
      }
    ' /proc/net/dev)
    SUMMARY="${SUMMARY}\n<code>DEBUG interfaces:\n${debug_list}</code>"
  fi

  send_code "$SUMMARY"
  return 0
}





handle_hotspot_on() {
  send_code "📡 Bật hotspot..."
  if cmd wifi start-softap "Zakshin" wpa2 "zakshin@123" >/dev/null 2>&1; then
  /system/bin/ifconfig swlan0 192.168.173.1/24 up
    send_code "✅ Đã bật hotspot"
  else
    send_code "❌ Không bật được hotspot (ROM/permission có thể hạn chế)"
  fi
}

handle_hotspot_off() {
  send_code "📡 Tắt hotspot..."
  if cmd wifi stop-softap >/dev/null 2>&1; then
    send_code "✅ Đã tắt hotspot"
  else
    send_code "❌ Không tắt được hotspot (ROM/permission có thể hạn chế)"
  fi
}

########################
# KHỞI ĐỘNG & VÒNG LẶP CHÍNH
########################

# Khởi tạo OFFSET từ file (chống ăn lại lệnh cũ sau reboot)
if [ -f "$BOT_OFFSET_FILE" ]; then
  OFFSET="$(cat "$BOT_OFFSET_FILE" 2>/dev/null || echo 0)"
else
  OFFSET=0
fi

# Gửi log khởi động (nếu đã biết chat_id)
if [ -n "$TELEGRAM_CHAT_ID" ]; then
  send_code "🤖 Telegram Device Bot đã khởi động. Gõ /help để xem lệnh."
fi

# CHẠY THEO DÕI THAY ĐỔI LIÊN TỤC (mỗi 5s)
(handle_monitor_changes >/dev/null 2>&1 &) 

# TỰ CHẠY /status 1 lần mỗi lần KHỞI ĐỘNG — chờ có mạng
(
  for i in $(seq 1 120); do   # chờ tối đa ~10 phút
    if has_network; then
      handle_status_on_boot
      exit 0
    fi
    sleep 5
  done
) &

while true; do
  [ -z "$TELEGRAM_TOKEN" ] && { echo "⚠️ Thiếu TELEGRAM_TOKEN, thoát."; exit 1; }

  RESP="$(curl -s "${BOT_API}/getUpdates?timeout=25&offset=${OFFSET}")"
  LAST_UPDATE_ID="$(echo "$RESP" | grep -o '"update_id":[0-9]*' | awk -F: '{print $2}' | sort -n | tail -n1)"

  if [ -n "$LAST_UPDATE_ID" ]; then
    OFFSET=$((LAST_UPDATE_ID + 1))
    echo "$OFFSET" > "$BOT_OFFSET_FILE"

    TEXT="$(echo "$RESP" | grep -o '"text":"[^"]*"' | sed 's/^"text":"//;s/"$//' | tail -n1)"
    CID="$(echo "$RESP" | grep -o '"chat":{"id":[-0-9]*' | sed 's/.*"id"://' | tail -n1)"
    if [ -n "$CID" ]; then
      TELEGRAM_CHAT_ID="$CID"
    fi

    case "$TEXT" in
      "/help")        handle_help ;;
      "/start")       handle_help ;;
      "/shutdown")    handle_shutdown ;;
      "/restart")     handle_restart ;;
      "/status")      handle_status ;;
      "/signal")      handle_signal ;;
      "/ip")          handle_ip ;;
      "/battery")     handle_battery ;;
	  "/datausage")   handle_datausage ;;
      "/rndis_on")    handle_rndis_on ;;
      "/rndis_off")   handle_rndis_off ;;
      "/hotspot_on")  handle_hotspot_on ;;
      "/hotspot_off") handle_hotspot_off ;;
      ""|*[![:print:]]*)
        ;;
      *)
        send_code "❌ Lệnh không hợp lệ: ${TEXT}\nGõ /help để xem danh sách lệnh."
        ;;
    esac
  fi

  [ -z "$RESP" ] && sleep 5
done
