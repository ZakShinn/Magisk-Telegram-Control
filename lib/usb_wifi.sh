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

rndis_on_apply() {
  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions rndis,adb 2>/dev/null || svc usb setFunctions rndis 2>/dev/null || true
  fi
  setprop sys.usb.config rndis,adb 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

handle_rndis_on() {
  send_code "🔌 Bật RNDIS (USB tether)..."
  rndis_on_apply
}

handle_rndis_off() {
  send_code "🔌 Tắt RNDIS (USB tether)..."
  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions mtp,adb 2>/dev/null || svc usb setFunctions mtp 2>/dev/null || true
  fi
  setprop sys.usb.config mtp,adb 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

# arg_line: phần sau "/hotspot_on" (đã tách), có thể rỗng — chỉ bật softap + ifconfig, không gửi Telegram.
# Trả 0 nếu bật được, 1 nếu không.
hotspot_on_apply() {
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
    return 0
  fi
  return 1
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

  ssid_esc="$(escape_html "$ssid")"
  if hotspot_on_apply "$arg_line"; then
    if [ -n "$pass" ]; then
      send_code "✅ Hotspot bật · SSID <code>${ssid_esc}</code> · WPA2"
    else
      send_code "✅ Hotspot bật · SSID <code>${ssid_esc}</code> · mở (open)"
    fi
  else
    if [ -n "$pass" ]; then
      send_code "❌ Hotspot không bật được · SSID <code>${ssid_esc}</code> · WPA2: thử mật khẩu ≥8 ký tự; kiểm tra quyền/ROM."
    else
      send_code "❌ Hotspot không bật được · SSID <code>${ssid_esc}</code> · mạng mở (open); kiểm tra quyền/ROM."
    fi
  fi
}

handle_hotspot_off() {
  if cmd wifi stop-softap >/dev/null 2>&1 \
    || svc wifi stop-softap >/dev/null 2>&1; then
    send_code "✅ Hotspot đã tắt."
  else
    send_code "❌ Không tắt được hotspot (ROM hoặc quyền)."
  fi
}
