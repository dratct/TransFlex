// @ts-check
import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';
import starlightLinksValidator from 'starlight-links-validator';

export default defineConfig({
  site: 'https://transflex.aiaz.io',
  integrations: [
    starlight({
      title: 'TransFlex',
      defaultLocale: 'root',
      locales: {
        root: { label: 'English', lang: 'en' },
        vi: { label: 'Tiếng Việt', lang: 'vi' },
      },
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/dratct/TransFlex' }],
      customCss: ['./src/styles/theme.css'],
      plugins: [
        // A Vietnamese page that links an English page is the easiest bilingual mistake to make.
        starlightLinksValidator({ errorOnInconsistentLocale: true }),
      ],
    }),
  ],
});
