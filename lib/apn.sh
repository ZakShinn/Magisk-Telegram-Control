# shellcheck shell=sh
# Thêm/chọn APN theo preset nhà mạng VN — kiểm tra data di động, lỗi thì khôi phục prefer APN cũ.

APN_STATE_DIR="${APN_STATE_DIR:-/data/local/tmp}"
APN_STATE_FILE="${APN_STATE_FILE:-${APN_STATE_DIR}/tg_apn_backup.state}"

apn_safe_numeric() {
  echo "${1:-}" | tr -cd '0-9'
}

apn_split_mcc_mnc() {
  num="$(apn_safe_numeric "$1")"
  len="${#num}"
  if [ "$len" -ge 6 ]; then
    echo "${num%???}" "${num#???}"
    return
  fi
  if [ "$len" -eq 5 ]; then
    echo "${num%??}" "${num#???}"
    return
  fi
  echo "" ""
}

apn_default_sub_id() {
  sub=""
  sub="$(settings get global subscription_default_data_values 2>/dev/null || true)"
  sub="$(apn_safe_numeric "$sub")"
  [ -n "$sub" ] && { echo "$sub"; return; }
  sub="$(settings get secure default_subscription 2>/dev/null || true)"
  sub="$(apn_safe_numeric "$sub")"
  [ -n "$sub" ] && { echo "$sub"; return; }
  echo "0"
}

apn_parse_row_id() {
  echo "$1" | grep -o '_id=[0-9]*' | head -n1 | cut -d= -f2
}

apn_get_preferred_id() {
  SUB="$(apn_default_sub_id)"
  row=""
  row="$(content query --uri "content://telephony/carriers/preferapn/${SUB}" 2>/dev/null | head -n1 || true)"
  id="$(apn_parse_row_id "$row")"
  if [ -n "$id" ]; then
    echo "$id"
    return
  fi
  row="$(content query --uri content://telephony/carriers/preferapn 2>/dev/null | head -n1 || true)"
  id="$(apn_parse_row_id "$row")"
  if [ -n "$id" ]; then
    echo "$id"
    return
  fi
  row="$(content query --uri content://telephony/carriers --where "current=1" 2>/dev/null | head -n1 || true)"
  apn_parse_row_id "$row"
}

apn_mobile_iface() {
  for n in rmnet_data0 rmnet_data1 rmnet0 rmnet1 rmnet_usb0 ccmni0 ccmni1 wwan0 usb0 lte_rmnet; do
    if ip link show "$n" >/dev/null 2>&1; then
      st="$(ip link show "$n" 2>/dev/null)"
      echo "$st" | grep -qE 'state UP|LOWER_UP' || continue
      echo "$n"
      return
    fi
  done
  ip -o link show 2>/dev/null | awk '
    $2 ~ /^(rmnet|ccmni|wwan)/ {
      gsub(/:$/, "", $2)
      if ($0 ~ /LOWER_UP|state UP/) { print $2; exit }
    }'
}

apn_verify_mobile_data() {
  iface="$(apn_mobile_iface)"
  url="${APN_VERIFY_URL:-http://connectivitycheck.gstatic.com/generate_204}"
  max_t="${APN_CURL_MAX_TIME:-14}"
  if [ -n "$iface" ]; then
    code="$(curl -s -o /dev/null -w "%{http_code}" --max-time "$max_t" --interface "$iface" "$url" 2>/dev/null || true)"
    [ "$code" = "204" ] && return 0
    if ping -c 2 -W 8 8.8.8.8 >/dev/null 2>&1; then
      return 0
    fi
    return 1
  fi
  code="$(curl -s -o /dev/null -w "%{http_code}" --max-time "$max_t" "$url" 2>/dev/null || true)"
  [ "$code" = "204" ] && return 0
  ping -c 2 -W 8 8.8.8.8 >/dev/null 2>&1
}

