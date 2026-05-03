# shellcheck shell=sh
# RNDIS, hotspot (giống bản gốc)

get_rndis_state_simple() {
  usb_state="$(getprop_safe sys.usb.state)"
  usb_cfg="$(getprop_safe sys.usb.config)"
  echo "$usb_state $usb_cfg" | grep -qi 'rndis' && echo "on" || echo "off"
}

get_hotspot_state_simple() {
  iface="$(dumpsys wifi 2>/dev/null | sed -n 's/.*SoftApManager{id=[^}]* iface=\([^ ]*\) .*/\1/p' | head -n1)"
  if [ -n "$iface" ] && ip link show "$iface" 2>/dev/null | grep -q "state UP"; then
    echo "on"
  else
    echo "off"
  fi
}

# Giữ hook nếu script khác gọi; bot không tự chạy script TTL. Bật tay qua Telegram: /ttl_on
ttl_tether_sync() {
  case "${TETHER_TTL_FIX:-1}" in
    0|false|FALSE|no|NO|off|OFF)
      ttl_tether_clear || true
      return 0
      ;;
  esac

  hs="$(get_hotspot_state_simple)"
  rd="$(get_rndis_state_simple)"
  if [ "$hs" = "on" ] || [ "$rd" = "on" ]; then
    if ttl_tether_apply 2>/dev/null; then
      :
    else
      ttl_tether_clear || true
    fi
  else
    ttl_tether_clear || true
  fi
}

handle_rndis_on() {
  send_code "🔌 Bật RNDIS (USB tether)..."
  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions rndis,adb 2>/dev/null || svc usb setFunctions rndis 2>/dev/null || true
  fi
  setprop sys.usb.config rndis,adb 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

handle_rndis_off() {
  send_code "🔌 Tắt RNDIS (USB tether)..."
  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions mtp,adb 2>/dev/null || svc usb setFunctions mtp 2>/dev/null || true
  fi
  setprop sys.usb.config mtp,adb 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

# arg_line: phần sau "/hotspot_on" (đã tách), có thể rỗng.
# /hotspot_on                    → dùng HOTSPOT_SSID / HOTSPOT_PASS hoặc mặc định gọn.
# /hotspot_on TênWiFi MậtKhẩu  → SSID = từ đầu, mật khẩu = phần còn lại (cho phép nhiều từ).
# /hotspot_on TênWiFi            → một từ: mật khẩu lấy HOTSPOT_PASS (nếu có), không thì mạng mở (open).
handle_hotspot_on() {
  arg_line="$1"
  arg_line="$(echo "$arg_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  if [ -z "$arg_line" ]; then
    ssid="${HOTSPOT_SSID:-Hotspot}"
    pass="${HOTSPOT_PASS:-12345678}"
  else
    ssid="${arg_line%% *}"
    if [ "$ssid" = "$arg_line" ]; then
      pass="${HOTSPOT_PASS:-}"
    else
      pass="${arg_line#"$ssid"}"
      pass="$(echo "$pass" | sed 's/^[[:space:]]*//')"
    fi
  fi

  send_code "📡 Bật hotspot (SSID: $(escape_html "$ssid"))..."

  hs_ok=0
  if [ -n "$pass" ]; then
    if cmd wifi start-softap "$ssid" wpa2 "$pass" >/dev/null 2>&1; then
      hs_ok=1
    fi
  else
    if cmd wifi start-softap "$ssid" open >/dev/null 2>&1; then
      hs_ok=1
    fi
  fi

  if [ "$hs_ok" = "1" ]; then
    /system/bin/ifconfig swlan0 192.168.173.1/24 up 2>/dev/null || true
    send_code "✅ Đã bật hotspot"
  else
    send_code "❌ Không bật được hotspot. Kiểm tra SSID/mật khẩu (WPA2 thường cần ≥8 ký tự) hoặc quyền/ROM."
  fi
}

handle_hotspot_off() {
  send_code "📡 Tắt hotspot..."
  if cmd wifi stop-softap >/dev/null 2>&1 \
    || svc wifi stop-softap >/dev/null 2>&1; then
    send_code "✅ Đã tắt hotspot"
  else
    send_code "❌ Không tắt được hotspot (ROM/permission có thể hạn chế)"
  fi
}
