// Checks what `astro build` cannot: every page exists in both languages for real,
// not as Starlight's silent "not translated yet" fallback.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const contentDir = join(root, 'src/content/docs');
const distDir = join(root, 'dist');
const errors = [];

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

const withoutExt = (path) => path.replace(/\.(md|mdx)$/, '');
const sources = walk(contentDir).filter((p) => /\.(md|mdx)$/.test(p)).map((p) => relative(contentDir, p));
const english = new Set(sources.filter((p) => !p.startsWith('vi/')).map(withoutExt));
const vietnamese = new Set(sources.filter((p) => p.startsWith('vi/')).map((p) => withoutExt(p.slice(3))));

for (const page of english) if (!vietnamese.has(page)) errors.push(`missing Vietnamese page: vi/${page}`);
for (const page of vietnamese) if (!english.has(page)) errors.push(`missing English page: ${page}`);

// Starlight's own notice text for a fallback page (translations/en.js, vi.js).
const fallbackNotices = [
  'This content is not available in your language yet.',
  'Nội dung này hiện chưa có sẵn bằng ngôn ngữ của bạn.',
];
for (const file of walk(distDir).filter((p) => p.endsWith('.html'))) {
  const html = readFileSync(file, 'utf8');
  if (fallbackNotices.some((notice) => html.includes(notice))) {
    errors.push(`fallback page built: ${relative(distDir, file)}`);
  }
}

if (errors.length > 0) {
  console.error(errors.join('\n'));
  process.exit(1);
}
console.log(`check-dist: ${english.size} pages in both languages`);
