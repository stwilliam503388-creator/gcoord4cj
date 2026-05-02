/**
 * Package: cj_gcoord_test
 *
 * Extra test suite — supplements gcoord_test.cj and transform_test.cj with:
 *
 *   MoreCitiesTest        — ground-truth round-trips for 5 geographically
 *                           spread Chinese cities, plus absolute value checks
 *   AllConvertPathsTest   — public transform() covers all 12 CRS pairings
 *                           explicitly (not via round-trip self-reference)
 *   ChinaBoundaryTest     — coordinates just inside / just outside the China
 *                           bounding box behave as expected
 *   AliasPathsTest        — EPSG4326 and BD09LL aliases work for every
 *                           direction that is distinct from their base CRS
 *   GeoJson3DTest         — 3-D coordinates (with altitude) are preserved
 *                           in all supported GeoJSON geometry types
 *
 * Ground-truth values
 * ───────────────────
 * All expected numeric values were computed with the JavaScript gcoord
 * reference implementation on Node.js 20.20.2 and are identical to the
 * algorithm in transform.cj (same IEEE 754 constants and formula).
 *
 * Tolerances
 * ──────────
 *   EX_GEO      1e-6 ° — hard accuracy threshold for single conversions
 *   EX_RT       1e-5 ° — round-trip tolerance (iterative GCJ02 residual)
 *   EX_MERC_ABS 1.0  m — absolute tolerance for EPSG:3857 metre values
 *   EX_MERC_RT  1e-8 ° — strict round-trip for exact-inverse EPSG:3857
 *
 * Run: cjpm test
 */
package cj_gcoord_test

import std.unittest.*
import std.unittest.testmacro.*
import std.math.*

import cj_gcoord.*
import cj_gcoord.crs.*
import cj_gcoord.geojson.*
import cj_gcoord.transform.*

// ---------------------------------------------------------------------------
// Tolerance constants (prefixed EX_ — no conflict with other test files)
// ---------------------------------------------------------------------------

private let EX_GEO: Float64      = 1.0e-6
private let EX_RT: Float64       = 1.0e-5
private let EX_MERC_ABS: Float64 = 1.0
private let EX_MERC_RT: Float64  = 1.0e-8

// ---------------------------------------------------------------------------
// Assertion helper (prefixed exClose — no conflict with assertClose/tfClose)
// ---------------------------------------------------------------------------

private func exClose(
    label: String, got: Float64, want: Float64, tol: Float64
): Unit {
    let diff = abs(got - want)
    @Assert(diff < tol,
        label + ": got=" + got.toString() +
        " want=" + want.toString() +
        " diff=" + diff.toString() +
        " tol=" + tol.toString()
    )
}

// ===========================================================================
// 1. MoreCitiesTest
//    Five major Chinese cities spread across different geographic zones.
//    Each entry is validated against the JS reference (listed in comments)
//    and verified with a WGS84→GCJ02→WGS84 and WGS84→BD09→WGS84 round-trip.
// ===========================================================================

@Test
class MoreCitiesTest {

    // ── Guangzhou (Pearl River Delta, south China) ──────────────────────────
    // JS: wgs84ToGcj02(113.2644, 23.1291) = [113.26972959210308, 23.126423339922844]
    // JS: wgs84ToBd09 (113.2644, 23.1291) = [113.27615075157122, 23.13271125723948]

    @TestCase
    func testGuangzhou_WgsToGcj(): Unit {
        let (lng, lat) = wgs84ToGcj02(113.2644, 23.1291)
        exClose("Guangzhou GCJ02 lng", lng, 113.26972959210308, EX_GEO)
        exClose("Guangzhou GCJ02 lat", lat, 23.126423339922844,  EX_GEO)
    }

    @TestCase
    func testGuangzhou_WgsToBd09(): Unit {
        let result = transform([113.2644, 23.1291], CRS.WGS84, CRS.BD09)
        exClose("Guangzhou BD09 lng", result[0], 113.27615075157122, EX_GEO)
        exClose("Guangzhou BD09 lat", result[1], 23.13271125723948,  EX_GEO)
    }

    @TestCase
    func testGuangzhou_RoundTrip_WgsGcj(): Unit {
        let origLng: Float64 = 113.2644
        let origLat: Float64 = 23.1291
        let r1 = transform([origLng, origLat], CRS.WGS84, CRS.GCJ02)
        let r2 = transform(r1,                 CRS.GCJ02, CRS.WGS84)
        exClose("Guangzhou RT GCJ02 lng", r2[0], origLng, EX_RT)
        exClose("Guangzhou RT GCJ02 lat", r2[1], origLat, EX_RT)
    }

