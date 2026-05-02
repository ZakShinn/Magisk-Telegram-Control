# TelegramControl · Điều khiển thiết bị qua Telegram / Remote device control via Telegram

**Tiếng Việt:** Module Magisk cho Android — bot Telegram (long polling) chạy trong `service.sh`; chỉ **chat ID** đã cấu hình mới điều khiển được. Dùng để xem trạng thái máy, sóng, pin, IP, SMS (tuỳ khả năng đọc `mmssms.db`), hotspot/RNDIS, preset APN nhà mạng Việt Nam, TTL tether (chỉ khi gõ lệnh), chuyển tiếp SMS tùy chọn, cảnh báo pin thấp, v.v.

**English:** Magisk module for Android — a Telegram bot (long polling) runs via `service.sh`; only the **configured chat ID** can issue commands. Use it for device status, signal, battery, IP, SMS (where `mmssms.db` is readable), hotspot/RNDIS, Vietnamese carrier APN presets, TTL tether (on demand only), optional SMS forwarding, low-battery alerts, and more.

---

## Yêu cầu · Requirements

| | **Tiếng Việt** | **English** |
|---|----------------|-------------|
| Thiết bị | Android đã root, cài **Magisk** (hoặc tương thích `service.d`) | Rooted Android with **Magisk** (or compatible `service.d`) |
| Mạng | Thiết bị cần ra Internet để long polling Telegram | Device needs outbound Internet for Telegram long polling |
| Bot | Tạo bot qua [@BotFather](https://t.me/BotFather), lấy token; biết **Chat ID** của bạn | Create a bot via [@BotFather](https://t.me/BotFather); know your **Chat ID** |

---

## Cài đặt nhanh · Quick install

**Tiếng Việt**

1. Sao chép `config.sh.example` thành `config.sh`, điền `TELEGRAM_TOKEN` và `TELEGRAM_CHAT_ID`.
2. Đóng gói thư mục module (theo chuẩn Magisk: `module.prop`, `service.sh`, `customize.sh`, `lib/`, `bin/`, …) thành ZIP và flash trong Magisk; hoặc dùng **trang web builder** trong thư mục `web/` để tải ZIP đã nhúng `config.sh`.
3. Khởi động lại nếu cần; kiểm tra log hoặc tin nhắn khởi động từ bot.

**English**

1. Copy `config.sh.example` to `config.sh` and set `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`.
2. Zip the module layout for Magisk (`module.prop`, `service.sh`, `customize.sh`, `lib/`, `bin/`, …) and flash it; or use the **`web/` builder** to download a ZIP with embedded `config.sh`.
3. Reboot if needed; verify via logs or the bot’s startup message.

---

## Cấu hình · Configuration

**Tiếng Việt**

- File `config.sh` (bắt buộc): token, chat ID; tùy chọn `SMS_FORWARD=1`, timeout polling (`TG_POLL_TIMEOUT`, `TG_CURL_MAX_TIME`), TTL tether (`TETHER_TTL_FIX`, `TETHER_TTL_VALUE`), gói AnyDesk (`ANYDESK_PKG`), thời gian chờ kiểm tra APN (`APN_VERIFY_SLEEP`, …).
- **SMS forward / đọc SMS:** có thể lộ OTP — chỉ bật khi hiểu rủi ro. Cần đọc được `mmssms.db` và nhị phân `sqlite3` trong `bin/` (chọn ABI theo `ro.product.cpu.abi` — xem `lib/sms.sh`).

**English**

- Required `config.sh`: token and chat ID; optional `SMS_FORWARD=1`, poll timeouts (`TG_POLL_TIMEOUT`, `TG_CURL_MAX_TIME`), TTL tether (`TETHER_TTL_FIX`, `TETHER_TTL_VALUE`), AnyDesk package (`ANYDESK_PKG`), APN verify delays (`APN_VERIFY_SLEEP`, …).
- **SMS read/forward:** can leak OTPs — enable only if you accept the risk. Requires readable `mmssms.db` and the bundled `sqlite3` under `bin/` (ABI selection in `lib/sms.sh`).

---

## Lệnh ví dụ · Example commands

Gõ trên Telegram (chỉ chat được phép): `/help`, `/start`, `/status`, `/signal`, `/ip`, `/battery`, `/datausage`, `/ping`, `/sms`, `/hotspot_on` / `/hotspot_off`, `/rndis_on` / `/rndis_off`, `/ttl` hoặc `/ttl_sync`, `/anydesk_fix`, `/apn list|auto|viettel|vinaphone|…`, `/shutdown`, `/restart`.

**English:** Same commands in Telegram (authorized chat only): `/help`, `/start`, `/status`, `/signal`, `/ip`, `/battery`, `/datausage`, `/ping`, `/sms`, Wi‑Fi hotspot and USB RNDIS toggles, `/ttl` / `/ttl_sync`, `/anydesk_fix`, `/apn …`, power actions.

Chi tiết đầy đủ trong `lib/handlers.sh` (tin nhắn `/help` trên máy). · **Full detail:** see `lib/handlers.sh` (and `/help` output on device).

---

## Trang web đóng gói ZIP · Web ZIP builder

**Tiếng Việt**

```bash
cd web
cp .env.example .env.local   # đặt NEXT_PUBLIC_SITE_URL nếu deploy
npm install
npm run build && npm start    # hoặc npm run dev khi phát triển
```

Script `prebuild` sẽ chạy `fetch-sqlite.mjs` và `sync-module.mjs` trước khi build Next.js.

**English**

```bash
cd web
cp .env.example .env.local   # set NEXT_PUBLIC_SITE_URL if deploying
npm install
npm run build && npm start    # or npm run dev for development
```

The `prebuild` script runs `fetch-sqlite.mjs` and `sync-module.mjs` before the Next.js build.

---

## Cấu trúc repo · Repository layout

| Đường dẫn · Path | Mô tả · Description |
|------------------|---------------------|
| `module.prop` | Metadata module Magisk · Magisk module metadata |
| `service.sh` | Khởi chạy bot, polling, giám sát pin/SMS · Bot entry, polling, monitors |
| `customize.sh` | `chmod` nhị phân `sqlite3` sau khi flash · Fixes `sqlite3` permissions after flash |
| `lib/*.sh` | Lệnh, mạng, pin, SMS, APN, TTL, … · Commands, network, battery, SMS, APN, TTL, … |
| `status.sh` | Báo cáo tổng hợp (gọi bởi `/status`) · Aggregated status report |
| `bin/` | `sqlite3` theo ABI (Termux builds; SQLite public domain) · Per-ABI `sqlite3` binaries |
| `web/` | Next.js — build ZIP có config nhúng · Next.js app to build configured ZIP |

---

## Bảo mật & trách nhiệm · Security & responsibility

**Tiếng Việt:** Bot có quyền root theo chức năng module. Giữ **token** và **chat ID** bí mật; không chia sẻ ZIP đã nhúng config. Tính năng SMS/OTP có rủi ro lộ dữ liệu. Bạn tự chịu trách nhiệm khi cài và sử dụng.

**English:** The module runs with root-level capabilities where implemented. Keep your **token** and **chat ID** private; do not share ZIPs with embedded config. SMS/OTP features carry data-exposure risk. You are responsible for installation and use.

---

## Giấy phép thành phần · Third-party

- **SQLite:** public domain — [sqlite.org](https://www.sqlite.org/)

---

*Tác giả module (theo `module.prop`): Zakshin (Hải Nghĩa). · Module author (per `module.prop`): Zakshin (Hải Nghĩa).*
