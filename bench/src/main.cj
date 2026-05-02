/**
 * cj-gcoord 性能基准测试
 * Performance Benchmark for cj-gcoord (Cangjie implementation)
 *
 * 测试场景与 JS 版本保持一致，便于横向对比：
 *   - 100,000 点 × 5 轮，取平均值
 *   - 覆盖所有 8 条转换路径 + GeoJSON Point 场景
 *
 * 构建并运行 / Build and run:
 *   cd bench && cjpm build && cjpm run
 *
 * 时间测量说明 / Timing note:
 *   Uses std.time.DateTime for wall-clock measurement.
 *   For micro-benchmark accuracy, consider using perf_event or
 *   the system monotonic clock when available.
 */
package cj_gcoord_bench

import std.math.*
import std.time.*

import cj_gcoord.*
import cj_gcoord.crs.*
import cj_gcoord.geojson.*

// ---------------------------------------------------------------------------
// 伪随机坐标生成（LCG — 不引入外部依赖，可重现）
// Pseudo-random coord generator (LCG — no external deps, reproducible)
// ---------------------------------------------------------------------------

var lcgState: UInt64 = 0x123456789ABCDEF0

func lcgNext(): Float64 {
    lcgState = lcgState &* 6364136223846793005u64 &+ 1442695040888963407u64
    // map to [0.0, 1.0)
    return Float64(lcgState >> 11) / Float64(1u64 << 53)
}

/** Generate N coordinates within mainland China bounding box. */
func genCoords(n: Int64): Array<Array<Float64>> {
    // lng: 73.66 ~ 135.05,  lat: 3.86 ~ 53.55
    var arr: Array<Array<Float64>> = Array<Array<Float64>>(n, {_ => [0.0, 0.0]})
    for (i in 0..n) {
        let lng = 73.66 + lcgNext() * (135.05 - 73.66)
        let lat =  3.86 + lcgNext() * ( 53.55 -  3.86)
        arr[i] = [lng, lat]
    }
    return arr
}

// ---------------------------------------------------------------------------
// Timing helpers
// ---------------------------------------------------------------------------

/** Return current time in nanoseconds (wall clock). */
func nowNs(): Int64 {
    let dt = DateTime.now()
    // DateTime.toUnixTimeStamp() returns Duration; use toNanoseconds()
    return dt.toUnixTimeStamp().toNanoseconds()
}

// ---------------------------------------------------------------------------
// Benchmark runner
// ---------------------------------------------------------------------------

let N: Int64  = 100000   // 每轮坐标点数 / points per round
let ROUNDS: Int64 = 5    // 轮数 / rounds

/**
 * Run one benchmark case.
 * fn receives a coordinate array and must call transform().
 */
func runBench(
    label: String,
    coords: Array<Array<Float64>>,
    fn: (Array<Float64>) -> Array<Float64>
): Unit {
    // warm-up — 1000 calls
    for (i in 0..1000) {
        let _ = fn(coords[i % Int64(coords.size)])
    }

    var totalNs: Int64 = 0
    var minNs: Int64 = 9223372036854775807i64   // Int64.MAX
    var maxNs: Int64 = 0

    for (_ in 0..ROUNDS) {
        let t0 = nowNs()
        for (i in 0..N) {
            let _ = fn(coords[i % Int64(coords.size)])
        }
        let elapsed = nowNs() - t0
        totalNs += elapsed
        if (elapsed < minNs) { minNs = elapsed }
        if (elapsed > maxNs) { maxNs = elapsed }
    }

    let avgNs   = totalNs / ROUNDS
    let avgMs   = Float64(avgNs) / 1_000_000.0
    let minMs   = Float64(minNs) / 1_000_000.0
    let maxMs   = Float64(maxNs) / 1_000_000.0
    let opsPerS = Float64(N) / (avgMs / 1000.0)
    let nsPerOp = Float64(avgNs) / Float64(N)

    // Pad label to 22 chars
    var paddedLabel = label
    while (paddedLabel.size < 22) { paddedLabel = paddedLabel + " " }

    println(
        paddedLabel + " | avg=" + fmtF(avgMs, 2) + "ms" +
        " | min=" + fmtF(minMs, 2) + "ms" +
        " | max=" + fmtF(maxMs, 2) + "ms" +
        " | " + fmtF(opsPerS / 1000.0, 0) + "k ops/s" +
        " | " + fmtF(nsPerOp, 1) + " ns/op"
    )
}

