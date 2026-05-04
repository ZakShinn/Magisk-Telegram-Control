# TelegramControl — điều khiển Android qua Telegram (Magisk)

**[Tiếng Việt](#vi)** · **[English](#en)**

<a id="vi"></a>

## Tiếng Việt

### Giới thiệu

TelegramControl là module Magisk (phiên bản module hiện tại trong `module.prop`) chạy nền qua `service.sh`, long‑polling Telegram Bot API và thực hiện lệnh trên thiết bị. Code được tách thành các file trong `lib/` (trạng thái, telephony, mạng, lệnh, vòng lặp, v.v.).

### Tạo file ZIP từ trình duyệt

- Mở **[magisk-telegram-control.vercel.app](https://magisk-telegram-control.vercel.app)**.
- Nhập đúng thứ tự trên giao diện:
  - **Chat ID**
  - **Bot token** (từ [@BotFather](https://t.me/BotFather))
- (Tuỳ chọn) Bật ô **AnyDesk — tự động cấp quyền media** nếu bạn cần hành vi đó trong module.
- Tải **TelegramControl.zip**, cài trong Magisk (hoặc KernelSU tương thích module), rồi **khởi động lại**.

Sau khi cài, chỉ **Chat ID** đã nhập trong ZIP mới được bot xử lý lệnh (bot gắn với token của bạn).

### Cấu hình thủ công

- Sao chép `config.sh.example` thành `config.sh` và điền `TELEGRAM_TOKEN`, `TELEGRAM_CHAT_ID`.
- Có thể chỉnh thêm hotspot, timeout poll, gói AnyDesk — xem comment trong `config.sh.example`.

### Lệnh Telegram

| Lệnh | Mô tả ngắn |
|------|------------|
| `/help`, `/start` | Danh sách lệnh |
| `/status` | Ảnh chụp trạng thái / thông tin thiết bị (chạy nền) |
| `/signal` | Sóng & mạng: nhà mạng, RAT, băng tần, RSRP, RSRQ/SINR, roaming, v.v. |
| `/ip` | IPv4/IPv6 cục bộ + thử lấy IP public |
| `/ping` hoặc `/ping 8.8.8.8` | Ping (mặc định 1.1.1.1) |
| `/battery` | Thông tin pin |
| `/datausage` | Thống kê lưu lượng (theo triển khai `lib/netstats.sh`) |
| `/sms` | 3 tin nhắn gần nhất trong inbox (`content query` — cần quyền đọc SMS) |
| `/loop_on <phút> <lệnh>` | Lặp: mỗi N phút chạy lệnh một lần (đến `/loop_off`; gồm `rndis`, `hotspot` mặc định, …) |
| `/loop_off` | Dừng mọi vòng `/loop_on` đang chạy nền |
| `/rndis_on`, `/rndis_off` | Bật / tắt USB tether (RNDIS) |
| `/hotspot_on [SSID mật_khẩu]` | Bật hotspot Wi‑Fi (có thể kèm SSID/mật khẩu hoặc dùng mặc định/config) |
| `/hotspot_off` | Tắt hotspot |
| `/wifi_on`, `/wifi_off` | Bật / tắt Wi‑Fi (`svc` / `cmd wifi`) |
| `/bt_on`, `/bt_off` | Bật / tắt Bluetooth (`svc` / `cmd bluetooth_manager`) |
| `/shutdown` | Tắt máy |
| `/restart` | Khởi động lại |

Tránh spam `/shutdown` và `/restart` vì lệnh có thể xếp hàng và gây khởi động lặp.

### Bảo mật

- **Không công khai bot token** và không để người lạ dùng bot của bạn.
- File `config.sh` (hoặc token trong môi trường dev) là thông tin nhạy cảm — không đưa lên git công khai.

### Repo & phát triển web (tuỳ chọn)

- **`service.sh`**, **`lib/*.sh`**: logic module trên máy.
- **`web/`**: trình tạo ZIP (Next.js). Chạy local: `cd web && npm install && npm run dev`.
- Build production: `cd web && npm run build` (có bước `prebuild` đồng bộ file module vào `web/module-files`).

### Ngôn ngữ (web chọn VI/EN → tải đúng module)

Web có 2 lựa chọn ngôn ngữ hiển thị: **Tiếng Việt (vi)** và **English (en)**. Khi bấm tải ZIP, web sẽ gửi `lang` lên API để server đóng gói đúng bộ file:

- `lang=vi` → đóng gói từ `web/module-files-vi`
- `lang=en` → đóng gói từ `web/module-files-en`
- Nếu thiếu thư mục ngôn ngữ, hệ thống sẽ fallback về `web/module-files`

Để ZIP tải về **chỉ chứa đúng ngôn ngữ bạn đã chuẩn bị**, hãy đặt file override theo cấu trúc module vào:

- `module-overrides/vi/...`
- `module-overrides/en/...`

Trong bước build (`npm run build`), script `web/scripts/sync-module.mjs` sẽ copy module gốc sang `web/module-files-vi|en` rồi **ghi đè** bằng nội dung trong `module-overrides/<lang>/`.

---

<a id="en"></a>

## English

### Overview

TelegramControl is a Magisk module (see `module.prop` for the current version) that runs in the background via `service.sh`, long‑polls the Telegram Bot API, and executes commands on the device. Logic is split across `lib/` (status, telephony, networking, handlers, loops, etc.).

### Build the ZIP from the website

- Open **[magisk-telegram-control.vercel.app](https://magisk-telegram-control.vercel.app)**.
- Fill in the form **in this order**:
  - **Chat ID**
  - **Bot token** (from [@BotFather](https://t.me/BotFather))
- (Optional) Enable **AnyDesk — auto media permission** if you need that behavior baked into the module.
- Download **TelegramControl.zip**, flash it in Magisk (or a compatible setup), then **reboot**.

After install, only the **Chat ID** you embedded in the ZIP can issue commands to your bot (for that bot token).

### Manual configuration

- Copy `config.sh.example` to `config.sh` and set `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`.
- Optional hotspot, poll timeouts, AnyDesk package — see comments in `config.sh.example`.

### Telegram commands

| Command | Summary |
|---------|---------|
| `/help`, `/start` | Command list |
| `/status` | Device / system status snapshot (runs in background) |
| `/signal` | Cellular signal & network details (operator, RAT, band, RSRP, RSRQ/SINR, roaming, …) |
| `/ip` | Local IPv4/IPv6 + best‑effort public IP |
| `/ping` or `/ping 8.8.8.8` | Ping (default target 1.1.1.1) |
| `/battery` | Battery info |
| `/datausage` | Data usage summary (see `lib/netstats.sh`) |
| `/sms` | Last 3 inbox SMS (`content query` — needs SMS read permission) |
| `/loop_on <minutes> <command>` | Repeat: run command every N minutes until `/loop_off` (includes `rndis`, default `hotspot`, …) |
| `/loop_off` | Stop all background `/loop_on` loops |
| `/rndis_on`, `/rndis_off` | USB tether (RNDIS) on/off |
| `/hotspot_on [SSID password]` | Wi‑Fi hotspot on (optional SSID/password or defaults/config) |
| `/hotspot_off` | Hotspot off |
| `/wifi_on`, `/wifi_off` | Wi‑Fi on/off (`svc` / `cmd wifi`) |
| `/bt_on`, `/bt_off` | Bluetooth on/off (`svc` / `cmd bluetooth_manager`) |
| `/shutdown` | Power off |
| `/restart` | Reboot |

Avoid spamming `/shutdown` and `/restart` because queued commands can cause repeated reboots.

### Security

- **Never publish your bot token** and do not let strangers use your bot.
- Treat `config.sh` (and any local overrides) as secrets — do not commit them to a public repository.

### Repository layout & web development (optional)

- **`service.sh`**, **`lib/*.sh`**: on-device module logic.
- **`web/`**: ZIP builder (Next.js). Local dev: `cd web && npm install && npm run dev`.
- Production build: `cd web && npm run build` (runs `prebuild` to sync module files into `web/module-files`).

### Language (VI/EN selection → download language-only module)

The website has 2 display languages: **Vietnamese (vi)** and **English (en)**. When downloading the ZIP, the UI sends `lang` to the API so the server packages the correct file set:

- `lang=vi` → package from `web/module-files-vi`
- `lang=en` → package from `web/module-files-en`
- If a language folder is missing, it falls back to `web/module-files`

To make the downloaded ZIP contain **only** your intended language variant, put your language-specific overrides (mirroring the module root layout) under:

- `module-overrides/vi/...`
- `module-overrides/en/...`

During build (`npm run build`), `web/scripts/sync-module.mjs` copies the base module into `web/module-files-vi|en` and then **overrides** files from `module-overrides/<lang>/`.
