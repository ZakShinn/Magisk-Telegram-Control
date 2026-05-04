import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "TelegramControl — Magisk · Telegram bot",
    short_name: "TelegramControl",
    description:
      "Build a Magisk module ZIP with Telegram bot config. · Tạo ZIP module nhúng Bot Token và Chat ID.",
    start_url: "/",
    display: "standalone",
    background_color: "#0a0508",
    theme_color: "#12070e",
    lang: "vi",
    icons: [
      {
        src: "/logo.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "any",
      },
    ],
  };
}
