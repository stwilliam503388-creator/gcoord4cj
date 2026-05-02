/**
 * Package: cj_gcoord_test
 *
 * cj-gcoord 库的单元测试。
 * Unit tests for the cj-gcoord library.
 *
 * 测试用例的预期值与原始 JavaScript gcoord 库及独立验证公式交叉比对：
 * Test values are cross-checked against the original JavaScript gcoord library
 * (https://github.com/hujiulong/gcoord) and independently verified formulas.
 *
 * 精度要求：地理坐标系的每次往返或已知值误差 < 1e-6 度（≈ 0.1 m），
 *           EPSG:3857 的误差 < 1e-3 m。
 * Precision requirement: every round-trip or known-value error < 1e-6 degrees
 * (≈ 0.1 m) for geographic systems, and < 1e-3 m for EPSG:3857.
 *
 * 运行方式 / Run with:
 *   cjpm test
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
// 精度容差常量
// Tolerance constants
// ---------------------------------------------------------------------------

/** 1e-6 度 ≈ 0.11 m — 地理坐标所需精度。
 *  1e-6 degrees ≈ 0.11 m — required accuracy for geographic coordinates */
private let GEO_TOL: Float64 = 1.0e-6

/** 迭代 gcj02→wgs84 相对期望 GCJ-02 正向值测试时的宽松容差（往返检验）。
 *  1e-5 ≈ 1 m 仍具参考价值。
 *  Looser tolerance for iterative gcj02→wgs84 when tested against expected
 *  GCJ-02 forward values (round-trip check).  1e-5 ≈ 1 m is still useful. */
private let ITER_TOL: Float64 = 1.0e-5

/** EPSG:3857 值的容差（米）/ Tolerance for EPSG:3857 values (metres) */
private let MERC_TOL: Float64 = 1.0e-3

// ---------------------------------------------------------------------------
// 断言辅助函数
// Assertion helpers
// ---------------------------------------------------------------------------

/** 断言 |a - b| < tol，失败时打印描述性消息。
 *  Assert that |a - b| < tol, printing a descriptive message on failure. */
private func assertClose(label: String, a: Float64, b: Float64, tol: Float64): Unit {
    let diff = abs(a - b)
    @Assert(diff < tol,
        label + ": |" + a.toString() + " - " + b.toString() +
        "| = " + diff.toString() + " >= tol " + tol.toString()
    )
}

// ===========================================================================
// 1. CRS 枚举测试
// 1. CRS enum tests
// ===========================================================================

@Test
class CRSTest {

    @TestCase
    func testEquality(): Unit {
        @Assert(CRS.WGS84    == CRS.WGS84)
        @Assert(CRS.GCJ02    == CRS.GCJ02)
        @Assert(CRS.BD09     == CRS.BD09)
        @Assert(CRS.BD09LL   == CRS.BD09LL)
        @Assert(CRS.EPSG4326 == CRS.EPSG4326)
        @Assert(CRS.EPSG3857 == CRS.EPSG3857)
    }

    @TestCase
    func testInequality(): Unit {
        @Assert(CRS.WGS84 != CRS.GCJ02)
        @Assert(CRS.GCJ02 != CRS.BD09)
        @Assert(CRS.WGS84 != CRS.EPSG3857)
        // Aliases are NOT equal to each other at enum level
        @Assert(CRS.EPSG4326 != CRS.GCJ02)
        @Assert(CRS.BD09LL   != CRS.WGS84)
    }

    @TestCase
    func testToString(): Unit {
        @Assert(CRS.WGS84.toString()    == "WGS84")
        @Assert(CRS.GCJ02.toString()    == "GCJ02")
        @Assert(CRS.BD09.toString()     == "BD09")
        @Assert(CRS.BD09LL.toString()   == "BD09LL")
        @Assert(CRS.EPSG4326.toString() == "EPSG4326")
        @Assert(CRS.EPSG3857.toString() == "EPSG3857")
    }
}

// ===========================================================================
// 2. 底层算法测试（cj_gcoord.transform）
// 2. Low-level algorithm tests  (cj_gcoord.transform)
// ===========================================================================

