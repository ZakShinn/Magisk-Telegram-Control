# shellcheck shell=sh
# Đọc SMS hộp thư đến qua lệnh content (tương đương adb shell content query --uri content://sms/inbox).

SMS_INBOX_URI="content://sms/inbox"
SMS_SHOW_COUNT=3
SMS_BODY_MAX=1200

_sms_content_bin() {
  if command -v content >/dev/null 2>&1; then
    echo "content"
    return
  fi
  for p in /system/bin/content /system_ext/bin/content; do
    if [ -x "$p" ]; then
      echo "$p"
      return
    fi
  done
  echo ""
}

# In ra kết quả content query (có thử projection + sort + limit).
sms_query_inbox_raw() {
  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1
  out="$($bin query --uri "$SMS_INBOX_URI" --projection address,date,body --sort "date DESC" --limit "$SMS_SHOW_COUNT" 2>/dev/null)"
  if printf '%s' "$out" | grep -q '^Row:'; then
    printf '%s' "$out"
    return 0
  fi
  $bin query --uri "$SMS_INBOX_URI" 2>/dev/null
}

_sms_fmt_date_ms() {
  ms="$1"
  case "$ms" in ''|*[!0-9]*) echo "—"; return ;; esac
  sec=$((ms / 1000))
  ds="$(date -r "$sec" '+%d/%m/%Y %H:%M' 2>/dev/null || date -d "@$sec" '+%d/%m/%Y %H:%M' 2>/dev/null || true)"
  if [ -n "$ds" ]; then
    echo "$ds"
  else
    echo "$ms"
  fi
}

handle_sms() {
  bin="$(_sms_content_bin)"
  if [ -z "$bin" ]; then
    send_code "❌ Không tìm thấy lệnh <code>content</code> (PATH / system)."
    return 1
  fi

  raw="$(sms_query_inbox_raw)"
  if [ -z "$raw" ]; then
    send_code "❌ Không đọc được SMS (quyền <code>READ_SMS</code> / ROM, hoặc hộp thư trống)."
    return 1
  fi

  rows="$(printf '%s\n' "$raw" | grep '^Row:' | head -n "$SMS_SHOW_COUNT")"
  if [ -z "$rows" ]; then
    send_code "ℹ️ Không có tin nhắn trong <code>sms/inbox</code>."
    return 0
  fi

  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '—')"
  ts_esc="$(escape_html "$ts")"
  out="<b>📩 ${SMS_SHOW_COUNT} SMS gần nhất (inbox)</b>
<i>${ts_esc}</i> · <code>content query --uri content://sms/inbox</code>
━━━━━━━━━━━━━━━━
"

  idx=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    idx=$((idx + 1))
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
    out="${out}<b>${idx}.</b> <code>${addr_esc}</code> · <i>${dt_esc}</i>
<pre>${body_esc}</pre>

"
  done <<EOF
$rows
EOF

  send_code "$out"
}
