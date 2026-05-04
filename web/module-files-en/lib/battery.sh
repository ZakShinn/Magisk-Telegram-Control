# shellcheck shell=sh
# Battery and charging status

get_batt_level() {
  dumpsys battery 2>/dev/null | awk -F: '/level/ {gsub(/ /,"",$2); print $2; exit}'
}

get_batt_status_code() {
  dumpsys battery 2>/dev/null | awk -F: '/status/ {gsub(/ /,"",$2); print $2; exit}'
}

get_charge_state_simple() {
  sc="$(get_batt_status_code)"
  case "$sc" in
    2|5) echo "charging" ;;
    3|4) echo "not_charging" ;;
    *)   echo "unknown" ;;
  esac
}

is_battery_charging_now() {
  case "$(get_charge_state_simple)" in
    charging) return 0 ;;
    *) return 1 ;;
  esac
}

get_batt_level_int() {
  lvl="$(get_batt_level)"
  case "$lvl" in
    ''|*[!0-9]*) echo "" ;;
    *) echo "$lvl" ;;
  esac
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
    2) health_txt="Good" ;;
    3) health_txt="Overheated" ;;
    4) health_txt="Dead" ;;
    5) health_txt="Over voltage" ;;
    6) health_txt="Failure" ;;
    7) health_txt="Cold" ;;
    *) health_txt="Unknown" ;;
  esac

  case "$status_code" in
    2) status_txt="Charging" ;;
    3) status_txt="Discharging (not charging)" ;;
    4) status_txt="Not charging" ;;
    5) status_txt="Full" ;;
    *) status_txt="Unknown" ;;
  esac

  cat <<EOF
🔋 Battery: <code>${level}%</code>
⚡ Charging: <code>${status_txt}</code>
🌡️ Temperature: <code>${temp_text}</code>
🔌 Voltage: <code>${voltage_text}</code>
❤️ Health: <code>${health_txt}</code> <i>(${health_code})</i>
EOF
}

