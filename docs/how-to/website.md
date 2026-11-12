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

## Deploy to the web server

The site is static files. It is served by the owner's own web server, managed
with aaPanel, at `transflex.aiaz.io`. The `Deploy site` job in
`.github/workflows/site.yml` builds `site/` and uploads `site/dist` to the
server over FTP (`site/scripts/deploy.sh`, which runs `lftp`), after the checks
pass, on every push to `main` that touches `site/`.

The job stays off until the repository variable `SITE_DEPLOY_ENABLED` is
`true`. Set it up once:

1. In aaPanel, open Website → PHP Project → Add site. Domain
   `transflex.aiaz.io`, PHP version Static, no database. Turn on Create FTP in
   the same form and note the FTP user and password. Then issue the site's
   certificate under its SSL settings. The site is static: do not add it as a
   Node project.

   The FTP account's home is the site folder
   (`/www/wwwroot/transflex.aiaz.io`), so the upload goes to `/`.
2. In the GitHub repository, under Settings → Secrets and variables → Actions,
   add these secrets:

   | Secret | Value |
   |---|---|
   | `SITE_DEPLOY_FTP_HOST` | The server's address |
   | `SITE_DEPLOY_FTP_USER` | The FTP user from step 1 |
   | `SITE_DEPLOY_FTP_PASSWORD` | Its password |
   | `SITE_DEPLOY_FTP_PORT` | Only if the port is not 21 |

3. On the Variables tab of the same page, add:

   | Variable | Value |
   |---|---|
   | `SITE_DEPLOY_FTP_TLS` | See below. Leave unset for `verify`. |
   | `SITE_DEPLOY_FTP_DIR` | Only if the account's home is not the site folder |
   | `SITE_DEPLOY_ENABLED` | `true` |

4. Run the `Site` workflow from the Actions tab (Run workflow, branch `main`)
   for the first deploy.

`SITE_DEPLOY_FTP_TLS` chooses how the connection is protected:

- `verify` (default): encrypted, and the server's certificate must be one
  GitHub's runner trusts. Use it when the FTP server presents a real
  certificate for the address in `SITE_DEPLOY_FTP_HOST`.
- `encrypt`: encrypted, but any certificate is accepted. Use it for the
  self-signed certificate aaPanel's FTP server ships with. The password is not
  readable on the way, but the server's identity is not proven.
- `off`: plain FTP. The password crosses the internet in clear text; use it
  only if the server offers no TLS at all.

The upload replaces everything in the site folder except `.user.ini`,
`.well-known/` and `.htaccess`, which belong to the server. Keep nothing else
there. The job fails when a secret is missing, the login is refused, or the
server does not offer the protection asked for.

In aaPanel's site settings, point the 404 page at `/404.html`. The server's
firewall must allow the FTP server's passive port range.

### The old site

`transflex.aiaz.io` served the site of the discontinued cross-platform app
until the first deploy (checked 2026-11-12). The first deploy empties the site
folder, so back up anything there you still want. `transflex-web.pages.dev`
is a separate copy of the old site: delete that project or redirect it.

### The download button

The button links to
`https://github.com/dratct/TransFlex/releases/latest/download/TransFlex-macos.zip`.
That asset is attached by `scripts/publish-release.sh`, so the link works from
the first stable Release published after that script change; earlier Releases
do not have it. Publish such a Release before announcing the site.
