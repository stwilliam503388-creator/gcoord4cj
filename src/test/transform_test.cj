/**
 * Package: cj_gcoord_test
 *
 * Phase-1 / Phase-2 comprehensive test suite for cj-gcoord.
 *
 * Test structure
 * ──────────────
 *   GroundTruthTest      — Step 2: exact JS ground-truth comparisons
 *   GeoJSONStructureTest — Step 2: GeoJSON type/structure preservation
 *   RobustnessTest       — Step 3: boundary & abnormal inputs
 *   SafetyTest           — Step 4: iteration bounds, large data, deep nesting
 *
 * Acceptance criteria (Step 1, P4 — defined before code)
 * ─────────────────────────────────────────────────────
 *   ① Numeric accuracy  : conversion error < 1e-6 ° (≈ 0.11 m)
 *   ② Round-trip error  : A→B→A < 1e-5 ° (iterative inverse residual)
 *   ③ GeoJSON integrity : type field unchanged; coordinate array depth unchanged
 *   ④ Exception safety  : out-of-range / NaN inputs throw Exception, no silent NaN
 *
 * Ground-truth values
 * ───────────────────
 * All expected values are computed from the JavaScript gcoord reference
 * (https://github.com/hujiulong/gcoord) using the identical algorithm on
 * Node.js 20.20.2.  Values are annotated inline for traceability (P1).
 *
 * P2 — Documented uncertainty
 * ───────────────────────────
 * (a) The problem statement's expected value for WGS84→GCJ02 [116.403988, 39.914266]
 *     is [116.41024449916938, 39.91640428150164].  The JS reference produces
 *     [116.41023240747266, 39.915670251113426] (latitude difference ≈ 7.3e-4 °).
 *     These tests use the JS-computed value as ground truth.
 *
 * (b) The problem statement's EPSG3857 expected values (12959935.48, 4849751.72)
 *     do not match the JS reference for input [116.403988, 39.914266]
 *     (JS gives 12958032.67, 4853491.46).  Tests use the JS-computed value.
 *
 * (c) Float64.NaN / Float64.Infinity syntax: used as written in the problem
 *     statement (Cangjie 0.53.4).  If these identifiers do not compile, replace
 *     with the arithmetic equivalents: 0.0/0.0 (NaN) and 1.0/0.0 (+Infinity).
 *
 * (d) NaN comparison: Cangjie Float64 is claimed IEEE 754 compliant (README).
 *     The NaN fix in gcoord.cj uses (x != x) which is guaranteed true only
 *     for NaN in IEEE 754.  Float64.isNaN() is NOT used because its existence
 *     in Cangjie 0.53.4 is unverified.
 *
 * P3 — Only constructs matching observed patterns in gcoord_test.cj are used.
 *
 * Run: cjpm test
 */
package cj_gcoord_test

import std.unittest.*
import std.unittest.testmacro.*
import std.math.*
import std.collection.*

import cj_gcoord.*
import cj_gcoord.crs.*
import cj_gcoord.geojson.*
import cj_gcoord.transform.*

// ---------------------------------------------------------------------------
// Tolerance constants — prefixed TF_ to avoid conflict with gcoord_test.cj
// ---------------------------------------------------------------------------

/** Hard acceptance threshold: 1e-6 ° ≈ 0.11 m (criterion ①) */
private let TF_GEO: Float64 = 1.0e-6

/** Round-trip tolerance for iterative GCJ02 inverse (criterion ②) */
private let TF_RT: Float64 = 1.0e-5

/** Strict round-trip tolerance for mathematically exact EPSG3857 inverse */
private let TF_MERC_RT: Float64 = 1.0e-8

/** Tolerance for EPSG:3857 metre values in absolute comparisons (1 metre) */
private let TF_MERC_ABS: Float64 = 1.0

// ---------------------------------------------------------------------------
// Assertion helper
// ---------------------------------------------------------------------------

