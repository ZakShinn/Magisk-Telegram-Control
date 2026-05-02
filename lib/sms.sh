# shellcheck shell=sh
# Đọc SMS và (tuỳ chọn) chuyển tiếp lên Telegram.
# SQLite: ưu tiên sqlite3 nhúng trong module (bin/sqlite3.* Termux ELF), sau đó sqlite hệ thống.

SMS_LAST_ID_FILE="/data/local/tmp/tg_sms_last_id"
SMS_DB="/data/data/com.android.providers.telephony/databases/mmssms.db"

_sms_sqlite_module_bin() {
  sd="${SCRIPT_DIR:-}"
  [ -z "$sd" ] && return 1
  abi="$(getprop ro.product.cpu.abi 2>/dev/null || echo "")"
  mod=""
  case "$abi" in
    arm64-v8a) mod="${sd}/bin/sqlite3.arm64" ;;
    armeabi-v7a|armeabi) mod="${sd}/bin/sqlite3.arm" ;;
    x86_64) mod="${sd}/bin/sqlite3.x86_64" ;;
    x86|i686) mod="${sd}/bin/sqlite3.x86" ;;
    *) return 1 ;;
  esac
  [ -f "$mod" ] || return 1
  chmod 755 "$mod" 2>/dev/null || true
  echo "$mod"
}

_sms_find_sqlite3() {
  mod="$(_sms_sqlite_module_bin 2>/dev/null)" && [ -n "$mod" ] && { echo "$mod"; return; }
  command -v sqlite3 >/dev/null 2>&1 && { echo "sqlite3"; return; }
  [ -x /system/bin/sqlite3 ] && { echo "/system/bin/sqlite3"; return; }
  [ -x /system/xbin/sqlite3 ] && { echo "/system/xbin/sqlite3"; return; }
  echo ""
}

# Chuẩn hoá body để ghép cột TAB (không dùng TAB trong SMS sau bước này).
_sms_flat_body_sql_expr() {
  echo "replace(replace(replace(replace(IFNULL(body,''), char(9), ' '), char(10), ' '), char(13), ' '), '|', '/')"
}

sms_human_date_ms() {
  ms="$1"
  case "$ms" in ''|*[!0-9]*) echo "?"; return ;; esac
  sec=$(( ms / 1000 ))
  if date -d "@$sec" >/dev/null 2>&1; then
    date -d "@$sec" '+%d/%m/%Y %H:%M' 2>/dev/null && return
  fi
  date -r "$sec" '+%d/%m/%Y %H:%M' 2>/dev/null && return
  echo "${ms}"
}

_sms_body_trim_telegram() {
  raw="$1"
  esc="$(escape_html "$raw")"
  echo "$esc" | awk '{ if (length($0)>3400) print substr($0,1,3400) "… <i>(đã cắt)</i>"; else print }'
}

sms_notify_one() {
  id="$1"
  addr="$2"
  body="$3"
  dms="$4"

  when="$(sms_human_date_ms "$dms")"
  addr_e="$(escape_html "$addr")"
  body_e="$(_sms_body_trim_telegram "$body")"

  send_code "$(cat <<EOF
<b>📩 SMS mới</b>
<code>────────────────────────</code>
• ID: <code>${id}</code>
• Từ: <code>${addr_e}</code>
• Lúc: <code>${when}</code>

${body_e}
EOF
)"
}

sms_sqlite_ids_after() {
  last="$1"
  sq="$(_sms_find_sqlite3)"
  [ -z "$sq" ] || [ ! -r "$SMS_DB" ] && { echo ""; return 1; }
  "$sq" "$SMS_DB" "SELECT _id FROM sms WHERE type=1 AND _id > ${last} ORDER BY _id ASC LIMIT 25;" 2>/dev/null
}

# Một dòng: address<TAB>body<TAB>date_ms — body đã loại TAB/xuống dòng.
sms_sqlite_row_tab_by_id() {
  id="$1"
  sq="$(_sms_find_sqlite3)"
  [ -z "$sq" ] || [ ! -r "$SMS_DB" ] && { echo ""; return 1; }
  flat="$(_sms_flat_body_sql_expr)"
  "$sq" -separator "$(printf '\t')" "$SMS_DB" \
    "SELECT IFNULL(address,'?'), ${flat}, COALESCE(date,0) FROM sms WHERE type=1 AND _id=${id} LIMIT 1;" 2>/dev/null \
    | head -n1
}

