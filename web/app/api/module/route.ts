import fs from "fs";
import path from "path";
import JSZip from "jszip";
import { NextResponse } from "next/server";

export const runtime = "nodejs";

const TOKEN_RE = /^[0-9]+:[A-Za-z0-9_-]+$/;
const CHAT_RE = /^-?[0-9]+$/;

function shSingleQuoted(value: string): string {
  return `'${value.replace(/'/g, "'\\''")}'`;
}

function jsonBilingual(status: number, vi: string, en: string) {
  return NextResponse.json({ errorVi: vi, errorEn: en }, { status });
}

export async function POST(req: Request) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonBilingual(400, "JSON không hợp lệ.", "Invalid JSON body.");
  }

  const anydeskAutoMedia =
    typeof body === "object" && body !== null && "anydeskAutoMedia" in body
      ? Boolean((body as { anydeskAutoMedia?: unknown }).anydeskAutoMedia)
      : false;

  const token =
    typeof body === "object" && body !== null && "token" in body
      ? String((body as { token?: unknown }).token ?? "").trim()
      : "";
  const chatId =
    typeof body === "object" && body !== null && "chatId" in body
      ? String((body as { chatId?: unknown }).chatId ?? "").trim()
      : "";

  if (!TOKEN_RE.test(token)) {
    return jsonBilingual(
      400,
      "Bot token không đúng định dạng.",
      "Bot token format looks invalid.",
    );
  }

  if (!CHAT_RE.test(chatId)) {
    return jsonBilingual(
      400,
      "Chat ID không đúng định dạng.",
      "Chat ID format looks invalid.",
    );
  }

  const root = path.join(process.cwd(), "module-files");
  const needed = [
    "module.prop",
    "service.sh",
    "customize.sh",
    path.join("lib", "common.sh"),
  ];

  for (const rel of needed) {
    if (!fs.existsSync(path.join(root, rel))) {
      return jsonBilingual(
        500,
        "Thiếu module-files — chạy npm run build trong thư mục web (prebuild đồng bộ + sqlite).",
        "Missing module-files — run npm run build in web/ (prebuild sync + sqlite).",
      );
    }
  }

  // Files must live at ZIP root — Magisk only recognizes module.prop / META-INF at archive root,
  // not inside an extra wrapping folder (would show "not a Magisk module").
  const zip = new JSZip();

  const walk = (relDir: string) => {
    const absDir = path.join(root, relDir);
    for (const name of fs.readdirSync(absDir)) {
      const rel = path.join(relDir, name);
      const abs = path.join(root, rel);
      const st = fs.statSync(abs);
      if (st.isDirectory()) walk(rel);
      else zip.file(rel.replace(/\\/g, "/"), fs.readFileSync(abs));
    }
  };

  for (const name of fs.readdirSync(root)) {
    const abs = path.join(root, name);
    const st = fs.statSync(abs);
    if (st.isDirectory()) walk(name);
    else zip.file(name, fs.readFileSync(abs));
  }

  const configBody =
    `# TelegramControl — sinh tự động (đừng chia sẻ file này)\n` +
    `TELEGRAM_TOKEN=${shSingleQuoted(token)}\n` +
    `TELEGRAM_CHAT_ID=${shSingleQuoted(chatId)}\n` +
    (anydeskAutoMedia ? `ANYDESK_AUTO_MEDIA=1\n` : "");

  zip.file("config.sh", configBody);

  const buf = await zip.generateAsync({
    type: "nodebuffer",
    compression: "DEFLATE",
    compressionOptions: { level: 9 },
  });

  return new NextResponse(new Uint8Array(buf), {
    status: 200,
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": 'attachment; filename="TelegramControl.zip"',
      "Cache-Control": "no-store",
    },
  });
}
