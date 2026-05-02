/** Base URL cho canonical, OG, sitemap (ưu tiên NEXT_PUBLIC_SITE_URL, rồi VERCEL_URL). */
export function getSiteUrl(): URL {
  const explicit = process.env.NEXT_PUBLIC_SITE_URL?.trim();
  if (explicit) {
    let u = explicit.replace(/\/$/, "");
    if (!/^https?:\/\//i.test(u)) u = `https://${u}`;
    return new URL(u);
  }
  const vercel = process.env.VERCEL_URL?.trim();
  if (vercel) return new URL(`https://${vercel.replace(/^https?:\/\//, "")}`);
  return new URL("http://localhost:3000");
}

export function getSiteOrigin(): string {
  return getSiteUrl().origin;
}