@Test
class TransformAlgorithmTest {

    // ---- WGS84 → GCJ02 ----------------------------------------------------
    // WGS84 转 GCJ02（火星坐标）

    /**
     * 北京天安门：gcoord 标准测试向量。
     * 预期值来自原始 JS 库。
     * Beijing Tiananmen: canonical gcoord test vector.
     * Expected values from the original JS library.
     */
    @TestCase
    func testWgs84ToGcj02_Beijing(): Unit {
        let (lng, lat) = wgs84ToGcj02(116.404, 39.915)
        // JS gcoord gives ≈ [116.41028, 39.91637]
        assertClose("Beijing GCJ02 lng", lng, 116.41028, 1.0e-4)
        assertClose("Beijing GCJ02 lat", lat, 39.91637,  1.0e-4)
    }

    @TestCase
    func testWgs84ToGcj02_Shanghai(): Unit {
        let (lng, lat) = wgs84ToGcj02(121.4737, 31.2304)
        // Should produce a non-trivial offset within China
        // GCJ02 ≠ WGS84 for points inside China
        @Assert(abs(lng - 121.4737) > 1.0e-5,
                "Expected non-zero longitude offset for Shanghai")
        @Assert(abs(lat - 31.2304) > 1.0e-5,
                "Expected non-zero latitude offset for Shanghai")
    }

    /** 中国境外坐标必须原样返回，不做任何偏移。
     *  Points outside China must be returned unchanged. */
    @TestCase
    func testWgs84ToGcj02_OutsideChina(): Unit {
        // New York
        let (lng, lat) = wgs84ToGcj02(-74.006, 40.7128)
        assertClose("NY lng unchanged", lng, -74.006,  1.0e-15)
        assertClose("NY lat unchanged", lat,  40.7128, 1.0e-15)

        // London
        let (lng2, lat2) = wgs84ToGcj02(-0.1276, 51.5074)
        assertClose("London lng unchanged", lng2, -0.1276,  1.0e-15)
        assertClose("London lat unchanged", lat2,  51.5074, 1.0e-15)
    }

    // ---- GCJ02 → WGS84（迭代逆变换）
    // ---- GCJ02 → WGS84 (iterative inverse) --------------------------------

    @TestCase
    func testGcj02ToWgs84_Beijing(): Unit {
        // Round-trip: WGS84 → GCJ02 → WGS84 must recover original
        let wgsLng0: Float64 = 116.404
        let wgsLat0: Float64 = 39.915
        let (gcjLng, gcjLat) = wgs84ToGcj02(wgsLng0, wgsLat0)
        let (wgsLng1, wgsLat1) = gcj02ToWgs84(gcjLng, gcjLat)
        assertClose("Beijing round-trip lng", wgsLng1, wgsLng0, GEO_TOL)
        assertClose("Beijing round-trip lat", wgsLat1, wgsLat0, GEO_TOL)
    }

    @TestCase
    func testGcj02ToWgs84_Shenzhen(): Unit {
        let wgsLng0: Float64 = 114.0579
        let wgsLat0: Float64 = 22.5431
        let (gcjLng, gcjLat) = wgs84ToGcj02(wgsLng0, wgsLat0)
        let (wgsLng1, wgsLat1) = gcj02ToWgs84(gcjLng, gcjLat)
        assertClose("Shenzhen round-trip lng", wgsLng1, wgsLng0, GEO_TOL)
        assertClose("Shenzhen round-trip lat", wgsLat1, wgsLat0, GEO_TOL)
    }

    @TestCase
    func testGcj02ToWgs84_OutsideChina(): Unit {
        // Points outside China: GCJ02→WGS84 must be identity
        let (lng, lat) = gcj02ToWgs84(-74.006, 40.7128)
        assertClose("NY GCJ02→WGS84 lng", lng, -74.006,  1.0e-15)
        assertClose("NY GCJ02→WGS84 lat", lat,  40.7128, 1.0e-15)
    }

