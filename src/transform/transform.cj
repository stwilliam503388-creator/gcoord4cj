/**
 * Package: cj_gcoord.transform
 *
 * Core coordinate-transformation algorithms.
 *
 * All functions follow a common signature:
 *   func <from>To<to>(lng: Float64, lat: Float64): (Float64, Float64)
 *
 * Algorithms are ported directly from the JavaScript gcoord library:
 *   https://github.com/hujiulong/gcoord  (src/coordtransform.ts)
 *
 * IEEE-754 Note:
 *   Cangjie Float64 uses the same IEEE 754 double-precision representation
 *   as JavaScript's Number type.  No additional precision handling is needed.
 *
 * Constant definitions:
 *   a  = 6 378 245.0   — Krasovsky ellipsoid semi-major axis (metres)
 *   b  = 6 356 863.019 — Krasovsky ellipsoid semi-minor axis (metres)
 *   ee = 0.006 693 42… — First eccentricity squared  (e² = 1 - (b/a)²)
 */
package cj_gcoord.transform

import std.math.*

// ---------------------------------------------------------------------------
// Earth-ellipsoid parameters (Krasovsky 1940, used by GCJ-02 standard)
// ---------------------------------------------------------------------------

/** Semi-major axis of the Krasovsky reference ellipsoid (metres). */
private let a: Float64 = 6378245.0

/** First eccentricity squared: e² = 1 − (b/a)² */
private let ee: Float64 = 0.00669342162296594323

/** Pi — defined explicitly to match JS Math.PI exactly. */
private let PI: Float64 = 3.141592653589793238

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Returns true when the coordinate lies outside mainland China.
 * The GCJ-02 / BD-09 offsets only apply inside China; coordinates
 * outside this bounding box are returned unchanged.
 */
private func isOutOfChina(lng: Float64, lat: Float64): Bool {
    !(lng > 73.66 && lng < 135.05 && lat > 3.86 && lat < 53.55)
}

/**
 * Latitude component of the WGS-84 → GCJ-02 offset polynomial.
 * Parameters are pre-shifted:  x = lng − 105, y = lat − 35.
 */
private func transformLat(x: Float64, y: Float64): Float64 {
    var ret: Float64 = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y +
                        0.1 * x * y + 0.2 * sqrt(abs(x))
    ret += (20.0 * sin(6.0 * x * PI) + 20.0 * sin(2.0 * x * PI)) * 2.0 / 3.0
    ret += (20.0 * sin(y * PI) + 40.0 * sin(y / 3.0 * PI)) * 2.0 / 3.0
    ret += (160.0 * sin(y / 12.0 * PI) + 320.0 * sin(y * PI / 30.0)) * 2.0 / 3.0
    return ret
}

/**
 * Longitude component of the WGS-84 → GCJ-02 offset polynomial.
 * Parameters are pre-shifted:  x = lng − 105, y = lat − 35.
 */
private func transformLng(x: Float64, y: Float64): Float64 {
    var ret: Float64 = 300.0 + x + 2.0 * y + 0.1 * x * x +
                       0.1 * x * y + 0.1 * sqrt(abs(x))
    ret += (20.0 * sin(6.0 * x * PI) + 20.0 * sin(2.0 * x * PI)) * 2.0 / 3.0
    ret += (20.0 * sin(x * PI) + 40.0 * sin(x / 3.0 * PI)) * 2.0 / 3.0
    ret += (150.0 * sin(x / 12.0 * PI) + 300.0 * sin(x / 30.0 * PI)) * 2.0 / 3.0
    return ret
}

/**
 * Computes the (dLat, dLng) offset applied when converting between
 * WGS-84 and GCJ-02.  The offset is derived from the Chinese national
 * standard GB/T 20257 obfuscation polynomial evaluated at the given point.
 *
 * Returns (dLat, dLng) in decimal degrees.
 */
