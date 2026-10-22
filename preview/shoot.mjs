// Takes phone-size screenshots of every PureBurn screen using sample data.
// Run by .github/workflows/preview.yml. Not part of the app.
import { chromium } from 'playwright';
import fs from 'fs';

const BASE = process.env.BASE_URL || 'http://localhost:8080/';
const OUT = process.env.OUT_DIR || 'shots';
fs.mkdirSync(OUT, { recursive: true });

const pad = (n) => String(n).padStart(2, '0');
const iso = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);

const today = new Date();
const monday = addDays(today, -((today.getDay() + 6) % 7));
const logs = {};
const waterByDay = [8, 6, 7, 5, 8, 3, 0];
const stepsByDay = [9400, 7200, 10100, 6100, 8800, 3000, 0];
for (let i = 0; i < 7; i++) {
  const day = addDays(monday, i);
  if (iso(day) > iso(today)) continue;
  const full = i % 2 === 0;
  logs[iso(day)] = {
    ex: full ? ['wu', 'main', 'cd'] : ['wu', 'main'],
    meal: full ? ['bf', 'mm', 'ln', 'sn'] : ['bf', 'ln'],
    water: waterByDay[i],
    steps: stepsByDay[i],
  };
}
const weights = [];
const w0 = 88;
for (let k = 5; k >= 0; k--) {
  weights.push({ d: iso(addDays(today, -k * 6)), kg: Math.round((w0 - (5 - k) * 0.7) * 10) / 10 });
}
const state = {
  p: { unit: 'metric', sex: 'm', age: 32, act: 'light', heightCm: 172, weightKg: 84.5, std: 'asia', goal: 'lose', targetKg: 74, pace: 'steady', days: 4, place: 'home', budget: 'std' },
  logs,
  weights,
  meas: [0, 1, 2, 3].map((k) => ({ d: iso(addDays(today, -(3 - k) * 10)), waist: 98 - k * 1.8, chest: 104 - k * 0.6, hip: 106 - k * 0.8 })),
};
// shared_preferences on the web keeps strings as JSON inside localStorage with a "flutter." prefix.
const stored = JSON.stringify(JSON.stringify(state));

const screens = [
  ['01-dashboard', 'dashboard'],
  ['02-profile-and-goal', 'profile'],
  ['03-your-plan', 'result'],
  ['04-bmi-and-weight', 'bmi'],
  ['05-daily-exercise', 'dex'],
  ['06-daily-diet', 'ddiet'],
  ['07-exercise-plan', 'explan'],
  ['08-diet-plan', 'dietplan'],
  ['09-progress', 'progress'],
  ['12-measurements', 'measure'],
  ['13-weekly-report', 'report'],
  ['14-settings', 'settings'],
];

const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'] });
async function shoot(name, mod, dark, w = 390, h = 1500, lang = '') {
  const ctx = await browser.newContext({
    viewport: { width: w, height: h },
    deviceScaleFactor: w > 600 ? 1 : 2,
    isMobile: w <= 600,
    hasTouch: w <= 600,
    locale: 'en-US',
    timezoneId: 'Asia/Karachi',
    colorScheme: dark ? 'dark' : 'light',
  });
  await ctx.addInitScript((v) => {
    try { localStorage.setItem('flutter.pureburn-state-v1', v); } catch (e) {}
  }, stored);
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.log('pageerror', name, e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.log('console.error', name, m.text().slice(0, 300)); });
  page.on('requestfailed', (r) => console.log('requestfailed', name, r.url().slice(0, 150), r.failure()?.errorText));
  await page.goto(`${BASE}?mod=${mod}${lang ? '&lang=' + lang : ''}`, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.waitForSelector('flt-glass-pane', { timeout: 25000, state: 'attached' });
  await page.waitForTimeout(5000);
  console.log('rendered', name, await page.evaluate(() => document.querySelectorAll('flt-glass-pane, canvas').length));
  await page.screenshot({ path: `${OUT}/${name}.png`, timeout: 20000 });
  console.log('saved', name);
  await ctx.close();
}

for (const [name, mod] of screens) {
  try { await shoot(name, mod, false, 390, mod === 'progress' ? 2600 : 1500); } catch (e) { console.log('FAILED', name, String(e).slice(0, 400)); }
}
try { await shoot('10-dashboard-dark', 'dashboard', true); } catch (e) { console.log('FAILED dark', String(e).slice(0, 400)); }
try { await shoot('11-dashboard-desktop', 'dashboard', false, 1100, 800); } catch (e) { console.log('FAILED desktop', String(e).slice(0, 400)); }

// A short screen recording so the animations can be seen.
try {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
    isMobile: true,
    hasTouch: true,
    locale: 'en-US',
    timezoneId: 'Asia/Karachi',
    recordVideo: { dir: process.env.CLIP_DIR || '../clip', size: { width: 390, height: 844 } },
  });
  await ctx.addInitScript((v) => {
    try { localStorage.setItem('flutter.pureburn-state-v1', v); } catch (e) {}
  }, stored);
  const page = await ctx.newPage();
  for (const mod of ['dashboard', 'bmi', 'dex', 'ddiet', 'dietplan', 'progress']) {
    await page.goto(`${BASE}?mod=${mod}`, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForSelector('flt-glass-pane', { timeout: 25000, state: 'attached' });
    await page.waitForTimeout(2500);
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(1500);
    await page.mouse.wheel(0, 700);
    await page.waitForTimeout(1500);
    console.log('clip', mod);
  }
  await ctx.close();
} catch (e) { console.log('CLIP FAILED', String(e).slice(0, 400)); }
await browser.close();
