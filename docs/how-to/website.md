# Website

The website at `transflex.aiaz.io` lives in `site/`: Astro with the Starlight
theme, in English and Vietnamese. Why it is built this way is in
[the decision record](../decisions/2026-11-08-website-astro-starlight-a04b.md).

## Run it locally

Node 24 (`site/.nvmrc`).

```sh
cd site
npm ci
npm run dev      # http://localhost:4321, reloads on save
npm run check    # builds, then runs scripts/check-dist.mjs
```

`npm run check` is what CI runs (`.github/workflows/site.yml`). It fails when:

- a page exists in one language only, or a Vietnamese page links an English one;
- a link is broken;
- a landing page lacks the download link, a clip, the five fact tiles or the
  support button;
- a page lacks the support link, or the blog lacks an index or its RSS feed.

## Add or change a page

- A doc page is two files: `site/src/content/docs/docs/<name>.md` and
  `site/src/content/docs/vi/docs/<name>.md`. Add `docs/<name>` to `sidebar` in
  `site/astro.config.mjs`.
- A blog post is two files under `blog/` and `vi/blog/`, with `date` and
  `authors: truongtc` in the frontmatter.
- Links are absolute and stay in the page's language: `/docs/install/` on an
  English page, `/vi/docs/install/` on a Vietnamese one.
- Header and footer text is in `site/src/content/i18n/en.json` and `vi.json`.
- Describe only what the app does. Check a shortcut, a label or a limit in
  `TransFlex/Sources` before writing it down.

## Pictures and clips

Every picture is drawn by the app itself, so it cannot drift from the real
views. Build the app, then:

```sh
TransFlex.app/Contents/MacOS/TransFlex --screenshots <dir>   # PNG, light and dark
TransFlex.app/Contents/MacOS/TransFlex --clips <dir>         # MP4 + last-frame PNG
```

Copy the screenshots into `site/src/assets/screenshots/`, the `*-poster.png`
files into `site/src/assets/clips/` and the `.mp4` files into
`site/public/clips/`. See
[the clips record](../decisions/2026-11-08-website-clips-6397.md).

## Deploy on Cloudflare Pages

Done once, in the Cloudflare dashboard, by the account owner.

1. Workers & Pages → Create → Pages → connect the `dratct/TransFlex` repository.
2. Build settings:
   - Production branch: `main`
   - Root directory: `site`
   - Build command: `npm run build`
   - Build output directory: `dist`
3. Environment variable `NODE_VERSION` = `24`. The Pages build image defaults to
   Node 22 (read 2026-11-11); the variable pins the version CI uses.
4. Custom domains → add `transflex.aiaz.io`. `aiaz.io` is already on
   Cloudflare, so the DNS record is created for you.
5. Optional, under build watch paths: include `site/*`, so a change to the app
   alone does not rebuild the site.

After that a push to `main` publishes the site (only when it touches `site/`,
if you set the watch path), and Cloudflare builds a preview for other branches.

### The old site

`transflex-web.pages.dev` describes the discontinued cross-platform app. Once
the new site is live, redirect it: in that Pages project add a `_redirects`
file with `/* https://transflex.aiaz.io/:splat 301`, or delete the project.

### The download button

The button links to
`https://github.com/dratct/TransFlex/releases/latest/download/TransFlex-macos.zip`.
That asset is attached by `scripts/publish-release.sh`, so the link works from
the first stable Release published after that script change; earlier Releases
do not have it. Publish such a Release before announcing the site.
