#!/system/bin/sh
# Magisk: chmod nhị phân sqlite3 nhúng (ZIP đôi khi strip quyền thực thi).

ui_print "- TelegramControl: sqlite3 nhúng"
if [ -d "$MODPATH/bin" ]; then
  chmod -R 755 "$MODPATH/bin" 2>/dev/null || true
  for f in "$MODPATH/bin/sqlite3".*; do
    [ -f "$f" ] && chmod 755 "$f"
  done
fi
