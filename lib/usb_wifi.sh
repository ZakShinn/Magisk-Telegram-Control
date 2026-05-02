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

# Giữ hook nếu script khác gọi; bot không tự gọi. Người dùng bật TTL qua Telegram: /ttl
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

handle_hotspot_on() {
  send_code "📡 Bật hotspot..."
  if cmd wifi start-softap "Zakshin" wpa2 "zakshin@123" >/dev/null 2>&1; then
    /system/bin/ifconfig swlan0 192.168.173.1/24 up 2>/dev/null || true
    send_code "✅ Đã bật hotspot"
  else
    send_code "❌ Không bật được hotspot (ROM/permission có thể hạn chế)"
  fi
}

handle_hotspot_off() {
  send_code "📡 Tắt hotspot..."
  if cmd wifi stop-softap >/dev/null 2>&1; then
    send_code "✅ Đã tắt hotspot"
  else
    send_code "❌ Không tắt được hotspot (ROM/permission có thể hạn chế)"
  fi
}
