/**
 * gcoord JavaScript 版性能基准测试
 * Performance benchmark for gcoord (JavaScript / Node.js)
 *
 * 与仓颉版 bench/src/main.cj 对齐，便于横向对比。
 *
 * 运行 / Run:
 *   node bench/benchmark.js
 *
 * 依赖 / Dependency:
 *   npm install gcoord  (from repository root or bench/)
 */
const gcoord = require('gcoord');

// ─── 测试数据 ───────────────────────────────────────────────────────────────
function genCoords(n) {
  const arr = [];
  for (let i = 0; i < n; i++) {
    // lng: 73.66~135.05,  lat: 3.86~53.55  (mainland China bbox)
    const lng = 73.66 + Math.random() * (135.05 - 73.66);
    const lat =  3.86 + Math.random() * ( 53.55 -  3.86);
    arr.push([lng, lat]);
  }
  return arr;
}

const N      = 100000;   // points per round
const ROUNDS = 5;        // rounds (take average)
const coords = genCoords(N);

// ─── 基准测试工具 ────────────────────────────────────────────────────────────
function bench(label, fn) {
  // warm-up
  for (let i = 0; i < 1000; i++) fn(coords[i % coords.length]);

  const times = [];
  for (let r = 0; r < ROUNDS; r++) {
    const t0 = process.hrtime.bigint();
    for (let i = 0; i < N; i++) fn(coords[i]);
    const t1 = process.hrtime.bigint();
    times.push(Number(t1 - t0) / 1e6);  // ns → ms
  }
  const avg    = times.reduce((a, b) => a + b, 0) / ROUNDS;
  const min    = Math.min(...times);
  const max    = Math.max(...times);
  const ops    = Math.round(N / (avg / 1000));
  const nsPerOp = (avg * 1e6 / N).toFixed(1);
  console.log(
    `${label.padEnd(28)} | avg=${avg.toFixed(2).padStart(8)}ms` +
    ` | min=${min.toFixed(2).padStart(8)}ms` +
    ` | max=${max.toFixed(2).padStart(8)}ms` +
    ` | ${(ops/1000).toFixed(0).padStart(7)}k ops/s` +
    ` | ${nsPerOp.padStart(9)} ns/op`
  );
  return { label, avg, min, max, ops, nsPerOp: parseFloat(nsPerOp) };
}

// ─── GeoJSON 基准测试 ────────────────────────────────────────────────────────
function benchGeoJSON(label, fn) {
  const M = 10000;
  const pts = genCoords(M);
  const geojsons = pts.map(p => ({ type: 'Point', coordinates: p }));

  for (let i = 0; i < 100; i++) fn(geojsons[i % geojsons.length]);

  const times = [];
  for (let r = 0; r < ROUNDS; r++) {
    const t0 = process.hrtime.bigint();
    for (let i = 0; i < M; i++) fn(geojsons[i]);
    const t1 = process.hrtime.bigint();
    times.push(Number(t1 - t0) / 1e6);
  }
  const avg    = times.reduce((a, b) => a + b, 0) / ROUNDS;
  const min    = Math.min(...times);
  const max    = Math.max(...times);
  const ops    = Math.round(M / (avg / 1000));
  const nsPerOp = (avg * 1e6 / M).toFixed(1);
  console.log(
    `${label.padEnd(28)} | avg=${avg.toFixed(2).padStart(8)}ms` +
    ` | min=${min.toFixed(2).padStart(8)}ms` +
    ` | max=${max.toFixed(2).padStart(8)}ms` +
    ` | ${(ops/1000).toFixed(0).padStart(7)}k ops/s` +
    ` | ${nsPerOp.padStart(9)} ns/op`
  );
  return { label, avg, min, max, ops, nsPerOp: parseFloat(nsPerOp) };
}

// ─── 运行测试 ────────────────────────────────────────────────────────────────
const SEP = '='.repeat(96);
const DASH = '-'.repeat(96);

console.log(SEP);
console.log(`gcoord JavaScript 版 — 性能基准测试`);
console.log(`Node.js ${process.version}  |  N=${N.toLocaleString()} 点/轮 × ${ROUNDS} 轮`);
console.log(SEP);
console.log(`${'测试项'.padEnd(28)} | ${'平均耗时'.padStart(12)} | ${'最小耗时'.padStart(12)} | ${'最大耗时'.padStart(12)} | ${'吞吐量'.padStart(11)} | ${'单次耗时'.padStart(13)}`);
console.log(DASH);

const results = [];
results.push(bench('WGS84 → GCJ02',           c => gcoord.transform(c, gcoord.WGS84, gcoord.GCJ02)));
results.push(bench('GCJ02 → WGS84',           c => gcoord.transform(c, gcoord.GCJ02, gcoord.WGS84)));
results.push(bench('GCJ02 → BD09',            c => gcoord.transform(c, gcoord.GCJ02, gcoord.BD09)));
results.push(bench('BD09  → GCJ02',           c => gcoord.transform(c, gcoord.BD09,  gcoord.GCJ02)));
results.push(bench('WGS84 → BD09',            c => gcoord.transform(c, gcoord.WGS84, gcoord.BD09)));
results.push(bench('BD09  → WGS84',           c => gcoord.transform(c, gcoord.BD09,  gcoord.WGS84)));
results.push(bench('WGS84 → EPSG3857',        c => gcoord.transform(c, gcoord.WGS84, gcoord.EPSG3857)));
results.push(bench('EPSG3857 → WGS84',        c => gcoord.transform(c, gcoord.EPSG3857, gcoord.WGS84)));
results.push(bench('WGS84 → EPSG4326 (same)', c => gcoord.transform(c, gcoord.WGS84, gcoord.EPSG4326)));

console.log(DASH);
console.log('\nGeoJSON Point 转换（M = 10,000 对象/轮 × 5 轮）');
console.log(DASH);
results.push(benchGeoJSON('GeoJSON Point WGS84→GCJ02', g => gcoord.transform(g, gcoord.WGS84, gcoord.GCJ02)));
results.push(benchGeoJSON('GeoJSON Point GCJ02→WGS84', g => gcoord.transform(g, gcoord.GCJ02, gcoord.WGS84)));
results.push(benchGeoJSON('GeoJSON Point WGS84→BD09',  g => gcoord.transform(g, gcoord.WGS84, gcoord.BD09)));

console.log(SEP);

const coordResults = results.slice(0, 8);
const avgOps = coordResults.reduce((s, r) => s + r.ops, 0) / coordResults.length;
console.log(`\n综合平均吞吐量（前 8 项坐标数组转换）: ${(avgOps / 1000).toFixed(0)}k ops/s`);
console.log('\n注: JS gcoord GCJ02→WGS84 使用收敛循环（while |dx|>1e-6），境内约 3–4 次迭代');
console.log('    仓颉版 (O2优化后) 使用相同收敛策略，阈值 1e-10°，典型 4 次迭代，与本 JS 数据直接可比');
console.log('    Cangjie benchmark: cd bench && cjpm build --release && cjpm run');
