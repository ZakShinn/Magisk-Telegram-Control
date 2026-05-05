# shellcheck shell=sh
# /check_sms_on — kiểm tra định kỳ inbox; SMS mới → gửi Telegram. /check_sms_off — dừng.

CHECK_SMS_WATCH_PID_FILE="${CHECK_SMS_WATCH_PID_FILE:-/data/local/tmp/tg_device_bot_check_sms_watch_pid}"
CHECK_SMS_WATCH_LAST_ID_FILE="${CHECK_SMS_WATCH_LAST_ID_FILE:-/data/local/tmp/tg_device_bot_check_sms_last_id}"
CHECK_SMS_WATCH_SORT_TMP="${CHECK_SMS_WATCH_SORT_TMP:-/data/local/tmp/tg_chk_sms_watch_sort}"
CHECK_SMS_WATCH_INTERVAL="${CHECK_SMS_WATCH_INTERVAL:-30}"

_check_sms_watch_extract_id() {
  printf '%s' "$1" | sed -n 's/.*_id=\([0-9][0-9]*\).*/\1/p'
}

_check_sms_watch_query_raw_limit() {
  lim="$1"
  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1
  out="$($bin query --uri "$SMS_INBOX_URI" --projection _id,address,date,body --sort "date DESC" --limit "$lim" 2>/dev/null)"
  if printf '%s' "$out" | grep -q '^Row:'; then
    printf '%s' "$out"
    return 0
  fi
  printf '%s' "$($bin query --uri "$SMS_INBOX_URI" --projection _id,address,date,body --sort "date DESC" --limit "$lim" 2>/dev/null)"
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
  out="<b>📩 SMS mới (inbox)</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━
<b>Từ</b> <code>${addr_esc}</code>
<b>Lúc</b> <i>${dt_esc}</i>
<pre>${body_esc}</pre>"
  send_code "$out"
}

_check_sms_watch_loop() {
  CID="$1"
  [ -n "$CID" ] && TELEGRAM_CHAT_ID="$CID"

  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1

  raw="$(_check_sms_watch_query_raw_limit 1)"
  row="$(printf '%s' "$raw" | grep '^Row:' | head -n1)"
  base=0
  if [ -n "$row" ]; then
    base="$(_check_sms_watch_extract_id "$row")"
    case "$base" in ''|*[!0-9]*) base=0 ;; esac
  fi
  printf '%s' "$base" > "$CHECK_SMS_WATCH_LAST_ID_FILE"

  while true; do
    sleep "$CHECK_SMS_WATCH_INTERVAL"

    raw_top="$(_check_sms_watch_query_raw_limit 1)"
    row_top="$(printf '%s' "$raw_top" | grep '^Row:' | head -n1)"
    cur_top=0
    if [ -n "$row_top" ]; then
      cur_top="$(_check_sms_watch_extract_id "$row_top")"
      case "$cur_top" in ''|*[!0-9]*) cur_top=0 ;; esac
    fi

    last="$(cat "$CHECK_SMS_WATCH_LAST_ID_FILE" 2>/dev/null)"
    case "$last" in ''|*[!0-9]*) last=0 ;; esac

    # Inbox tip giảm (xóa tin): đồng bộ watermark.
    if [ "$cur_top" -lt "$last" ] 2>/dev/null; then
      printf '%s' "$cur_top" > "$CHECK_SMS_WATCH_LAST_ID_FILE"
      continue
    fi

    [ "$cur_top" -gt "$last" ] 2>/dev/null || continue

    batch="$(_check_sms_watch_query_raw_limit 80)"
    [ -z "$batch" ] && continue

    tmp_rows="/data/local/tmp/tg_chk_sms_rows.$$"
    printf '%s\n' "$batch" | grep '^Row:' > "$tmp_rows" 2>/dev/null || : >"$tmp_rows"

    rm -f "$CHECK_SMS_WATCH_SORT_TMP"
    while IFS= read -r line || [ -n "$line" ]; do
      [ -z "$line" ] && continue
      id="$(_check_sms_watch_extract_id "$line")"
      case "$id" in ''|*[!0-9]*) continue ;; esac
      [ "$id" -gt "$last" ] || continue
      printf '%s\t%s\n' "$id" "$line" >> "$CHECK_SMS_WATCH_SORT_TMP"
    done < "$tmp_rows"
    rm -f "$tmp_rows"

    if [ -f "$CHECK_SMS_WATCH_SORT_TMP" ] && [ -s "$CHECK_SMS_WATCH_SORT_TMP" ]; then
      sort -n "$CHECK_SMS_WATCH_SORT_TMP" | while IFS= read -r rec || [ -n "$rec" ]; do
        [ -z "$rec" ] && continue
        id="$(printf '%s' "$rec" | cut -f1)"
        line="$(printf '%s' "$rec" | cut -f2-)"
        case "$id" in ''|*[!0-9]*) continue ;; esac
        [ "$id" -gt "$last" ] || continue
        _check_sms_watch_send_one_row "$line"
      done
      printf '%s' "$cur_top" > "$CHECK_SMS_WATCH_LAST_ID_FILE"
    fi

    rm -f "$CHECK_SMS_WATCH_SORT_TMP"
  done
}

handle_check_sms_watch_on() {
  CID="$1"
  bin="$(_sms_content_bin)"
  if [ -z "$bin" ]; then
    send_code "❌ Không tìm thấy lệnh <code>content</code> (PATH / system)."
    return 1
  fi

  if [ -f "$CHECK_SMS_WATCH_PID_FILE" ]; then
    old="$(cat "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null)"
    case "$old" in ''|*[!0-9]*) old="" ;; esac
    if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
      send_code "ℹ️ Theo dõi SMS đã <b>bật</b>. Dùng <code>/check_sms_off</code> để tắt trước khi bật lại."
      return 0
    fi
    rm -f "$CHECK_SMS_WATCH_PID_FILE"
  fi

  (_check_sms_watch_loop "$CID") &
  echo $! > "$CHECK_SMS_WATCH_PID_FILE"

  send_code "✅ Đã <b>bật</b> theo dõi SMS (mỗi <b>${CHECK_SMS_WATCH_INTERVAL}</b>s kiểm tra inbox).

SMS <b>mới</b> sau lệnh này sẽ được gửi lên Telegram (cần quyền <code>READ_SMS</code>).

Tắt: <code>/check_sms_off</code>"
}

handle_check_sms_watch_off() {
  if [ ! -f "$CHECK_SMS_WATCH_PID_FILE" ]; then
    send_code "ℹ️ Theo dõi SMS chưa bật."
    return 0
  fi
  pid="$(cat "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null)"
  case "$pid" in ''|*[!0-9]*) pid="" ;; esac
  ok=0
  if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
    ok=1
  fi
  rm -f "$CHECK_SMS_WATCH_PID_FILE"
  rm -f "$CHECK_SMS_WATCH_LAST_ID_FILE"
  rm -f "$CHECK_SMS_WATCH_SORT_TMP"
  if [ "$ok" = 1 ]; then
    send_code "✅ Đã <b>tắt</b> theo dõi SMS."
  else
    send_code "ℹ️ Đã xóa trạng thái theo dõi SMS (tiến trình có thể đã thoát trước đó)."
  fi
}
