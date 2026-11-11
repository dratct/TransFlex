// Checks what `astro build` cannot: every page exists in both languages for real,
// not as Starlight's silent "not translated yet" fallback.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
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

// The release workflow attaches the archive under this fixed name (scripts/publish-release.sh).
const downloadHref = 'href="https://github.com/dratct/TransFlex/releases/latest/download/TransFlex-macos.zip"';
for (const landing of ['index.html', 'vi/index.html']) {
  if (!readFileSync(join(distDir, landing), 'utf8').includes(downloadHref)) {
    errors.push(`no download link on ${landing}`);
  }
}

// Clips: never `autoplay` in the markup (a script plays them unless the reader asked
// for reduced motion), a still image under each for no-JS and reduced motion, and
// every movie the page names is in the build.
const attrs = (tag) => new Set(tag.match(/\s[\w-]+(?==|\s|>)/g)?.map((a) => a.trim()));
const clipSets = {};
for (const landing of ['index.html', 'vi/index.html']) {
  const html = readFileSync(join(distDir, landing), 'utf8');
  const figures = [...html.matchAll(/<figure[^>]*class="[^"]*\bclip\b[^"]*"[^>]*>([\s\S]*?)<\/figure>/g)];
  const videos = figures.map(([, inner]) => [inner, inner.match(/<video[^>]*>/)?.[0] ?? '']);
  if (!videos.some(([, tag]) => tag.includes('data-clip="hero"'))) errors.push(`no hero clip on ${landing}`);
  if (!videos.some(([, tag]) => tag.includes('data-clip="replace"'))) errors.push(`no Replace Selection clip on ${landing}`);
  clipSets[landing] = videos.map(([, tag]) => tag.match(/data-clip="([^"]+)"/)?.[1] ?? '?').join(' ');
  for (const [inner, tag] of videos) {
    const name = tag.match(/data-clip="([^"]+)"/)?.[1] ?? '?';
    const has = attrs(tag);
    for (const a of ['muted', 'loop', 'playsinline']) if (!has.has(a)) errors.push(`${landing} clip ${name}: no ${a}`);
    // The script sets the movie; under reduced motion it never does, so nothing downloads.
    if (!tag.includes('preload="none"') || /\ssrc=/.test(tag)) errors.push(`${landing} clip ${name}: downloads before the script decides`);
    // Below the fold a clip downloads only once scrolled to.
    if (name !== 'hero' && !has.has('data-lazy')) errors.push(`${landing} clip ${name}: loads before it is on screen`);
    if (has.has('autoplay')) errors.push(`${landing} clip ${name}: autoplay plays before reduced motion is checked`);
    if ((inner.match(/<img/g) ?? []).length !== 2) errors.push(`${landing} clip ${name}: needs a light and a dark still`);
    for (const [, src] of tag.matchAll(/data-(?:light|dark)="([^"]+)"/g)) {
      if (!existsSync(join(distDir, src))) errors.push(`${landing} clip ${name}: ${src} is not in dist`);
    }
  }
}

// Blog: an index in both languages, a feed, and no English plugin text on the Vietnamese one.
for (const file of ['blog/index.html', 'vi/blog/index.html', 'blog/rss.xml']) {
  if (!existsSync(join(distDir, file))) errors.push(`no ${file}`);
}
if (existsSync(join(distDir, 'vi/blog/index.html'))) {
  const html = readFileSync(join(distDir, 'vi/blog/index.html'), 'utf8');
  for (const english of ['All posts', 'Recent posts', 'Newer posts', 'Older posts']) {
    if (html.includes(english)) errors.push(`vi/blog/index.html shows the plugin's English "${english}"`);
  }
}

if (clipSets['index.html'] !== clipSets['vi/index.html']) {
  errors.push(`clips differ: English has ${clipSets['index.html']}, Vietnamese ${clipSets['vi/index.html']}`);
}

// The privacy and licence facts are a grid of exactly five tiles, the same on both pages.
for (const landing of ['index.html', 'vi/index.html']) {
  const html = readFileSync(join(distDir, landing), 'utf8');
  const grid = html.match(/<div[^>]*class="[^"]*\bfacts\b[^"]*"[^>]*>([\s\S]*?)<\/div>/)?.[1] ?? '';
  const tiles = (grid.match(/<li\b/g) ?? []).length;
  if (tiles !== 5) errors.push(`${landing}: ${tiles} fact tiles, want 5`);
}

// Support: every page offers the support link (footer), and each landing page
// has the button beside its download.
const supportHref = 'href="https://paypal.me/truongtc1109"';
for (const file of walk(distDir).filter((p) => p.endsWith('.html') && !p.endsWith('404.html'))) {
  if (!readFileSync(file, 'utf8').includes(supportHref)) errors.push(`no support link on ${relative(distDir, file)}`);
}
for (const landing of ['index.html', 'vi/index.html']) {
  const block = readFileSync(join(distDir, landing), 'utf8').match(/<div[^>]*class="[^"]*\bdownload\b[^"]*"[^>]*>[\s\S]*?<\/div>/)?.[0] ?? '';
  if (!block.includes(supportHref)) errors.push(`no support button beside the download on ${landing}`);
}
for (const page of ['support/index.html', 'vi/support/index.html']) {
  if (!existsSync(join(distDir, page))) errors.push(`no ${page}`);
}

if (errors.length > 0) {
  console.error(errors.join('\n'));
  process.exit(1);
}
console.log(`check-dist: ${english.size} pages in both languages`);
