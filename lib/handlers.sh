# shellcheck shell=sh
# Xử lý lệnh Telegram (cần SCRIPT_DIR, đã source common/battery/telephony/usb_wifi/netstats)

handle_help() {
  send_code "$(cat <<'EOF'
<b>📖 Lệnh</b> · chạm tên lệnh hoặc gõ trong chat.

/help /start — hướng dẫn
/ping — ping DNS + uptime · DNS mặc định chỉnh bằng TG_PING_DNS trong config.sh
/status — báo cáo máy
/signal — sóng, nhà mạng, loại mạng
/ip — IP nội bộ / public
/battery — pin
/datausage — lưu lượng
/sms — vài SMS đến · SMS_FORWARD trong config để tự đẩy tin mới

/rndis_on /rndis_off — USB tether
/hotspot_on /hotspot_off — Wi‑Fi hotspot
/ttl như /ttl 65 — TTL khi đang tether
/anydesk_fix — AnyDesk màn hình

/apn list · /apn auto · /apn viettel|vinaphone|mobifone|vietnamobile|gmobile — chỉ thêm preset, vào Cài đặt để chọn APN

/shutdown · /restart
EOF
)"
}

_ping_find_bin() {
  for x in ping /system/bin/ping /vendor/bin/ping; do
    if command -v "$x" >/dev/null 2>&1; then command -v "$x"; return 0; fi
    [ -x "$x" ] 2>/dev/null && { echo "$x"; return 0; }
  done
  return 1
}

_ping_parse_avg_ms() {
  raw="$1"
  line="$(echo "$raw" | grep 'min/avg/max' | head -n1)"
  [ -z "$line" ] && line="$(echo "$raw" | grep 'avg/max' | head -n1)"
  if [ -n "$line" ]; then
    tmp="$(echo "$line" | sed 's/.*=//' | sed 's/ms//' | tr -d ' ')"
    mid="$(echo "$tmp" | cut -d/ -f2)"
    case "$mid" in *[!0-9.]*) mid="" ;; esac
    [ -n "$mid" ] && { printf '%s' "$mid"; return 0; }
  fi
  echo "$raw" | grep -o 'time=[0-9.]*' | sed 's/^time=//' | awk '{ if ($1+0 > 0) { s+=($1+0); n++ } } END { if (n > 0) printf "%.0f", s/n }'
}

_ping_dns_avg_ms() {
  h="$1"
  pb="$(_ping_find_bin)" || { printf err; return 1; }
  raw="$("$pb" -c 4 "$h" 2>&1)" || true
  ms="$(_ping_parse_avg_ms "$raw")"
  [ -z "$ms" ] && { printf err; return 1; }
  printf '%s' "$ms"
  return 0
}

get_uptime_short() {
  if [ -r /proc/uptime ]; then
    up=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
    days=$(( up / 86400 ))
    hours=$(( (up % 86400) / 3600 ))
    mins=$(( (up % 3600) / 60 ))
    echo "${days}d ${hours}h ${mins}m"
    return
  fi
  echo "N/A"
}

handle_ping() {
  up="$(get_uptime_short 2>/dev/null || echo "N/A")"
  hosts="${TG_PING_DNS:-8.8.8.8 1.1.1.1 223.5.5.5}"
  msg="<b>Ping DNS</b>\nUptime $(escape_html "$up")\n\n"

  for h in $hosts; do
    [ -z "$h" ] && continue
    avg="$(_ping_dns_avg_ms "$h")"
    case "$avg" in err|'')
      msg="${msg}$(escape_html "$h"): không phản hồi\n"
      ;;
    *)
      msg="${msg}$(escape_html "$h"): ${avg} ms\n"
      ;;
    esac
  done

  send_code "$msg"
}

handle_status() {
  if [ -f "${SCRIPT_DIR}/status.sh" ]; then
    ( sh "${SCRIPT_DIR}/status.sh" >/dev/null 2>&1 & )
    send_code "✅ <b>Status</b>\nĐang thu thập — tin nhắn sẽ gửi trong giây lát."
  else
    send_code "❌ Không tìm thấy <code>status.sh</code>"
  fi
}

handle_status_on_boot() {
  if [ -f "${SCRIPT_DIR}/status.sh" ]; then
    ( sh "${SCRIPT_DIR}/status.sh" >/dev/null 2>&1 & )
    send_code "🚀 <b>Khởi động xong</b>\nĐang gửi báo cáo <code>/status</code>…"
  else
    send_code "❌ Không tìm thấy <code>status.sh</code>"
  fi
}

