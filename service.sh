#!/system/bin/sh
# Bot Telegram điều khiển thiết bị — Magisk service.d

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="${SCRIPT_DIR}/config.sh"

if [ ! -f "$CFG" ]; then
  echo "TelegramControl: thiếu config.sh — hãy dùng config.sh.example hoặc tải ZIP từ web."
  exit 1
fi
# shellcheck source=/dev/null
. "$CFG"

# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/battery.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/telephony.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/ttl_tether.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/usb_wifi.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/netstats.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/sms.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/anydesk.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/apn.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/handlers.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/monitor.sh"

BOT_OFFSET_FILE="/data/local/tmp/tg_device_bot_offset"

if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
  echo "TelegramControl: TELEGRAM_TOKEN hoặc TELEGRAM_CHAT_ID trống trong config.sh"
  exit 1
fi

# Chỉ phản hồi đúng Chat ID đã cấu hình (tránh bot bị người khác điều khiển).
ALLOWED_CHAT_ID="${TELEGRAM_CHAT_ID}"

if [ -f "$BOT_OFFSET_FILE" ]; then
  OFFSET="$(cat "$BOT_OFFSET_FILE" 2>/dev/null || echo 0)"
else
  OFFSET=0
fi

send_code "🤖 <b>Telegram Device Bot</b>\nĐã khởi động · gõ <code>/help</code> để xem lệnh."

(telegram_register_bot_commands >/dev/null 2>&1 &)

(handle_monitor_changes >/dev/null 2>&1 &)
(handle_low_battery_watch >/dev/null 2>&1 &)

SMS_FORWARD_RAW="${SMS_FORWARD:-0}"
case "$SMS_FORWARD_RAW" in
  1|true|TRUE|yes|YES|on|ON)
    (handle_sms_forward_loop >/dev/null 2>&1 &)
    ;;
esac

(
  sleep 22
  anydesk_grant_project_media "${ANYDESK_PKG:-com.anydesk.anydeskandroid}"
) >/dev/null 2>&1 &

(
  i=1
  while [ "$i" -le 120 ]; do
    if has_network; then
      handle_status_on_boot
      exit 0
    fi
    sleep 5
    i=$((i + 1))
  done
) &

# Long polling: Telegram timeout tối đa 50s — curl --max-time phải > timeout để không bị cắt TTL kết nối.
TG_POLL_TIMEOUT="${TG_POLL_TIMEOUT:-50}"
TG_CURL_MAX_TIME="${TG_CURL_MAX_TIME:-75}"

while true; do
  RESP="$(curl -s --max-time "${TG_CURL_MAX_TIME}" "${BOT_API}/getUpdates?timeout=${TG_POLL_TIMEOUT}&offset=${OFFSET}")"

  UPD_TMP="/data/local/tmp/tg_updates.$$"
  rm -f "$UPD_TMP"
  MAX_UID=0

  if command -v jq >/dev/null 2>&1 && printf '%s' "$RESP" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$RESP" | jq -r '.result[]? | "\(.update_id)\t\(.message.text // "")\t\(.message.chat.id // "")"' > "$UPD_TMP" 2>/dev/null || true
  fi

  if [ -s "$UPD_TMP" ]; then
    while IFS="$(printf '\t')" read -r uid text cid || [ -n "$uid" ]; do
      [ -z "$uid" ] && continue
      case "$uid" in *[!0-9]*) continue ;; esac
      [ "$uid" -gt "$MAX_UID" ] && MAX_UID="$uid"
      dispatch_command "${text:-}" "${cid:-}"
    done < "$UPD_TMP"
    rm -f "$UPD_TMP"
    if [ "$MAX_UID" -gt 0 ]; then
      OFFSET=$((MAX_UID + 1))
      echo "$OFFSET" > "$BOT_OFFSET_FILE"
    fi
  else
    rm -f "$UPD_TMP"
    LAST_UPDATE_ID="$(echo "$RESP" | grep -o '"update_id":[0-9]*' | awk -F: '{print $2}' | sort -n | tail -n1)"
    if [ -n "$LAST_UPDATE_ID" ]; then
      OFFSET=$((LAST_UPDATE_ID + 1))
      echo "$OFFSET" > "$BOT_OFFSET_FILE"

      TEXT="$(echo "$RESP" | grep -o '"text":"[^"]*"' | sed 's/^"text":"//;s/"$//' | tail -n1)"
      CID="$(echo "$RESP" | grep -o '"chat":{"id":[-0-9]*' | sed 's/.*"id"://' | tail -n1)"
      dispatch_command "$TEXT" "$CID"
    fi
  fi

  [ -z "$RESP" ] && sleep 5
done