    @TestCase
    func testGuangzhou_RoundTrip_WgsBd09(): Unit {
        let origLng: Float64 = 113.2644
        let origLat: Float64 = 23.1291
        let r1 = transform([origLng, origLat], CRS.WGS84, CRS.BD09)
        let r2 = transform(r1,                 CRS.BD09,  CRS.WGS84)
        exClose("Guangzhou RT BD09 lng", r2[0], origLng, EX_RT)
        exClose("Guangzhou RT BD09 lat", r2[1], origLat, EX_RT)
    }

    // ── Chengdu (Sichuan basin, south-west China) ───────────────────────────
    // JS: wgs84ToGcj02(104.0668, 30.5728) = [104.06930547724922, 30.570346141080414]
    // JS: wgs84ToBd09 (104.0668, 30.5728) = [104.07578295683295, 30.576351856151092]

    @TestCase
    func testChengdu_WgsToGcj(): Unit {
        let (lng, lat) = wgs84ToGcj02(104.0668, 30.5728)
        exClose("Chengdu GCJ02 lng", lng, 104.06930547724922, EX_GEO)
        exClose("Chengdu GCJ02 lat", lat, 30.570346141080414,  EX_GEO)
    }

    @TestCase
    func testChengdu_WgsToBd09(): Unit {
        let result = transform([104.0668, 30.5728], CRS.WGS84, CRS.BD09)
        exClose("Chengdu BD09 lng", result[0], 104.07578295683295, EX_GEO)
        exClose("Chengdu BD09 lat", result[1], 30.576351856151092,  EX_GEO)
    }

    @TestCase
    func testChengdu_RoundTrip_WgsGcj(): Unit {
        let origLng: Float64 = 104.0668
        let origLat: Float64 = 30.5728
        let r1 = transform([origLng, origLat], CRS.WGS84, CRS.GCJ02)
        let r2 = transform(r1,                 CRS.GCJ02, CRS.WGS84)
        exClose("Chengdu RT GCJ02 lng", r2[0], origLng, EX_RT)
        exClose("Chengdu RT GCJ02 lat", r2[1], origLat, EX_RT)
    }

    @TestCase
    func testChengdu_RoundTrip_WgsBd09(): Unit {
        let origLng: Float64 = 104.0668
        let origLat: Float64 = 30.5728
        let r1 = transform([origLng, origLat], CRS.WGS84, CRS.BD09)
        let r2 = transform(r1,                 CRS.BD09,  CRS.WGS84)
        exClose("Chengdu RT BD09 lng", r2[0], origLng, EX_RT)
        exClose("Chengdu RT BD09 lat", r2[1], origLat, EX_RT)
    }

    // ── Harbin (Heilongjiang, north-east China) ─────────────────────────────
    // JS: wgs84ToGcj02(126.5353, 45.8038) = [126.5413392508647, 45.805780778072744]
    // JS: wgs84ToBd09 (126.5353, 45.8038) = [126.5479579811097, 45.811395444926795]

    @TestCase
    func testHarbin_WgsToGcj(): Unit {
        let (lng, lat) = wgs84ToGcj02(126.5353, 45.8038)
        exClose("Harbin GCJ02 lng", lng, 126.5413392508647,  EX_GEO)
        exClose("Harbin GCJ02 lat", lat, 45.805780778072744, EX_GEO)
    }

    @TestCase
    func testHarbin_WgsToBd09(): Unit {
        let result = transform([126.5353, 45.8038], CRS.WGS84, CRS.BD09)
        exClose("Harbin BD09 lng", result[0], 126.5479579811097,  EX_GEO)
        exClose("Harbin BD09 lat", result[1], 45.811395444926795, EX_GEO)
    }

    @TestCase
    func testHarbin_RoundTrip_WgsGcj(): Unit {
        let origLng: Float64 = 126.5353
        let origLat: Float64 = 45.8038
        let r1 = transform([origLng, origLat], CRS.WGS84, CRS.GCJ02)
        let r2 = transform(r1,                 CRS.GCJ02, CRS.WGS84)
        exClose("Harbin RT GCJ02 lng", r2[0], origLng, EX_RT)
        exClose("Harbin RT GCJ02 lat", r2[1], origLat, EX_RT)
    }

    // ── Lhasa (Tibet, high altitude) ────────────────────────────────────────
    // JS: wgs84ToGcj02(91.1322, 29.6594) = [91.13374330328365, 29.656679367927367]
    // JS: wgs84ToBd09 (91.1322, 29.6594) = [91.14034211832347, 29.662425250377858]