/** Run a GeoJSON benchmark with M point objects. */
func runGeoJSONBench(
    label: String,
    from: CRS,
    to: CRS
): Unit {
    let M: Int64 = 10000
    let pts = genCoords(M)
    var geojsons: Array<GeoJSON> = Array<GeoJSON>(M, {i => Point(pts[i])})

    // warm-up
    for (i in 0..100) {
        let _ = transformGeoJSON(geojsons[i % M], from, to)
    }

    var totalNs: Int64 = 0
    var minNs: Int64 = 9223372036854775807i64
    var maxNs: Int64 = 0

    for (_ in 0..ROUNDS) {
        let t0 = nowNs()
        for (i in 0..M) {
            let _ = transformGeoJSON(geojsons[i], from, to)
        }
        let elapsed = nowNs() - t0
        totalNs += elapsed
        if (elapsed < minNs) { minNs = elapsed }
        if (elapsed > maxNs) { maxNs = elapsed }
    }

    let avgNs   = totalNs / ROUNDS
    let avgMs   = Float64(avgNs) / 1_000_000.0
    let minMs   = Float64(minNs) / 1_000_000.0
    let maxMs   = Float64(maxNs) / 1_000_000.0
    let opsPerS = Float64(M) / (avgMs / 1000.0)
    let nsPerOp = Float64(avgNs) / Float64(M)

    var paddedLabel = label
    while (paddedLabel.size < 22) { paddedLabel = paddedLabel + " " }

    println(
        paddedLabel + " | avg=" + fmtF(avgMs, 2) + "ms" +
        " | min=" + fmtF(minMs, 2) + "ms" +
        " | max=" + fmtF(maxMs, 2) + "ms" +
        " | " + fmtF(opsPerS / 1000.0, 0) + "k ops/s" +
        " | " + fmtF(nsPerOp, 1) + " ns/op"
    )
}

// ---------------------------------------------------------------------------
// Float formatting helper (no std.format dependency)
// ---------------------------------------------------------------------------

/** Format f with `dec` decimal places. */
func fmtF(f: Float64, dec: Int64): String {
    if (dec == 0) {
        return Int64(f + 0.5).toString()
    }
    let scale: Float64 = pow(10.0, Float64(dec))
    let rounded = Float64(Int64(f * scale + 0.5)) / scale
    let intPart = Int64(rounded)
    let fracPart = Int64((rounded - Float64(intPart)) * scale + 0.5)
    var fracStr = fracPart.toString()
    // zero-pad fraction
    while (Int64(fracStr.size) < dec) { fracStr = "0" + fracStr }
    return intPart.toString() + "." + fracStr
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

/** Repeat character c n times to form a string. */
func strRepeat(c: String, n: Int64): String {
    var result = ""
    for (_ in 0..n) { result += c }
    return result
}

main(): Int64 {
    let sep = strRepeat("=", 92)
    let dash = strRepeat("-", 92)

    println(sep)
    println("cj-gcoord 仓颉版 — 性能基准测试  (N=" + N.toString() + " 点/轮 × " + ROUNDS.toString() + " 轮)")
    println(sep)
    println("测试项                   | 平均耗时     | 最小耗时     | 最大耗时     | 吞吐量        | 单次耗时")
    println(dash)

    let coords = genCoords(N)

    runBench("WGS84 → GCJ02",    coords, {c => transform(c, CRS.WGS84, CRS.GCJ02)})
    runBench("GCJ02 → WGS84",    coords, {c => transform(c, CRS.GCJ02, CRS.WGS84)})
    runBench("GCJ02 → BD09",     coords, {c => transform(c, CRS.GCJ02, CRS.BD09)})
    runBench("BD09  → GCJ02",    coords, {c => transform(c, CRS.BD09,  CRS.GCJ02)})
    runBench("WGS84 → BD09",     coords, {c => transform(c, CRS.WGS84, CRS.BD09)})
    runBench("BD09  → WGS84",    coords, {c => transform(c, CRS.BD09,  CRS.WGS84)})
    runBench("WGS84 → EPSG3857", coords, {c => transform(c, CRS.WGS84, CRS.EPSG3857)})
    runBench("EPSG3857 → WGS84", coords, {c => transform(c, CRS.EPSG3857, CRS.WGS84)})
    runBench("WGS84 → EPSG4326 (same)", coords, {c => transform(c, CRS.WGS84, CRS.EPSG4326)})

    println(dash)
    println("\nGeoJSON Point 转换（10,000 对象）")
    println(dash)

    runGeoJSONBench("GeoJSON WGS84→GCJ02",  CRS.WGS84, CRS.GCJ02)
    runGeoJSONBench("GeoJSON GCJ02→WGS84",  CRS.GCJ02, CRS.WGS84)
    runGeoJSONBench("GeoJSON WGS84→BD09",   CRS.WGS84, CRS.BD09)

    println(sep)
    println("注：GCJ02→WGS84 使用收敛退出循环（阈值 1×10⁻¹⁰ 度），中国境内典型 ~4 次迭代，精度 < 1×10⁻¹⁰ 度（≈0.01 mm）")
    println("    JS版使用同样收敛策略（阈值 1×10⁻⁶ 度），境内约 3 次迭代（精度 ≈0.1 m）")
    println("    仓颉版精度更高（阈值更严），两者吞吐量差距预计 < 1.5× (仓颉更快)")
    return 0
}
