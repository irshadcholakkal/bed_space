import { mkdir, copyFile } from 'node:fs/promises';
import sharp from 'sharp';
import { fileURLToPath } from 'node:url';

// This script lives in landing/scripts; repository assets are two levels up.
const assets = new URL('../../assets/', import.meta.url);
const media = new URL('../public/media/', import.meta.url);
await mkdir(media, { recursive: true });
await Promise.all([
  sharp(fileURLToPath(new URL('landing/landscape.jpg', assets))).resize({ width: 1600, withoutEnlargement: true })
    .webp({ quality: 78 }).toFile(fileURLToPath(new URL('landscape.webp', media))),
  sharp(fileURLToPath(new URL('landing/landscape.jpg', assets))).resize({ width: 760, withoutEnlargement: true })
    .webp({ quality: 75 }).toFile(fileURLToPath(new URL('landscape-small.webp', media))),
  sharp(fileURLToPath(new URL('landing/hills.png', assets))).webp({ quality: 80 })
    .toFile(fileURLToPath(new URL('hills.webp', media))),
  copyFile(new URL('logo.png', assets), new URL('logo.png', media)),
  copyFile(new URL('fonts/HedvigLettersSerif.ttf', assets), new URL('serif.ttf', media)),
  copyFile(new URL('fonts/HedvigLettersSerif-OFL.txt', assets), new URL('FONT-LICENSE.txt', media)),
  copyFile(new URL('../node_modules/@fontsource-variable/inter/files/inter-latin-wght-normal.woff2', import.meta.url), new URL('inter.woff2', media)),
  copyFile(new URL('../node_modules/@fontsource-variable/inter/LICENSE', import.meta.url), new URL('INTER-LICENSE.txt', media)),
]);