handle_signal() {
  dbm="$(get_dbm)"
  nettypedesc="$(get_nettype_with_desc)"
  bandinfo="$(get_band_info)"
  quality="$(map_sig_quality "$dbm")"
  operator="$(get_operator_name)"

  msg="<b>📶 Sóng &amp; mạng</b>\n<code>────────────────────────</code>\n\n"
  msg="${msg}📍 Nhà mạng\n └ <code>${operator}</code>\n\n"
  msg="${msg}📡 Loại mạng\n └ <code>${nettypedesc}</code>\n\n"

  if [ -n "$bandinfo" ]; then
    msg="${msg}🎯 Band\n └ <code>${bandinfo}</code>\n\n"
  fi

  msg="${msg}📉 RSSI\n └ <code>${dbm} dBm</code>\n\n"
  msg="${msg}⭐ Chất lượng\n └ <code>${quality}</code>"

  send_code "$msg"
}

handle_ip() {
  if command -v ip >/dev/null 2>&1; then
    ipv4="$(
      ip -o -4 addr show 2>/dev/null \
        | awk '!/127\.0\.0\.1/ {print " └ " $2 ": " $4}'
    )"

    ipv6="$(
      ip -o -6 addr show 2>/dev/null \
        | awk '!/ ::1\/128/ && !/ scope host / {print " └ " $2 ": " $4}'
    )"

    if [ -z "$ipv4$ipv6" ]; then
      local_ips="<i>Không lấy được IP nội bộ</i>"
    else
      local_ips=""
      [ -n "$ipv4" ] && local_ips="${local_ips}<b>IPv4</b>${ipv4}\n"
      [ -n "$ipv6" ] && local_ips="${local_ips}<b>IPv6</b>${ipv6}\n"
    fi

  else
    out="$(ifconfig 2>/dev/null)"
    [ -z "$out" ] && out="Không lấy được IP nội bộ"
    local_ips="<pre>${out}</pre>"
  fi

  pub="$(get_public_ip)"
  if [ -n "$pub" ]; then
    pub_line="<code>${pub}</code>"
  else
    pub_line="<i>không lấy được</i>"
  fi

  send_code "<b>🌐 Địa chỉ IP</b>\n<code>────────────────────────</code>\n\n<b>Nội bộ</b>\n${local_ips}\n<b>Public</b>\n └ ${pub_line}"
}

handle_battery() {
  info="$(get_batt_info_text)"
  send_code "<b>🔋 Pin</b>\n<code>────────────────────────</code>\n\n${info}"
}

handle_ttl_command() {
  TEXT_IN="$1"
  TEXT="$TEXT_IN"
  case "$TEXT_IN" in /ttl_sync|/ttl_sync[[:space:]]*) TEXT="/ttl$(echo "$TEXT_IN" | sed 's|^/ttl_sync||')" ;; esac

  arg="$(echo "$TEXT" | sed 's|^/ttl||;s/^[[:space:]]*//;s/[[:space:]]*$//')"
  num=""
  if [ -n "$arg" ]; then
    case "$arg" in *[!0-9]*)
      safe="$(escape_html "$arg")"
      send_code "❌ <b>TTL</b>\nTham số không hợp lệ: <code>${safe}</code>\nDùng số nguyên <code>1</code>–<code>255</code>, ví dụ <code>/ttl 65</code>, hoặc chỉ <code>/ttl</code> để dùng mặc định."
      return
      ;;
    esac
    num="$arg"
    if [ "$num" -lt 1 ] 2>/dev/null || [ "$num" -gt 255 ] 2>/dev/null; then
      send_code "❌ <b>TTL</b>\nGiá trị phải từ <code>1</code> đến <code>255</code>."
      return
    fi
  fi

  hs="$(get_hotspot_state_simple)"
  rd="$(get_rndis_state_simple)"

  if [ "$hs" != "on" ] && [ "$rd" != "on" ]; then
    ttl_tether_clear || true
    send_code "$(cat <<EOF
<b>📶 TTL tether — nhật ký</b>
<code>────────────────────────</code>

<b>Trạng thái</b>: Hotspot <code>${hs}</code> · RNDIS <code>${rd}</code> — cả hai đều không bật nên <b>không áp rule TTL mới</b>.

<b>Đã chạy</b>
• <code>ttl_tether_clear</code> — gỡ toàn bộ jump <code>POSTROUTING → ${TTL_CHAIN4} / ${TTL_CHAIN6}</code> trên iface kiểu nhà mạng (rmnet/ccmni…), flush và xóa chain module (nếu còn).

<i>Bật hotspot hoặc RNDIS rồi gửi lại </i><code>/ttl</code><i>.</i>
EOF
)"
    return
  fi

  ttl_src_line=""
  if [ -n "$num" ]; then
    ttl_src_line="Giá trị TTL: <code>${num}</code> (theo đúng số bạn gõ trên Telegram)."
  elif [ -n "${TETHER_TTL_VALUE:-}" ]; then
    ttl_src_line="Giá trị TTL: lấy từ <code>TETHER_TTL_VALUE=${TETHER_TTL_VALUE}</code> trong <code>config.sh</code>."
  else
    def_sys="$(_ttl_sysctl_default)"
    ttl_src_line="Giá trị TTL: <code>${def_sys}</code> (từ <code>sysctl net.ipv4.ip_default_ttl</code>, hoặc 65 nếu không đọc được)."
  fi

  send_code "📶 <b>TTL tether</b>\nĐang áp rule (hotspot/RNDIS đang bật)…"

  if ! ttl_tether_apply "$num" 2>/dev/null; then
    ttl_tether_clear || true
    send_code "$(cat <<EOF