private func delta(lng: Float64, lat: Float64): (Float64, Float64) {
    var dLat: Float64 = transformLat(lng - 105.0, lat - 35.0)
    var dLng: Float64 = transformLng(lng - 105.0, lat - 35.0)

    let radLat: Float64 = lat / 180.0 * PI
    var magic: Float64  = sin(radLat)
    magic = 1.0 - ee * magic * magic
    let sqrtMagic: Float64 = sqrt(magic)

    // Scale to degrees using ellipsoidal radii of curvature
    dLat = dLat * 180.0 / ((a * (1.0 - ee)) / (magic * sqrtMagic) * PI)
    dLng = dLng * 180.0 / (a / sqrtMagic * cos(radLat) * PI)

    return (dLat, dLng)
}

// ---------------------------------------------------------------------------
// WGS-84 ↔ GCJ-02
// ---------------------------------------------------------------------------

/**
 * Converts WGS-84 coordinates to GCJ-02 (Mars Coordinate System).
 *
 * Coordinates outside mainland China are returned unchanged.
 *
 * @param lng  WGS-84 longitude in decimal degrees
 * @param lat  WGS-84 latitude in decimal degrees
 * @return     (gcj02Lng, gcj02Lat) in decimal degrees
 */
public func wgs84ToGcj02(lng: Float64, lat: Float64): (Float64, Float64) {
    if (isOutOfChina(lng, lat)) {
        return (lng, lat)
    }
    let (dLat, dLng) = delta(lng, lat)
    return (lng + dLng, lat + dLat)
}

/**
 * Converts GCJ-02 coordinates back to WGS-84 using iterative approximation.
 *
 * The iterative Newton-like approach converges to centimetre-level accuracy
 * within 30 iterations for any point on Earth.
 *
 * @param lng  GCJ-02 longitude in decimal degrees
 * @param lat  GCJ-02 latitude in decimal degrees
 * @return     (wgs84Lng, wgs84Lat) in decimal degrees
 */
public func gcj02ToWgs84(lng: Float64, lat: Float64): (Float64, Float64) {
    if (isOutOfChina(lng, lat)) {
        return (lng, lat)
    }
    var wgsLng: Float64 = lng
    var wgsLat: Float64 = lat
    // 30 iterations — error ≪ 1 × 10⁻⁷ degrees (≈ 1 cm)
    for (_ in 0..30) {
        let (dLat, dLng) = delta(wgsLng, wgsLat)
        wgsLng = lng - dLng
        wgsLat = lat - dLat
    }
    return (wgsLng, wgsLat)
}

// ---------------------------------------------------------------------------
// GCJ-02 ↔ BD-09
// ---------------------------------------------------------------------------

/**
 * Converts GCJ-02 coordinates to Baidu BD-09.
 *
 * BD-09 applies an additional circular rotation and radial offset to GCJ-02
 * coordinates.  The offset constants 0.0065 / 0.006 are the Baidu offsets.
 *
 * @param lng  GCJ-02 longitude in decimal degrees
 * @param lat  GCJ-02 latitude in decimal degrees
 * @return     (bd09Lng, bd09Lat) in decimal degrees
 */
public func gcj02ToBd09(lng: Float64, lat: Float64): (Float64, Float64) {
    let z: Float64     = sqrt(lng * lng + lat * lat) +
                         0.00002 * sin(lat * PI * 3000.0 / 180.0)
    let theta: Float64 = atan2(lat, lng) +
                         0.000003 * cos(lng * PI * 3000.0 / 180.0)
    return (z * cos(theta) + 0.0065, z * sin(theta) + 0.006)
}

/**
 * Converts BD-09 coordinates back to GCJ-02.
 *
 * Reverses the Baidu circular rotation applied in gcj02ToBd09.
 *
 * @param lng  BD-09 longitude in decimal degrees
 * @param lat  BD-09 latitude in decimal degrees
 * @return     (gcj02Lng, gcj02Lat) in decimal degrees
 */
public func bd09ToGcj02(lng: Float64, lat: Float64): (Float64, Float64) {
    let x: Float64     = lng - 0.0065
    let y: Float64     = lat - 0.006
    let z: Float64     = sqrt(x * x + y * y) -
                         0.00002 * sin(y * PI * 3000.0 / 180.0)
    let theta: Float64 = atan2(y, x) -
                         0.000003 * cos(x * PI * 3000.0 / 180.0)
    return (z * cos(theta), z * sin(theta))
}

