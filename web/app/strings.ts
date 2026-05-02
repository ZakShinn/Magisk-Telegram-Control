export type Lang = "vi" | "en";

export const STR = {
  vi: {
    skipToContent: "Bỏ qua đến nội dung",
    donateQrAlt:
      "Mã QR VietQR ủng hộ — MB Bank 0968884946 — Võ Hoàng Hải Nghĩa",
    title: "TelegramControl · Builder ZIP module",
    lead:
      "Nhập Bot Token và Chat ID để tạo file ZIP module Magisk đã nhúng config.sh. Tải về và flash trong Magisk như module thông thường.",
    tokenLabel: "Bot token (@BotFather)",
    chatLabel: "Chat ID",
    chatPh: "-100xxxxxxxx hoặc số User ID",
    smsLabel:
      "Chuyển tiếp SMS mới lên Telegram (SMS_FORWARD=1) — mặc định bật, bỏ tích để tắt. OTP có thể lộ; ROM cần cho phép đọc content://sms / kho SMS.",
    submit: "Tải TelegramControl.zip",
    submitting: "Đang đóng gói…",
    hint:
      "Sau khi cài và khởi động lại: chỉ Chat ID đã nhập mới có quyền điều khiển bot.",
    errNetwork: "Không tải được — kiểm tra mạng hoặc thử lại.",
    errContactHint: "Nếu vẫn gặp lỗi hoặc cần hỗ trợ:",
    errContactLink: "liên hệ qua Facebook",
    themeDark: "Tối",
    themeLight: "Sáng",
    langVi: "Tiếng Việt",
    langEn: "English",
    donateTitle: "Ủng hộ",
    donateRecipient: "Võ Hoàng Hải Nghĩa",
    donateBankName: "Ngân hàng MB",
    contactFacebook: "Liên hệ · Báo lỗi (Facebook)",
    partnerFooter:
      "TelegramControl · Module Magisk điều khiển thiết bị Android qua Telegram.",
  },
  en: {
    skipToContent: "Skip to content",
    donateQrAlt:
      "VietQR donate — MB Bank 0968884946 — Vo Hoang Hai Nghia",
    title: "TelegramControl · Magisk ZIP builder",
    lead:
      "Enter your Bot Token and Chat ID to build a Magisk module ZIP with embedded config.sh. Download and flash in Magisk as usual.",
    tokenLabel: "Bot token (@BotFather)",
    chatLabel: "Chat ID",
    chatPh: "-100xxxxxxxx or numeric user ID",
    smsLabel:
      "Forward new SMS (SMS_FORWARD=1) — on by default, uncheck to disable. OTPs may leak; ROM must allow SMS provider / database access.",
    submit: "Download TelegramControl.zip",
    submitting: "Building ZIP…",
    hint:
      "After install and reboot: only the Chat ID you entered can control the bot.",
    errNetwork: "Download failed — check your connection and retry.",
    errContactHint: "If the problem persists or you need support:",
    errContactLink: "contact via Facebook",
    themeDark: "Dark",
    themeLight: "Light",
    langVi: "Tiếng Việt",
    langEn: "English",
    donateTitle: "Donate",
    donateRecipient: "Võ Hoàng Hải Nghĩa",
    donateBankName: "MB Bank",
    contactFacebook: "Contact · Report issues (Facebook)",
    partnerFooter:
      "TelegramControl · Magisk module for Android control via Telegram.",
  },
} as const;

export type Strings = (typeof STR)[Lang];

export function pick(lang: Lang): Strings {
  return STR[lang];
}