sms_forward_try_poll_once() {
  last="$(cat "$SMS_LAST_ID_FILE" 2>/dev/null || echo 0)"
  case "$last" in ''|*[!0-9]*) last=0 ;; esac

  sq="$(_sms_find_sqlite3)"
  if [ -n "$sq" ] && [ -r "$SMS_DB" ]; then
    ids="$(sms_sqlite_ids_after "$last")"
    newlast="$last"
    if [ -n "$ids" ]; then
      for sid in $ids; do
        [ -z "$sid" ] && continue
        case "$sid" in *[!0-9]*) continue ;; esac
        row="$(sms_sqlite_row_tab_by_id "$sid")"
        [ -z "$row" ] && continue
        addr="$(printf '%s\n' "$row" | cut -f1)"
        body="$(printf '%s\n' "$row" | cut -f2)"
        dms="$(printf '%s\n' "$row" | cut -f3)"
        sms_notify_one "$sid" "$addr" "$body" "$dms"
        [ "$sid" -gt "$newlast" ] && newlast="$sid"
      done
    fi
    echo "$newlast" > "$SMS_LAST_ID_FILE"
    return 0
  fi

  command -v content >/dev/null 2>&1 || return 1

  lid="$(content query --uri content://sms/inbox --projection _id --sort "_id DESC" --limit 1 2>/dev/null \
    | grep -o '_id=[0-9]*' | head -n1 | cut -d= -f2)"
  [ -z "$lid" ] && return 1
  case "$lid" in *[!0-9]*) return 1 ;; esac

  [ "$lid" -gt "$last" ] 2>/dev/null || {
    echo "$last" > "$SMS_LAST_ID_FILE"
    return 0
  }

  raw="$(content query --uri content://sms/inbox --projection address:body:date:_id --where "_id=${lid}" --limit 1 2>/dev/null)"
  addr="$(echo "$raw" | grep -o 'address=[^,]*' | head -n1 | sed 's/^address=//')"
  body="$(echo "$raw" | grep -o 'body=[^,]*' | head -n1 | sed 's/^body=//')"
  dms="$(echo "$raw" | grep -o 'date=[^,]*' | head -n1 | sed 's/^date=//')"
  sms_notify_one "$lid" "$addr" "$body" "$dms"
  echo "$lid" > "$SMS_LAST_ID_FILE"
}

sms_seed_last_id_if_needed() {
  cur="$(cat "$SMS_LAST_ID_FILE" 2>/dev/null || echo 0)"
  case "$cur" in ''|*[!0-9]*) cur=0 ;; esac
  [ "$cur" -ne 0 ] 2>/dev/null && return 0

  sq="$(_sms_find_sqlite3)"
  if [ -n "$sq" ] && [ -r "$SMS_DB" ]; then
    max="$("$sq" "$SMS_DB" "SELECT COALESCE(MAX(_id),0) FROM sms WHERE type=1;" 2>/dev/null)"
    case "$max" in ''|*[!0-9]*) max=0 ;; esac
    echo "$max" > "$SMS_LAST_ID_FILE"
    return 0
  fi

  command -v content >/dev/null 2>&1 || return 0
  lid="$(content query --uri content://sms/inbox --projection _id --sort "_id DESC" --limit 1 2>/dev/null \
    | grep -o '_id=[0-9]*' | head -n1 | cut -d= -f2)"
  case "$lid" in ''|*[!0-9]*) lid=0 ;; esac
  echo "$lid" > "$SMS_LAST_ID_FILE"
}

handle_sms_forward_loop() {
  mkdir -p "$(dirname "$SMS_LAST_ID_FILE")" 2>/dev/null || true
  [ -f "$SMS_LAST_ID_FILE" ] || echo "0" > "$SMS_LAST_ID_FILE"
  sms_seed_last_id_if_needed

  while true; do
    sms_forward_try_poll_once >/dev/null 2>&1 || true
    sleep 28
  done
}

handle_sms_inbox() {
  sq="$(_sms_find_sqlite3)"
  if [ -z "$sq" ] || [ ! -r "$SMS_DB" ]; then
    send_code "$(cat <<'EOF'
📩 <b>SMS</b>
Không đọc được kho SMS.

<i>Cần đọc được</i> <code>mmssms.db</code> <i>khi chạy root (tuỳ SELinux/ROM). SQLite nhúng:</i> <code>bin/sqlite3.*</code>
EOF
)"
    return 1
  fi

  flat="$(_sms_flat_body_sql_expr)"
  tab="$(printf '\t')"
  data="$("$sq" -separator "$tab" "$SMS_DB" "
SELECT _id,
       COALESCE(address,'?'),
       substr(${flat},1,160),
       COALESCE(date,0)
FROM sms WHERE type=1
ORDER BY _id DESC LIMIT 7;" 2>/dev/null)"

  if [ -z "$data" ]; then
    send_code "📩 <b>Hộp thư đến</b>\n<i>Trống hoặc không truy vấn được.</i>"
    return 0
  fi

  msg="<b>📩 SMS gần đây</b>\n<code>────────────────────────</code>\n\n"
  OLDIFS="$IFS"
  while IFS="$(printf '\t')" read -r sid addr snippet dms || [ -n "$sid" ]; do
    [ -z "$sid" ] && continue
    when="$(sms_human_date_ms "$dms")"
    msg="${msg}• <code>#$(escape_html "$sid")</code> <b>$(escape_html "$addr")</b>\n └ <i>${when}</i>\n └ $(escape_html "$snippet")\n\n"
  done <<SMS_EOF
$data
SMS_EOF
  IFS="$OLDIFS"

  send_code "$msg"
}
