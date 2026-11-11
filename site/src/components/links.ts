/** The `custom` entry of `.github/FUNDING.yml`. */
export const supportHref = 'https://paypal.me/truongtc1109';

/** A site path in the page's language: `/docs/install/` or `/vi/docs/install/`. */
export function localized(path: string, locale: string | undefined): string {
  return locale ? `/${locale}${path}` : path;
}
