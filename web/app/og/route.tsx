import { ImageResponse } from "next/og";

export const runtime = "edge";

export const size = {
  width: 1200,
  height: 630,
};

export const contentType = "image/png";

export function GET() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "linear-gradient(135deg, #0c0f14 0%, #121a2a 55%, #0c0f14 100%)",
          color: "#eaf1ff",
          padding: 64,
          fontFamily:
            'ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji", "Segoe UI Emoji"',
        }}
      >
        <div
          style={{
            width: "100%",
            height: "100%",
            display: "flex",
            flexDirection: "column",
            justifyContent: "space-between",
            border: "1px solid rgba(255,255,255,0.14)",
            borderRadius: 36,
            padding: 56,
            background: "rgba(8, 12, 18, 0.55)",
          }}
        >
          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            <div style={{ display: "flex", gap: 14, alignItems: "center" }}>
              <div
                style={{
                  width: 18,
                  height: 18,
                  borderRadius: 999,
                  background: "#7aa8ff",
                  boxShadow: "0 0 0 6px rgba(122,168,255,0.16)",
                }}
              />
              <div style={{ fontSize: 28, opacity: 0.92 }}>TelegramControl</div>
            </div>

            <div style={{ fontSize: 60, lineHeight: 1.1, fontWeight: 800 }}>
              Magisk Telegram Control
            </div>
            <div style={{ fontSize: 34, lineHeight: 1.2, opacity: 0.9 }}>
              Tạo ZIP module điều khiển Android qua Telegram bot
            </div>
          </div>

          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "flex-end",
              gap: 24,
              fontSize: 26,
              opacity: 0.85,
            }}
          >
            <div>Nhúng token/chat id · Tải ZIP · Flash Magisk</div>
            <div style={{ opacity: 0.8 }}>magisk-telegram-control.vercel.app</div>
          </div>
        </div>
      </div>
    ),
    size,
  );
}

