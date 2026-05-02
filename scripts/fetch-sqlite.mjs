/**
 * Tải sqlite3 (gói Termux, ELF Android/bionic) cho arm/arm64/x86/i686,
 * giải nén data.tar.xz và copy nhị phân vào repo/bin/.
 *
 * Chạy: node scripts/fetch-sqlite.mjs  [--force]
 * Cần: Node 18+, tar hỗ trợ -xJf (Windows 10+ thường có).
 */

import fs from "fs";
import https from "https";
import http from "http";
import path from "path";
import os from "os";
import { fileURLToPath } from "url";
import { execFileSync } from "child_process";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const binDir = path.join(repoRoot, "bin");

const POOL =
  "https://packages.termux.dev/apt/termux-main/pool/main/s/sqlite/";
const ARCH_MAP = [
  { suffix: "aarch64", out: "sqlite3.arm64" },
  { suffix: "arm", out: "sqlite3.arm" },
  { suffix: "x86_64", out: "sqlite3.x86_64" },
  { suffix: "i686", out: "sqlite3.x86" },
];

function fetchBuffer(url) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith("https") ? https : http;
    lib
      .get(url, (res) => {
        const loc = res.headers.location;
        if ((res.statusCode === 301 || res.statusCode === 302) && loc) {
          fetchBuffer(new URL(loc, url).href).then(resolve).catch(reject);
          return;
        }
        if (res.statusCode !== 200) {
          reject(new Error(`${url} → HTTP ${res.statusCode}`));
          return;
        }
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve(Buffer.concat(chunks)));
      })
      .on("error", reject);
  });
}

function extractDataTarXzFromDeb(debBuf) {
  const magic = debBuf.slice(0, 8).toString("ascii");
  if (magic !== "!<arch>\n") throw new Error("Không phải file .deb (ar)");

  let off = 8;
  while (off + 60 <= debBuf.length) {
    const hdr = debBuf.slice(off, off + 60);
    const name = hdr.slice(0, 16).toString("ascii").replace(/\s+$/, "");
    const sizeStr = hdr.slice(48, 58).toString("ascii").trim();
    const size = parseInt(sizeStr, 10);
    if (!Number.isFinite(size) || size < 0) break;

    off += 60;
    const body = debBuf.slice(off, off + size);
    off += size;
    if (off % 2 === 1) off++;

    const baseName = name.replace(/^#\d+\s*/, "").replace(/\/$/, "").trim();
    if (baseName === "data.tar.xz" || name.startsWith("data.tar.xz"))
      return body;
  }
  throw new Error("Không thấy data.tar.xz trong .deb");
}

function findSqliteUnder(dir) {
  let found = null;
  const walk = (d) => {
    if (!fs.existsSync(d)) return;
    for (const ent of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, ent.name);
      if (ent.isDirectory()) walk(p);
      else if (ent.name === "sqlite3") {
        found = p;
        return;
      }
    }
  };
  walk(dir);
  return found;
}

function extractSqliteBinary(dataTarXz, destPath) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "tg-sqlite-"));
  const xzPath = path.join(tmp, "data.tar.xz");
  fs.writeFileSync(xzPath, dataTarXz);
  try {
    execFileSync("tar", ["-xJf", xzPath, "-C", tmp], { stdio: "pipe" });
  } catch (e) {
    fs.rmSync(tmp, { recursive: true, force: true });
    throw new Error(`tar -xJf thất bại: ${e.message}`);
  }

  const sqlitePath = findSqliteUnder(tmp);
  if (!sqlitePath) {
    fs.rmSync(tmp, { recursive: true, force: true });
    throw new Error("Không tìm thấy sqlite3 trong data.tar.xz");
  }
  fs.mkdirSync(path.dirname(destPath), { recursive: true });
  fs.copyFileSync(sqlitePath, destPath);
  fs.rmSync(tmp, { recursive: true, force: true });
}

function pickLatestDebName(html, archSuffix) {
  const re = new RegExp(`href="(sqlite_[^"]+_${archSuffix}\\.deb)"`, "gi");
  const names = [];
  let m;
  while ((m = re.exec(html))) names.push(m[1]);
  if (!names.length)
    throw new Error(`Không thấy sqlite_*_${archSuffix}.deb trong index`);
  names.sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
  return names[0];
}

async function main() {
  const force = process.argv.includes("--force");
  fs.mkdirSync(binDir, { recursive: true });

  console.log("fetch-sqlite: đọc index Termux…");
  const html = (await fetchBuffer(POOL)).toString("utf8");

  for (const { suffix, out } of ARCH_MAP) {
    const dest = path.join(binDir, out);
    if (!force && fs.existsSync(dest) && fs.statSync(dest).size > 10000) {
      console.log(`fetch-sqlite: giữ nguyên ${out} (đã có, dùng --force để tải lại)`);
      continue;
    }

    const debName = pickLatestDebName(html, suffix);
    const debUrl = new URL(debName, POOL).href;
    console.log(`fetch-sqlite: ${suffix} ← ${debUrl}`);
    const debBuf = await fetchBuffer(debUrl);
    const xz = extractDataTarXzFromDeb(debBuf);
    extractSqliteBinary(xz, dest);
    try {
      fs.chmodSync(dest, 0o755);
    } catch {
      /* Windows */
    }
    console.log(`fetch-sqlite: OK → bin/${out} (${fs.statSync(dest).size} bytes)`);
  }

  fs.writeFileSync(
    path.join(binDir, "README.txt"),
    [
      "sqlite3 binaries from Termux packages (same ABI as Android userland).",
      "SQLite public domain — https://sqlite.org/",
      "Pick file by ro.product.cpu.abi — see lib/sms.sh.",
      "",
    ].join("\n"),
    "utf8",
  );

  console.log("fetch-sqlite: hoàn tất.");
}

main().catch((e) => {
  console.error("fetch-sqlite:", e.message || e);
  process.exit(1);
});