apn_toggle_mobile_data() {
  svc data disable >/dev/null 2>&1 || true
  sleep 2
  svc data enable >/dev/null 2>&1 || true
}

apn_set_preferred_apn_id() {
  sub="$1"
  apn_id="$2"
  content insert --uri "content://telephony/carriers/preferapn/${sub}" --bind apn_id:i:"${apn_id}" >/dev/null 2>&1 && return 0
  content insert --uri content://telephony/carriers/preferapn --bind apn_id:i:"${apn_id}" >/dev/null 2>&1 && return 0
  content update --uri content://telephony/carriers --bind current:i:1 --where "_id=${apn_id}" >/dev/null 2>&1 && return 0
  return 1
}

apn_insert_preset_row() {
  name="$1"
  apn_val="$2"
  numeric_full="$3"
  mcc="$4"
  mnc="$5"

  if [ -n "$mcc" ] && [ -n "$mnc" ]; then
    content insert --uri content://telephony/carriers \
      --bind name:s:"$name" \
      --bind apn:s:"$apn_val" \
      --bind numeric:s:"$numeric_full" \
      --bind type:s:"default,supl,dun" \
      --bind protocol:s:"IPV4V6" \
      --bind roaming_protocol:s:"IPV4V6" \
      --bind carrier_enabled:i:1 \
      --bind bearer_bitmask:i:0 \
      --bind mvno_type:s:"" \
      --bind mvno_match_data:s:"" \
      --bind mcc:i:$mcc \
      --bind mnc:s:"$mnc" >/dev/null 2>&1 && return 0
    return 1
  fi
  content insert --uri content://telephony/carriers \
    --bind name:s:"$name" \
    --bind apn:s:"$apn_val" \
    --bind numeric:s:"$numeric_full" \
    --bind type:s:"default,supl,dun" \
    --bind protocol:s:"IPV4V6" \
    --bind roaming_protocol:s:"IPV4V6" \
    --bind carrier_enabled:i:1 \
    --bind bearer_bitmask:i:0 \
    --bind mvno_type:s:"" \
    --bind mvno_match_data:s:"" >/dev/null 2>&1
}

apn_lookup_new_id_by_name() {
  nm="$1"
  row="$(content query --uri content://telephony/carriers --where "name='${nm}'" 2>/dev/null | head -n1 || true)"
  apn_parse_row_id "$row"
}

apn_delete_row() {
  id="$1"
  [ -z "$id" ] && return 0
  content delete --uri content://telephony/carriers --where "_id=${id}" >/dev/null 2>&1 || true
}

apn_preset_apn_string() {
  case "$1" in
    viettel) echo "v-internet" ;;
    vinaphone) echo "m3-world" ;;
    mobifone) echo "m-wap" ;;
    vietnamobile) echo "internet" ;;
    gmobile) echo "internet" ;;
    *) echo "" ;;
  esac
}

apn_preset_display() {
  case "$1" in
    viettel) echo "Viettel" ;;
    vinaphone) echo "Vinaphone" ;;
    mobifone) echo "Mobifone" ;;
    vietnamobile) echo "Vietnamobile" ;;
    gmobile) echo "Gmobile" ;;
    *) echo "$1" ;;
  esac
}

apn_detect_preset_slug() {
  alpha="$(get_operator_name 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  num="$(apn_safe_numeric "$(getprop gsm.sim.operator.numeric 2>/dev/null)$(getprop gsm.operator.numeric 2>/dev/null)")"
  case "$alpha" in
    *viettel*|*vittel*) echo "viettel"; return ;;
    *vina*|*vnpt*) echo "vinaphone"; return ;;
    *mobi*|*mbf*) echo "mobifone"; return ;;
    *vietnamobile*|*vnm*) echo "vietnamobile"; return ;;
    *gmobile*|*beeline*|*gtel*) echo "gmobile"; return ;;
  esac
  case "$num" in
    *452019*) echo "mobifone" ;;
    *452011*) echo "viettel" ;;
    *45202*) echo "vinaphone" ;;
    *45205*) echo "vietnamobile" ;;
    *45207*) echo "gmobile" ;;
    *45201*) echo "viettel" ;;
    *) echo "" ;;
  esac
}