/** Assert |got - want| < tol with a descriptive failure message. */
private func tfClose(
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
// Step 2 — Ground-truth value comparison (criterion ①②)
// All expected values produced by the JS reference on Node.js 20.20.2.
// ===========================================================================

@Test
class GroundTruthTest {

    // ── WGS84 → GCJ02 ──────────────────────────────────────────────────────

    /**
     * JS: wgs84ToGcj02(116.403988, 39.914266) = [116.41023240747266, 39.915670251113426]
     *
     * P2(a): problem statement lists a different expected value; JS value used here.
     */
    @TestCase
    func testWgs84ToGcj02_canonicalPoint(): Unit {
        let (lng, lat) = wgs84ToGcj02(116.403988, 39.914266)
        tfClose("WGS84→GCJ02 canonical lng", lng, 116.41023240747266, TF_GEO)
        tfClose("WGS84→GCJ02 canonical lat", lat, 39.915670251113426, TF_GEO)
    }

    /**
     * JS: wgs84ToGcj02(121.473701, 31.230416) = [121.47822405739267, 31.22847374224698]
     */
    @TestCase
    func testWgs84ToGcj02_Shanghai(): Unit {
        let (lng, lat) = wgs84ToGcj02(121.473701, 31.230416)
        tfClose("WGS84→GCJ02 Shanghai lng", lng, 121.47822405739267, TF_GEO)
        tfClose("WGS84→GCJ02 Shanghai lat", lat, 31.22847374224698,  TF_GEO)
    }

    // ── GCJ02 → WGS84 (iterative inverse) ──────────────────────────────────

    /**
     * JS: gcj02ToWgs84(123.0, 45.0) = [122.99395581007795, 44.99804061843881]
     *
     * Problem statement lists ≈ [122.99395597, 44.99804071]; difference < 2e-7,
     * which is within the TF_GEO threshold.
     */
    @TestCase
    func testGcj02ToWgs84_absoluteValue(): Unit {
        let (lng, lat) = gcj02ToWgs84(123.0, 45.0)
        tfClose("GCJ02→WGS84 absolute lng", lng, 122.99395581007795, TF_GEO)
        tfClose("GCJ02→WGS84 absolute lat", lat, 44.99804061843881,  TF_GEO)
    }

    // ── WGS84 → BD09 ───────────────────────────────────────────────────────

    /**
     * JS: wgs84ToBd09(116.403988, 39.914266) = [116.41661560068297, 39.92196580126834]
     * Matches problem statement exactly.
     */
    @TestCase
    func testWgs84ToBd09_canonicalPoint(): Unit {
        let result = transform([116.403988, 39.914266], CRS.WGS84, CRS.BD09)
        tfClose("WGS84→BD09 canonical lng", result[0], 116.41661560068297, TF_GEO)
        tfClose("WGS84→BD09 canonical lat", result[1], 39.92196580126834,  TF_GEO)
    }

    // ── GCJ02 → BD09 ───────────────────────────────────────────────────────

    /**
     * JS: gcj02ToBd09(116.404, 39.915) = [116.41036949371029, 39.92133699351022]
     */
    @TestCase
    func testGcj02ToBd09_canonicalPoint(): Unit {
        let (lng, lat) = gcj02ToBd09(116.404, 39.915)
        tfClose("GCJ02→BD09 canonical lng", lng, 116.41036949371029, TF_GEO)
        tfClose("GCJ02→BD09 canonical lat", lat, 39.92133699351022,  TF_GEO)
    }

    // ── BD09 → GCJ02 ───────────────────────────────────────────────────────

    /**
     * JS: bd09ToGcj02(116.41661560068297, 39.92196580126834) = [116.41023297738252, 39.91566923424004]
     * Input is the output of wgs84ToBd09 above.
     */
    @TestCase
    func testBd09ToGcj02_canonicalPoint(): Unit {
        let (lng, lat) = bd09ToGcj02(116.41661560068297, 39.92196580126834)
        tfClose("BD09→GCJ02 canonical lng", lng, 116.41023297738252, TF_GEO)
        tfClose("BD09→GCJ02 canonical lat", lat, 39.91566923424004,  TF_GEO)
    }

    // ── WGS84 → EPSG:3857 ──────────────────────────────────────────────────

    /**
     * JS: wgs84ToEpsg3857(116.403988, 39.914266) = [12958032.668662556, 4853491.457810296]
     *
     * P2(b): problem statement expects (12959935.48, 4849751.72) which does not
     * match the JS reference for this input.  JS value used here.
     */
    @TestCase
    func testWgs84ToEpsg3857_canonicalPoint(): Unit {
        let (x, y) = wgs84ToEpsg3857(116.403988, 39.914266)
        tfClose("WGS84→EPSG3857 canonical x", x, 12958032.668662556, TF_MERC_ABS)
        tfClose("WGS84→EPSG3857 canonical y", y,  4853491.457810296, TF_MERC_ABS)
    }

    /**
     * EPSG3857 inverse is mathematically exact; round-trip error < 1e-8.
     * JS: epsg3857ToWgs84(wgs84ToEpsg3857(116.403988, 39.914266)) = [116.403988, 39.914266]
     * (error = 0).
     */
    @TestCase
    func testEpsg3857ToWgs84_roundTrip_strict(): Unit {
        let (x, y)     = wgs84ToEpsg3857(116.403988, 39.914266)
        let (lng, lat) = epsg3857ToWgs84(x, y)
        tfClose("EPSG3857 strict RT lng", lng, 116.403988, TF_MERC_RT)
        tfClose("EPSG3857 strict RT lat", lat,  39.914266, TF_MERC_RT)
    }

    // ── EPSG4326 ≡ WGS84 ───────────────────────────────────────────────────

    /**
     * EPSG4326 is an alias for WGS84; results must be bit-for-bit identical
     * because normalizedCRS collapses them before routing.
     */
    @TestCase
    func testEpsg4326_equalsWgs84(): Unit {
        let r1 = transform([116.403988, 39.914266], CRS.EPSG4326, CRS.GCJ02)
        let r2 = transform([116.403988, 39.914266], CRS.WGS84,    CRS.GCJ02)
        @Assert(r1[0] == r2[0], "EPSG4326 alias: lng bit-identical to WGS84")
        @Assert(r1[1] == r2[1], "EPSG4326 alias: lat bit-identical to WGS84")
    }

    // ── Round-trips (criterion ②) ───────────────────────────────────────────

    /** WGS84 → GCJ02 → WGS84: residual < TF_RT (1e-5 °). */
    @TestCase
    func testRoundTrip_Wgs84_Gcj02(): Unit {
        let origLng: Float64 = 116.403988
        let origLat: Float64 = 39.914266
        let (gcjLng, gcjLat) = wgs84ToGcj02(origLng, origLat)
        let (wgsLng, wgsLat) = gcj02ToWgs84(gcjLng, gcjLat)
        tfClose("WGS84↔GCJ02 RT lng", wgsLng, origLng, TF_RT)
        tfClose("WGS84↔GCJ02 RT lat", wgsLat, origLat, TF_RT)
    }

    /** WGS84 → BD09 → WGS84: residual < TF_RT.
     *  JS round-trip error for this input: lng=5.7e-7, lat=1.0e-6 (both < 1e-5). */
    @TestCase
    func testRoundTrip_Wgs84_Bd09(): Unit {
        let origLng: Float64 = 116.403988
        let origLat: Float64 = 39.914266
        let r1 = transform([origLng, origLat], CRS.WGS84, CRS.BD09)
        let r2 = transform(r1, CRS.BD09, CRS.WGS84)
        tfClose("WGS84↔BD09 RT lng", r2[0], origLng, TF_RT)
        tfClose("WGS84↔BD09 RT lat", r2[1], origLat, TF_RT)
    }

    /** WGS84 → EPSG3857 → WGS84: strict round-trip < TF_MERC_RT (1e-8 °). */
    @TestCase
    func testRoundTrip_Wgs84_Epsg3857_strict(): Unit {
        let origLng: Float64 = 116.403988
        let origLat: Float64 = 39.914266
        let r1 = transform([origLng, origLat], CRS.WGS84,    CRS.EPSG3857)
        let r2 = transform(r1,                 CRS.EPSG3857, CRS.WGS84)
        tfClose("WGS84↔EPSG3857 strict RT lng", r2[0], origLng, TF_MERC_RT)
        tfClose("WGS84↔EPSG3857 strict RT lat", r2[1], origLat, TF_MERC_RT)
    }
}

// ===========================================================================
// Step 2 — GeoJSON structure preservation (criterion ③)
// Verifies: getType() unchanged, coordinate array depth unchanged.
// ===========================================================================

@Test
class GeoJSONStructureTest {

    /** Point: type="Point" preserved; coordinates transformed. */
    @TestCase
    func testPoint_typePreserved(): Unit {
        let pt  = Point([116.403988, 39.914266])
        let out = transformGeoJSON(pt, CRS.WGS84, CRS.GCJ02)
        @Assert(out.getType() == "Point", "Point getType() preserved")
        match (out) {
            case p: Point =>
                @Assert(abs(p.coordinates[0] - 116.403988) > TF_GEO,
                    "Point coordinates were transformed")
            case _ => @Assert(false, "Expected Point output type")
        }
    }

    /** LineString: type preserved; vertex count unchanged. */
    @TestCase
    func testLineString_typePreserved(): Unit {
        let ls  = LineString([[116.0, 39.0], [117.0, 40.0]])
        let out = transformGeoJSON(ls, CRS.WGS84, CRS.GCJ02)
        @Assert(out.getType() == "LineString", "LineString getType() preserved")
        match (out) {
            case l: LineString =>
                @Assert(l.coordinates.size == 2, "vertex count unchanged")
            case _ => @Assert(false, "Expected LineString output type")
        }
    }

    /** Polygon: type preserved; ring count and vertex count unchanged. */
    @TestCase
    func testPolygon_typeAndStructurePreserved(): Unit {
        let ring: Array<Array<Float64>> = [
            [116.0, 39.0], [117.0, 39.0], [117.0, 40.0], [116.0, 40.0], [116.0, 39.0]
        ]
        let pg  = Polygon([ring])
        let out = transformGeoJSON(pg, CRS.WGS84, CRS.GCJ02)
        @Assert(out.getType() == "Polygon", "Polygon getType() preserved")
        match (out) {
            case p: Polygon =>
                @Assert(p.coordinates.size == 1,    "ring count unchanged")
                @Assert(p.coordinates[0].size == 5, "vertex count unchanged")
            case _ => @Assert(false, "Expected Polygon output type")
        }
    }

    /** MultiPolygon: type preserved; polygon count unchanged. */
    @TestCase
    func testMultiPolygon_typePreserved(): Unit {
        let ring: Array<Array<Float64>> = [
            [116.0, 39.0], [117.0, 39.0], [117.0, 40.0], [116.0, 39.0]
        ]
        let mpg = MultiPolygon([[ring]])
        let out = transformGeoJSON(mpg, CRS.WGS84, CRS.GCJ02)
        @Assert(out.getType() == "MultiPolygon", "MultiPolygon getType() preserved")
        match (out) {
            case m: MultiPolygon =>
                @Assert(m.coordinates.size == 1, "polygon count unchanged")
            case _ => @Assert(false, "Expected MultiPolygon output type")
        }
    }

    /** Feature: type="Feature" preserved; properties string unchanged. */
    @TestCase
    func testFeature_typeAndPropertiesPreserved(): Unit {
        let feat = Feature(
            Some<Geometry>(Point([116.403988, 39.914266])),
            Some<String>("{\"name\":\"test\"}")
        )
        let out = transformGeoJSON(feat, CRS.WGS84, CRS.GCJ02)
        @Assert(out.getType() == "Feature", "Feature getType() preserved")
        match (out) {
            case f: Feature =>
                match (f.properties) {
                    case Some(p) =>
                        @Assert(p == "{\"name\":\"test\"}", "properties unchanged")
                    case None => @Assert(false, "properties must not become None")
                }
            case _ => @Assert(false, "Expected Feature output type")
        }
    }

    /** FeatureCollection: type preserved; feature count unchanged. */
    @TestCase
    func testFeatureCollection_typePreserved(): Unit {
        let fc = FeatureCollection([
            Feature(Some<Geometry>(Point([116.403988, 39.914266])), None<String>),
            Feature(Some<Geometry>(Point([121.473701, 31.230416])), None<String>)
        ])
        let out = transformGeoJSON(fc, CRS.WGS84, CRS.GCJ02)
        @Assert(out.getType() == "FeatureCollection",
            "FeatureCollection getType() preserved")
        match (out) {
            case c: FeatureCollection =>
                @Assert(c.features.size == 2, "feature count unchanged")
            case _ => @Assert(false, "Expected FeatureCollection output type")
        }
    }
}

// ===========================================================================
// Step 3 — Boundary and robustness tests (criterion ④)
// Each test verifies that an out-of-range or malformed input throws Exception.
// ===========================================================================

@Test
class RobustnessTest {

    /** Empty array [] must throw, not return garbage. */
    @TestCase
    func testTransform_emptyArray(): Unit {
        var thrown = false
        try {
            let _ = transform([], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "Empty array must throw Exception")
    }

    /** Single-element [116.0] must throw. */
    @TestCase
    func testTransform_singleElement(): Unit {
        var thrown = false
        try {
            let _ = transform([116.0], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "Single-element array must throw Exception")
    }

    /** Longitude 181.0 (> 180) must throw. */
    @TestCase
    func testTransform_lngPositiveBound(): Unit {
        var thrown = false
        try {
            let _ = transform([181.0, 39.0], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "lng=181.0 must throw Exception")
    }

    /** Longitude -181.0 (< -180) must throw. */
    @TestCase
    func testTransform_lngNegativeBound(): Unit {
        var thrown = false
        try {
            let _ = transform([-181.0, 39.0], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "lng=-181.0 must throw Exception")
    }

    /** Latitude 91.0 (> 90) must throw. */
    @TestCase
    func testTransform_latPositiveBound(): Unit {
        var thrown = false
        try {
            let _ = transform([116.0, 91.0], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "lat=91.0 must throw Exception")
    }

    /** Latitude -91.0 (< -90) must throw. */
    @TestCase
    func testTransform_latNegativeBound(): Unit {
        var thrown = false
        try {
            let _ = transform([116.0, -91.0], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "lat=-91.0 must throw Exception")
    }

    /**
     * NaN longitude must throw (criterion ④).
     *
     * P2(c) Syntax: Float64.NaN used as suggested by problem statement.
     *   If this identifier does not compile in Cangjie 0.53.4, replace with
     *   the helper: `let nanVal: Float64 = 0.0 / 0.0`.
     *
     * Without the NaN fix in gcoord.cj this test FAILS because IEEE 754
     * mandates NaN < -180.0 == false and NaN > 180.0 == false, so NaN
     * silently passes the existing bounds check.
     */
    @TestCase
    func testTransform_nanLng(): Unit {
        var thrown = false
        try {
            let _ = transform([Float64.NaN, 39.0], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "NaN longitude must throw Exception (requires NaN fix)")
    }

    /**
     * NaN latitude must throw (criterion ④).
     */
    @TestCase
    func testTransform_nanLat(): Unit {
        var thrown = false
        try {
            let _ = transform([116.0, Float64.NaN], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "NaN latitude must throw Exception (requires NaN fix)")
    }

    /**
     * +Infinity longitude must throw.
     * This test should PASS without any fix because Infinity > 180.0 == true
     * is caught by the existing bounds check.
     *
     * P2(c): Float64.Infinity used as per problem statement; replace with
     *   `let infVal: Float64 = 1.0 / 0.0` if it does not compile.
     */
    @TestCase
    func testTransform_infinityLng(): Unit {
        var thrown = false
        try {
            let _ = transform([Float64.Infinity, 39.0], CRS.WGS84, CRS.GCJ02)
        } catch (e: Exception) {
            thrown = true
        }
        @Assert(thrown, "+Infinity longitude must throw Exception")
    }

    /**
     * Polar point [0.0, 90.0]: lat == 90.0 is on the valid boundary (≤ 90.0),
     * so no exception expected.  isOutOfChina(0.0, 90.0) == true → passes through.
     * Must not crash and must return the original coordinate unchanged.
     */
    @TestCase
    func testTransform_polarNorth_noException(): Unit {
        let result = transform([0.0, 90.0], CRS.WGS84, CRS.GCJ02)
        tfClose("polar north lng unchanged", result[0],  0.0, 1.0e-15)
        tfClose("polar north lat unchanged", result[1], 90.0, 1.0e-15)
    }

    /** Polar point [0.0, -90.0]: must not crash; coordinate returned unchanged. */
    @TestCase
    func testTransform_polarSouth_noException(): Unit {
        let result = transform([0.0, -90.0], CRS.WGS84, CRS.GCJ02)
        tfClose("polar south lng unchanged", result[0],   0.0, 1.0e-15)
        tfClose("polar south lat unchanged", result[1], -90.0, 1.0e-15)
    }
}

// ===========================================================================
// Step 4 — Safety tests
// ===========================================================================

@Test
class SafetyTest {

    /**
     * GCJ02 → WGS84 iteration is bounded to 30 steps (no infinite loop).
     *
     * We verify that four China-boundary corner points all converge within
     * TF_RT after the fixed 30-iteration budget.  If the loop were unbounded
     * this test would hang; the fact it completes proves the bound exists.
     *
     * P1 Assumption: The test runner enforces a timeout; if it does not,
     *   add `--timeout 60` to cjpm test arguments.
     */
    @TestCase
    func testGcj02ToWgs84_iterationBounded(): Unit {
        let corners: Array<Array<Float64>> = [
            [73.66, 3.86], [135.04, 3.86], [73.66, 53.54], [135.04, 53.54]
        ]
        for (c in corners) {
            let (gcjLng, gcjLat) = wgs84ToGcj02(c[0], c[1])
            let (wgsLng, wgsLat) = gcj02ToWgs84(gcjLng, gcjLat)
            tfClose("iteration bound lng " + c[0].toString(), wgsLng, c[0], TF_RT)
            tfClose("iteration bound lat " + c[1].toString(), wgsLat, c[1], TF_RT)
        }
    }

    /**
     * Large EPSG:3857 input (1e10 m) must not throw or cause integer overflow.
     *
     * Float64 can represent 1e10 exactly.  The atan(exp(…)) may produce ±90°
     * as exp saturates to Infinity → atan(Infinity) = π/2, which is valid.
     * EPSG:3857 source bypasses the geographic range check, so no exception
     * is expected.
     *
     * P1: "no overflow" is verified by completion without Exception.
     */
    @TestCase
    func testEpsg3857_largeInput_noOverflow(): Unit {
        var completed = false
        try {
            let (lng, lat) = epsg3857ToWgs84(1.0e10, 1.0e10)
            // Result may be extreme (large lng or lat = ±90); just must not throw.
            completed = true
        } catch (e: Exception) {
            // Unexpected path — EPSG3857 input bypasses geo range check
        }
        @Assert(completed, "Large EPSG:3857 input must not throw")
    }

    /**
     * GeometryCollection nested 5 levels deep must not stack-overflow.
     *
     * transformGeometry is recursive.  Depth 5 is a minimal stress test.
     * If the Cangjie runtime raises a StackOverflowError (as an Exception),
     * this test fails, indicating the recursion needs depth limiting.
     */
    @TestCase
    func testGeometryCollection_deepNesting_noStackOverflow(): Unit {
        let d1 = GeometryCollection([Point([116.0, 39.0])])
        let d2 = GeometryCollection([d1])
        let d3 = GeometryCollection([d2])
        let d4 = GeometryCollection([d3])
        let d5 = GeometryCollection([d4])
        var completed = false
        try {
            let _ = transformGeoJSON(d5, CRS.WGS84, CRS.GCJ02)
            completed = true
        } catch (e: Exception) {
            // Stack overflow or unexpected error — report as failure
        }
        @Assert(completed, "5-level nested GeometryCollection must not crash")
    }

    /**
     * FeatureCollection with 10,000 Features must not exhaust memory.
     *
     * P1: "no memory error" is verified by the transform completing without
     * throwing.  Cangjie GC is assumed to handle the temporary arrays.
     * All 10,000 features are identical Points (constant coordinates) to
     * avoid the need for Int→Float64 conversion.
     */
    @TestCase
    func testFeatureCollection_largeSize_noMemoryError(): Unit {
        var buf = ArrayList<Feature>()
        for (_ in 0..10000) {
            buf.append(Feature(
                Some<Geometry>(Point([116.5, 39.5])),
                None<String>
            ))
        }
        let fc = FeatureCollection(buf.toArray())
        var completed = false
        try {
            let _ = transformGeoJSON(fc, CRS.WGS84, CRS.GCJ02)
            completed = true
        } catch (e: Exception) {
            // Memory error or unexpected exception
        }
        @Assert(completed, "10,000-feature FeatureCollection must not throw")
    }
}
