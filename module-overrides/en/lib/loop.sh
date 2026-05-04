# shellcheck shell=sh
# /loop_on: run a command every N minutes until /loop_off (background process).

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

run_loop_scheduled_inner() {
  inner="$(_loop_cmd_normalize "$1")"
  CID="$2"
  [ -n "$CID" ] && TELEGRAM_CHAT_ID="$CID"
  case "$inner" in
    status)
      send_code "⏰ <b>Scheduled loop</b> <code>/status</code>"
      handle_status
      ;;
    signal)
      send_code "⏰ <b>Scheduled loop</b> <code>/signal</code>"
      handle_signal
      ;;
    ip)
      send_code "⏰ <b>Scheduled loop</b> <code>/ip</code>"
      handle_ip
      ;;
    battery)
      send_code "⏰ <b>Scheduled loop</b> <code>/battery</code>"
      handle_battery
      ;;
    datausage)
      send_code "⏰ <b>Scheduled loop</b> <code>/datausage</code>"
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

handle_loop_on() {
  rest="$1"
  CID="$2"

  minutes="$(printf '%s' "$rest" | awk '{print $1}')"
  inner="$(printf '%s' "$rest" | awk '{print $2}')"
  inner="$(_loop_cmd_normalize "$inner")"

  if [ -z "$minutes" ] || [ -z "$inner" ]; then
    send_code "❌ Usage: <code>/loop_on &lt;minutes&gt; &lt;command&gt;</code>

Example: <code>/loop_on 1 rndis</code> — every <b>1 minute</b> enable RNDIS again, until <code>/loop_off</code>.

Commands: <code>status</code>, <code>signal</code>, <code>ip</code>, <code>battery</code>, <code>datausage</code>, <code>rndis</code> (or <code>rndis_on</code>), <code>hotspot</code> (or <code>hotspot_on</code>, default config like <code>/hotspot_on</code>).

<i><code>rndis</code> / <code>hotspot</code> in loops do not send a message every cycle (avoid spam).</i>"
    return 1
  fi

  if ! echo "$minutes" | grep -qE '^[0-9]+$'; then
    send_code "❌ Minutes must be a positive integer."
    return 1
  fi
  if [ "$minutes" -lt 1 ] || [ "$minutes" -gt 10080 ]; then
    send_code "❌ Valid minutes range: 1–10080 (up to 7 days)."
    return 1
  fi
  if ! _loop_cmd_allowed "$inner"; then
    send_code "❌ Command not allowed: <code>$(escape_html "$inner")</code>. Run <code>/loop_on</code> with no args to see the list."
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
      extra=" (silent execution each cycle)"
      ;;
    *)
      extra=""
      ;;
  esac

  send_code "✅ Loop <code>/$(escape_html "$inner")</code> every <b>${minutes}</b> minute(s)${extra}. First run in <b>${minutes}</b> minute(s). Stop: <code>/loop_off</code>"
}

handle_loop_off() {
  if [ ! -f "$LOOP_PID_FILE" ] || [ ! -s "$LOOP_PID_FILE" ]; then
    send_code "ℹ️ No background loops (file empty or no <code>/loop_on</code> yet)."
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
  send_code "✅ Stopped background loops (signal sent to <b>${killed}</b> process(es))."
}

