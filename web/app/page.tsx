"use client";

import { useEffect, useState } from "react";
import { pick, type Lang } from "./strings";

const DONATE_STK = "0968884946";
const DONATE_VIETQR_URL =
  "https://img.vietqr.io/image/MB-0968884946-compact.png?addTag=ZakshinTools";
const CONTACT_FACEBOOK_URL =
  "https://www.facebook.com/profile.php?id=100006985387032";

const LS_THEME = "tg-module-theme";
const LS_LANG = "tg-module-lang";

type Theme = "dark" | "light";

export default function HomePage() {
  const [theme, setTheme] = useState<Theme>("dark");
  const [lang, setLang] = useState<Lang>("vi");
  const [mounted, setMounted] = useState(false);

  const [token, setToken] = useState("");
  const [chatId, setChatId] = useState("");
  const [smsForward, setSmsForward] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const t = pick(lang);

  useEffect(() => {
    setMounted(true);
    try {
      const st = localStorage.getItem(LS_THEME) as Theme | null;
      const sl = localStorage.getItem(LS_LANG) as Lang | null;
      if (st === "light" || st === "dark") setTheme(st);
      if (sl === "en" || sl === "vi") setLang(sl);
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    if (!mounted) return;
    document.documentElement.setAttribute("data-theme", theme);
    try {
      localStorage.setItem(LS_THEME, theme);
    } catch {
      /* ignore */
    }
  }, [theme, mounted]);

  useEffect(() => {
    if (!mounted) return;
    document.documentElement.lang = lang === "vi" ? "vi" : "en";
    try {
      localStorage.setItem(LS_LANG, lang);
    } catch {
      /* ignore */
    }
  }, [lang, mounted]);

  async function downloadZip(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch("/api/module", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: token.trim(),
          chatId: chatId.trim(),
          smsForward,
        }),
      });
      if (!res.ok) {
        const j = await res.json().catch(() => ({}));
        const msg =
          lang === "vi"
            ? (typeof j.errorVi === "string" ? j.errorVi : null) ??
              (typeof j.error === "string" ? j.error : null)
            : (typeof j.errorEn === "string" ? j.errorEn : null) ??
              (typeof j.error === "string" ? j.error : null);
        setError(msg ?? `HTTP ${res.status}`);
        return;
      }
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "TelegramControl.zip";
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      setError(t.errNetwork);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page-shell">
      <a href="#main-content" className="skip-link">
        {t.skipToContent}
      </a>
      <header className="toolbar">
        <div className="toggle-group" role="group" aria-label="Theme">
          <button
            type="button"
            className={theme === "dark" ? "active" : ""}
            onClick={() => setTheme("dark")}
          >
            {t.themeDark}
          </button>
          <button
            type="button"
            className={theme === "light" ? "active" : ""}
            onClick={() => setTheme("light")}
          >
            {t.themeLight}
          </button>
        </div>
        <div className="toggle-group" role="group" aria-label="Language">
          <button
            type="button"
            className={lang === "vi" ? "active" : ""}
            onClick={() => setLang("vi")}
          >
            {t.langVi}
          </button>
          <button
            type="button"
            className={lang === "en" ? "active" : ""}
            onClick={() => setLang("en")}
          >
            {t.langEn}
          </button>
        </div>
      </header>

      <main id="main-content" className="main-content" tabIndex={-1}>
        <article className="card" aria-labelledby="page-title">
          <h1 id="page-title">{t.title}</h1>
          <p className="lead">{t.lead}</p>

          <form onSubmit={downloadZip} aria-busy={loading}>
          <div className="field">
            <label htmlFor="token">{t.tokenLabel}</label>
            <input
              id="token"
              name="token"
              autoComplete="off"
              placeholder="123456789:AA..."
              value={token}
              onChange={(ev) => setToken(ev.target.value)}
              spellCheck={false}
            />
          </div>

          <div className="field">
            <label htmlFor="chatId">{t.chatLabel}</label>
            <input
              id="chatId"
              name="chatId"
              autoComplete="off"
              placeholder={t.chatPh}
              value={chatId}
              onChange={(ev) => setChatId(ev.target.value)}
              spellCheck={false}
            />
          </div>

          <div className="field checkbox-field">
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={smsForward}
                onChange={(ev) => setSmsForward(ev.target.checked)}
              />
              <span>{t.smsLabel}</span>
            </label>
          </div>

          <button type="submit" disabled={loading}>
            {loading ? t.submitting : t.submit}
          </button>

          {error ? (
            <div className="err-block">
              <div className="err" role="alert">
                {error}
              </div>
              <p className="err-hint">
                {t.errContactHint}{" "}
                <a
                  href={CONTACT_FACEBOOK_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {t.errContactLink}
                </a>
                .
              </p>
            </div>
          ) : null}

          <div className="hint">{t.hint}</div>
        </form>

        <footer className="footer-card">
          <h2>{t.donateTitle}</h2>
          <div className="donate-qr-wrap">
            <img
              className="donate-qr"
              src={DONATE_VIETQR_URL}
              width={220}
              height={220}
              alt={t.donateQrAlt}
              decoding="async"
              loading="lazy"
              fetchPriority="low"
            />
            <div className="donate-meta">
              <div>
                <strong>{t.donateRecipient}</strong>
              </div>
              <div className="bank">
                {t.donateBankName} · {DONATE_STK}
              </div>
            </div>
          </div>

          <div className="links-row">
            <a
              href={CONTACT_FACEBOOK_URL}
              target="_blank"
              rel="noopener noreferrer"
            >
              {t.contactFacebook}
            </a>
          </div>

          <p className="footer-tagline">{t.partnerFooter}</p>
        </footer>
        </article>
      </main>
    </div>
  );
}