apn_apply_preset_flow() {
  slug="$1"
  apn_str="$(apn_preset_apn_string "$slug")"
  if [ -z "$apn_str" ]; then
    send_code "❌ <b>APN</b>\nPreset không hợp lệ."
    return 1
  fi

  sim_num="$(apn_safe_numeric "$(getprop gsm.sim.operator.numeric 2>/dev/null)")"
  [ -z "$sim_num" ] && sim_num="$(apn_safe_numeric "$(getprop gsm.operator.numeric 2>/dev/null)")"
  if [ -z "$sim_num" ]; then
    send_code "❌ <b>APN</b>\nKhông đọc được MCC/MNC SIM (<code>gsm.sim.operator.numeric</code> trống)."
    return 1
  fi

  SUB="$(apn_default_sub_id)"
  old_id="$(apn_get_preferred_id)"
  ts="$(date +%s)"
  uniq_name="TG_${slug}_${ts}"

  rm -f "$APN_STATE_FILE" 2>/dev/null || true
  umask 077
  {
    echo "OLD_ID=${old_id:-}"
    echo "SUB=${SUB}"
    echo "NEW_ID="
    echo "SIM_NUM=${sim_num}"
    echo "SLUG=${slug}"
  } > "$APN_STATE_FILE"

  mcc_mnc="$(apn_split_mcc_mnc "$sim_num")"
  mcc="$(echo "$mcc_mnc" | awk '{print $1}')"
  mnc="$(echo "$mcc_mnc" | awk '{print $2}')"

  disp="$(apn_preset_display "$slug")"
  send_code "📡 <b>APN ${disp}</b>\nSIM numeric <code>${sim_num}</code> · preset <code>${apn_str}</code>\nĐang thêm và chọn APN…"

  if ! apn_insert_preset_row "$uniq_name" "$apn_str" "$sim_num" "$mcc" "$mnc"; then
    send_code "❌ <b>APN</b>\n<code>content insert</code> thất bại (ROM có thể khóa Telephony DB)."
    rm -f "$APN_STATE_FILE"
    return 1
  fi

  new_id="$(apn_lookup_new_id_by_name "$uniq_name")"
  if [ -z "$new_id" ]; then
    send_code "❌ <b>APN</b>\nĐã insert nhưng không đọc được <code>_id</code> hàng mới."
    rm -f "$APN_STATE_FILE"
    return 1
  fi

  tmp_state="${APN_STATE_FILE}.tmp.$$"
  grep -v '^NEW_ID=' "$APN_STATE_FILE" > "$tmp_state"
  echo "NEW_ID=${new_id}" >> "$tmp_state"
  mv "$tmp_state" "$APN_STATE_FILE"

  if ! apn_set_preferred_apn_id "$SUB" "$new_id"; then
    send_code "⚠️ <b>APN</b>\nThêm OK nhưng không set được prefer — đang xóa hàng thử nghiệm."
    apn_delete_row "$new_id"
    rm -f "$APN_STATE_FILE"
    return 1
  fi

  apn_toggle_mobile_data
  sleep "$((${APN_VERIFY_SLEEP:-12}))"

  if apn_verify_mobile_data; then
    iface="$(apn_mobile_iface)"
    iface_disp="${iface:-<i>mặc định route</i>}"
    send_code "✅ <b>APN ${disp}</b>\nĐã chọn · kiểm tra data OK (iface: ${iface_disp})."
    rm -f "$APN_STATE_FILE"
    return 0
  fi

  send_code "⚠️ <b>APN ${disp}</b>\nKiểm tra kết nối <b>thất bại</b> — khôi phục APN trước đó."

  old_id_saved="$(grep '^OLD_ID=' "$APN_STATE_FILE" 2>/dev/null | cut -d= -f2-)"
  sub_saved="$(grep '^SUB=' "$APN_STATE_FILE" 2>/dev/null | cut -d= -f2-)"

  apn_delete_row "$new_id"

  if [ -n "$old_id_saved" ]; then
    apn_set_preferred_apn_id "${sub_saved:-$SUB}" "$old_id_saved" || true
    content update --uri content://telephony/carriers --bind current:i:1 --where "_id=${old_id_saved}" >/dev/null 2>&1 || true
  fi

  apn_toggle_mobile_data
  rm -f "$APN_STATE_FILE"
  send_code "↩️ Đã khôi phục prefer APN cũ (id <code>${old_id_saved:-?}</code>). Nếu vẫn lỗi, kiểm tra tay trong Cài đặt → SIM."
}