❌ <b>TTL tether</b>
Áp rule thất bại (không có <code>iptables</code> hoặc không có iface <code>rmnet</code>/<code>ccmni</code>… đang dùng).

Đã gọi <code>ttl_tether_clear</code> để tránh rule nửa vời.
EOF
)"
    return
  fi

  tv="${TTL_LAST_APPLY_VALUE:-?}"
  n4="${TTL_LAST_POSTROUTING_V4:-0}"
  n6="${TTL_LAST_POSTROUTING_V6:-0}"
  ipt4="${TTL_LAST_IPT4:-iptables}"
  ipt6="${TTL_LAST_IPT6:-}"
  v4t="${TTL_LAST_V4_TARGET:-TTL}"

  if [ -n "$ipt6" ] && [ "$n6" != "0" ]; then
    ttl_step4="(4) <code>${ipt6} -t mangle</code> — chain <code>${TTL_CHAIN6}</code> với <code>HL --hl-set ${tv}</code> và POSTROUTING tương tự IPv4 (<code>${n6}</code> iface)."
  else
    ttl_step4="(4) IPv6: không áp được (thiếu <code>ip6tables</code> hoặc không gắn được iface nhà mạng)."
  fi

  send_code "$(cat <<EOF
<b>📶 TTL tether — nhật ký &amp; ý nghĩa</b>
<code>────────────────────────</code>

<b>Điều kiện</b>: Hotspot <code>${hs}</code> · RNDIS <code>${rd}</code>
${ttl_src_line}

<b>Các bước thực tế</b>
(1) <code>ttl_tether_clear</code> — xóa rule cũ của module: lệnh <code>-D POSTROUTING -o &lt;iface&gt; -j ${TTL_CHAIN4}</code> (lặp đủ), rồi <code>-F/-X ${TTL_CHAIN4}</code> và tương tự IPv6 cho <code>${TTL_CHAIN6}</code> — tránh chồng chuỗi khi chạy lại.
(2) <code>${ipt4} -t mangle -N ${TTL_CHAIN4}</code> — tạo chain riêng; trong chain: <code>${v4t}</code> để đặt TTL/Hop Limit cố định = <code>${tv}</code> cho gói đi qua.
(3) Với mỗi iface tên <code>rmnet*</code>, <code>ccmni*</code>, …: <code>-A POSTROUTING -o &lt;iface&gt; -j ${TTL_CHAIN4}</code> — gói <b>ra nhà mạng</b> bị áp TTL đó (sau NAT tether TTL thường thấp hơn một bước; set cố định làm giảm dấu hiệu đó với một số DPI).
${ttl_step4}

<b>Kết quả</b>: TTL đang dùng <code>${tv}</code> · số rule POSTROUTING IPv4 đã gắn: <code>${n4}</code> · IPv6: <code>${n6}</code>

<i>Hiệu quả không đảm bảo trên mọi chip/offload; có thể trái điều khoản nhà mạng.</i>
EOF
)"
}

dispatch_command() {
  TEXT="$1"
  CID="$2"

  if [ -n "${ALLOWED_CHAT_ID:-}" ]; then
    [ "$CID" != "$ALLOWED_CHAT_ID" ] && return 0
  else
    [ -n "$CID" ] && TELEGRAM_CHAT_ID="$CID"
  fi

  case "$TEXT" in
    "/help"|"/start") handle_help ;;
    "/ping") handle_ping ;;
    "/shutdown") handle_shutdown ;;
    "/restart") handle_restart ;;
    "/status") handle_status ;;
    "/signal") handle_signal ;;
    "/ip") handle_ip ;;
    "/battery") handle_battery ;;
    "/sms") handle_sms_inbox ;;
    "/datausage") handle_datausage ;;
    "/rndis_on") handle_rndis_on ;;
    "/rndis_off") handle_rndis_off ;;
    "/hotspot_on") handle_hotspot_on ;;
    "/hotspot_off") handle_hotspot_off ;;
    /ttl*) handle_ttl_command "$TEXT" ;;
    "/anydesk_fix") handle_anydesk_fix ;;
    /apn*) handle_apn_command "$TEXT" ;;
    ""|*[![:print:]]*) ;;
    *)
      safe="$(escape_html "$TEXT")"
      send_code "❌ <b>Lệnh không hợp lệ</b>\n<code>${safe}</code>\n\nGõ <code>/help</code> để xem danh sách."
      ;;
  esac
}
