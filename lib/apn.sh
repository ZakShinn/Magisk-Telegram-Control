# shellcheck shell=sh
# Thêm bản APN preset (nhà mạng VN) — không đổi APN đang chọn trong Cài đặt.

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

apn_parse_row_id() {
  echo "$1" | grep -o '_id=[0-9]*' | head -n1 | cut -d= -f2
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

  ts="$(date +%s)"
  uniq_name="TG_${slug}_${ts}"

  mcc_mnc="$(apn_split_mcc_mnc "$sim_num")"
  mcc="$(echo "$mcc_mnc" | awk '{print $1}')"
  mnc="$(echo "$mcc_mnc" | awk '{print $2}')"

  disp="$(apn_preset_display "$slug")"
  send_code "📡 <b>APN ${disp}</b>\nSIM <code>${sim_num}</code> · trường APN <code>${apn_str}</code>\nChỉ <b>thêm</b> cấu hình — bạn chọn trong Cài đặt."

  if ! apn_insert_preset_row "$uniq_name" "$apn_str" "$sim_num" "$mcc" "$mnc"; then
    send_code "❌ <b>APN</b>\n<code>content insert</code> thất bại (ROM có thể khóa Telephony DB)."
    return 1
  fi

  new_id="$(apn_lookup_new_id_by_name "$uniq_name")"
  if [ -z "$new_id" ]; then
    send_code "❌ <b>APN</b>\nĐã insert nhưng không đọc được <code>_id</code> hàng mới."
    return 1
  fi

  send_code "✅ <b>Đã thêm APN</b>\n<i>Tên trong danh sách:</i> <code>$(escape_html "$uniq_name")</code>\n<code>_id</code>=<code>${new_id}</code>\n\nVào <b>Cài đặt → SIM / Mạng di động → Tên điểm truy cập (APN)</b> và <b>chọn</b> cấu hình này thủ công."
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

Mỗi lệnh <b>chỉ thêm</b> một dòng APN preset vào máy (bảng Telephony). <b>Không</b> tự đặt làm APN đang dùng — bạn chọn trong Cài đặt → SIM → Tên điểm truy cập.

<code>/apn list</code> — danh preset (tên mạng → chuỗi APN)
<code>/apn auto</code> — đoán mạng từ SIM / tên nhà mạng
<code>/apn vinaphone</code> · <code>/apn viettel</code> · <code>/apn mobifone</code> · <code>/apn vietnamobile</code> · <code>/apn gmobile</code>
<i>(alias: vina, mobi, vnmb, gmobi…)</i>

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
