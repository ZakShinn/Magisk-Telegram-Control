# shellcheck shell=sh
# /check_sms_on — poll inbox; new inbound SMS → Telegram. /check_sms_off — stop watcher.

CHECK_SMS_WATCH_PID_FILE="${CHECK_SMS_WATCH_PID_FILE:-/data/local/tmp/tg_device_bot_check_sms_watch_pid}"
CHECK_SMS_WATCH_LAST_TS_FILE="${CHECK_SMS_WATCH_LAST_TS_FILE:-/data/local/tmp/tg_device_bot_check_sms_last_ts}"
CHECK_SMS_WATCH_LAST_TIE_FILE="${CHECK_SMS_WATCH_LAST_TIE_FILE:-/data/local/tmp/tg_device_bot_check_sms_last_tie}"
CHECK_SMS_WATCH_SORT_TMP="${CHECK_SMS_WATCH_SORT_TMP:-/data/local/tmp/tg_chk_sms_watch_sort}"
CHECK_SMS_WATCH_INTERVAL="${CHECK_SMS_WATCH_INTERVAL:-30}"

_check_sms_watch_extract_id() {
  # `content query` may output `_id=123` or `_id= 123` depending on Android build.
  printf '%s' "$1" | sed -n 's/.*_id=[[:space:]]*\([0-9][0-9]*\).*/\1/p'
}

_check_sms_watch_extract_date() {
  printf '%s' "$1" | sed -n 's/.*, date=[[:space:]]*\([0-9][0-9]*\),.*/\1/p'
}

_check_sms_watch_is_perm_error() {
  printf '%s' "$1" | grep -qiE 'permission denial|securityexception|requires .*read_sms|not allowed to access'
}

_check_sms_watch_query_raw_limit() {
  lim="$1"
  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1
  out="$($bin query --uri "$SMS_INBOX_URI" --projection _id,address,date,body --sort "date DESC" --limit "$lim" 2>&1)"
  printf '%s' "$out"
}

_check_sms_watch_send_one_row() {
  line="$1"
  addr="$(printf '%s' "$line" | sed -n 's/.*, address=\([^,]*\).*/\1/p')"
  [ -z "$addr" ] && addr="$(printf '%s' "$line" | sed -n 's/^[^,]*address=\([^,]*\).*/\1/p')"
  dt_ms="$(printf '%s' "$line" | sed -n 's/.*, date=\([0-9][0-9]*\), date_sent=.*/\1/p')"
  [ -z "$dt_ms" ] && dt_ms="$(printf '%s' "$line" | sed -n 's/.*, date=\([0-9][0-9]*\).*/\1/p')"
  body="$(printf '%s' "$line" | sed -n 's/.*, body=\(.*\), service_center=.*/\1/p')"
  [ -z "$body" ] && body="$(printf '%s' "$line" | sed -n 's/.*, body=\(.*\)$/\1/p')"
  dt_h="$(_sms_fmt_date_ms "$dt_ms")"
  blen="$(printf '%s' "$body" | wc -c | tr -d ' ')"
  body_short="$body"
  if [ "${blen:-0}" -gt "$SMS_BODY_MAX" ] 2>/dev/null; then
    body_short="$(printf '%s' "$body" | head -c "$SMS_BODY_MAX")…"
  fi
  addr_esc="$(escape_html "$addr")"
  dt_esc="$(escape_html "$dt_h")"
  body_esc="$(escape_html "$body_short")"
  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '—')"
  ts_esc="$(escape_html "$ts")"
  out="<b>📩 New SMS (inbox)</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━
<b>From</b> <code>${addr_esc}</code>
<b>When</b> <i>${dt_esc}</i>
<pre>${body_esc}</pre>"
  send_code "$out"
}

