const fs = require('fs');
const strategy = process.argv[2] || 'mobile';
const file = `/tmp/pagespeed-${strategy}.json`;
const raw = fs.readFileSync(file, 'utf8');
const data = JSON.parse(raw);
const c = data.lighthouseResult.categories;
const audits = data.lighthouseResult.audits;

console.log(`\n=== PageSpeed Insights (${strategy.toUpperCase()}) ===`);
console.log('');
Object.entries(c).forEach(([k, v]) => {
  const score = typeof v.score === 'number' ? (v.score * 100).toFixed(0) : 'N/A';
  console.log(`  ${k.padEnd(20)} ${score}`);
});

// Top diagnostics
console.log('');
console.log('--- Key Metrics ---');
['first-contentful-paint', 'largest-contentful-paint', 'total-blocking-time', 'cumulative-layout-shift', 'speed-index'].forEach(key => {
  const a = audits[key];
  if (a) {
    const val = a.numericValue ? `${a.numericValue.toFixed(1)} ${a.numericUnit || ''}` : a.score !== undefined ? `${(a.score * 100).toFixed(0)}` : 'N/A';
    console.log(`  ${key.padEnd(30)} ${val}`);
  }
});
