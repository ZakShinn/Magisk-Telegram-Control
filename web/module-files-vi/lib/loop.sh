# shellcheck shell=sh
# /loop_on: mỗi N phút chạy lệnh một lần, lặp cho đến /loop_off (tiến trình nền).

LOOP_PID_FILE="${LOOP_PID_FILE:-/data/local/tmp/tg_device_bot_loop_pids}"

_loop_cmd_normalize() {
  echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^\/\+//' | tr '[:upper:]' '[:lower:]'
}

_loop_cmd_allowed() {
  case "$1" in
    status|signal|ip|battery|datausage|rndis|rndis_on|hotspot|hotspot_on) return 0 ;;
    *) return 1 ;;
  esac
}

# Một lượt chạy trong vòng lặp — không qua notify_command_received.
# rndis / hotspot: chỉ thực thi (không spam Telegram mỗi chu kỳ).
run_loop_scheduled_inner() {
  inner="$(_loop_cmd_normalize "$1")"
  CID="$2"
  [ -n "$CID" ] && TELEGRAM_CHAT_ID="$CID"
  case "$inner" in
    status)
      send_code "⏰ <b>Lặp theo lịch</b> <code>/status</code>"
      handle_status
      ;;
    signal)
      send_code "⏰ <b>Lặp theo lịch</b> <code>/signal</code>"
      handle_signal
      ;;
    ip)
      send_code "⏰ <b>Lặp theo lịch</b> <code>/ip</code>"
      handle_ip
      ;;
    battery)
      send_code "⏰ <b>Lặp theo lịch</b> <code>/battery</code>"
      handle_battery
      ;;
    datausage)
      send_code "⏰ <b>Lặp theo lịch</b> <code>/datausage</code>"
      handle_datausage
      ;;
    rndis|rndis_on)
      rndis_on_apply
      ;;
    hotspot|hotspot_on)
      hotspot_on_apply "" || true
      ;;
  esac
}

# rest = phần sau "/loop_on", ví dụ "1 rndis"
handle_loop_on() {
  rest="$1"
  CID="$2"

  minutes="$(printf '%s' "$rest" | awk '{print $1}')"
  inner="$(printf '%s' "$rest" | awk '{print $2}')"
  inner="$(_loop_cmd_normalize "$inner")"

  if [ -z "$minutes" ] || [ -z "$inner" ]; then
    send_code "❌ Cú pháp: <code>/loop_on &lt;phút&gt; &lt;lệnh&gt;</code>

Ví dụ: <code>/loop_on 1 rndis</code> — cứ <b>1 phút</b> bật RNDIS một lần, lặp đến <code>/loop_off</code>.

Lệnh: <code>status</code>, <code>signal</code>, <code>ip</code>, <code>battery</code>, <code>datausage</code>, <code>rndis</code> (hoặc <code>rndis_on</code>), <code>hotspot</code> (hoặc <code>hotspot_on</code>, cấu hình mặc định như <code>/hotspot_on</code>).

<i><code>rndis</code> / <code>hotspot</code> trong lặp không gửi tin mỗi chu kỳ (tránh spam).</i>"
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
    send_code "❌ Không hẹn được lệnh <code>$(escape_html "$inner")</code>. Gõ <code>/loop_on</code> không đối số để xem danh sách."
    return 1
  fi

  sec=$(( minutes * 60 ))
  (
    while true; do
      sleep "$sec"
      run_loop_scheduled_inner "$inner" "$CID"
    done
  ) &
  loop_pid=$!
  echo "$loop_pid" >> "$LOOP_PID_FILE"

  case "$inner" in
    rndis|rndis_on|hotspot|hotspot_on)
      extra=" (chỉ thực thi im lặng mỗi chu kỳ)"
      ;;
    *)
      extra=""
      ;;
  esac

  send_code "✅ Lặp <code>/$(escape_html "$inner")</code> mỗi <b>${minutes}</b> phút${extra}. Lần đầu sau <b>${minutes}</b> phút. Dừng: <code>/loop_off</code>"
}

handle_loop_off() {
  if [ ! -f "$LOOP_PID_FILE" ] || [ ! -s "$LOOP_PID_FILE" ]; then
    send_code "ℹ️ Không có vòng lặp nền (file trống hoặc chưa từng <code>/loop_on</code>)."
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
  send_code "✅ Đã dừng lặp nền (đã gửi tín hiệu tới <b>${killed}</b> tiến trình)."
}
