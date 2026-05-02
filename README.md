# TelegramControl

README **song ngữ**: phần **Tiếng Việt** ở trên, **English** ở dưới.

---

## Tiếng Việt

Module Magisk chạy bot Telegram trên điện thoại (long polling); chỉ **một Chat ID** đã cấu hình mới được gửi lệnh.

### Các tính năng

- **Thông tin thiết bị:** `/status` (báo cáo tổng hợp), `/signal` (sóng, loại mạng, band nếu đọc được), `/ip`, `/battery`, `/datausage`, `/ping`.
- **SMS:** `/sms` xem tin gần đây (khi đọc được `mmssms.db` và có `sqlite3` trong module). Tuỳ chọn **`SMS_FORWARD=1`** trong `config.sh` để chuyển tiếp SMS mới lên Telegram — **OTP có thể lộ**, chỉ bật khi chấp nhận rủi ro.
- **Chia sẻ mạng:** `/hotspot_on` · `/hotspot_off`, `/rndis_on` · `/rndis_off`.
- **TTL tether:** `/ttl` hoặc `/ttl_sync` — **chỉ khi bạn gõ lệnh** (ví dụ `/ttl 65`); không tự bật khi hotspot/RNDIS hay khi khởi động.
- **AnyDesk:** `/anydesk_fix` cấp quyền phù hợp để chia sẻ màn hình ổn hơn.
- **APN (nhà mạng VN):** `/apn list`, `/apn auto`, `/apn viettel|vinaphone|mobifone|vietnamobile|gmobile` — ghi preset và đặt làm APN đang dùng (cần kiểm tra data sau khi áp dụng).
- **Nguồn:** `/shutdown`, `/restart`.
- **Khác:** tin nhắn khi bot khởi động; có thể gửi `/status` sau khi có mạng lúc boot; giám sát **pin thấp** và cảnh báo qua Telegram.

Danh sách lệnh đầy đủ và mô tả chi tiết: gõ **`/help`** hoặc **`/start`** trên Telegram.

### Hướng dẫn sử dụng

1. **Chuẩn bị Telegram:** tạo bot với [@BotFather](https://t.me/BotFather), lấy **token**; xác định **Chat ID** của bạn (chỉ chat đó được điều khiển).
2. **Cấu hình:**
   - **Cách A:** đổi tên `config.sh.example` thành `config.sh`, điền `TELEGRAM_TOKEN` và `TELEGRAM_CHAT_ID`. Tuỳ chọn chỉnh `SMS_FORWARD`, timeout polling, TTL, gói AnyDesk, v.v. theo chú thích trong file.
   - **Cách B:** dùng ứng dụng web trong thư mục `web/` để build ZIP đã nhúng `config.sh`, rồi cài ZIP đó (xem `web/package.json`: `npm install`, `npm run build`).
3. **Cài trên máy:** đóng gói module theo chuẩn Magisk (đủ `module.prop`, `service.sh`, `customize.sh`, `lib/`, `bin/`, `config.sh`, …) và flash trong Magisk Manager; khởi động lại nếu cần.
4. **Dùng hằng ngày:** mở chat với bot, gõ lệnh (ví dụ `/help`). Tránh spam nhiều lệnh liên tiếp.
5. **Bảo mật:** không chia sẻ token, chat ID hay file ZIP có config; ai có token/chat đúng có thể điều khiển máy qua các lệnh module.

---

## English

Magisk module that runs a Telegram bot on the device (long polling). Only your **configured Chat ID** may send commands.

### Features

- **Device info:** `/status` (aggregated report), `/signal` (signal, network type, band when available), `/ip`, `/battery`, `/datausage`, `/ping`.
- **SMS:** `/sms` for recent messages (requires readable `mmssms.db` and bundled `sqlite3`). Optional **`SMS_FORWARD=1`** in `config.sh` forwards new SMS to Telegram — **OTPs may leak**; enable only if you accept the risk.
- **Tethering:** `/hotspot_on` · `/hotspot_off`, `/rndis_on` · `/rndis_off`.
- **TTL tether:** `/ttl` or `/ttl_sync` — **only when you send the command** (e.g. `/ttl 65`); not applied automatically for hotspot/RNDIS or at boot.
- **AnyDesk:** `/anydesk_fix` adjusts permissions for smoother screen sharing.
- **APN (Vietnamese carriers):** `/apn list`, `/apn auto`, `/apn viettel|vinaphone|mobifone|vietnamobile|gmobile` — writes a preset and selects it (verify mobile data afterward).
- **Power:** `/shutdown`, `/restart`.
- **Other:** startup message from the bot; optional `/status`-style report after boot when network is up; **low-battery** monitoring via Telegram.

Full command list: send **`/help`** or **`/start`** to the bot.

### How to use

1. **Telegram:** create a bot with [@BotFather](https://t.me/BotFather), copy the **token**; know your **Chat ID** (only that chat can control the device).
2. **Configure:**
   - **Option A:** rename `config.sh.example` to `config.sh`, set `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`. Optionally adjust `SMS_FORWARD`, poll timeouts, TTL, AnyDesk package, etc., as commented in the file.
   - **Option B:** use the web app under `web/` to build a ZIP with embedded `config.sh`, then install that ZIP (see `web/package.json`: `npm install`, `npm run build`).
3. **Install:** zip the Magisk module layout (`module.prop`, `service.sh`, `customize.sh`, `lib/`, `bin/`, `config.sh`, …) and flash it in Magisk Manager; reboot if prompted.
4. **Daily use:** open the bot chat and send commands (e.g. `/help`). Avoid sending many commands back-to-back.
5. **Security:** do not share your token, chat ID, or ZIPs containing config — anyone with valid credentials could control the device through this module.
