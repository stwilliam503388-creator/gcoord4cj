/**
 * cj-gcoord Demo Application
 *
 * 功能演示 / Feature Showcase
 * ─────────────────────────────────────────────────────────────────────────
 * 本示例模拟「GPS 轨迹与 GeoJSON POI 处理」场景，展示 cj-gcoord 库的全部
 * 公开 API：坐标系转换、GeoJSON 变换、别名处理和异常捕获。
 *
 * This demo simulates a "GPS track & GeoJSON POI processing" scenario and
 * exercises every public API in the cj-gcoord library.
 *
 * Scenarios covered
 * ─────────────────
 *   1. GPS track   WGS84 → GCJ02  (AutoNavi / Google Maps China)
 *   2. Baidu POI   WGS84 → BD09   (Baidu Maps SDK)
 *   3. Tile server WGS84 → EPSG:3857 (Web Mercator, metres)
 *   4. Inverse     GCJ02 → WGS84  (recover GPS position from map click)
 *   5. GeoJSON LineString route transform (batch via transformGeoJSON)
 *   6. GeoJSON FeatureCollection POI dataset transform
 *   7. CRS aliases: EPSG4326 ≡ WGS84, BD09LL ≡ BD09
 *   8. Error handling: invalid coordinates raise descriptive exceptions
 *
 * Build and run
 * ─────────────
 *   # From the examples/ directory:
 *   cjpm build && cjpm run
 *
 *   # Or compile manually against the library:
 *   cjc --package-path .. src/main.cj -o demo && ./demo
 */
package cj_gcoord_demo

import std.math.*

import cj_gcoord.*
import cj_gcoord.crs.*
import cj_gcoord.geojson.*

// ---------------------------------------------------------------------------
// Minimal print helpers — only use toString() which is universally available
// ---------------------------------------------------------------------------

func coordStr(arr: Array<Float64>): String {
    "[" + arr[0].toString() + ", " + arr[1].toString() + "]"
}

