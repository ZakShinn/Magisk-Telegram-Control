# shellcheck shell=sh
# Xử lý lệnh Telegram (giống bản gốc trong old/service.sh)

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

handle_status() {
  (handle_status_send >/dev/null 2>&1 &)
  send_code "✅ Đang thu thập thông tin"
}

handle_status_on_boot() {
  (handle_status_send >/dev/null 2>&1 &)
  send_code "✅ Hệ thống khởi động thành công. Đang thu thập thông tin hệ thống"
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
  if [ -n "$bandinfo" ]; then
    msg="${msg}• Band      : ${bandinfo}\n"
  fi
  msg="${msg}• Tín hiệu  : ${dbm} dBm\n"
  msg="${msg}• Chất lượng: ${quality}"

  send_code "$msg"
}

handle_ip() {
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
    out="$(ifconfig 2>/dev/null)"
    [ -z "$out" ] && out="Không lấy được IP nội bộ"
    local_ips="$out"
  fi

  pub="$(get_public_ip)"
  if [ -n "$pub" ]; then
    out="${local_ips}\n\nPublic IP: ${pub}"
  else
    out="${local_ips}\n\nPublic IP: (không lấy được)"
  fi

  send_code "$out"
}

handle_battery() {
  info="$(get_batt_info_text)"
  send_code "$info"
}

dispatch_command() {
  TEXT="$1"
  CID="$2"

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
    ""|*[![:print:]]*) ;;
    *)
      send_code "❌ Lệnh không hợp lệ: ${TEXT}\nGõ /help để xem danh sách lệnh."
      ;;
  esac
}
