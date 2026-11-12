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
`.github/workflows/site.yml` builds `site/` and copies `site/dist` to the
server with `rsync` over SSH (`site/scripts/deploy.sh`), after the checks pass,
on every push to `main` that touches `site/`.

The job stays off until the repository variable `SITE_DEPLOY_ENABLED` is
`true`. Set it up once:

1. In aaPanel, add a website for `transflex.aiaz.io` (static; no PHP or
   database) and issue its certificate. Note the site folder, normally
   `/www/wwwroot/transflex.aiaz.io`.
2. On your own machine, make a key pair used for nothing else:

   ```sh
   ssh-keygen -t ed25519 -N "" -C "transflex-site-deploy" -f transflex-site-deploy
   ```

3. On the server, give the deploy user that key and write access to the site
   folder. Use a user that can write there and nowhere it does not need to;
   avoid `root`. Append `transflex-site-deploy.pub` to that user's
   `~/.ssh/authorized_keys`.
4. Read the server's host key, and check it against the server before trusting
   it:

   ```sh
   ssh-keyscan -p 22 <server address>
   ```

5. In the GitHub repository, under Settings → Secrets and variables → Actions,
   add these secrets:

   | Secret | Value |
   |---|---|
   | `SITE_DEPLOY_HOST` | The server's address |
   | `SITE_DEPLOY_PORT` | The SSH port; leave unset for 22 |
   | `SITE_DEPLOY_USER` | The deploy user |
   | `SITE_DEPLOY_PATH` | The site folder, e.g. `/www/wwwroot/transflex.aiaz.io` |
   | `SITE_DEPLOY_SSH_KEY` | The whole private key file `transflex-site-deploy` |
   | `SITE_DEPLOY_KNOWN_HOSTS` | The `ssh-keyscan` output from step 4 |

   Then delete the private key file from your machine.
6. Add the variable `SITE_DEPLOY_ENABLED` = `true`, and run the `Site` workflow
   from the Actions tab (Run workflow, branch `main`) for the first deploy.

The copy replaces everything in the site folder except `.user.ini`,
`.well-known/` and `.htaccess`, which belong to the server. Keep nothing else
there. The job fails, and changes nothing, when a secret is missing or the
server's host key does not match.

In aaPanel's site settings, point the 404 page at `/404.html`.

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
