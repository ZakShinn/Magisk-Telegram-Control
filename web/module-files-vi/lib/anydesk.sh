# shellcheck shell=sh
#
# AnyDesk helpers (optional)
#

anydesk_auto_media_loop() {
  ANYDESK_AUTO_MEDIA="${ANYDESK_AUTO_MEDIA:-0}"
  [ "$ANYDESK_AUTO_MEDIA" = "1" ] || return 0

  ANYDESK_PKG="${ANYDESK_PKG:-com.anydesk.anydeskandroid}"

  until [ "$(getprop sys.boot_completed)" -eq 1 ]; do
    sleep 5
  done

  while true; do
    appops set "$ANYDESK_PKG" PROJECT_MEDIA allow >/dev/null 2>&1
    sleep 60
  done
}

start_anydesk_auto_media_loop() {
  (anydesk_auto_media_loop >/dev/null 2>&1 &)
}

