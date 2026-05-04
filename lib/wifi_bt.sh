# shellcheck shell=sh
# Bật / tắt Wi‑Fi và Bluetooth qua svc/cmd (tùy ROM).

handle_wifi_on() {
  send_code "📶 Đang bật Wi‑Fi..."
  if svc wifi enable 2>/dev/null || cmd wifi set-wifi-enabled enabled 2>/dev/null; then
    send_code "✅ Wi‑Fi đã bật."
  else
    send_code "❌ Không bật được Wi‑Fi (thử <code>svc wifi enable</code> / quyền root / ROM)."
  fi
}

handle_wifi_off() {
  send_code "📶 Đang tắt Wi‑Fi..."
  if svc wifi disable 2>/dev/null || cmd wifi set-wifi-enabled disabled 2>/dev/null; then
    send_code "✅ Wi‑Fi đã tắt."
  else
    send_code "❌ Không tắt được Wi‑Fi (ROM hoặc quyền)."
  fi
}

handle_bt_on() {
  send_code "📳 Đang bật Bluetooth..."
  if svc bluetooth enable 2>/dev/null || cmd bluetooth_manager enable 2>/dev/null; then
    send_code "✅ Bluetooth đã bật."
  else
    send_code "❌ Không bật được Bluetooth (thử <code>svc bluetooth enable</code> / ROM)."
  fi
}

handle_bt_off() {
  send_code "📳 Đang tắt Bluetooth..."
  if svc bluetooth disable 2>/dev/null || cmd bluetooth_manager disable 2>/dev/null; then
    send_code "✅ Bluetooth đã tắt."
  else
    send_code "❌ Không tắt được Bluetooth (ROM hoặc quyền)."
  fi
}