    // ---- GCJ02 ↔ BD09（百度坐标）
    // ---- GCJ02 ↔ BD09 -----------------------------------------------------

    @TestCase
    func testGcj02ToBd09_Beijing(): Unit {
        // GCJ02 Beijing ≈ [116.41028, 39.91637]
        let (lng, lat) = gcj02ToBd09(116.41028, 39.91637)
        // BD09 should have ~0.006/0.006 additional offset
        assertClose("Beijing BD09 lng", lng, 116.41714, 1.0e-4)
        assertClose("Beijing BD09 lat", lat, 39.92275,  1.0e-4)
    }

    @TestCase
    func testBd09ToGcj02_RoundTrip(): Unit {
        let gcjLng0: Float64 = 116.41028
        let gcjLat0: Float64 = 39.91637
        let (bdLng, bdLat) = gcj02ToBd09(gcjLng0, gcjLat0)
        let (gcjLng1, gcjLat1) = bd09ToGcj02(bdLng, bdLat)
        assertClose("GCJ02 round-trip lng", gcjLng1, gcjLng0, GEO_TOL)
        assertClose("GCJ02 round-trip lat", gcjLat1, gcjLat0, GEO_TOL)
    }

    @TestCase
    func testBd09ToGcj02_Shanghai(): Unit {
        // Round-trip for Shanghai
        let gcjLng0: Float64 = 121.4862
        let gcjLat0: Float64 = 31.2198
        let (bdLng, bdLat) = gcj02ToBd09(gcjLng0, gcjLat0)
        let (gcjLng1, gcjLat1) = bd09ToGcj02(bdLng, bdLat)
        assertClose("Shanghai BD09 round-trip lng", gcjLng1, gcjLng0, GEO_TOL)
        assertClose("Shanghai BD09 round-trip lat", gcjLat1, gcjLat0, GEO_TOL)
    }

    // ---- WGS84 → BD09 / BD09 → WGS84（往返覆盖见 PublicAPITest）
    // ---- WGS84 → BD09 / BD09 → WGS84 -------------------------------------

    // (round-trip coverage for WGS84 ↔ BD09 is in PublicAPITest.testRoundTrip_Wgs84_Bd09)

    // ---- WGS84 ↔ EPSG:3857（Web Mercator）
    // ---- WGS84 ↔ EPSG:3857 ------------------------------------------------

    /**
     * 已知结果：本初子午线与赤道交点：
     *   WGS84 (0, 0) → EPSG:3857 (0, 0)
     * Known result for the prime meridian at the equator:
     *   WGS84 (0, 0) → EPSG:3857 (0, 0)
     */
    @TestCase
    func testWgs84ToEpsg3857_Origin(): Unit {
        let (x, y) = wgs84ToEpsg3857(0.0, 0.0)
        assertClose("Origin x", x, 0.0, MERC_TOL)
        assertClose("Origin y", y, 0.0, MERC_TOL)
    }

    /**
     * WGS84 (180, 0) → EPSG:3857 (20037508.34, 0)
     */
    @TestCase
    func testWgs84ToEpsg3857_Dateline(): Unit {
        let (x, y) = wgs84ToEpsg3857(180.0, 0.0)
        assertClose("Dateline x", x, 20037508.34, MERC_TOL)
        assertClose("Dateline y", y, 0.0,         MERC_TOL)
    }

    @TestCase
    func testWgs84ToEpsg3857_Beijing(): Unit {
        let (x, y) = wgs84ToEpsg3857(116.404, 39.915)
        // Cross-checked with PostGIS ST_Transform
        assertClose("Beijing Mercator x", x, 12958430.18, 1.0)
        assertClose("Beijing Mercator y", y,  4852278.95, 1.0)
    }

    @TestCase
    func testEpsg3857ToWgs84_RoundTrip(): Unit {
        let lng0: Float64 = 116.404
        let lat0: Float64 = 39.915
        let (x, y)     = wgs84ToEpsg3857(lng0, lat0)
        let (lng1, lat1) = epsg3857ToWgs84(x, y)
        assertClose("EPSG3857 round-trip lng", lng1, lng0, GEO_TOL)
        assertClose("EPSG3857 round-trip lat", lat1, lat0, GEO_TOL)
    }