// ---------------------------------------------------------------------------
// WGS-84 ↔ EPSG:3857  (Web Mercator)
// ---------------------------------------------------------------------------

/**
 * Projects WGS-84 longitude/latitude to EPSG:3857 (Web Mercator).
 *
 * The output is in metres relative to the WGS-84 equatorial circumference.
 * The constant 20 037 508.34 = π × 6 378 137 (WGS-84 equatorial radius).
 *
 * @param lng  WGS-84 longitude in decimal degrees, range [−180, 180]
 * @param lat  WGS-84 latitude in decimal degrees, range (−90, 90)
 * @return     (x, y) in metres
 */
public func wgs84ToEpsg3857(lng: Float64, lat: Float64): (Float64, Float64) {
    let x: Float64 = lng * 20037508.34 / 180.0
    // Mercator forward: y = R · ln(tan(π/4 + φ/2)), scaled to match x scale
    let y: Float64 = log(tan((90.0 + lat) * PI / 360.0)) /
                     (PI / 180.0) * 20037508.34 / 180.0
    return (x, y)
}

/**
 * Unprojects EPSG:3857 (Web Mercator) metres back to WGS-84 lon/lat.
 *
 * Inverse Mercator: φ = 2·atan(e^(y/R)) − π/2
 *
 * @param x  Easting in metres
 * @param y  Northing in metres
 * @return   (wgs84Lng, wgs84Lat) in decimal degrees
 */
public func epsg3857ToWgs84(x: Float64, y: Float64): (Float64, Float64) {
    let lng: Float64 = x / 20037508.34 * 180.0
    let lat: Float64 = atan(exp(y / 20037508.34 * PI)) * 360.0 / PI - 90.0
    return (lng, lat)
}

// ---------------------------------------------------------------------------
// Composite convenience functions (via intermediate CRS)
// ---------------------------------------------------------------------------

/**
 * Converts WGS-84 to BD-09 via GCJ-02.
 */
private func wgs84ToBd09(lng: Float64, lat: Float64): (Float64, Float64) {
    let (gcjLng, gcjLat) = wgs84ToGcj02(lng, lat)
    return gcj02ToBd09(gcjLng, gcjLat)
}

/**
 * Converts BD-09 to WGS-84 via GCJ-02.
 */
private func bd09ToWgs84(lng: Float64, lat: Float64): (Float64, Float64) {
    let (gcjLng, gcjLat) = bd09ToGcj02(lng, lat)
    return gcj02ToWgs84(gcjLng, gcjLat)
}

/**
 * Converts GCJ-02 to EPSG:3857 via WGS-84.
 */
private func gcj02ToEpsg3857(lng: Float64, lat: Float64): (Float64, Float64) {
    let (wLng, wLat) = gcj02ToWgs84(lng, lat)
    return wgs84ToEpsg3857(wLng, wLat)
}

/**
 * Converts EPSG:3857 to GCJ-02 via WGS-84.
 */
private func epsg3857ToGcj02(x: Float64, y: Float64): (Float64, Float64) {
    let (wLng, wLat) = epsg3857ToWgs84(x, y)
    return wgs84ToGcj02(wLng, wLat)
}

/**
 * Converts BD-09 to EPSG:3857 via GCJ-02 → WGS-84.
 */
private func bd09ToEpsg3857(lng: Float64, lat: Float64): (Float64, Float64) {
    let (gcjLng, gcjLat) = bd09ToGcj02(lng, lat)
    let (wLng, wLat)     = gcj02ToWgs84(gcjLng, gcjLat)
    return wgs84ToEpsg3857(wLng, wLat)
}

/**
 * Converts EPSG:3857 to BD-09 via WGS-84 → GCJ-02.
 */
private func epsg3857ToBd09(x: Float64, y: Float64): (Float64, Float64) {
    let (wLng, wLat)     = epsg3857ToWgs84(x, y)
    let (gcjLng, gcjLat) = wgs84ToGcj02(wLng, wLat)
    return gcj02ToBd09(gcjLng, gcjLat)
}