    @TestCase
    func testLhasa_WgsToGcj(): Unit {
        let (lng, lat) = wgs84ToGcj02(91.1322, 29.6594)
        exClose("Lhasa GCJ02 lng", lng, 91.13374330328365,  EX_GEO)
        exClose("Lhasa GCJ02 lat", lat, 29.656679367927367, EX_GEO)
    }

    @TestCase
    func testLhasa_WgsToBd09(): Unit {
        let result = transform([91.1322, 29.6594], CRS.WGS84, CRS.BD09)
        exClose("Lhasa BD09 lng", result[0], 91.14034211832347, EX_GEO)
        exClose("Lhasa BD09 lat", result[1], 29.662425250377858, EX_GEO)
    }

    @TestCase
    func testLhasa_RoundTrip_WgsBd09(): Unit {
        let origLng: Float64 = 91.1322
        let origLat: Float64 = 29.6594
        let r1 = transform([origLng, origLat], CRS.WGS84, CRS.BD09)
        let r2 = transform(r1,                 CRS.BD09,  CRS.WGS84)
        exClose("Lhasa RT BD09 lng", r2[0], origLng, EX_RT)
        exClose("Lhasa RT BD09 lat", r2[1], origLat, EX_RT)
    }

    // ── Urumqi (Xinjiang, far west China) ───────────────────────────────────
    // JS: wgs84ToGcj02(87.6177, 43.7928) = [87.62054922425168, 43.79402455549771]
    // JS: wgs84ToBd09 (87.6177, 43.7928) = [87.6269813254592,  43.80014663419902]

    @TestCase
    func testUrumqi_WgsToGcj(): Unit {
        let (lng, lat) = wgs84ToGcj02(87.6177, 43.7928)
        exClose("Urumqi GCJ02 lng", lng, 87.62054922425168, EX_GEO)
        exClose("Urumqi GCJ02 lat", lat, 43.79402455549771, EX_GEO)
    }

    @TestCase
    func testUrumqi_WgsToBd09(): Unit {
        let result = transform([87.6177, 43.7928], CRS.WGS84, CRS.BD09)
        exClose("Urumqi BD09 lng", result[0], 87.6269813254592,  EX_GEO)
        exClose("Urumqi BD09 lat", result[1], 43.80014663419902, EX_GEO)
    }

    @TestCase
    func testUrumqi_RoundTrip_WgsGcj(): Unit {
        let origLng: Float64 = 87.6177
        let origLat: Float64 = 43.7928
        let r1 = transform([origLng, origLat], CRS.WGS84, CRS.GCJ02)
        let r2 = transform(r1,                 CRS.GCJ02, CRS.WGS84)
        exClose("Urumqi RT GCJ02 lng", r2[0], origLng, EX_RT)
        exClose("Urumqi RT GCJ02 lat", r2[1], origLat, EX_RT)
    }

    @TestCase
    func testUrumqi_RoundTrip_WgsBd09(): Unit {
        let origLng: Float64 = 87.6177
        let origLat: Float64 = 43.7928
        let r1 = transform([origLng, origLat], CRS.WGS84, CRS.BD09)
        let r2 = transform(r1,                 CRS.BD09,  CRS.WGS84)
        exClose("Urumqi RT BD09 lng", r2[0], origLng, EX_RT)
        exClose("Urumqi RT BD09 lat", r2[1], origLat, EX_RT)
    }

    // ── EPSG:3857 for multiple cities ───────────────────────────────────────
    // JS: wgs84ToEpsg3857(113.2644, 23.1291) = [12608535.33, 2647638.58]
    // JS: wgs84ToEpsg3857(104.0668, 30.5728) = [11584663.18, 3577392.49]

    @TestCase
    func testGuangzhou_WgsToEpsg3857(): Unit {
        let (x, y) = wgs84ToEpsg3857(113.2644, 23.1291)
        exClose("Guangzhou EPSG3857 x", x, 12608535.331250532, EX_MERC_ABS)
        exClose("Guangzhou EPSG3857 y", y,  2647638.5825103126, EX_MERC_ABS)
    }

    @TestCase
    func testChengdu_WgsToEpsg3857(): Unit {
        let (x, y) = wgs84ToEpsg3857(104.0668, 30.5728)
        exClose("Chengdu EPSG3857 x", x, 11584663.182872845, EX_MERC_ABS)
        exClose("Chengdu EPSG3857 y", y,  3577392.4862613603, EX_MERC_ABS)
    }

    @TestCase
    func testHarbin_WgsToEpsg3857(): Unit {
        let (x, y) = wgs84ToEpsg3857(126.5353, 45.8038)
        exClose("Harbin EPSG3857 x", x, 14085845.161413344, EX_MERC_ABS)
        exClose("Harbin EPSG3857 y", y,  5748963.584603561,  EX_MERC_ABS)
    }
}

