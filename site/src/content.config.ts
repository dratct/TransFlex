import { defineCollection, z } from 'astro:content';
import { docsLoader, i18nLoader } from '@astrojs/starlight/loaders';
import { docsSchema, i18nSchema } from '@astrojs/starlight/schema';
import { blogSchema } from 'starlight-blog/schema';

export const collections = {
  docs: defineCollection({
    loader: docsLoader(),
    schema: docsSchema({
      extend: (context) =>
        blogSchema(context).extend({
          // A looping clip in the hero in place of `hero.image`: names files from `TransFlex --clips`.
          heroClip: z.object({ name: z.string(), alt: z.string() }).optional(),
          // Short facts under the hero's buttons: licence, system, chips.
          heroNotes: z.array(z.string()).optional(),
        }),
    }),
  }),
  i18n: defineCollection({
    loader: i18nLoader(),
    schema: i18nSchema({
      // The site's own header and footer text (ThemeSelect.astro, Footer.astro).
      extend: z.object({
        'tf.nav.docs': z.string().optional(),
        'tf.nav.blog': z.string().optional(),
        'tf.nav.support': z.string().optional(),
        'tf.footer.free': z.string().optional(),
        'tf.footer.support': z.string().optional(),
        'tf.footer.more': z.string().optional(),
      }),
    }),
  }),
};
