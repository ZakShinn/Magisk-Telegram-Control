# shellcheck shell=sh
# Đọc SMS và (tuỳ chọn) chuyển tiếp lên Telegram.
# SQLite: ưu tiên sqlite3 nhúng trong module (bin/sqlite3.* Termux ELF), sau đó sqlite hệ thống.

SMS_LAST_ID_FILE="/data/local/tmp/tg_sms_last_id"
SMS_DB="/data/data/com.android.providers.telephony/databases/mmssms.db"
# Giống viewer PHP: query toàn bảng SMS provider (sms), không chỉ sms/inbox — một số ROM/Google Messages trả dữ liệu đầy đủ hơn ở đây.
SMS_PROVIDER_URI="${SMS_PROVIDER_URI:-content://sms}"

# Đường dẫn content có khi không nằm trong PATH của service shell; một số ROM cần --user 0.
SMS_CQ=""
_sms_content_bin() {
  [ -n "$SMS_CQ" ] && { printf '%s' "$SMS_CQ"; return 0; }
  for c in content /system/bin/content /apex/com.android.tethering/bin/content; do
    if command -v "$c" >/dev/null 2>&1; then SMS_CQ="$(command -v "$c")"; printf '%s' "$SMS_CQ"; return 0; fi
    if [ -x "$c" ] 2>/dev/null; then SMS_CQ="$c"; printf '%s' "$SMS_CQ"; return 0; fi
  done
  return 1
}

_sms_content_query() {
  cq="$(_sms_content_bin)" || return 1
  out="$("$cq" query "$@" 2>/dev/null)"
  case "$out" in *[Uu]sage*|*[Ee]rror*|*"Couldn't find"*|*"not found"*|"")
    out="$("$cq" query --user 0 "$@" 2>/dev/null)"
    ;;
  *)
    printf '%s\n' "$out"
    return 0
    ;;
  esac
  printf '%s\n' "$out"
}

# Một cột một truy vấn — parse đúng kể cả body có dấu phẩy. Tham số 3 tuỳ chọn = URI (mặc định SMS_PROVIDER_URI).
_sms_content_cell() {
  sid="$1"
  col="$2"
  uri="$3"
  case "$uri" in '') uri="$SMS_PROVIDER_URI" ;; esac
  line="$(_sms_content_query --uri "$uri" --projection "$col" --where "_id=${sid}" 2>/dev/null | head -n1)"
  [ -z "$line" ] && { printf ''; return 1; }
  rest="$(printf '%s\n' "$line" | sed -e 's/^Row:[[:space:]]*[0-9]*[[:space:]]*//')"
  case "$rest" in "${col}="*)
    printf '%s' "${rest#"${col}="}"
    ;;
  *)
    printf ''
    ;;
  esac
  return 0
}

sms_content_recv_row_vals() {
  sid="$1"
  uri="$2"
  case "$uri" in '') uri="$SMS_PROVIDER_URI" ;; esac
  addr="$(_sms_content_cell "$sid" address "$uri")"
  body="$(_sms_content_cell "$sid" body "$uri")"
  dms="$(_sms_content_cell "$sid" date "$uri")"
  printf '%s\t%s\t%s\n' "$addr" "$body" "$dms"
}

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

  # Giống viewer PHP (content://sms). Nếu ROM không lọc type= trong WHERE, fallback sms/inbox.
  if _sms_content_bin >/dev/null 2>&1; then
    newlast="$last"
    uri="$SMS_PROVIDER_URI"
    idlist="$(
      _sms_content_query --uri "$uri" \
        --projection _id \
        --where "type=1 AND _id>${last}" \
        --sort "_id ASC" 2>/dev/null \
        | grep -o '_id=[0-9]*' | cut -d= -f2
    )"
    if [ -z "$idlist" ]; then
      uri="content://sms/inbox"
      idlist="$(
        _sms_content_query --uri "$uri" \
          --projection _id \
          --where "_id>${last}" \
          --sort "_id ASC" 2>/dev/null \
          | grep -o '_id=[0-9]*' | cut -d= -f2
      )"
    fi
    n=0
    for sid in $idlist; do
      [ -z "$sid" ] && continue
      case "$sid" in *[!0-9]*) continue ;; esac
      n=$((n + 1))
      [ "$n" -gt 25 ] && break
      tp="$(_sms_content_cell "$sid" type "${uri}")"
      case "$tp" in 1|'1'|"") ;;
      *)
        continue
        ;;
      esac
      row="$(sms_content_recv_row_vals "$sid" "$uri")"
      [ -z "$row" ] && continue
      addr="$(printf '%s\n' "$row" | cut -f1)"
      body="$(printf '%s\n' "$row" | cut -f2)"
      dms="$(printf '%s\n' "$row" | cut -f3)"
      sms_notify_one "$sid" "$addr" "$body" "$dms"
      [ "$sid" -gt "$newlast" ] 2>/dev/null && newlast="$sid"
    done
    echo "$newlast" > "$SMS_LAST_ID_FILE"
    return 0
  fi

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

  return 1
}