handle_apn_command() {
  raw="$1"
  arg="$(echo "$raw" | sed 's|^/apn||;s/^[[:space:]]*//;s/[[:space:]]*$//')"
  arg_lc="$(echo "$arg" | tr '[:upper:]' '[:lower:]')"

  case "$arg_lc" in
    ""|help|-h|--help)
      send_code "$(cat <<'EOF'
<b>📡 APN (nhà mạng VN)</b>
<code>────────────────────────</code>

Mỗi lệnh dưới đây <b>ghi cấu hình APN preset vào máy</b> (bảng Telephony), chọn làm APN đang dùng, bật lại dữ liệu rồi thử kết nối.

<code>/apn list</code> — danh preset (tên mạng → chuỗi APN)
<code>/apn auto</code> — đoán mạng từ SIM / tên nhà mạng
<code>/apn vinaphone</code> · <code>/apn viettel</code> · <code>/apn mobifone</code> · <code>/apn vietnamobile</code> · <code>/apn gmobile</code>
<i>(vẫn có alias ngắn: vina, mobi, vnmb, gmobi…)</i>

Nếu kiểm tra data thất bại: <b>xóa bản ghi APN vừa thêm</b> và khôi phục APN ưu tiên trước đó.

<i>Một số ROM có thể chặn </i><code>content insert</code><i>; cần root.</i>
EOF
)"
      ;;
    list|danhsach|ds)
      send_code "$(cat <<'EOF'
<b>📡 Preset APN (cài vào máy)</b>
<code>────────────────────────</code>
• <code>/apn viettel</code> → trường APN <code>v-internet</code>
• <code>/apn vinaphone</code> → <code>m3-world</code>
• <code>/apn mobifone</code> → <code>m-wap</code>
• <code>/apn vietnamobile</code> → <code>internet</code>
• <code>/apn gmobile</code> → <code>internet</code>

MCC/MNC luôn theo SIM. Ví dụ Vinaphone: <code>/apn vinaphone</code>
EOF
)"
      ;;
    auto)
      d="$(apn_detect_preset_slug)"
      if [ -z "$d" ]; then
        send_code "❌ <b>APN auto</b>\nKhông đoán được mạng. Thử <code>/apn list</code> rồi chọn tay (vd. <code>/apn viettel</code>)."
        return
      fi
      apn_apply_preset_flow "$d"
      ;;
    viettel|vtel)
      apn_apply_preset_flow viettel ;;
    vina|vinaphone|vnp)
      apn_apply_preset_flow vinaphone ;;
    mobi|mobifone|mbf)
      apn_apply_preset_flow mobifone ;;
    vnmb|vietnamobile|vnm)
      apn_apply_preset_flow vietnamobile ;;
    gmobi|gmobile|g_mobile|beeline)
      apn_apply_preset_flow gmobile ;;
    *)
      safe="$(escape_html "$arg")"
      send_code "❌ Không rõ <code>${safe}</code>\nGõ <code>/apn</code> hoặc <code>/apn list</code>."
      ;;
  esac
}
