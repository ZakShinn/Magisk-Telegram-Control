
<<<<<<< HEAD

# TelegramControl — điều khiển máy Android qua Telegram  
**[Tiếng Việt](#vi)** · **[English](#en)**

## 🇻🇳 Tiếng Việt

### Trang web để tải bản cài

1. Mở **[magisk-telegram-control.vercel.app](https://magisk-telegram-control.vercel.app)** trên trình duyệt máy tính hoặc điện thoại (trên trang đó có sẵn hai nút chọn **Tiếng Việt** / **English** cho ngôn ngữ giao diện).
2. Dán **mã bot** và **Chat ID** của bạn (thông tin bạn có được khi tạo và dùng bot trên Telegram).
3. Nếu bạn muốn **mọi tin nhắn SMS mới** tự gửi vào Telegram, đánh dấu ô đó — **tin có mã xác nhận (OTP) cũng có thể đi vào Telegram**, chỉ dùng khi bạn thật sự cần.
4. Bấm nút để **tải file ZIP** (tên file mặc định có thể là TelegramControl.zip).
5. Cài ZIP đó bằng **Magisk** (giống cài các module làm chủ máy có root), rồi **khởi động lại** máy khi được hỏi hoặc khi thấy máy chưa chạy ứng dụng.

Sau khi cài xong: mở Telegram, chỉ trong **đúng cuộc trò chuyện** với bot đã được bạn nhập vào là bạn có thể **xin thông tin máy** và **điều khiển các việc** mà TelegramControl mang lại — **đừng xem các cuộc trò chuyện đó của người lạ.**

### Lệnh trên Telegram (gửi vào đúng chat với bot)


| Lệnh                                                                                   | Để làm gì                                                                                 |
| -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `/help`, `/start`                                                                      | Xem toàn bộ lệnh.                                                                         |
| `/ping`                                                                                | Kiểm tra bot đang hoạt động và thời gian máy đã bật bao lâu.                              |
| `/status`                                                                              | Gửi báo cáo tổng hợp tình trạng máy.                                                      |
| `/signal`                                                                              | Xem sóng, loại mạng và nhà mạng hiển thị.                                                 |
| `/ip`                                                                                  | Xem địa chỉ mạng trên máy và IP ra internet (nếu lấy được).                               |
| `/battery`                                                                             | Xem pin, nhiệt độ, có đang sạc không, v.v.                                                |
| `/datausage`                                                                           | Xem lưu lượng đã xài của dữ liệu di động và Wi‑Fi.                                        |
| `/sms`                                                                                 | Xem một số tin SMS gần đây trên máy.                                                      |
| `/hotspot_on`, `/hotspot_off`                                                          | Bật hoặc tắt phát Wi‑Fi chia sẻ mạng.                                                     |
| `/rndis_on`, `/rndis_off`                                                              | Bật hoặc tắt chia sẻ mạng qua cáp USB (RNDIS).                                            |
| `/ttl`, `/ttl_sync`, `/ttl 65`                                                         | Chỉnh TTL khi đang chia sẻ mạng — **chỉ chạy khi bạn gõ** (có thể thêm số sau `/ttl`).    |
| `/anydesk_fix`                                                                         | Mở quyền cho AnyDesk để chia sẻ màn hình từ xa ổn hơn.                                    |
| `/apn list`                                                                            | Liệt kê bảng cấu hình APN gợi ý (nhà mạng Việt Nam).                                      |
| `/apn auto`                                                                            | Thử đoán nhà mạng theo SIM rồi áp cấu hình APN tương ứng.                                 |
| `/apn viettel`, `/apn vinaphone`, `/apn mobifone`, `/apn vietnamobile`, `/apn gmobile` | Thêm và chọn một cấu hình APN theo nhà mạng để vào được dữ liệu di động khi hay lỗi mạng. |
| `/shutdown`                                                                            | **Tắt máy** (xin gọi chỉ khi bạn chủ động muốn tắt).                                      |
| `/restart`                                                                             | **Khởi động lại máy**.                                                                    |


**Lưu ý:** Tin SMS mới có thể tự gửi lên Telegram không cần lệnh riêng nếu bạn **đã bật tùy chọn đó lúc tải ZIP** trên web — trong đó có thể có tin OTP, hãy cân nhắc bảo mật. Sau khi cài máy, bot cũng có thể **nhắn báo pin thấp** hoặc gửi **báo cáo khởi động** (không phải lệnh bạn gõ).

**[⇧ Lên đầu · Back to language switch](#top)**



## 🇬🇧 English

**➜** [Jump to Tiếng Việt](#vi)

### Website to download your module

1. Open **[magisk-telegram-control.vercel.app](https://magisk-telegram-control.vercel.app)** in any browser—the site offers **Vietnamese / English** toggle buttons so you can pick the UI language quickly.
2. Paste your bot **token** and **chat ID** (the values from when you configured your Telegram bot).
3. Only tick **SMS forwarding** if you really want new text messages echoed to Telegram—**that may include OTPs and private notices**, so use it thoughtfully.
4. Download the ZIP (the suggested filename may be TelegramControl.zip).
5. Flash it inside **Magisk** like every other root module, then **reboot** if prompted or until the automation starts behaving as expected.

Once installed: in Telegram only the **conversation you wired up** during setup can chat with your bot — **avoid letting strangers use or see that bot chat.**

### Telegram commands (sent in your bot chat)


| Command                                                                                | What it does                                                                                       |
| -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `/help`, `/start`                                                                      | Shows the whole command menu.                                                                      |
| `/ping`                                                                                | Confirms the bot is alive plus how long Android has stayed up since boot.                          |
| `/status`                                                                              | Sends one bundled health/status report snapshot.                                                   |
| `/signal`                                                                              | Shows signal/network type and the carrier name surfaced by the handset.                            |
| `/ip`                                                                                  | Lists local IPs on the interfaces (and tries to reveal the public-facing IP once).                 |
| `/battery`                                                                             | Shows charge level, temperature, plugged state, etc.                                               |
| `/datausage`                                                                           | Shows cumulative mobile‑data vs Wi‑Fi usage totals.                                                |
| `/sms`                                                                                 | Lists a handful of the latest SMS conversations that the module can read.                          |
| `/hotspot_on`, `/hotspot_off`                                                          | Enables or disables portable Wi‑Fi hotspot sharing.                                                |
| `/rndis_on`, `/rndis_off`                                                              | Enables or disables USB tethering/RNDIS tethering flow.                                            |
| `/ttl`, `/ttl_sync`, `/ttl 65`                                                         | Applies tether TTL tweaking **only while you intentionally run it** (optional value after `/ttl`). |
| `/anydesk_fix`                                                                         | Grants AnyDesk the media permission it needs for smoother remote screen share.                     |
| `/apn list`                                                                            | Prints the Vietnamese carrier APN preset lookup table.                                             |
| `/apn auto`                                                                            | Guesses the carrier from the SIM and applies the matching preset.                                  |
| `/apn viettel`, `/apn vinaphone`, `/apn mobifone`, `/apn vietnamobile`, `/apn gmobile` | Adds/selects the preset APN for that carrier when mobile data misbehaves.                          |
| `/shutdown`                                                                            | **Powers the phone off**—only send this when you really mean it.                                   |
| `/restart`                                                                             | **Reboots the phone**.                                                                             |


**Note:** New SMS can still stream up to Telegram **without** a dedicated command if you **enabled that checkbox on the download page**—OTPs may appear there. After install the module may also **ping you on low battery** or **post a boot summary** automatically; those are not commands you type.

**[⇧ Back to language switch · Lên phần chọn ngôn ngữ](#top)**