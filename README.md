# TelegramControl — điều khiển máy Android qua Telegram
**[Tiếng Việt](#vi)** · **[English](#en)**

## <a id="vi"></a>Tiếng Việt

### Mô tả nhanh
TelegramControl là module Magisk chạy nền (`service.sh`) để nhận lệnh từ Telegram Bot và thực hiện các thao tác cơ bản trên máy.

**Module hiện tại:**
- **Không dùng `sqlite3`**
- **Không có** SMS/APN/AnyDesk/TTL
- `/status` là **tính năng nội bộ**: bot gọi `handle_status_send` trong `lib/status.sh` (không cần chạy `status.sh` độc lập)

### Cài đặt
- Cài ZIP module bằng Magisk như bình thường, rồi reboot.
- Mở `service.sh` và sửa 2 dòng sau cho đúng bot của bạn:
  - `TELEGRAM_TOKEN="..."`
  - `TELEGRAM_CHAT_ID="..."`

### Lệnh hỗ trợ
- `/help`, `/start`: xem danh sách lệnh
- `/status`: báo cáo tổng hợp hệ thống
- `/signal`: thông tin sóng (nhà mạng, loại mạng, band, dBm)
- `/ip`: IP nội bộ + public IP (nếu lấy được)
- `/battery`: thông tin pin hiện tại
- `/datausage`: thống kê lưu lượng realtime
- `/rndis_on`, `/rndis_off`: bật/tắt RNDIS (USB tether)
- `/hotspot_on`, `/hotspot_off`: bật/tắt phát Wi‑Fi
- `/shutdown`: tắt máy
- `/restart`: khởi động lại

### Bảo mật
Hiện bot sẽ lấy `chat_id` từ tin nhắn đến (để trả lời), nên **không chia sẻ bot/token** và **không để người lạ biết bot của bạn**.

## <a id="en"></a>English

### Quick overview
TelegramControl is a Magisk module that runs in background (`service.sh`) and listens for Telegram bot commands to control basic device actions.

**Current module behavior:**
- **No `sqlite3`**
- **No** SMS/APN/AnyDesk/TTL features
- `/status` is **internal**: the bot calls `handle_status_send` from `lib/status.sh` (no standalone `status.sh` script)

### Install
- Flash the ZIP in Magisk, then reboot.
- Edit `service.sh` and set:
  - `TELEGRAM_TOKEN="..."`
  - `TELEGRAM_CHAT_ID="..."`

### Supported commands
- `/help`, `/start`: show commands
- `/status`: full system snapshot
- `/signal`: signal/network info
- `/ip`: local IPs + public IP (best effort)
- `/battery`: battery info
- `/datausage`: realtime traffic summary
- `/rndis_on`, `/rndis_off`: USB tether (RNDIS) on/off
- `/hotspot_on`, `/hotspot_off`: Wi‑Fi hotspot on/off
- `/shutdown`: power off
- `/restart`: reboot

### Security note
The bot replies based on incoming `chat_id`. **Keep your bot/token private** and do not expose the bot chat to strangers.
