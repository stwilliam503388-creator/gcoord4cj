// Benchmark GeoJSON Polygon conversion for diagnostic table
const gcoord = require('gcoord');

function genPoly(nPts) {
  // Generate a simple polygon ring with nPts points in China bbox
  const ring = [];
  for (let i = 0; i < nPts; i++) {
    ring.push([73.66 + Math.random()*(135.05-73.66), 3.86 + Math.random()*(53.55-3.86)]);
  }
  ring.push(ring[0]); // close ring
  return { type: 'Polygon', coordinates: [ring] };
}

function genPoint() {
  return { type: 'Point', coordinates: [73.66 + Math.random()*(135.05-73.66), 3.86 + Math.random()*(53.55-3.86)] };
}

const ROUNDS = 5;

function benchGeo(label, N, genFn) {
  const items = Array.from({length: N}, genFn);
  // warmup
  for (let i = 0; i < 10; i++) gcoord.transform(items[i%N], gcoord.WGS84, gcoord.GCJ02);
  const times = [];
  for (let r = 0; r < ROUNDS; r++) {
    const t0 = process.hrtime.bigint();
    for (let i = 0; i < N; i++) gcoord.transform(items[i], gcoord.WGS84, gcoord.GCJ02);
    times.push(Number(process.hrtime.bigint()-t0)/1e6);
  }
  const avg = times.reduce((a,b)=>a+b,0)/ROUNDS;
  const ops = Math.round(N/(avg/1000));
  const nsOp = (avg*1e6/N).toFixed(0);
  console.log(`${label.padEnd(30)} avg=${avg.toFixed(2)}ms  ${(ops/1000).toFixed(0)}k ops/s  ${nsOp} ns/op`);
}

console.log('=== GeoJSON JS benchmarks ===');
benchGeo('1000 × Point (WGS84→GCJ02)',     1000, genPoint);
benchGeo('100 × Polygon(50pts)',             100, () => genPoly(50));
benchGeo('100 × Polygon(50pts) GCJ02→WGS84',100, () => genPoly(50));
