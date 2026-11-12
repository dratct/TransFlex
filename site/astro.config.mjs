// @ts-check
import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';
import starlightBlog from 'starlight-blog';
import starlightLinksValidator from 'starlight-links-validator';

export default defineConfig({
  site: 'https://transflex.aiaz.io',
  integrations: [
    starlight({
      title: 'TransFlex',
      logo: { src: './src/assets/logo.svg', alt: '' },
      defaultLocale: 'root',
      locales: {
        root: { label: 'English', lang: 'en' },
        vi: { label: 'Tiếng Việt', lang: 'vi' },
      },
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/dratct/TransFlex' }],
      sidebar: [
        {
          label: 'Docs',
          translations: { vi: 'Hướng dẫn' },
          items: [
            'docs/install',
            'docs/quick-start',
            'docs/shortcuts',
            'docs/presets',
            'docs/providers',
            'docs/images',
            'docs/history',
            'docs/privacy',
            'docs/troubleshooting',
          ],
        },
        'support',
      ],
      customCss: [
        '@fontsource/be-vietnam-pro/400.css',
        '@fontsource/be-vietnam-pro/500.css',
        '@fontsource/be-vietnam-pro/600.css',
        '@fontsource/be-vietnam-pro/700.css',
        '@fontsource/be-vietnam-pro/800.css',
        './src/styles/theme.css',
      ],
      components: {
        Header: './src/components/Header.astro',
        Hero: './src/components/Hero.astro',
        Footer: './src/components/Footer.astro',
        ThemeSelect: './src/components/ThemeSelect.astro',
      },
      plugins: [
        starlightBlog({
          // ThemeSelect.astro draws the header links, the blog's among them.
          navigation: 'none',
          authors: { truongtc: { name: 'TruongTC', url: 'https://github.com/dratct' } },
        }),
        // A Vietnamese page that links an English page is the easiest bilingual mistake to make.
        starlightLinksValidator({ errorOnInconsistentLocale: true }),
      ],
    }),
  ],
});
