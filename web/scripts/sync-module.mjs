import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..", "..");
const destRoot = path.resolve(__dirname, "..", "module-files");

const files = ["module.prop", "service.sh"];
const libSrc = path.join(repoRoot, "lib");
const libDst = path.join(destRoot, "lib");

fs.rmSync(destRoot, { recursive: true, force: true });
fs.mkdirSync(libDst, { recursive: true });

for (const f of files) {
  fs.copyFileSync(path.join(repoRoot, f), path.join(destRoot, f));
}

if (!fs.existsSync(libSrc)) {
  console.error("sync-module: missing ../lib from repo root");
  process.exit(1);
}

for (const name of fs.readdirSync(libSrc)) {
  if (!name.endsWith(".sh")) continue;
  fs.copyFileSync(path.join(libSrc, name), path.join(libDst, name));
}

const binSrc = path.join(repoRoot, "bin");
const binDst = path.join(destRoot, "bin");
if (fs.existsSync(binSrc)) {
  fs.mkdirSync(binDst, { recursive: true });
  for (const name of fs.readdirSync(binSrc)) {
    const src = path.join(binSrc, name);
    if (!fs.statSync(src).isFile()) continue;
    fs.copyFileSync(src, path.join(binDst, name));
  }
}

const cust = path.join(repoRoot, "customize.sh");
if (fs.existsSync(cust)) {
  fs.copyFileSync(cust, path.join(destRoot, "customize.sh"));
}

console.log("sync-module: copied module → web/module-files");
