// Kopierar webbsidans filer till app/www, så att appen alltid byggs av exakt samma kod som varvtraining.com.
// Körs av "npm run web" och "npm run sync", och i molnbygget.
import { cpSync, rmSync, mkdirSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const app = dirname(dirname(fileURLToPath(import.meta.url)));
const root = dirname(app);
const out = join(app, "www");

// Det som appen behöver. Teamets sida, SQL-filer och verktyg följer inte med.
const FILES = ["index.html", "manifest.webmanifest", "supabase-config.js", "apple-touch-icon.png"];
const DIRS = ["icons", "vendor", "data", "legal"];

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
for (const f of FILES) if (existsSync(join(root, f))) cpSync(join(root, f), join(out, f));
for (const d of DIRS) if (existsSync(join(root, d))) cpSync(join(root, d), join(out, d), { recursive: true });

const html = readFileSync(join(out, "index.html"), "utf8");
if (!html.includes("IS_NATIVE")) console.warn("Varning: index.html saknar appläget (IS_NATIVE).");
writeFileSync(join(out, "app-build.txt"), `Byggd ${new Date().toISOString()}\n`);
console.log("Webbfilerna är kopierade till app/www.");