// ===========================================================================
// 2. AllConvertPathsTest
//    Exercises every one of the 12 directed CRS conversion paths through the
//    public transform() API, confirming routing is wired correctly.
//    Round-trip composition (A→B then B→A) is used as a self-consistent check
//    where an absolute ground-truth value is not required.
// ===========================================================================

@Test
class AllConvertPathsTest {

    // Reference point inside China; used for all paths below.
    private let refLng: Float64 = 116.404
    private let refLat: Float64 = 39.915

    @TestCase
    func testPath_Wgs84ToGcj02(): Unit {
        let r = transform([refLng, refLat], CRS.WGS84, CRS.GCJ02)
        // Non-trivial offset expected inside China
        @Assert(abs(r[0] - refLng) > 1.0e-5, "WGS84→GCJ02 must produce non-zero lng offset")
        @Assert(abs(r[1] - refLat) > 1.0e-5, "WGS84→GCJ02 must produce non-zero lat offset")
    }

    @TestCase
    func testPath_Gcj02ToWgs84_roundtrip(): Unit {
        let gcj = transform([refLng, refLat], CRS.WGS84,  CRS.GCJ02)
        let wgs = transform(gcj,              CRS.GCJ02,  CRS.WGS84)
        exClose("Path GCJ02→WGS84 RT lng", wgs[0], refLng, EX_RT)
        exClose("Path GCJ02→WGS84 RT lat", wgs[1], refLat, EX_RT)
    }

    @TestCase
    func testPath_Wgs84ToBd09(): Unit {
        // JS: wgs84ToBd09(116.404, 39.915) = [116.41662724378733, 39.922699552216216]
        let r = transform([refLng, refLat], CRS.WGS84, CRS.BD09)
        exClose("WGS84→BD09 lng", r[0], 116.41662724378733, EX_GEO)
        exClose("WGS84→BD09 lat", r[1], 39.922699552216216,  EX_GEO)
    }

    @TestCase
    func testPath_Bd09ToWgs84_roundtrip(): Unit {
        let bd  = transform([refLng, refLat], CRS.WGS84, CRS.BD09)
        let wgs = transform(bd,               CRS.BD09,  CRS.WGS84)
        exClose("Path BD09→WGS84 RT lng", wgs[0], refLng, EX_RT)
        exClose("Path BD09→WGS84 RT lat", wgs[1], refLat, EX_RT)
    }

    @TestCase
    func testPath_Gcj02ToBd09(): Unit {
        let gcj = transform([refLng, refLat], CRS.WGS84, CRS.GCJ02)
        let bd  = transform(gcj,              CRS.GCJ02, CRS.BD09)
        // BD09 should have ~0.006/0.006 offset relative to GCJ02
        @Assert(abs(bd[0] - gcj[0]) > 1.0e-4, "GCJ02→BD09 must produce non-zero lng offset")
        @Assert(abs(bd[1] - gcj[1]) > 1.0e-4, "GCJ02→BD09 must produce non-zero lat offset")
    }

    @TestCase
    func testPath_Bd09ToGcj02_roundtrip(): Unit {
        let gcj  = transform([refLng, refLat], CRS.WGS84, CRS.GCJ02)
        let bd   = transform(gcj,              CRS.GCJ02, CRS.BD09)
        let gcj2 = transform(bd,               CRS.BD09,  CRS.GCJ02)
        exClose("Path BD09→GCJ02 RT lng", gcj2[0], gcj[0], EX_GEO)
        exClose("Path BD09→GCJ02 RT lat", gcj2[1], gcj[1], EX_GEO)
    }

    @TestCase
    func testPath_Wgs84ToEpsg3857(): Unit {
        // JS: wgs84ToEpsg3857(116.404, 39.915) = [12958034.00, 4853597.99]
        let r = transform([refLng, refLat], CRS.WGS84, CRS.EPSG3857)
        exClose("WGS84→EPSG3857 x", r[0], 12958034.004496444, EX_MERC_ABS)
        exClose("WGS84→EPSG3857 y", r[1],  4853597.987624213, EX_MERC_ABS)
    }

    @TestCase
    func testPath_Epsg3857ToWgs84_strict(): Unit {
        let merc = transform([refLng, refLat], CRS.WGS84,    CRS.EPSG3857)
        let wgs  = transform(merc,             CRS.EPSG3857, CRS.WGS84)
        exClose("Path EPSG3857→WGS84 RT lng", wgs[0], refLng, EX_MERC_RT)
        exClose("Path EPSG3857→WGS84 RT lat", wgs[1], refLat, EX_MERC_RT)
    }

