#!/system/bin/sh
# Snapshot hệ thống — gửi Telegram khi có config + curl

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "${SCRIPT_DIR}/config.sh" ]; then
  # shellcheck source=/dev/null
  . "${SCRIPT_DIR}/config.sh"
fi

# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/battery.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/telephony.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/device_info.sh"

OPERATOR="$(get_operator_name)"
NETTYPE="$(get_nettype_with_desc)"
DBM="$(get_dbm)"

sigqual="$(map_sig_quality "$DBM")"
if [ "$sigqual" = "Rất tốt" ]; then
  BARS="📶📶📶📶"
elif [ "$sigqual" = "Trung bình" ]; then
  BARS="📶📶📶"
elif [ "$sigqual" = "Xấu" ]; then
  BARS="📶"
else
  BARS="—"
fi

if echo "$DBM" | grep -qE '^-?[0-9]+'; then
  SIG_TEXT="${DBM} dBm · ${BARS} (${sigqual})"
else
  SIG_TEXT="${DBM}"
fi

BATT_LEVEL="$(get_batt_level)"
BATT_STATUS="$(get_batt_status_label)"
BATT_TEMP="$(get_batt_temp_c)"
BATT_VOLTAGE="$(get_batt_voltage_mv)"
BATT_HEALTH="$(get_batt_health_label)"

STORAGE="$(get_storage)"
RAM="$(get_ram)"

TODAY="$(date +'%d/%m/%Y')"
NOW_TIME="$(date +'%H:%M:%S')"
WEEKDAY="$(weekday_vi)"
UPTIME_STR="$(get_uptime_long)"

MOBILE_DATA_STATUS="$(get_mobile_data_status)"
HOTSPOT_STATUS="$(get_hotspot_status)"
WIFI_STATUS="$(get_wifi_status)"
BLUETOOTH_STATUS="$(get_bluetooth_status)"

CPU_TEMP="$(get_cpu_temp)"
CPU_FREQ="$(get_cpu_freq)"

MESSAGE="$(cat <<EOF
<b>📋 Thông tin hệ thống</b>
<code>────────────────────────</code>

<b>📡 Mạng di động</b>
• Nhà mạng: <code>${OPERATOR}</code>
• Tín hiệu: <code>${SIG_TEXT}</code>
• Chuẩn mạng: <code>${NETTYPE}</code>

<b>🔋 Pin</b>
• Mức pin: <code>${BATT_LEVEL}%</code>
• Trạng thái: <code>${BATT_STATUS}</code>
• Nhiệt độ pin: <code>${BATT_TEMP} °C</code>
• Điện áp: <code>${BATT_VOLTAGE}</code>
• Sức khỏe pin: <code>${BATT_HEALTH}</code>

<b>💾 Bộ nhớ</b>
• RAM: <code>${RAM}</code>
• Dung lượng: <code>${STORAGE}</code>

<b>⚙️ Hiệu năng</b>
• CPU (ước lượng): <code>${CPU_TEMP}</code> · <code>${CPU_FREQ}</code>

<b>🌐 Kết nối nhanh</b>
• Dữ liệu SIM: <code>${MOBILE_DATA_STATUS}</code>
• Hotspot: <code>${HOTSPOT_STATUS}</code>
• Wi‑Fi: <code>${WIFI_STATUS}</code>
• Bluetooth: <code>${BLUETOOTH_STATUS}</code>

<b>⏰ Thời gian</b>
• <code>${WEEKDAY}, ${TODAY}</code> · <code>${NOW_TIME}</code>
• Uptime: <code>${UPTIME_STR}</code>
EOF
)"

printf '%s\n' "$MESSAGE"

if [ "$1" = "send" ] || { [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; }; then
  if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "TELEGRAM_TOKEN hoặc TELEGRAM_CHAT_ID chưa cấu hình — chỉ in ra màn hình."
    exit 0
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "parse_mode=HTML" \
      --data-urlencode "text=${MESSAGE}" >/dev/null 2>&1 && echo "Đã gửi Telegram."
  else
    echo "Không có curl — không gửi được Telegram."
  fi
fi

exit 0
