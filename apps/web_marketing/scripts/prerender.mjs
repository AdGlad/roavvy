// Pre-render every route to static HTML so the content is visible without
// JavaScript (crawlers, reviewers, link previews). Run after `vite build`
// and `vite build --ssr`; see the "build" script in package.json.
import { readFile, writeFile, rm } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const dist = path.join(root, 'dist')
const ssrDir = path.join(root, 'dist-ssr')
const SITE = 'https://www.roavvy.com'

const { render, PAGES } = await import(path.join(ssrDir, 'entry-server.js'))
const template = await readFile(path.join(dist, 'index.html'), 'utf8')

const escape = (s) => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')

function page(url, title, { indexable = true } = {}) {
  const html = render(url)
  if (!html.trim()) throw new Error(`Empty render for ${url}`)
  let out = template.replace('<div id="root"></div>', `<div id="root">${html}</div>`)
  out = out.replace(/<title>[^<]*<\/title>/, `<title>${escape(title)}</title>`)
  if (indexable) {
    const canonical = SITE + (url === '/' ? '/' : url)
    out = out
      .replace(/<link rel="canonical" href="[^"]*" \/>/, `<link rel="canonical" href="${canonical}" />`)
      .replace(/<meta property="og:url" content="[^"]*" \/>/, `<meta property="og:url" content="${canonical}" />`)
  } else {
    out = out.replace(/<link rel="canonical" href="[^"]*" \/>\n?/, '<meta name="robots" content="noindex" />\n')
  }
  return out
}

for (const { path: url, title } of PAGES) {
  // With cleanUrls in firebase.json, /about is served from about.html.
  const file = url === '/' ? 'index.html' : `${url.slice(1)}.html`
  await writeFile(path.join(dist, file), page(url, title))
  console.log(`prerendered ${url} -> ${file}`)
}
await writeFile(path.join(dist, '404.html'), page('/__not-found__', 'Page not found | Roavvy', { indexable: false }))
console.log('prerendered 404.html')

await rm(ssrDir, { recursive: true, force: true })