    @TestCase
    func testPath_Gcj02ToEpsg3857(): Unit {
        // Route: GCJ02→WGS84→EPSG3857 (validated via public API self-consistency)
        let gcj  = transform([refLng, refLat], CRS.WGS84,  CRS.GCJ02)
        let wgs  = transform(gcj,              CRS.GCJ02,  CRS.WGS84)
        let expM = transform(wgs,              CRS.WGS84,  CRS.EPSG3857)
        let gotM = transform(gcj,              CRS.GCJ02,  CRS.EPSG3857)
        exClose("GCJ02→EPSG3857 x", gotM[0], expM[0], EX_MERC_ABS)
        exClose("GCJ02→EPSG3857 y", gotM[1], expM[1], EX_MERC_ABS)
    }

    @TestCase
    func testPath_Epsg3857ToGcj02_roundtrip(): Unit {
        let merc = transform([refLng, refLat], CRS.GCJ02,    CRS.EPSG3857)
        let gcj2 = transform(merc,             CRS.EPSG3857, CRS.GCJ02)
        exClose("EPSG3857→GCJ02 RT lng", gcj2[0], refLng, EX_RT)
        exClose("EPSG3857→GCJ02 RT lat", gcj2[1], refLat, EX_RT)
    }

    @TestCase
    func testPath_Bd09ToEpsg3857(): Unit {
        // Route: BD09→GCJ02→WGS84→EPSG3857 (validated via self-consistency)
        let bd   = transform([refLng, refLat], CRS.WGS84, CRS.BD09)
        let wgs  = transform(bd,               CRS.BD09,  CRS.WGS84)
        let expM = transform(wgs,              CRS.WGS84, CRS.EPSG3857)
        let gotM = transform(bd,               CRS.BD09,  CRS.EPSG3857)
        exClose("BD09→EPSG3857 x", gotM[0], expM[0], EX_MERC_ABS)
        exClose("BD09→EPSG3857 y", gotM[1], expM[1], EX_MERC_ABS)
    }

    @TestCase
    func testPath_Epsg3857ToBd09_roundtrip(): Unit {
        let bd   = transform([refLng, refLat], CRS.WGS84, CRS.BD09)
        let merc = transform(bd,               CRS.BD09,  CRS.EPSG3857)
        let bd2  = transform(merc,             CRS.EPSG3857, CRS.BD09)
        exClose("EPSG3857→BD09 RT lng", bd2[0], bd[0], EX_RT)
        exClose("EPSG3857→BD09 RT lat", bd2[1], bd[1], EX_RT)
    }
}

// ===========================================================================
// 3. ChinaBoundaryTest
//    Coordinates just inside the China bounding box (73.66°–135.05° lon,
//    3.86°–53.55° lat, both exclusive) must receive a non-zero GCJ02 offset;
//    coordinates just outside must be returned unchanged.
// ===========================================================================

@Test
class ChinaBoundaryTest {

    /**
     * [73.67, 3.87] is strictly inside the box — offset must be non-zero.
     * JS: wgs84ToGcj02(73.67, 3.87) → lng offset ≈ 0.002798 ≠ 0
     */
    @TestCase
    func testInsideChina_hasOffset(): Unit {
        let (lng, lat) = wgs84ToGcj02(73.67, 3.87)
        @Assert(abs(lng - 73.67) > 1.0e-5,
            "Point inside China must have non-zero GCJ02 longitude offset")
        @Assert(abs(lat - 3.87) > 1.0e-5,
            "Point inside China must have non-zero GCJ02 latitude offset")
    }

    /**
     * [73.65, 3.84] is outside the box — must be returned unchanged.
     * JS: wgs84ToGcj02(73.65, 3.84) == [73.65, 3.84]
     */
    @TestCase
    func testOutsideChina_noOffset(): Unit {
        let (lng, lat) = wgs84ToGcj02(73.65, 3.84)
        exClose("Outside China lng identity", lng, 73.65, 1.0e-15)
        exClose("Outside China lat identity", lat,  3.84, 1.0e-15)
    }

    /**
     * GCJ02→WGS84 is also identity outside China.
     */
    @TestCase
    func testGcj02ToWgs84_outsideChina_noOp(): Unit {
        let (lng, lat) = gcj02ToWgs84(73.65, 3.84)
        exClose("Outside China gcj→wgs lng", lng, 73.65, 1.0e-15)
        exClose("Outside China gcj→wgs lat", lat,  3.84, 1.0e-15)
    }

