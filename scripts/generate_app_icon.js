// Usage (needs Node + Playwright with Chromium): node scripts/generate_app_icon.js, then copy the PNGs into MyRussian/Assets.xcassets/AppIcon.appiconset/.
// Concept: «От А до Я» (from A to Я). Я is the last letter of the alphabet and means "I/me"; the gold ring mirrors the Journey effort ring.
// Renders the My Russian app icon variants (1024×1024, no rounded corners: iOS applies the mask).
const { chromium } = require('playwright');

const variants = {
  light: {
    bg: 'radial-gradient(120% 120% at 25% 15%, #D9483B 0%, #B8322A 45%, #7E1B17 100%)',
    glyph: '#FFF4E6', glyphShadow: 'rgba(60,8,6,0.35)',
    track: 'rgba(255,244,230,0.16)', ring: ['#FFD27A', '#F2A93B'], dot: '#FFF4E6', small: 'rgba(255,244,230,0.75)',
    sheen: true,
  },
  dark: {
    bg: 'radial-gradient(120% 120% at 25% 15%, #2A1614 0%, #160C0B 60%, #0B0606 100%)',
    glyph: '#FF6F61', glyphShadow: 'rgba(0,0,0,0.5)',
    track: 'rgba(255,111,97,0.14)', ring: ['#FFD27A', '#F2A93B'], dot: '#FFF4E6', small: 'rgba(255,111,97,0.7)',
    sheen: false,
  },
  tinted: { // grayscale on black; iOS applies the user's tint
    bg: '#000000',
    glyph: '#FFFFFF', glyphShadow: 'rgba(0,0,0,0)',
    track: 'rgba(255,255,255,0.16)', ring: ['#BFBFBF', '#BFBFBF'], dot: '#FFFFFF', small: 'rgba(255,255,255,0.6)',
    sheen: false,
  },
};

function html(v) {
  // Ring: centre (512, 512), radius 400, sweeping 300° clockwise from the bottom-left (А) to just short of a full circle.
  const cx = 512, cy = 512, r = 360;
  const start = 125, sweep = 290; // degrees, 0 = 3 o'clock, clockwise
  const rad = d => d * Math.PI / 180;
  const p = d => [cx + r * Math.cos(rad(d)), cy + r * Math.sin(rad(d))];
  const [sx, sy] = p(start), [ex, ey] = p(start + sweep);
  const arc = `M ${sx} ${sy} A ${r} ${r} 0 1 1 ${ex} ${ey}`;
  return `<!doctype html><html><head><style>
    html,body{margin:0;width:1024px;height:1024px;overflow:hidden;background:#000}
    .icon{position:relative;width:1024px;height:1024px;background:${v.bg}}
    svg{position:absolute;inset:0}
  </style></head><body><div class="icon">
  <svg width="1024" height="1024" viewBox="0 0 1024 1024">
    <defs>
      <linearGradient id="ring" x1="0" y1="1" x2="1" y2="0">
        <stop offset="0" stop-color="${v.ring[1]}"/><stop offset="1" stop-color="${v.ring[0]}"/>
      </linearGradient>
      <radialGradient id="glow"><stop offset="0" stop-color="${v.dot}" stop-opacity="0.9"/><stop offset="1" stop-color="${v.dot}" stop-opacity="0"/></radialGradient>
      <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="${v.glyphShadow}"/></filter>
      <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#fff" stop-opacity="0.18"/><stop offset="0.45" stop-color="#fff" stop-opacity="0"/>
      </linearGradient>
    </defs>
    ${v.sheen ? '<rect width="1024" height="1024" fill="url(#sheen)"/>' : ''}
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${v.track}" stroke-width="38"/>
    <path d="${arc}" fill="none" stroke="url(#ring)" stroke-width="38" stroke-linecap="round"/>
    <circle cx="${ex}" cy="${ey}" r="66" fill="url(#glow)"/>
    <circle cx="${ex}" cy="${ey}" r="29" fill="${v.dot}"/>
    <text x="${sx - 52}" y="${sy + 92}" text-anchor="middle" font-family="FreeSerif" font-weight="700" font-size="92" fill="${v.small}">А</text>
    <text x="526" y="722" text-anchor="middle" font-family="FreeSerif" font-weight="700" font-size="580" fill="${v.glyph}" filter="url(#soft)">Я</text>
  </svg></div></body></html>`;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
  for (const [name, v] of Object.entries(variants)) {
    await page.setContent(html(v));
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `AppIcon-${name}.png`, omitBackground: false });
  }
  await browser.close();
})();
