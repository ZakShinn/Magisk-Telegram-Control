import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "TelegramControl — Magisk · Telegram bot",
    short_name: "TelegramControl",
    description:
      "Build a Magisk module ZIP with Telegram bot config. · Tạo ZIP module nhúng Bot Token và Chat ID.",
    start_url: "/",
    display: "standalone",
    background_color: "#0c0f14",
    theme_color: "#151a22",
    lang: "vi",
  };
}