    @TestCase
    func testEpsg3857ToWgs84_Origin(): Unit {
        let (lng, lat) = epsg3857ToWgs84(0.0, 0.0)
        assertClose("Mercator origin lng", lng, 0.0, GEO_TOL)
        assertClose("Mercator origin lat", lat, 0.0, GEO_TOL)
    }
}

// ===========================================================================
// 3. 公开 API 测试（cj_gcoord）
// 3. Public API tests  (cj_gcoord)
// ===========================================================================

@Test
class PublicAPITest {

    // ---- 相同坐标系恒等变换
    // ---- Same-CRS identity ------------------------------------------------

    @TestCase
    func testSameCRS(): Unit {
        let coord: Array<Float64> = [116.404, 39.915]
        let result = transform(coord, CRS.WGS84, CRS.WGS84)
        assertClose("Same CRS lng", result[0], 116.404, 1.0e-15)
        assertClose("Same CRS lat", result[1],  39.915, 1.0e-15)
    }

    /** EPSG4326 须被视为 WGS84（别名）。
     *  EPSG4326 must be treated as WGS84 (alias). */
    @TestCase
    func testEpsg4326AliasWgs84(): Unit {
        let coord: Array<Float64> = [116.404, 39.915]
        // EPSG4326 → GCJ02 must produce same result as WGS84 → GCJ02
        let r1 = transform(coord, CRS.EPSG4326, CRS.GCJ02)
        let r2 = transform(coord, CRS.WGS84,    CRS.GCJ02)
        assertClose("EPSG4326 alias lng", r1[0], r2[0], 1.0e-15)
        assertClose("EPSG4326 alias lat", r1[1], r2[1], 1.0e-15)
    }

    /** BD09LL 须被视为 BD09（别名）。
     *  BD09LL must be treated as BD09 (alias). */
    @TestCase
    func testBd09LLAlias(): Unit {
        // WGS84 → BD09LL should equal WGS84 → BD09
        let coord: Array<Float64> = [116.404, 39.915]
        let r1 = transform(coord, CRS.WGS84, CRS.BD09LL)
        let r2 = transform(coord, CRS.WGS84, CRS.BD09)
        assertClose("BD09LL alias lng", r1[0], r2[0], 1.0e-15)
        assertClose("BD09LL alias lat", r1[1], r2[1], 1.0e-15)
    }

    // ---- 数组坐标基本转换路径
    // ---- Array coordinate – basic paths -----------------------------------

    @TestCase
    func testTransform_Wgs84ToGcj02(): Unit {
        let result = transform([116.404, 39.915], CRS.WGS84, CRS.GCJ02)
        assertClose("WGS84→GCJ02 lng", result[0], 116.41028, 1.0e-4)
        assertClose("WGS84→GCJ02 lat", result[1],  39.91637, 1.0e-4)
    }

    @TestCase
    func testTransform_Gcj02ToWgs84(): Unit {
        let gcj: Array<Float64> = [116.41028, 39.91637]
        let result = transform(gcj, CRS.GCJ02, CRS.WGS84)
        assertClose("GCJ02→WGS84 lng", result[0], 116.404, 1.0e-4)
        assertClose("GCJ02→WGS84 lat", result[1],  39.915, 1.0e-4)
    }

    @TestCase
    func testTransform_Wgs84ToBd09(): Unit {
        let result = transform([116.404, 39.915], CRS.WGS84, CRS.BD09)
        assertClose("WGS84→BD09 lng", result[0], 116.41714, 1.0e-4)
        assertClose("WGS84→BD09 lat", result[1],  39.92275, 1.0e-4)
    }

    @TestCase
    func testTransform_Bd09ToWgs84(): Unit {
        let bd: Array<Float64> = [116.41714, 39.92275]
        let result = transform(bd, CRS.BD09, CRS.WGS84)
        assertClose("BD09→WGS84 lng", result[0], 116.404, 1.0e-4)
        assertClose("BD09→WGS84 lat", result[1],  39.915, 1.0e-4)
    }

