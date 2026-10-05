// Render a mockup page and check it for overflow.
//   node tools/shot.mjs <page.html> <out.png> [query] [--clip=#id]
// query is appended to the URL, e.g. "scale=1.3&w=320" (screens.html reads it).
// Prints every element inside a .phone that overflows its phone frame
// horizontally, or whose text is clipped (scrollWidth > clientWidth with
// overflow hidden and no ellipsis).
import { createRequire } from 'node:module';
const { chromium } = createRequire('/opt/node22/lib/node_modules/')('playwright');
import path from 'node:path';
const [page, out, query = '', clipArg] = process.argv.slice(2);
const browser = await chromium.launch();
const p = await browser.newPage({ viewport: { width: 1600, height: 1000 }, deviceScaleFactor: 1 });
await p.goto('file://' + path.resolve(page) + (query ? '?' + query : ''));
await p.waitForTimeout(400);
const problems = await p.evaluate(() => {
  const out = [];
  for (const phone of document.querySelectorAll('.phone')) {
    const pr = phone.getBoundingClientRect();
    const id = phone.closest('[data-block]')?.dataset.block || phone.id || '?';
    for (const el of phone.querySelectorAll('*')) {
      const r = el.getBoundingClientRect();
      if (r.width === 0) continue;
      if (r.right > pr.right + 1 || r.left < pr.left - 1) {
        out.push(`${id}: <${el.tagName.toLowerCase()} class="${el.className}"> spills ${Math.round(Math.max(r.right - pr.right, pr.left - r.left))}px: "${(el.textContent||'').trim().slice(0,40)}"`);
      }
      const cs = getComputedStyle(el);
      if (el.scrollWidth > el.clientWidth + 1 && cs.overflowX === 'hidden' && cs.textOverflow !== 'ellipsis' && el.children.length === 0) {
        out.push(`${id}: clipped text "${el.textContent.trim().slice(0,40)}"`);
      }
    }
  }
  return [...new Set(out)];
});
if (clipArg) {
  const sel = clipArg.replace('--clip=', '');
  await p.locator(sel).screenshot({ path: out });
} else {
  await p.screenshot({ path: out, fullPage: true });
}
console.log(problems.length ? problems.join('\n') : 'no overflow');
await browser.close();