_check_sms_watch_loop() {
  CID="$1"
  [ -n "$CID" ] && TELEGRAM_CHAT_ID="$CID"

  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1

  raw="$(_check_sms_watch_query_raw_limit 1)"
  if _check_sms_watch_is_perm_error "$raw"; then
    send_code "❌ Cannot watch SMS: blocked by <code>READ_SMS</code> permission or ROM policy for <code>content://sms</code> in background."
    return 1
  fi
  row="$(printf '%s' "$raw" | grep '^Row:' | head -n1)"
  base_ts=0
  base_id=0
  if [ -n "$row" ]; then
    base_ts="$(_check_sms_watch_extract_date "$row")"
    [ -z "$base_ts" ] && base_ts="$(printf '%s' "$row" | sed -n 's/.*date=[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
    case "$base_ts" in ''|*[!0-9]*) base_ts=0 ;; esac
    base_id="$(_check_sms_watch_extract_id "$row")"
    case "$base_id" in ''|*[!0-9]*) base_id=0 ;; esac
  fi
  printf '%s' "$base_ts" > "$CHECK_SMS_WATCH_LAST_TS_FILE"
  printf '%s,%s' "$base_ts" "$base_id" > "$CHECK_SMS_WATCH_LAST_TIE_FILE"

  while true; do
    sleep "$CHECK_SMS_WATCH_INTERVAL"

    raw_top="$(_check_sms_watch_query_raw_limit 1)"
    if _check_sms_watch_is_perm_error "$raw_top"; then
      send_code "❌ Stopped SMS watch: no permission to read SMS (<code>READ_SMS</code>) / ROM blocks inbox access."
      return 1
    fi
    row_top="$(printf '%s' "$raw_top" | grep '^Row:' | head -n1)"
    cur_top_ts=0
    cur_top_id=0
    if [ -n "$row_top" ]; then
      cur_top_ts="$(_check_sms_watch_extract_date "$row_top")"
      [ -z "$cur_top_ts" ] && cur_top_ts="$(printf '%s' "$row_top" | sed -n 's/.*date=[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
      case "$cur_top_ts" in ''|*[!0-9]*) cur_top_ts=0 ;; esac
      cur_top_id="$(_check_sms_watch_extract_id "$row_top")"
      case "$cur_top_id" in ''|*[!0-9]*) cur_top_id=0 ;; esac
    fi

    last_ts="$(cat "$CHECK_SMS_WATCH_LAST_TS_FILE" 2>/dev/null)"
    case "$last_ts" in ''|*[!0-9]*) last_ts=0 ;; esac
    last_tie="$(cat "$CHECK_SMS_WATCH_LAST_TIE_FILE" 2>/dev/null)"
    last_tie_ts="${last_tie%%,*}"
    last_tie_id="${last_tie#*,}"
    case "$last_tie_ts" in ''|*[!0-9]*) last_tie_ts="$last_ts" ;; esac
    case "$last_tie_id" in ''|*[!0-9]*) last_tie_id=0 ;; esac

    if [ "$cur_top_ts" -lt "$last_ts" ] 2>/dev/null; then
      printf '%s' "$cur_top_ts" > "$CHECK_SMS_WATCH_LAST_TS_FILE"
      printf '%s,%s' "$cur_top_ts" "$cur_top_id" > "$CHECK_SMS_WATCH_LAST_TIE_FILE"
      continue
    fi

    [ "$cur_top_ts" -gt "$last_ts" ] 2>/dev/null || continue

    batch="$(_check_sms_watch_query_raw_limit 80)"
    if _check_sms_watch_is_perm_error "$batch"; then
      send_code "❌ Stopped SMS watch: cannot read inbox (Permission Denial)."
      return 1
    fi
    [ -z "$batch" ] && continue

    tmp_rows="/data/local/tmp/tg_chk_sms_rows.$$"
    printf '%s\n' "$batch" | grep '^Row:' > "$tmp_rows" 2>/dev/null || : >"$tmp_rows"

    rm -f "$CHECK_SMS_WATCH_SORT_TMP"
    while IFS= read -r line || [ -n "$line" ]; do
      [ -z "$line" ] && continue
      ts="$(_check_sms_watch_extract_date "$line")"
      [ -z "$ts" ] && ts="$(printf '%s' "$line" | sed -n 's/.*date=[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
      case "$ts" in ''|*[!0-9]*) continue ;; esac
      [ "$ts" -gt "$last_ts" ] 2>/dev/null || continue
      [ "$ts" -le "$cur_top_ts" ] 2>/dev/null || continue
      id="$(_check_sms_watch_extract_id "$line")"
      case "$id" in ''|*[!0-9]*) id=0 ;; esac
      if [ "$ts" -eq "$last_tie_ts" ] 2>/dev/null && [ "$id" -le "$last_tie_id" ] 2>/dev/null; then
        continue
      fi
      printf '%s\t%s\t%s\n' "$ts" "$id" "$line" >> "$CHECK_SMS_WATCH_SORT_TMP"
    done < "$tmp_rows"
    rm -f "$tmp_rows"

    if [ -f "$CHECK_SMS_WATCH_SORT_TMP" ] && [ -s "$CHECK_SMS_WATCH_SORT_TMP" ]; then
      sort -n "$CHECK_SMS_WATCH_SORT_TMP" | while IFS= read -r rec || [ -n "$rec" ]; do
        [ -z "$rec" ] && continue
        ts="$(printf '%s' "$rec" | cut -f1)"
        id="$(printf '%s' "$rec" | cut -f2)"
        line="$(printf '%s' "$rec" | cut -f3-)"
        case "$ts" in ''|*[!0-9]*) continue ;; esac
        _check_sms_watch_send_one_row "$line"
      done
      printf '%s' "$cur_top_ts" > "$CHECK_SMS_WATCH_LAST_TS_FILE"
      printf '%s,%s' "$cur_top_ts" "$cur_top_id" > "$CHECK_SMS_WATCH_LAST_TIE_FILE"
    fi

    rm -f "$CHECK_SMS_WATCH_SORT_TMP"
  done
}

