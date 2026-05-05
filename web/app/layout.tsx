import type { Metadata, Viewport } from "next";
import "./globals.css";
import SiteJsonLd from "./components/site-json-ld";
import { getSiteUrl } from "../lib/site-url";

const siteUrl = getSiteUrl();

export const metadata: Metadata = {
  metadataBase: siteUrl,
  title: {
    // 50–60 chars, keyword-left (Google).
    default: "Magisk Telegram Control - Tạo module điều khiển Android",
    template: "%s | Magisk Telegram Control",
  },
  description:
    // 150–160 chars, keyword + CTA (Google).
    "Tạo Magisk module điều khiển Android qua Telegram bot: nhúng token/chat id, tải ZIP và flash. Bắt đầu ngay để quản lý máy từ xa an toàn.",
  applicationName: "TelegramControl",
  authors: [{ name: "Zakshin (Hải Nghĩa)" }],
  icons: {
    icon: [{ url: "/logo.png" }],
    apple: [{ url: "/logo.png" }],
  },
  keywords: [
    "Magisk",
    "Magisk module",
    "Telegram bot",
    "Android",
    "TelegramControl",
    "ZIP builder",
    "remote control",
    "điều khiển điện thoại",
    "module Magisk",
    "BotFather",
    "config.sh",
    "điện thoại Android",
  ],
  alternates: {
    canonical: "/",
    languages: {
      vi: "/",
      "x-default": "/",
      en: "/",
    },
  },
  openGraph: {
    type: "website",
    locale: "vi_VN",
    alternateLocale: ["en_US"],
    url: siteUrl,
    siteName: "TelegramControl",
    title: "Tạo Magisk module điều khiển Android qua Telegram",
    description:
      "Build ZIP module Magisk với token/chat id sẵn sàng flash. Chia sẻ link đẹp trên Facebook và hiển thị chuẩn Google.",
    images: [
      {
        url: "/og",
        width: 1200,
        height: 630,
        alt: "Magisk Telegram Control - Tạo module điều khiển Android",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Magisk Telegram Control - Tạo module điều khiển Android",
    description:
      "Tạo ZIP module Magisk nhúng token/chat id để điều khiển Android qua Telegram bot. Tải về và flash ngay.",
    images: ["/og"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true },
  },
  appleWebApp: {
    capable: true,
    title: "TelegramControl",
    statusBarStyle: "black-translucent",
  },
  formatDetection: {
    telephone: false,
    email: false,
    address: false,
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "#0c0f14" },
    { media: "(prefers-color-scheme: light)", color: "#eef2f9" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="vi" suppressHydrationWarning data-theme="dark">
      <body>
        <SiteJsonLd />
        {children}
      </body>
    </html>
  );
}
