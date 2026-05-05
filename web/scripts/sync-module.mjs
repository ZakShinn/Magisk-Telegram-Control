import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..", "..");
const destRoots = {
  /** Vietnamese: repo root + optional module-overrides/vi */
  vi: path.resolve(__dirname, "..", "module-files-vi"),
  /** English: repo root + module-overrides/en */
  en: path.resolve(__dirname, "..", "module-files-en"),
};

const coreFiles = ["module.prop", "service.sh"];
const libSrc = path.join(repoRoot, "lib");
const binSrc = path.join(repoRoot, "bin");
const custSrc = path.join(repoRoot, "customize.sh");

function copyFileIfExists(src, dst) {
  if (!fs.existsSync(src)) return false;
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.copyFileSync(src, dst);
  return true;
}

function copyDirFlatSh(srcDir, dstDir) {
  if (!fs.existsSync(srcDir)) return;
  fs.mkdirSync(dstDir, { recursive: true });
  for (const name of fs.readdirSync(srcDir)) {
    if (!name.endsWith(".sh")) continue;
    fs.copyFileSync(path.join(srcDir, name), path.join(dstDir, name));
  }
}

function copyDirFiles(srcDir, dstDir) {
  if (!fs.existsSync(srcDir)) return;
  fs.mkdirSync(dstDir, { recursive: true });
  for (const name of fs.readdirSync(srcDir)) {
    const src = path.join(srcDir, name);
    if (!fs.statSync(src).isFile()) continue;
    fs.copyFileSync(src, path.join(dstDir, name));
  }
}

function applyOverrides(lang, destRoot) {
  // Optional overrides folder (mirror module root):
  // repoRoot/module-overrides/vi/... or repoRoot/module-overrides/en/...
  const overRoot = path.join(repoRoot, "module-overrides", lang);
  if (!fs.existsSync(overRoot)) return;

  const walk = (relDir) => {
    const absDir = path.join(overRoot, relDir);
    for (const name of fs.readdirSync(absDir)) {
      const rel = path.join(relDir, name);
      const abs = path.join(overRoot, rel);
      const st = fs.statSync(abs);
      if (st.isDirectory()) walk(rel);
      else copyFileIfExists(abs, path.join(destRoot, rel));
    }
  };

  walk("");
}

function syncOne(destRoot, lang) {
  fs.rmSync(destRoot, { recursive: true, force: true });
  fs.mkdirSync(destRoot, { recursive: true });

  for (const f of coreFiles) {
    fs.copyFileSync(path.join(repoRoot, f), path.join(destRoot, f));
  }

  if (!fs.existsSync(libSrc)) {
    console.error("sync-module: missing ../lib from repo root");
    process.exit(1);
  }

  const libDst = path.join(destRoot, "lib");
  copyDirFlatSh(libSrc, libDst);

  const binDst = path.join(destRoot, "bin");
  copyDirFiles(binSrc, binDst);

  copyFileIfExists(custSrc, path.join(destRoot, "customize.sh"));

  if (lang) applyOverrides(lang, destRoot);
}

syncOne(destRoots.vi, "vi");
syncOne(destRoots.en, "en");

console.log("sync-module: copied module → web/module-files-vi + web/module-files-en");
