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
