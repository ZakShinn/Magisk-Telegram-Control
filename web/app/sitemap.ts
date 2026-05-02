import type { MetadataRoute } from "next";
import { getSiteOrigin } from "../lib/site-url";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = getSiteOrigin();
  return [
    {
      url: base.endsWith("/") ? base.slice(0, -1) : base,
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 1,
    },
  ];
}
