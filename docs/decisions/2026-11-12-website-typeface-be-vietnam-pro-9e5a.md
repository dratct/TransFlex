# Website set in Be Vietnam Pro, with a dark green band on the landing page

Status: accepted — 2026-11-12

## Context

The website used the system font and Starlight's stock layout. The owner found
the landing page looked like an old native settings screen and asked for
something with more character. Half the site's text is Vietnamese, so a
typeface must carry the Vietnamese subset.

## Decision

- The site is set in Be Vietnam Pro, self-hosted through the
  `@fontsource/be-vietnam-pro` package (OFL-1.1), weights 400 to 800. The
  system faces stay as the fallback. No font is loaded from another host.
- The landing page's hero is a band of dark green (`--tf-ink`) in both themes,
  laid out as the app's popup at page size: the headline in the other language
  as the Original, the page's headline as the Translation, streamed in word by
  word. The app's accent green and logo are unchanged.
- The app itself keeps the system font; this is a website decision only.

## Consequences

- One more dependency under `site/`, and font files in every build.
- The website's type no longer matches the app's; the app's own views still
  appear on the page as real captures.
- The streaming headline needs JavaScript; without it, or under reduced
  motion, the headline is shown at once.
