import { getSiteOrigin, getSiteUrl } from "../../lib/site-url";

const SITE_NAME = "TelegramControl";

export default function SiteJsonLd() {
  const url = getSiteUrl().href.replace(/\/$/, "");
  const origin = getSiteOrigin();

  const graph = [
    {
      "@type": "WebSite",
      "@id": `${origin}/#website`,
      name: SITE_NAME,
      url: origin,
      description:
        "Magisk module builder: Telegram bot remote control for Android. · Tạo ZIP module điều khiển điện thoại qua Telegram.",
      inLanguage: ["vi", "en"],
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${origin}/#software`,
      name: SITE_NAME,
      applicationCategory: "UtilitiesApplication",
      operatingSystem: "Android",
      offers: {
        "@type": "Offer",
        price: "0",
        priceCurrency: "USD",
      },
      description:
        "Download a configured Magisk module ZIP with Telegram bot token and chat ID embedded in config.sh.",
    },
    {
      "@type": "WebPage",
      "@id": `${url}#webpage`,
      url,
      name: `${SITE_NAME} — Magisk module builder`,
      isPartOf: { "@id": `${origin}/#website` },
    },
  ];

  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": graph,
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  );
}
