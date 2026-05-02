================================================================================
  TelegramControl — Magisk module · Remote phone control via Telegram
================================================================================

[Tiếng Việt]
TelegramControl là module Magisk cho Android: `service.sh` chạy bot Telegram
(long polling), chỉ chat ID đã cấu hình mới điều khiển được. Bạn nhập
TELEGRAM_TOKEN và TELEGRAM_CHAT_ID trong `config.sh` hoặc dùng trang web builder
để tải ZIP đã nhúng config.

Các lệnh ví dụ: `/help`, `/status`, `/signal`, `/ip`, `/battery`, `/sms`,
hotspot/RNDIS, preset APN nhà mạng VN (`/apn vinaphone`, …), TTL tether chỉ khi
gõ `/ttl`, chuyển tiếp SMS (tuỳ chọn), giám sát pin thấp, v.v.
Repo: module.prop + lib/*.sh + status.sh + nhị phân sqlite3 trong `bin/`.

[English]
TelegramControl is a Magisk module for Android: `service.sh` runs a Telegram
bot (long polling); only the configured chat ID can issue commands. Set
TELEGRAM_TOKEN and TELEGRAM_CHAT_ID in `config.sh` or use the web builder ZIP.

Examples: `/help`, `/status`, `/signal`, `/ip`, `/battery`, `/sms`, hotspot /
RNDIS, Vietnamese carrier APN presets (`/apn vinaphone`, …), TTL tether via `/ttl`
only, optional SMS forwarding, low-battery alerts, etc.
Layout: module.prop, lib/*.sh, status.sh, and sqlite3 binaries under `bin/`.

--------------------------------------------------------------------------------
  Thư mục `bin/` · `bin/` folder — sqlite3
--------------------------------------------------------------------------------

[Tiếng Việt]
`sqlite3` được đóng gói từ Termux (ELF, ABI khớp userland Android). SQLite là
public domain — https://sqlite.org/

Module chọn đúng file theo `ro.product.cpu.abi` khi đọc SMS (`mmssms.db`);
logic chọn ABI nằm trong `lib/sms.sh`.

[English]
The `sqlite3` builds come from Termux packages (ELF, Android userland ABI).
SQLite is public domain — https://sqlite.org/

The module picks the matching binary using `ro.product.cpu.abi` when reading
SMS (`mmssms.db`); see `lib/sms.sh` for ABI selection.
