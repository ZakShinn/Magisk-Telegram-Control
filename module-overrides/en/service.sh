#!/system/bin/sh
# Telegram bot to control device

TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
[ -f "${SCRIPT_DIR}/config.sh" ] && . "${SCRIPT_DIR}/config.sh"

# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/battery.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/telephony.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/usb_wifi.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/wifi_bt.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/netstats.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/sms.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/check_sms_watch.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/handlers.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/status.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/loop.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/monitor.sh"
# shellcheck source=/dev/null
[ -f "${SCRIPT_DIR}/lib/anydesk.sh" ] && . "${SCRIPT_DIR}/lib/anydesk.sh"

BOT_OFFSET_FILE="/data/local/tmp/tg_device_bot_offset"
LOOP_PID_FILE="/data/local/tmp/tg_device_bot_loop_pids"
BOT_COMMANDS_SYNCED_FILE="/data/local/tmp/tg_device_bot_commands_synced"

start_anydesk_auto_media_loop || true

# /loop_on processes do not survive service reboot; clear old PID list to avoid killing wrong processes.
rm -f "$LOOP_PID_FILE" 2>/dev/null || true
rm -f "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null || true

if [ -f "$BOT_OFFSET_FILE" ]; then
  OFFSET="$(cat "$BOT_OFFSET_FILE" 2>/dev/null || echo 0)"
else
  OFFSET=0
fi

if [ -n "$TELEGRAM_CHAT_ID" ]; then
  send_code "🤖 Telegram Device Bot started. Type /help to see commands."
fi

(handle_monitor_changes >/dev/null 2>&1 &)

(
  for i in $(seq 1 120); do
    if has_network; then
      if [ ! -f "$BOT_COMMANDS_SYNCED_FILE" ]; then
        telegram_set_my_commands "$(bot_my_commands_json)" || true
        : >"$BOT_COMMANDS_SYNCED_FILE" 2>/dev/null || true
      fi
      handle_status_on_boot
      exit 0
    fi
    sleep 5
  done
) &

while true; do
  [ -z "$TELEGRAM_TOKEN" ] && { echo "⚠️ Missing TELEGRAM_TOKEN, exiting."; exit 1; }

  RESP="$(curl -s "${BOT_API}/getUpdates?timeout=25&offset=${OFFSET}")"
  LAST_UPDATE_ID="$(echo "$RESP" | grep -o '"update_id":[0-9]*' | awk -F: '{print $2}' | sort -n | tail -n1)"

  if [ -n "$LAST_UPDATE_ID" ]; then
    OFFSET=$((LAST_UPDATE_ID + 1))
    echo "$OFFSET" > "$BOT_OFFSET_FILE"

    TEXT="$(echo "$RESP" | grep -o '"text":"[^"]*"' | sed 's/^"text":"//;s/"$//' | tail -n1)"
    CID="$(echo "$RESP" | grep -o '"chat":{"id":[-0-9]*' | sed 's/.*"id"://' | tail -n1)"

    dispatch_command "$TEXT" "$CID"
  fi

  [ -z "$RESP" ] && sleep 5
done

