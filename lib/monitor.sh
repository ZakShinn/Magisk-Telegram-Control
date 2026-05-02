# shellcheck shell=sh
# Theo dõi sạc / RNDIS / hotspot + cảnh báo pin thấp

LOW_BATT_WARN_PCT=10
LOW_BATT_CLEAR_PCT=15
LOW_BATT_STATE_FILE="/data/local/tmp/tg_low_batt_alert_state"

handle_monitor_changes() {
  last_charge="$(get_charge_state_simple)"
  last_rndis="$(get_rndis_state_simple)"
  last_hotspot="$(get_hotspot_state_simple)"

  while true; do
    cur_charge="$(get_charge_state_simple)"
    cur_rndis="$(get_rndis_state_simple)"
    cur_hotspot="$(get_hotspot_state_simple)"

    if [ "$cur_charge" != "$last_charge" ]; then
      lvl="$(get_batt_level)"
      case "$cur_charge" in
        charging)
          send_code "⚡ <b>Sạc</b>\nĐã cắm nguồn · pin <code>${lvl}%</code>"
          ;;
        not_charging)
          send_code "🔋 <b>Ngừng sạc</b>\nPin <code>${lvl}%</code>"
          ;;
        *)
          send_code "🔋 <b>Pin</b>\nTrạng thái không rõ."
          ;;
      esac
      last_charge="$cur_charge"
    fi

    if [ "$cur_rndis" != "$last_rndis" ]; then
      if [ "$cur_rndis" = "on" ]; then
        send_code "🔌 <b>RNDIS</b>\nĐã bật."
      else
        send_code "🔌 <b>RNDIS</b>\nĐã tắt."
      fi
      last_rndis="$cur_rndis"
    fi

    if [ "$cur_hotspot" != "$last_hotspot" ]; then
      if [ "$cur_hotspot" = "on" ]; then
        send_code "📡 <b>Hotspot</b>\nĐã bật."
      elif [ "$cur_hotspot" = "off" ]; then
        send_code "📡 <b>Hotspot</b>\nĐã tắt."
      else
        send_code "📡 <b>Hotspot</b>\nTrạng thái không rõ."
      fi
      last_hotspot="$cur_hotspot"
    fi

    sleep 5
  done
}

_handle_low_battery_alert_state_read() {
  cat "$LOW_BATT_STATE_FILE" 2>/dev/null || echo "idle"
}

_handle_low_battery_alert_state_write() {
  echo "$1" > "$LOW_BATT_STATE_FILE" 2>/dev/null || true
}

handle_low_battery_watch() {
  while true; do
    lvl="$(get_batt_level_int)"
    charging=false
    is_battery_charging_now && charging=true

    state="$(_handle_low_battery_alert_state_read)"

    if [ "$charging" = "true" ]; then
      _handle_low_battery_alert_state_write "idle"
      sleep 45
      continue
    fi

    if [ -z "$lvl" ]; then
      sleep 45
      continue
    fi

    if [ "$lvl" -ge "$LOW_BATT_CLEAR_PCT" ] 2>/dev/null; then
      if [ "$state" = "armed" ]; then
        _handle_low_battery_alert_state_write "idle"
      fi
      sleep 45
      continue
    fi

    if [ "$lvl" -le "$LOW_BATT_WARN_PCT" ] 2>/dev/null; then
      if [ "$state" != "armed" ]; then
        send_code "$(cat <<EOF
<b>🚨 Pin cực thấp</b>
<code>────────────────────────</code>

Pin chỉ còn <code>${lvl}%</code>.
⚠️ Vui lòng <b>cắm sạc ngay</b> để tránh tắt nguồn đột ngột.

<i>Cảnh báo khi ≤ ${LOW_BATT_WARN_PCT}% · tự tắt khi đã sạc hoặc pin ≥ ${LOW_BATT_CLEAR_PCT}%.</i>
EOF
)"
        _handle_low_battery_alert_state_write "armed"
      fi
    fi

    sleep 45
  done
}
