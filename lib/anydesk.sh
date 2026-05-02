# shellcheck shell=sh
# Cấp PROJECT_MEDIA cho AnyDesk (chia sẻ màn hình).

ANYDESK_PKG="${ANYDESK_PKG:-com.anydesk.anydeskandroid}"

anydesk_grant_project_media() {
  pkg="$1"
  [ -z "$pkg" ] && pkg="$ANYDESK_PKG"

  appops set --user 0 "$pkg" PROJECT_MEDIA allow 2>/dev/null || true
  appops set "$pkg" PROJECT_MEDIA allow 2>/dev/null || true
  cmd appops set "$pkg" PROJECT_MEDIA allow 2>/dev/null || true
  cmd appops set --user 0 "$pkg" PROJECT_MEDIA allow 2>/dev/null || true
}

handle_anydesk_fix() {
  send_code "🖥 <b>AnyDesk</b>\nĐang gán <code>PROJECT_MEDIA allow</code> cho <code>${ANYDESK_PKG}</code>…"
  anydesk_grant_project_media "$ANYDESK_PKG"
  chk="$(appops get "$ANYDESK_PKG" PROJECT_MEDIA 2>/dev/null || cmd appops get "$ANYDESK_PKG" PROJECT_MEDIA 2>/dev/null || echo "?")"
  send_code "✅ Đã chạy appops.\n<code>${chk}</code>"
}