sms_seed_last_id_if_needed() {
  cur="$(cat "$SMS_LAST_ID_FILE" 2>/dev/null || echo 0)"
  case "$cur" in ''|*[!0-9]*) cur=0 ;; esac
  [ "$cur" -ne 0 ] 2>/dev/null && return 0

  if _sms_content_bin >/dev/null 2>&1; then
    lid="$(
      _sms_content_query --uri "$SMS_PROVIDER_URI" \
        --projection _id \
        --where "type=1" \
        --sort "_id DESC" --limit 1 2>/dev/null \
      | grep -o '_id=[0-9]*' | head -n1 | cut -d= -f2
    )"
    case "$lid" in ''|*[!0-9]*)
      lid="$(
        _sms_content_query --uri content://sms/inbox \
          --projection _id \
          --sort "_id DESC" --limit 1 2>/dev/null \
        | grep -o '_id=[0-9]*' | head -n1 | cut -d= -f2
      )"
      ;;
    esac
    case "$lid" in ''|*[!0-9]*) lid=0 ;; esac
    echo "$lid" > "$SMS_LAST_ID_FILE"
    return 0
  fi

  sq="$(_sms_find_sqlite3)"
  if [ -n "$sq" ] && [ -r "$SMS_DB" ]; then
    max="$("$sq" "$SMS_DB" "SELECT COALESCE(MAX(_id),0) FROM sms WHERE type=1;" 2>/dev/null)"
    case "$max" in ''|*[!0-9]*) max=0 ;; esac
    echo "$max" > "$SMS_LAST_ID_FILE"
  fi

  return 0
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

_sms_inbox_html_via_content() {
  uri="$SMS_PROVIDER_URI"
  ids="$(
    _sms_content_query --uri "$uri" \
      --projection _id \
      --where "type=1" \
      --sort "_id DESC" 2>/dev/null \
      | grep -o '_id=[0-9]*' | cut -d= -f2 | head -n7
  )"
  if [ -z "$ids" ]; then
    uri="content://sms/inbox"
    ids="$(
      _sms_content_query --uri "$uri" \
        --projection _id \
        --sort "_id DESC" 2>/dev/null \
        | grep -o '_id=[0-9]*' | cut -d= -f2 | head -n7
    )"
  fi
  [ -z "$ids" ] && { printf ''; return 0; }
  msg_out="<b>📩 SMS đến gần đây</b>\n<code>────────────────────────</code>\n\n"
  for sid in $ids; do
    [ -z "$sid" ] && continue
    tp="$(_sms_content_cell "$sid" type "$uri")"
    case "$tp" in 1|'1'|"") ;;
    *) continue ;; esac
    row="$(sms_content_recv_row_vals "$sid" "$uri")"
    [ -z "$row" ] && continue
    addr="$(printf '%s\n' "$row" | cut -f1)"
    snippet="$(printf '%s\n' "$row" | cut -f2)"
    dms="$(printf '%s\n' "$row" | cut -f3)"
    snippet="$(echo "$snippet" | awk '{ print substr($0,1,160) }')"
    when="$(sms_human_date_ms "$dms")"
    msg_out="${msg_out}• <code>#$(escape_html "$sid")</code> <b>$(escape_html "$addr")</b>\n └ <i>${when}</i>\n └ $(escape_html "$snippet")\n\n"
  done
  printf '%s' "$msg_out"
}

handle_sms_inbox() {
  sq="$(_sms_find_sqlite3)"

  if _sms_content_bin >/dev/null 2>&1; then
    cmsg="$(_sms_inbox_html_via_content)"
    if [ -n "$cmsg" ]; then
      send_code "$cmsg"
      return 0
    fi
  fi

  if [ -n "$sq" ] && [ -r "$SMS_DB" ]; then
    flat="$(_sms_flat_body_sql_expr)"
    tab="$(printf '\t')"
    data="$("$sq" -separator "$tab" "$SMS_DB" "
SELECT _id,
       COALESCE(address,'?'),
       substr(${flat},1,160),
       COALESCE(date,0)
FROM sms WHERE type=1
ORDER BY _id DESC LIMIT 7;" 2>/dev/null)"

    if [ -n "$data" ]; then
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
      return 0
    fi
  fi

  if _sms_content_bin >/dev/null 2>&1; then
    send_code "📩 <b>Hộp thư đến</b>\n<i>Trống hoặc không truy vấn được</i> (content://sms + user 0)."
    return 0
  fi

  send_code "$(cat <<'EOF'
📩 <b>SMS</b>
Không đọc được kho SMS (thiếu lệnh <code>content</code> và không đọc được <code>mmssms.db</code>).

Cần root + <code>content query --uri content://sms</code> hoặc quyền đọc provider Telephony.
EOF
)"
  return 1
}
