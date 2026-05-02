# shellcheck shell=sh
# Tiện ích dùng chung + gửi Telegram

getprop_safe() { getprop "$1" 2>/dev/null || echo ""; }

# API base (token từ config.sh)
BOT_API="https://api.telegram.org/bot${TELEGRAM_TOKEN}"

send_msg() {
  text="$1"
  [ -z "$TELEGRAM_TOKEN" ] && { echo "TELEGRAM_TOKEN chưa được cấu hình"; return; }
  [ -z "$TELEGRAM_CHAT_ID" ] && { echo "TELEGRAM_CHAT_ID chưa được cấu hình"; return; }

  curl -s "${BOT_API}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "parse_mode=HTML" \
    --data-urlencode "text=${text}" >/dev/null 2>&1
}

send_code() {
  raw="$1"
  text="$(printf '%b' "$raw")"
  send_msg "$text"
}

escape_html() {
  echo "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

has_network() {
  curl -s --max-time 5 "${BOT_API}/getMe" | grep -q '"ok":true'
}

# Giống BotCommand + set_my_commands trong python-telegram — menu gợi ý lệnh trên Telegram.
telegram_register_bot_commands() {
  [ -z "${TELEGRAM_TOKEN:-}" ] && return 1
  command -v curl >/dev/null 2>&1 || return 1
  f="/data/local/tmp/tg_set_cmds_$$.json"
  umask 077
  cat > "$f" <<'JSONEOF'
{"commands":[
{"command":"start","description":"Khởi động và xem hướng dẫn"},
{"command":"help","description":"Danh sách lệnh đầy đủ"},
{"command":"ping","description":"Ping tới các DNS và thời gian bật máy"},
{"command":"status","description":"Báo cáo tổng hợp thiết bị"},
{"command":"signal","description":"Sóng, nhà mạng, loại mạng"},
{"command":"ip","description":"Địa chỉ IP nội bộ và public"},
{"command":"battery","description":"Mức pin và trạng thái sạc"},
{"command":"datausage","description":"Dữ liệu di động và Wi-Fi đã dùng"},
{"command":"sms","description":"Tin SMS đến gần đây"},
{"command":"rndis_on","description":"Bật chia sẻ mạng qua USB"},
{"command":"rndis_off","description":"Tắt chia sẻ mạng qua USB"},
{"command":"hotspot_on","description":"Bật phát Wi-Fi"},
{"command":"hotspot_off","description":"Tắt phát Wi-Fi"},
{"command":"ttl","description":"Đặt TTL khi tether (có hotspot hoặc USB)"},
{"command":"ttl_sync","description":"Giống /ttl"},
{"command":"anydesk_fix","description":"Quyền AnyDesk chia sẻ màn hình"},
{"command":"apn","description":"Thêm preset APN nhà mạng VN (xem help)"},
{"command":"shutdown","description":"Tắt máy"},
{"command":"restart","description":"Khởi động lại"}
]}
JSONEOF
  curl -sS --max-time 25 -X POST "${BOT_API}/setMyCommands" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d @"$f" >/dev/null 2>&1 || true
  rm -f "$f" 2>/dev/null || true
}