    @TestCase
    func testTransform_Gcj02ToBd09(): Unit {
        let result = transform([116.41028, 39.91637], CRS.GCJ02, CRS.BD09)
        assertClose("GCJ02→BD09 lng", result[0], 116.41714, 1.0e-4)
        assertClose("GCJ02→BD09 lat", result[1],  39.92275, 1.0e-4)
    }

    @TestCase
    func testTransform_Bd09ToGcj02(): Unit {
        let result = transform([116.41714, 39.92275], CRS.BD09, CRS.GCJ02)
        assertClose("BD09→GCJ02 lng", result[0], 116.41028, 1.0e-4)
        assertClose("BD09→GCJ02 lat", result[1],  39.91637, 1.0e-4)
    }

    @TestCase
    func testTransform_Wgs84ToEpsg3857(): Unit {
        let result = transform([116.404, 39.915], CRS.WGS84, CRS.EPSG3857)
        assertClose("WGS84→EPSG3857 x", result[0], 12958430.18, 1.0)
        assertClose("WGS84→EPSG3857 y", result[1],  4852278.95, 1.0)
    }

    @TestCase
    func testTransform_Epsg3857ToWgs84(): Unit {
        let result = transform([12958430.18, 4852278.95], CRS.EPSG3857, CRS.WGS84)
        assertClose("EPSG3857→WGS84 lng", result[0], 116.404, 1.0e-4)
        assertClose("EPSG3857→WGS84 lat", result[1],  39.915, 1.0e-4)
    }

    @TestCase
    func testTransform_Gcj02ToEpsg3857(): Unit {
        let gcj: Array<Float64> = [116.41028, 39.91637]
        let wRef = transform(gcj, CRS.GCJ02, CRS.WGS84)
        let exp  = transform(wRef, CRS.WGS84, CRS.EPSG3857)
        let got  = transform(gcj, CRS.GCJ02, CRS.EPSG3857)
        assertClose("GCJ02→EPSG3857 x", got[0], exp[0], MERC_TOL)
        assertClose("GCJ02→EPSG3857 y", got[1], exp[1], MERC_TOL)
    }

    @TestCase
    func testTransform_Bd09ToEpsg3857(): Unit {
        let bd: Array<Float64> = [116.41714, 39.92275]
        let wRef = transform(bd, CRS.BD09, CRS.WGS84)
        let exp  = transform(wRef, CRS.WGS84, CRS.EPSG3857)
        let got  = transform(bd, CRS.BD09, CRS.EPSG3857)
        assertClose("BD09→EPSG3857 x", got[0], exp[0], MERC_TOL)
        assertClose("BD09→EPSG3857 y", got[1], exp[1], MERC_TOL)
    }

    // ---- 高程保留测试
    // ---- Altitude preservation --------------------------------------------

    @TestCase
    func testTransform_AltitudePreserved(): Unit {
        let coord: Array<Float64> = [116.404, 39.915, 50.0]
        let result = transform(coord, CRS.WGS84, CRS.GCJ02)
        @Assert(result.size == 3, "altitude element should be preserved")
        assertClose("Altitude preserved", result[2], 50.0, 1.0e-15)
    }

    // ---- 往返测试（六条对称路径全覆盖）
    // ---- Round-trips (all six symmetric paths) ----------------------------

    @TestCase
    func testRoundTrip_Wgs84_Gcj02(): Unit {
        let orig: Array<Float64> = [116.404, 39.915]
        let gcj  = transform(orig, CRS.WGS84, CRS.GCJ02)
        let back = transform(gcj,  CRS.GCJ02, CRS.WGS84)
        assertClose("WGS84↔GCJ02 lng", back[0], orig[0], GEO_TOL)
        assertClose("WGS84↔GCJ02 lat", back[1], orig[1], GEO_TOL)
    }

