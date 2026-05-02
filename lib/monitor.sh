# shellcheck shell=sh
# Theo dõi sạc / RNDIS / hotspot (giống bản gốc trong old/service.sh)

handle_monitor_changes() {
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
