import type { MetadataRoute } from "next";
import { getSiteOrigin, getSiteUrl } from "../lib/site-url";

export default function robots(): MetadataRoute.Robots {
  const origin = getSiteOrigin();
  return {
    rules: [{ userAgent: "*", allow: "/" }],
    sitemap: `${origin}/sitemap.xml`,
    host: getSiteUrl().host,
  };
}
