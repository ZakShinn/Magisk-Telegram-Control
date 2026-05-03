# shellcheck shell=sh
# Hẹn giờ chạy lệnh một lần sau N phút (/loop_on) · hủy (/loop_off)

LOOP_PID_FILE="${LOOP_PID_FILE:-/data/local/tmp/tg_device_bot_loop_pids}"

_loop_cmd_normalize() {
  echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^\/\+//' | tr '[:upper:]' '[:lower:]'
}

_loop_cmd_allowed() {
  case "$1" in
    status|signal|ip|battery|datausage) return 0 ;;
    *) return 1 ;;
  esac
}

# Gọi sau sleep — không qua notify_command_received
run_loop_scheduled_inner() {
  inner="$(_loop_cmd_normalize "$1")"
  CID="$2"
  [ -n "$CID" ] && TELEGRAM_CHAT_ID="$CID"
  case "$inner" in
    status)
      send_code "⏰ <b>Tự chạy theo lịch</b> <code>/status</code>"
      handle_status
      ;;
    signal)
      send_code "⏰ <b>Tự chạy theo lịch</b> <code>/signal</code>"
      handle_signal
      ;;
    ip)
      send_code "⏰ <b>Tự chạy theo lịch</b> <code>/ip</code>"
      handle_ip
      ;;
    battery)
      send_code "⏰ <b>Tự chạy theo lịch</b> <code>/battery</code>"
      handle_battery
      ;;
    datausage)
      send_code "⏰ <b>Tự chạy theo lịch</b> <code>/datausage</code>"
      handle_datausage
      ;;
  esac
}

# rest = phần sau "/loop_on", ví dụ "60 status"
handle_loop_on() {
  rest="$1"
  CID="$2"

  minutes="$(printf '%s' "$rest" | awk '{print $1}')"
  inner="$(printf '%s' "$rest" | awk '{print $2}')"
  inner="$(_loop_cmd_normalize "$inner")"

  if [ -z "$minutes" ] || [ -z "$inner" ]; then
    send_code "❌ Cú pháp: <code>/loop_on &lt;phút&gt; &lt;lệnh&gt;</code>

Ví dụ: <code>/loop_on 60 status</code> — sau <b>60 phút</b> chạy <code>/status</code> <b>một lần</b>.

Lệnh được phép: <code>status</code>, <code>signal</code>, <code>ip</code>, <code>battery</code>, <code>datausage</code>.
Hủy mọi hẹn giờ nền: <code>/loop_off</code>"
    return 1
  fi

  if ! echo "$minutes" | grep -qE '^[0-9]+$'; then
    send_code "❌ Số phút phải là số nguyên dương."
    return 1
  fi
  if [ "$minutes" -lt 1 ] || [ "$minutes" -gt 10080 ]; then
    send_code "❌ Số phút hợp lệ: 1–10080 (tối đa 7 ngày)."
    return 1
  fi
  if ! _loop_cmd_allowed "$inner"; then
    send_code "❌ Không hẹn được lệnh <code>$(escape_html "$inner")</code>. Chỉ: status, signal, ip, battery, datausage."
    return 1
  fi

  sec=$(( minutes * 60 ))
  (
    sleep "$sec"
    run_loop_scheduled_inner "$inner" "$CID"
  ) &
  loop_pid=$!
  echo "$loop_pid" >> "$LOOP_PID_FILE"

  send_code "✅ Đã hẹn <code>/$(escape_html "$inner")</code> sau <b>${minutes}</b> phút (chạy một lần).

<i>Hủy tất cả hẹn giờ đang chờ: <code>/loop_off</code></i>"
}

handle_loop_off() {
  if [ ! -f "$LOOP_PID_FILE" ] || [ ! -s "$LOOP_PID_FILE" ]; then
    send_code "ℹ️ Không có hẹn giờ nền nào (file trống hoặc chưa từng <code>/loop_on</code>)."
    return 0
  fi
  killed=0
  while IFS= read -r pid || [ -n "$pid" ]; do
    [ -z "$pid" ] && continue
    if kill "$pid" 2>/dev/null; then
      killed=$(( killed + 1 ))
    fi
  done < "$LOOP_PID_FILE"
  rm -f "$LOOP_PID_FILE"
  send_code "✅ Đã hủy hẹn giờ nền (đã gửi tín hiệu dừng tới <b>${killed}</b> tiến trình <code>sleep</code>)."
}