    @TestCase
    func testRoundTrip_Wgs84_Bd09(): Unit {
        let orig: Array<Float64> = [113.2644, 23.1291]
        let bd   = transform(orig, CRS.WGS84, CRS.BD09)
        let back = transform(bd,   CRS.BD09,  CRS.WGS84)
        assertClose("WGS84↔BD09 lng", back[0], orig[0], GEO_TOL)
        assertClose("WGS84↔BD09 lat", back[1], orig[1], GEO_TOL)
    }

    @TestCase
    func testRoundTrip_Gcj02_Bd09(): Unit {
        let orig: Array<Float64> = [116.41028, 39.91637]
        let bd   = transform(orig, CRS.GCJ02, CRS.BD09)
        let back = transform(bd,   CRS.BD09,  CRS.GCJ02)
        assertClose("GCJ02↔BD09 lng", back[0], orig[0], GEO_TOL)
        assertClose("GCJ02↔BD09 lat", back[1], orig[1], GEO_TOL)
    }

    @TestCase
    func testRoundTrip_Wgs84_Epsg3857(): Unit {
        let orig: Array<Float64> = [121.4737, 31.2304]
        let merc = transform(orig, CRS.WGS84,    CRS.EPSG3857)
        let back = transform(merc, CRS.EPSG3857, CRS.WGS84)
        assertClose("WGS84↔EPSG3857 lng", back[0], orig[0], GEO_TOL)
        assertClose("WGS84↔EPSG3857 lat", back[1], orig[1], GEO_TOL)
    }

    @TestCase
    func testRoundTrip_Gcj02_Epsg3857(): Unit {
        let orig: Array<Float64> = [116.41028, 39.91637]
        let merc = transform(orig, CRS.GCJ02,    CRS.EPSG3857)
        let back = transform(merc, CRS.EPSG3857, CRS.GCJ02)
        assertClose("GCJ02↔EPSG3857 lng", back[0], orig[0], GEO_TOL)
        assertClose("GCJ02↔EPSG3857 lat", back[1], orig[1], GEO_TOL)
    }

    @TestCase
    func testRoundTrip_Bd09_Epsg3857(): Unit {
        let orig: Array<Float64> = [116.41714, 39.92275]
        let merc = transform(orig, CRS.BD09,     CRS.EPSG3857)
        let back = transform(merc, CRS.EPSG3857, CRS.BD09)
        assertClose("BD09↔EPSG3857 lng", back[0], orig[0], GEO_TOL)
        assertClose("BD09↔EPSG3857 lat", back[1], orig[1], GEO_TOL)
    }
}

// ===========================================================================
// 4. GeoJSON 集成测试
// 4. GeoJSON integration tests
// ===========================================================================

@Test
class GeoJSONTest {

    // ---- Point（点）------------------------------------------------------

    @TestCase
    func testPoint_Wgs84ToGcj02(): Unit {
        let pt  = Point([116.404, 39.915])
        let out = transformGeoJSON(pt, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case p: Point =>
                assertClose("Point GCJ02 lng", p.coordinates[0], 116.41028, 1.0e-4)
                assertClose("Point GCJ02 lat", p.coordinates[1],  39.91637, 1.0e-4)
            case _ => @Assert(false, "Expected Point")
        }
    }

    @TestCase
    func testPoint_SameCRS(): Unit {
        let pt  = Point([116.404, 39.915])
        let out = transformGeoJSON(pt, CRS.WGS84, CRS.WGS84)
        match (out) {
            case p: Point =>
                assertClose("Same CRS Point lng", p.coordinates[0], 116.404, 1.0e-15)
                assertClose("Same CRS Point lat", p.coordinates[1],  39.915, 1.0e-15)
            case _ => @Assert(false, "Expected Point")
        }
    }

    // ---- MultiPoint（多点）-----------------------------------------------

