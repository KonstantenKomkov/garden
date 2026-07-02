// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  site: 'https://garden-app.ru',
  trailingSlash: 'always',
  prefetch: {
    defaultStrategy: 'hover',
  },
  build: {
    format: 'directory',
  },
});
