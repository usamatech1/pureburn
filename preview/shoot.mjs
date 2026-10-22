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
];

const browser = await chromium.launch();
async function shoot(name, mod, dark) {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 1500 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
    colorScheme: dark ? 'dark' : 'light',
  });
  await ctx.addInitScript((v) => {
    try { localStorage.setItem('flutter.pureburn-state-v1', v); } catch (e) {}
  }, stored);
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.log('pageerror', name, e.message));
  await page.goto(`${BASE}?mod=${mod}`, { waitUntil: 'load' });
  await page.waitForSelector('flt-glass-pane', { timeout: 60000 });
  await page.waitForTimeout(5000);
  await page.screenshot({ path: `${OUT}/${name}.png` });
  console.log('saved', name);
  await ctx.close();
}

for (const [name, mod] of screens) await shoot(name, mod, false);
await shoot('10-dashboard-dark', 'dashboard', true);
await browser.close();