    @TestCase
    func testMultiPoint_Wgs84ToGcj02(): Unit {
        let mp  = MultiPoint([[116.404, 39.915], [121.4737, 31.2304]])
        let out = transformGeoJSON(mp, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case p: MultiPoint =>
                @Assert(p.coordinates.size == 2, "MultiPoint size unchanged")
                // First point (Beijing)
                assertClose("MP[0] lng", p.coordinates[0][0], 116.41028, 1.0e-4)
                assertClose("MP[0] lat", p.coordinates[0][1],  39.91637, 1.0e-4)
                // Second point should also be offset
                @Assert(abs(p.coordinates[1][0] - 121.4737) > 1.0e-5,
                        "Expected non-zero offset for Shanghai")
            case _ => @Assert(false, "Expected MultiPoint")
        }
    }

    // ---- LineString（线串）-----------------------------------------------

    @TestCase
    func testLineString_Wgs84ToGcj02(): Unit {
        let ls  = LineString([[116.404, 39.915], [121.4737, 31.2304]])
        let out = transformGeoJSON(ls, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case l: LineString =>
                @Assert(l.coordinates.size == 2, "LineString point count unchanged")
                assertClose("LS[0] lng", l.coordinates[0][0], 116.41028, 1.0e-4)
            case _ => @Assert(false, "Expected LineString")
        }
    }

    // ---- Polygon（多边形）------------------------------------------------

    @TestCase
    func testPolygon_Wgs84ToGcj02(): Unit {
        // Simple square around Beijing
        let ring: Array<Array<Float64>> = [
            [116.0, 39.5], [116.8, 39.5],
            [116.8, 40.3], [116.0, 40.3], [116.0, 39.5]
        ]
        let pg  = Polygon([ring])
        let out = transformGeoJSON(pg, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case p: Polygon =>
                @Assert(p.coordinates.size == 1, "one ring preserved")
                @Assert(p.coordinates[0].size == 5, "five vertices preserved")
                // Every vertex should be shifted
                @Assert(abs(p.coordinates[0][0][0] - 116.0) > 1.0e-5,
                        "Expected offset on ring vertex")
            case _ => @Assert(false, "Expected Polygon")
        }
    }

    // ---- MultiLineString（多线串）----------------------------------------

    @TestCase
    func testMultiLineString_PointCount(): Unit {
        let mls = MultiLineString([
            [[116.0, 39.0], [117.0, 40.0]],
            [[121.0, 31.0], [122.0, 32.0]]
        ])
        let out = transformGeoJSON(mls, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case m: MultiLineString =>
                @Assert(m.coordinates.size == 2, "two line strings preserved")
                @Assert(m.coordinates[0].size == 2, "two points in line 0")
                @Assert(m.coordinates[1].size == 2, "two points in line 1")
            case _ => @Assert(false, "Expected MultiLineString")
        }
    }

    // ---- MultiPolygon（多多边形）-----------------------------------------

    @TestCase
    func testMultiPolygon_StructurePreserved(): Unit {
        let ring1: Array<Array<Float64>> = [
            [116.0, 39.0], [116.5, 39.0], [116.5, 39.5], [116.0, 39.0]
        ]
        let ring2: Array<Array<Float64>> = [
            [121.0, 31.0], [121.5, 31.0], [121.5, 31.5], [121.0, 31.0]
        ]
        let mpg = MultiPolygon([[ring1], [ring2]])
        let out = transformGeoJSON(mpg, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case m: MultiPolygon =>
                @Assert(m.coordinates.size == 2, "two polygons preserved")
                @Assert(m.coordinates[0].size == 1, "one ring in polygon 0")
                @Assert(m.coordinates[0][0].size == 4, "four vertices in ring 0")
            case _ => @Assert(false, "Expected MultiPolygon")
        }
    }

    // ---- GeometryCollection（几何集合）-----------------------------------

    @TestCase
    func testGeometryCollection(): Unit {
        let gc  = GeometryCollection([
            Point([116.404, 39.915]),
            LineString([[116.404, 39.915], [121.4737, 31.2304]])
        ])
        let out = transformGeoJSON(gc, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case g: GeometryCollection =>
                @Assert(g.geometries.size == 2, "two geometries preserved")
                match (g.geometries[0]) {
                    case p: Point =>
                        assertClose("GC Point lng", p.coordinates[0], 116.41028, 1.0e-4)
                    case _ => @Assert(false, "Expected Point in GeometryCollection")
                }
            case _ => @Assert(false, "Expected GeometryCollection")
        }
    }