handle_check_sms_watch_on() {
  CID="$1"
  bin="$(_sms_content_bin)"
  if [ -z "$bin" ]; then
    send_code "❌ <code>content</code> command not found (PATH / system)."
    return 1
  fi

  if [ -f "$CHECK_SMS_WATCH_PID_FILE" ]; then
    old="$(cat "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null)"
    case "$old" in ''|*[!0-9]*) old="" ;; esac
    if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
      send_code "ℹ️ SMS watch is already <b>on</b>. Use <code>/check_sms_off</code> before enabling again."
      return 0
    fi
    rm -f "$CHECK_SMS_WATCH_PID_FILE"
  fi

  (_check_sms_watch_loop "$CID") &
  echo $! > "$CHECK_SMS_WATCH_PID_FILE"

  send_code "✅ SMS watch <b>enabled</b> (poll every <b>${CHECK_SMS_WATCH_INTERVAL}</b>s).

<b>New</b> inbound SMS after this command will be sent here (<code>READ_SMS</code> required).

Stop: <code>/check_sms_off</code>"
}

handle_check_sms_watch_off() {
  if [ ! -f "$CHECK_SMS_WATCH_PID_FILE" ]; then
    send_code "ℹ️ SMS watch is not enabled."
    return 0
  fi
  pid="$(cat "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null)"
  case "$pid" in ''|*[!0-9]*) pid="" ;; esac
  ok=0
  if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
    ok=1
  fi
  rm -f "$CHECK_SMS_WATCH_PID_FILE"
  rm -f "$CHECK_SMS_WATCH_LAST_TS_FILE"
  rm -f "$CHECK_SMS_WATCH_LAST_TIE_FILE"
  rm -f "$CHECK_SMS_WATCH_SORT_TMP"
  if [ "$ok" = 1 ]; then
    send_code "✅ SMS watch <b>disabled</b>."
  else
    send_code "ℹ️ Cleared SMS watch state (process may have already exited)."
  fi
}