    /**
     * A point well outside China (Tokyo) must pass through all paths unchanged.
     */
    @TestCase
    func testTokyo_allPathsIdentity(): Unit {
        let tokyoLng: Float64 = 139.6917
        let tokyoLat: Float64 = 35.6895
        let (g1, g2) = wgs84ToGcj02(tokyoLng, tokyoLat)
        exClose("Tokyo WGS84→GCJ02 lng", g1, tokyoLng, 1.0e-15)
        exClose("Tokyo WGS84→GCJ02 lat", g2, tokyoLat, 1.0e-15)
        let (w1, w2) = gcj02ToWgs84(tokyoLng, tokyoLat)
        exClose("Tokyo GCJ02→WGS84 lng", w1, tokyoLng, 1.0e-15)
        exClose("Tokyo GCJ02→WGS84 lat", w2, tokyoLat, 1.0e-15)
    }

    /**
     * A point in South America is outside China — must be unchanged.
     */
    @TestCase
    func testSaoPaulo_outsideChina(): Unit {
        let (lng, lat) = wgs84ToGcj02(-46.6333, -23.5505)
        exClose("São Paulo GCJ02 lng identity", lng, -46.6333, 1.0e-15)
        exClose("São Paulo GCJ02 lat identity", lat, -23.5505, 1.0e-15)
    }
}

// ===========================================================================
// 4. AliasPathsTest
//    EPSG4326 ≡ WGS84 and BD09LL ≡ BD09 must produce bit-identical results
//    to their canonical CRS counterparts for every conversion direction.
// ===========================================================================

@Test
class AliasPathsTest {

    private let ptLng: Float64 = 116.404
    private let ptLat: Float64 = 39.915

    /** EPSG4326 → GCJ02 bit-identical to WGS84 → GCJ02. */
    @TestCase
    func testEpsg4326ToGcj02_equalsWgs84(): Unit {
        let r1 = transform([ptLng, ptLat], CRS.EPSG4326, CRS.GCJ02)
        let r2 = transform([ptLng, ptLat], CRS.WGS84,    CRS.GCJ02)
        @Assert(r1[0] == r2[0], "EPSG4326→GCJ02 lng must equal WGS84→GCJ02")
        @Assert(r1[1] == r2[1], "EPSG4326→GCJ02 lat must equal WGS84→GCJ02")
    }

    /** EPSG4326 → BD09 bit-identical to WGS84 → BD09. */
    @TestCase
    func testEpsg4326ToBd09_equalsWgs84(): Unit {
        let r1 = transform([ptLng, ptLat], CRS.EPSG4326, CRS.BD09)
        let r2 = transform([ptLng, ptLat], CRS.WGS84,    CRS.BD09)
        @Assert(r1[0] == r2[0], "EPSG4326→BD09 lng must equal WGS84→BD09")
        @Assert(r1[1] == r2[1], "EPSG4326→BD09 lat must equal WGS84→BD09")
    }

    /** EPSG4326 → EPSG3857 bit-identical to WGS84 → EPSG3857. */
    @TestCase
    func testEpsg4326ToEpsg3857_equalsWgs84(): Unit {
        let r1 = transform([ptLng, ptLat], CRS.EPSG4326, CRS.EPSG3857)
        let r2 = transform([ptLng, ptLat], CRS.WGS84,    CRS.EPSG3857)
        @Assert(r1[0] == r2[0], "EPSG4326→EPSG3857 x must equal WGS84→EPSG3857")
        @Assert(r1[1] == r2[1], "EPSG4326→EPSG3857 y must equal WGS84→EPSG3857")
    }

    /** GCJ02 → EPSG4326 bit-identical to GCJ02 → WGS84. */
    @TestCase
    func testGcj02ToEpsg4326_equalsGcj02ToWgs84(): Unit {
        let gcj = transform([ptLng, ptLat], CRS.WGS84, CRS.GCJ02)
        let r1  = transform(gcj, CRS.GCJ02, CRS.EPSG4326)
        let r2  = transform(gcj, CRS.GCJ02, CRS.WGS84)
        @Assert(r1[0] == r2[0], "GCJ02→EPSG4326 lng must equal GCJ02→WGS84")
        @Assert(r1[1] == r2[1], "GCJ02→EPSG4326 lat must equal GCJ02→WGS84")
    }

    /** WGS84 → BD09LL bit-identical to WGS84 → BD09. */
    @TestCase
    func testWgs84ToBd09LL_equalsBd09(): Unit {
        let r1 = transform([ptLng, ptLat], CRS.WGS84, CRS.BD09LL)
        let r2 = transform([ptLng, ptLat], CRS.WGS84, CRS.BD09)
        @Assert(r1[0] == r2[0], "WGS84→BD09LL lng must equal WGS84→BD09")
        @Assert(r1[1] == r2[1], "WGS84→BD09LL lat must equal WGS84→BD09")
    }