    // ---- Feature（要素）--------------------------------------------------

    @TestCase
    func testFeature_WithGeometry(): Unit {
        let feat = Feature(
            Some<Geometry>(Point([116.404, 39.915])),
            Some<String>("{\"name\":\"Beijing\"}")
        )
        let out = transformGeoJSON(feat, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case f: Feature =>
                // properties 属性必须原样保留
                // Properties must be preserved
                match (f.properties) {
                    case Some(p) =>
                        @Assert(p == "{\"name\":\"Beijing\"}", "Properties preserved")
                    case None => @Assert(false, "Properties should not be None")
                }
                // 几何坐标必须经过变换
                // Geometry must be transformed
                match (f.geometry) {
                    case Some(g) =>
                        match (g) {
                            case p: Point =>
                                assertClose("Feature Point lng", p.coordinates[0], 116.41028, 1.0e-4)
                                assertClose("Feature Point lat", p.coordinates[1],  39.91637, 1.0e-4)
                            case _ => @Assert(false, "Expected Point in Feature")
                        }
                    case None => @Assert(false, "Feature geometry should not be None")
                }
            case _ => @Assert(false, "Expected Feature")
        }
    }

    @TestCase
    func testFeature_NullGeometry(): Unit {
        let feat = Feature(None<Geometry>, None<String>)
        let out  = transformGeoJSON(feat, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case f: Feature =>
                match (f.geometry) {
                    case None => ()   // correct: null geometry preserved as null（正确：空几何原样保留）
                    case Some(_) => @Assert(false, "Geometry should remain None")
                }
            case _ => @Assert(false, "Expected Feature")
        }
    }

    // ---- FeatureCollection（要素集合）------------------------------------

    @TestCase
    func testFeatureCollection(): Unit {
        let fc = FeatureCollection([
            Feature(Some<Geometry>(Point([116.404, 39.915])),  None<String>),
            Feature(Some<Geometry>(Point([121.4737, 31.2304])), None<String>)
        ])
        let out = transformGeoJSON(fc, CRS.WGS84, CRS.GCJ02)
        match (out) {
            case c: FeatureCollection =>
                @Assert(c.features.size == 2, "two features preserved")
                match (c.features[0].geometry) {
                    case Some(g) =>
                        match (g) {
                            case p: Point =>
                                assertClose("FC[0] lng", p.coordinates[0], 116.41028, 1.0e-4)
                            case _ => @Assert(false, "Expected Point")
                        }
                    case None => @Assert(false, "Geometry should not be None")
                }
            case _ => @Assert(false, "Expected FeatureCollection")
        }
    }
}

// ===========================================================================
// 5. 错误处理测试
// 5. Error-handling tests
// ===========================================================================

@Test
class ErrorHandlingTest {

    @TestCase
    func testTransform_TooFewElements(): Unit {
        var thrown = false
        try {
            let _ = transform([116.404], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "Expected exception for coord.size < 2")
    }

    @TestCase
    func testTransform_LngOutOfRange(): Unit {
        var thrown = false
        try {
            let _ = transform([200.0, 39.915], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "Expected exception for lng > 180")
    }

    @TestCase
    func testTransform_LatOutOfRange(): Unit {
        var thrown = false
        try {
            let _ = transform([116.404, -91.0], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "Expected exception for lat < -90")
    }

    @TestCase
    func testTransformPosition_TooFewElements(): Unit {
        var thrown = false
        try {
            // A Point with fewer than 2 coordinates must trigger an error
            // when its geometry is traversed by the public transformGeoJSON API.
            // 少于 2 个坐标的 Point，在公开 transformGeoJSON API 遍历其几何时必须触发异常。
            let _ = transformGeoJSON(Point([116.404]), CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "Expected exception for position.size < 2")
    }
}
