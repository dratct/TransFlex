# Website in `site/`, built with Astro and Starlight

Status: accepted — 2026-11-08

## Context

The only TransFlex website (`transflex-web.pages.dev`) describes the earlier
Tauri app: Mac, Windows and Linux downloads from `dl-transflex.aiaz.io` and a
$39 Pro tier. Its source is not in this repository. The native macOS app here
is MIT-licensed and free, and ships on GitHub Releases with a versioned asset
name (`TransFlex-<version>-macos-universal-signed-notarized.zip`).

## Decision

- One website replaces the old one, for the native macOS app only. The Tauri
  app is discontinued; the site offers no Windows or Linux download.
- No pricing: the site says free and open source, and links a support button
  to the `custom` entry of `.github/FUNDING.yml`.
- The site lives in `site/` in this repository, so a feature and the page that
  describes it change in one pull request.
- Built with Astro (`astro`) and its docs theme Starlight
  (`@astrojs/starlight`): a landing page, user docs and a blog, in English and
  Vietnamese from the start. The blog is the `starlight-blog` plugin; internal
  links are checked by `starlight-links-validator`, which also fails a
  Vietnamese page that links an English one.
- `.github/workflows/site.yml` builds and checks `site/` on every change to
  it; the app's `ci.yml` ignores `site/**`.
- Hosted on Cloudflare Pages at `transflex.aiaz.io`, built by Cloudflare from
  `site/` on push; `aiaz.io` DNS is already on Cloudflare.
- The download button points at a fixed-name asset that `release.yml` attaches
  to every Release (prereleases too; GitHub's `latest` skips them):
  `https://github.com/dratct/TransFlex/releases/latest/download/TransFlex-macos.zip`.
  The page never needs a rebuild to offer a new version.

## Consequences

- The repository gains a Node toolchain under `site/` only; the app build and
  its CI do not depend on it.
- Every user-facing text exists twice; a page added in one language without
  the other is a gap Starlight shows as a fallback.
- A Release without `TransFlex-macos.zip` breaks the download button.

## Rejected

- Static HTML with no build: docs, a blog and two languages would repeat the
  header, footer and navigation on every page.
- Next.js: built for apps with accounts and live data; a static site gains
  nothing from it.
- Reading the GitHub API at build time for a versioned link: the page would go
  stale whenever a release forgot to rebuild it.
- GitHub Pages: needs a deploy workflow while DNS stays on Cloudflare anyway.