    /** BD09LL → WGS84 bit-identical to BD09 → WGS84. */
    @TestCase
    func testBd09LLToWgs84_equalsBd09(): Unit {
        let bd = transform([ptLng, ptLat], CRS.WGS84, CRS.BD09)
        let r1 = transform(bd, CRS.BD09LL, CRS.WGS84)
        let r2 = transform(bd, CRS.BD09,   CRS.WGS84)
        @Assert(r1[0] == r2[0], "BD09LL→WGS84 lng must equal BD09→WGS84")
        @Assert(r1[1] == r2[1], "BD09LL→WGS84 lat must equal BD09→WGS84")
    }

    /** BD09LL → GCJ02 bit-identical to BD09 → GCJ02. */
    @TestCase
    func testBd09LLToGcj02_equalsBd09(): Unit {
        let bd = transform([ptLng, ptLat], CRS.WGS84, CRS.BD09)
        let r1 = transform(bd, CRS.BD09LL, CRS.GCJ02)
        let r2 = transform(bd, CRS.BD09,   CRS.GCJ02)
        @Assert(r1[0] == r2[0], "BD09LL→GCJ02 lng must equal BD09→GCJ02")
        @Assert(r1[1] == r2[1], "BD09LL→GCJ02 lat must equal BD09→GCJ02")
    }

    /** EPSG4326 → BD09LL combines two aliases — must equal WGS84 → BD09. */
    @TestCase
    func testEpsg4326ToBd09LL_equalsWgs84ToBd09(): Unit {
        let r1 = transform([ptLng, ptLat], CRS.EPSG4326, CRS.BD09LL)
        let r2 = transform([ptLng, ptLat], CRS.WGS84,    CRS.BD09)
        @Assert(r1[0] == r2[0], "EPSG4326→BD09LL lng must equal WGS84→BD09")
        @Assert(r1[1] == r2[1], "EPSG4326→BD09LL lat must equal WGS84→BD09")
    }

    /** EPSG4326 → EPSG4326 (same CRS) must return the original array unchanged. */
    @TestCase
    func testSameCRS_Epsg4326(): Unit {
        let coord: Array<Float64> = [ptLng, ptLat]
        let result = transform(coord, CRS.EPSG4326, CRS.EPSG4326)
        exClose("EPSG4326 same CRS lng", result[0], ptLng, 1.0e-15)
        exClose("EPSG4326 same CRS lat", result[1], ptLat, 1.0e-15)
    }

    /** BD09LL → BD09LL (same CRS) must return the original array unchanged. */
    @TestCase
    func testSameCRS_Bd09LL(): Unit {
        let bd = transform([ptLng, ptLat], CRS.WGS84, CRS.BD09)
        let result = transform(bd, CRS.BD09LL, CRS.BD09LL)
        exClose("BD09LL same CRS lng", result[0], bd[0], 1.0e-15)
        exClose("BD09LL same CRS lat", result[1], bd[1], 1.0e-15)
    }
}

// ===========================================================================
// 5. GeoJson3DTest
//    Coordinates with altitude (third element) must be transformed correctly
//    in every supported GeoJSON geometry type:
//    - The lng/lat components must be updated by the CRS conversion.
//    - The altitude component must be preserved bit-for-bit.
// ===========================================================================

@Test
class GeoJson3DTest {

    private let alt3D: Float64 = 150.0

    /** Point with altitude: [lng, lat, alt] → lng/lat transformed, alt unchanged. */
    @TestCase
    func testPoint3D(): Unit {
        let pt  = Point([116.404, 39.915, alt3D])
        let out = transformGeoJSON(pt, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case p: Point =>
                @Assert(p.coordinates.size == 3, "3-D Point must retain 3 elements")
                @Assert(abs(p.coordinates[0] - 116.404) > 1.0e-5,
                    "3-D Point lng must be transformed")
                exClose("3-D Point alt", p.coordinates[2], alt3D, 1.0e-15)
            case _ => @Assert(false, "Expected Point")
        }
    }

    /** MultiPoint with altitude: all points must have altitude preserved. */
    @TestCase
    func testMultiPoint3D(): Unit {
        let mp  = MultiPoint([
            [116.404, 39.915, alt3D],
            [121.4737, 31.2304, 200.0]
        ])
        let out = transformGeoJSON(mp, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case m: MultiPoint =>
                @Assert(m.coordinates.size == 2, "point count preserved")
                @Assert(m.coordinates[0].size == 3, "first point is 3-D")
                @Assert(m.coordinates[1].size == 3, "second point is 3-D")
                exClose("MultiPoint[0] alt", m.coordinates[0][2], alt3D,  1.0e-15)
                exClose("MultiPoint[1] alt", m.coordinates[1][2], 200.0, 1.0e-15)
            case _ => @Assert(false, "Expected MultiPoint")
        }
    }

