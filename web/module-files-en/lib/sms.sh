# shellcheck shell=sh
# Read inbox SMS via the `content` command (similar to: adb shell content query --uri content://sms/inbox).

SMS_INBOX_URI="content://sms/inbox"
SMS_SHOW_COUNT=1
SMS_BODY_MAX=1200
SMS_SHOW_MAX=50

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
    send_code "❌ Cannot find <code>content</code> command (PATH / system)."
    return 1
  fi

  rest="$(echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  SMS_SHOW_COUNT=1
  if [ -n "$rest" ]; then
    case "$rest" in
      *[!0-9]*)
        send_code "❌ Invalid SMS count (use a positive integer, e.g. <code>/sms 5</code>)."
        return 1
        ;;
      0)
        send_code "❌ Count must be ≥ 1."
        return 1
        ;;
      *)
        SMS_SHOW_COUNT="$rest"
        if [ "$SMS_SHOW_COUNT" -gt "$SMS_SHOW_MAX" ] 2>/dev/null; then
          SMS_SHOW_COUNT="$SMS_SHOW_MAX"
        fi
        ;;
    esac
  fi

  raw="$(sms_query_inbox_raw)"
  if [ -z "$raw" ]; then
    send_code "❌ Failed to read SMS (<code>READ_SMS</code> permission / ROM policy, or empty inbox)."
    return 1
  fi

  rows="$(printf '%s\n' "$raw" | grep '^Row:' | head -n "$SMS_SHOW_COUNT")"
  if [ -z "$rows" ]; then
    send_code "ℹ️ No messages in <code>sms/inbox</code>."
    return 0
  fi

  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '—')"
  ts_esc="$(escape_html "$ts")"
  out="<b>📩 Last ${SMS_SHOW_COUNT} SMS (inbox)</b>
<i>${ts_esc}</i>
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