func header(title: String): Unit {
    println("")
    println("=== " + title + " ===")
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

main(): Int64 {
    println("cj-gcoord Coordinate Conversion Demo")
    println("======================================")

    // =========================================================================
    // Scenario 1 — GPS Track: WGS84 → GCJ02
    //
    // Raw GPS receivers record WGS84.  AutoNavi (高德) and Google Maps China
    // use GCJ02.  Without conversion, points appear offset by ~300-500 m.
    // =========================================================================
    header("1. GPS Track  WGS84 → GCJ02  (AutoNavi / Google China)")

    let gpsWgs: Array<Array<Float64>> = [
        [116.404,  39.915 ],   // 北京 Beijing
        [121.4737, 31.2304],   // 上海 Shanghai
        [113.2644, 23.1291],   // 广州 Guangzhou
        [104.0668, 30.5728],   // 成都 Chengdu
        [87.6177,  43.7928]    // 乌鲁木齐 Urumqi
    ]

    for (fix in gpsWgs) {
        let gcj = transform(fix, CRS.WGS84, CRS.GCJ02)
        println("  WGS84 " + coordStr(fix) + " -> GCJ02 " + coordStr(gcj))
    }

    // =========================================================================
    // Scenario 2 — Baidu POI export: WGS84 → BD09
    //
    // Baidu Maps SDK expects BD09 coordinates.
    // =========================================================================
    header("2. Baidu POI Export  WGS84 → BD09")

    let pois: Array<Array<Float64>> = [
        [116.404,  39.915 ],   // 天安门 Tiananmen
        [121.4737, 31.2304],   // 外滩 The Bund, Shanghai
        [91.1322,  29.6594]    // 布达拉宫 Potala Palace, Lhasa
    ]

    for (poi in pois) {
        let bd = transform(poi, CRS.WGS84, CRS.BD09)
        println("  WGS84 " + coordStr(poi) + " -> BD09 " + coordStr(bd))
    }

    // =========================================================================
    // Scenario 3 — Web Mercator: WGS84 → EPSG:3857
    //
    // Tile-based servers (OpenStreetMap, Mapbox) use Web Mercator.
    // X and Y are in metres relative to the equatorial circumference.
    // =========================================================================
    header("3. Web Mercator Tiles  WGS84 → EPSG:3857  (metres)")

    let wgsPoints: Array<Array<Float64>> = [
        [116.404,  39.915],   // Beijing
        [0.0,       0.0  ],   // Null Island
        [180.0,     0.0  ]    // International Date Line
    ]

    for (pt in wgsPoints) {
        let merc = transform(pt, CRS.WGS84, CRS.EPSG3857)
        println("  WGS84 " + coordStr(pt) + " -> EPSG:3857 [" +
                merc[0].toString() + " m, " + merc[1].toString() + " m]")
    }

    // =========================================================================
    // Scenario 4 — Inverse conversion: GCJ02 → WGS84 (30-step iteration)
    //
    // When a user taps an AutoNavi map point (GCJ02), recover the GPS position.
    // The round-trip error should be < 1e-5 °  (≈ 1 m).
    // =========================================================================
    header("4. Inverse  GCJ02 → WGS84  (iterative, 30 steps)")

    let gcjPts: Array<Array<Float64>> = [
        [116.41028, 39.91637],   // GCJ02 Beijing
        [121.4862,  31.2198 ]    // GCJ02 Shanghai
    ]

    for (pt in gcjPts) {
        let wgs  = transform(pt, CRS.GCJ02, CRS.WGS84)
        let back = transform(wgs, CRS.WGS84, CRS.GCJ02)
        let errLng = abs(back[0] - pt[0])
        let errLat = abs(back[1] - pt[1])
        println("  GCJ02 " + coordStr(pt) + " -> WGS84 " + coordStr(wgs))
        println("    Round-trip error: lng=" + errLng.toString() +
                " lat=" + errLat.toString() + " (both should be < 1e-5)")
    }

    // =========================================================================
    // Scenario 5 — GeoJSON LineString route: WGS84 → GCJ02
    //
    // transformGeoJSON converts every vertex in one call and returns a new
    // GeoJSON object of the same type (LineString).
    // =========================================================================
    header("5. GeoJSON LineString Route  WGS84 → GCJ02")

    let route = LineString([
        [116.404, 39.915],
        [117.100, 39.500],
        [118.200, 38.900]
    ])
    let gcjRoute = transformGeoJSON(route, CRS.WGS84, CRS.GCJ02)

    println("  Input  type: " + route.getType())
    println("  Output type: " + gcjRoute.getType() + "  (must be identical)")
    match (gcjRoute) {
        case ls: LineString =>
            println("  Vertex count: " + ls.coordinates.size.toString())
            var i = 0
            for (v in ls.coordinates) {
                println("    vertex " + i.toString() + ": GCJ02 " + coordStr(v))
                i = i + 1
            }
        case _ => println("  ERROR: unexpected type")
    }

    // =========================================================================
    // Scenario 6 — GeoJSON FeatureCollection: WGS84 → BD09
    //
    // FeatureCollection may contain heterogeneous geometries.  Properties are
    // preserved unchanged; only coordinates are transformed.
    // =========================================================================
    header("6. GeoJSON FeatureCollection  WGS84 → BD09")

    let poiFC = FeatureCollection([
        Feature(
            Some<Geometry>(Point([116.404, 39.915])),
            Some<String>("{\"name\":\"Tiananmen\",\"category\":\"landmark\"}")
        ),
        Feature(
            Some<Geometry>(LineString([[121.0, 31.0], [121.5, 31.5]])),
            Some<String>("{\"name\":\"Shanghai Route\",\"category\":\"route\"}")
        ),
        Feature(
            None<Geometry>,
            Some<String>("{\"name\":\"No geometry\",\"note\":\"geometry is null\"}")
        )
    ])

    let bd09FC = transformGeoJSON(poiFC, CRS.WGS84, CRS.BD09)
    println("  Output type: " + bd09FC.getType())
    match (bd09FC) {
        case fc: FeatureCollection =>
            println("  Feature count: " + fc.features.size.toString())
            var fi = 0
            for (feat in fc.features) {
                let geomType = match (feat.geometry) {
                    case Some(g) => g.getType()
                    case None    => "null"
                }
                let propStr = match (feat.properties) {
                    case Some(p) => p
                    case None    => "(none)"
                }
                println("  Feature " + fi.toString() +
                        ": geom=" + geomType + "  props=" + propStr)
                fi = fi + 1
            }
        case _ => println("  ERROR: unexpected type")
    }

    // =========================================================================
    // Scenario 7 — CRS aliases
    //
    // EPSG4326 ≡ WGS84 and BD09LL ≡ BD09 are normalised internally so the
    // results are bit-for-bit identical to the canonical CRS.
    // =========================================================================
    header("7. CRS Aliases  EPSG4326 ≡ WGS84,  BD09LL ≡ BD09")

    let testPt: Array<Float64> = [116.404, 39.915]

    let via_wgs84    = transform(testPt, CRS.WGS84,    CRS.GCJ02)
    let via_epsg4326 = transform(testPt, CRS.EPSG4326, CRS.GCJ02)
    let eqGcj = (via_wgs84[0] == via_epsg4326[0]) && (via_wgs84[1] == via_epsg4326[1])
    println("  WGS84→GCJ02:    " + coordStr(via_wgs84))
    println("  EPSG4326→GCJ02: " + coordStr(via_epsg4326))
    println("  Bit-identical:  " + eqGcj.toString())

    let via_bd09   = transform(testPt, CRS.WGS84, CRS.BD09)
    let via_bd09ll = transform(testPt, CRS.WGS84, CRS.BD09LL)
    let eqBd = (via_bd09[0] == via_bd09ll[0]) && (via_bd09[1] == via_bd09ll[1])
    println("  WGS84→BD09:   " + coordStr(via_bd09))
    println("  WGS84→BD09LL: " + coordStr(via_bd09ll))
    println("  Bit-identical: " + eqBd.toString())

    // =========================================================================
    // Scenario 8 — Error handling
    //
    // All invalid inputs throw Exception with a descriptive message.
    // =========================================================================
    header("8. Error Handling  — invalid coordinates")

    // 8a. Empty coordinate array
    var caught = false
    try {
        let _ = transform([], CRS.WGS84, CRS.GCJ02)
    } catch (_: Exception) {
        caught = true
    }
    println("  Empty array   throws Exception: " + caught.toString())

    // 8b. Longitude > 180
    caught = false
    try {
        let _ = transform([200.0, 39.0], CRS.WGS84, CRS.GCJ02)
    } catch (_: Exception) {
        caught = true
    }
    println("  lng=200.0     throws Exception: " + caught.toString())

    // 8c. Latitude < -90
    caught = false
    try {
        let _ = transform([116.0, -91.0], CRS.WGS84, CRS.GCJ02)
    } catch (_: Exception) {
        caught = true
    }
    println("  lat=-91.0     throws Exception: " + caught.toString())

    // 8d. NaN input (handled by (x != x) IEEE 754 guard added in gcoord.cj)
    caught = false
    try {
        let nanVal: Float64 = 0.0 / 0.0   // IEEE 754 NaN — avoids Float64.isNaN() (unverified API)
        let _ = transform([nanVal, 39.0], CRS.WGS84, CRS.GCJ02)
    } catch (_: Exception) {
        caught = true
    }
    println("  lng=NaN       throws Exception: " + caught.toString())

    // =========================================================================
    // Done
    // =========================================================================
    header("Demo complete")
    println("  Run 'cjpm test' from the project root for the full test suite.")
    println("")

    return 0
}