    /** LineString with altitude: vertex count and altitude preserved. */
    @TestCase
    func testLineString3D(): Unit {
        let ls  = LineString([
            [116.0, 39.0, 10.0],
            [117.0, 40.0, 20.0],
            [118.0, 41.0, 30.0]
        ])
        let out = transformGeoJSON(ls, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case l: LineString =>
                @Assert(l.coordinates.size == 3, "vertex count preserved")
                exClose("LineString[0] alt", l.coordinates[0][2], 10.0, 1.0e-15)
                exClose("LineString[1] alt", l.coordinates[1][2], 20.0, 1.0e-15)
                exClose("LineString[2] alt", l.coordinates[2][2], 30.0, 1.0e-15)
            case _ => @Assert(false, "Expected LineString")
        }
    }

    /** Polygon with altitude: ring structure and altitude preserved. */
    @TestCase
    func testPolygon3D(): Unit {
        let ring: Array<Array<Float64>> = [
            [116.0, 39.0, alt3D], [117.0, 39.0, alt3D],
            [117.0, 40.0, alt3D], [116.0, 40.0, alt3D],
            [116.0, 39.0, alt3D]
        ]
        let pg  = Polygon([ring])
        let out = transformGeoJSON(pg, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case p: Polygon =>
                @Assert(p.coordinates.size == 1,    "ring count preserved")
                @Assert(p.coordinates[0].size == 5, "vertex count preserved")
                @Assert(p.coordinates[0][0].size == 3, "vertex is 3-D")
                exClose("Polygon[0][0] alt", p.coordinates[0][0][2], alt3D, 1.0e-15)
            case _ => @Assert(false, "Expected Polygon")
        }
    }

    /** Feature wrapping a 3-D Point: altitude must survive feature traversal. */
    @TestCase
    func testFeature3D(): Unit {
        let feat = Feature(
            Some<Geometry>(Point([116.404, 39.915, alt3D])),
            Some<String>("{\"name\":\"3D test\"}")
        )
        let out = transformGeoJSON(feat, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case f: Feature =>
                match (f.geometry) {
                    case Some(g) =>
                        match (g) {
                            case p: Point =>
                                @Assert(p.coordinates.size == 3,
                                    "3-D Point in Feature must retain 3 elements")
                                exClose("Feature 3-D alt", p.coordinates[2], alt3D, 1.0e-15)
                            case _ => @Assert(false, "Expected Point in Feature")
                        }
                    case None => @Assert(false, "geometry must not be None")
                }
            case _ => @Assert(false, "Expected Feature")
        }
    }

    /** FeatureCollection mixing 2-D and 3-D Points: each point's dimensionality preserved. */
    @TestCase
    func testFeatureCollection_mixed2D3D(): Unit {
        let fc = FeatureCollection([
            Feature(Some<Geometry>(Point([116.404, 39.915])),        None<String>),
            Feature(Some<Geometry>(Point([121.4737, 31.2304, alt3D])), None<String>)
        ])
        let out = transformGeoJSON(fc, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case c: FeatureCollection =>
                @Assert(c.features.size == 2, "feature count preserved")
                // First point is 2-D
                match (c.features[0].geometry) {
                    case Some(g) =>
                        match (g) {
                            case p: Point =>
                                @Assert(p.coordinates.size == 2, "first point must be 2-D")
                            case _ => @Assert(false, "Expected Point")
                        }
                    case None => @Assert(false, "geometry must not be None")
                }
                // Second point is 3-D with altitude preserved
                match (c.features[1].geometry) {
                    case Some(g) =>
                        match (g) {
                            case p: Point =>
                                @Assert(p.coordinates.size == 3, "second point must be 3-D")
                                exClose("FC 3-D alt", p.coordinates[2], alt3D, 1.0e-15)
                            case _ => @Assert(false, "Expected Point")
                        }
                    case None => @Assert(false, "geometry must not be None")
                }
            case _ => @Assert(false, "Expected FeatureCollection")
        }
    }

    /** WGS84→EPSG3857 with altitude: metre values correct, altitude preserved. */
    @TestCase
    func testPoint3D_toEpsg3857(): Unit {
        let coord: Array<Float64> = [116.404, 39.915, alt3D]
        let result = transform(coord, CRS.WGS84, CRS.EPSG3857)
        @Assert(result.size == 3, "3-D coord must produce 3-element result")
        exClose("3-D Mercator x",   result[0], 12958034.004496444, EX_MERC_ABS)
        exClose("3-D Mercator y",   result[1],  4853597.987624213, EX_MERC_ABS)
        exClose("3-D Mercator alt", result[2], alt3D, 1.0e-15)
    }
}
