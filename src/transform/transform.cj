/**
 * Package: cj_gcoord.transform
 *
 * 核心坐标转换算法包。
 * Core coordinate-transformation algorithms.
 *
 * 所有函数遵循统一签名：
 * All functions follow a common signature:
 *   func <from>To<to>(lng: Float64, lat: Float64): (Float64, Float64)
 *
 * 算法直接移植自 JavaScript gcoord 库：
 * Algorithms are ported directly from the JavaScript gcoord library:
 *   https://github.com/hujiulong/gcoord  (src/coordtransform.ts)
 *
 * IEEE-754 说明：
 * 仓颉 Float64 使用与 JavaScript Number 相同的 IEEE 754 双精度表示，无需额外精度处理。
 * IEEE-754 Note:
 *   Cangjie Float64 uses the same IEEE 754 double-precision representation
 *   as JavaScript's Number type.  No additional precision handling is needed.
 *
 * 常量定义：
 * Constant definitions:
 *   a  = 6 378 245.0   — 克拉索夫斯基椭球长半轴（米）/ Krasovsky ellipsoid semi-major axis (metres)
 *   b  = 6 356 863.019 — 克拉索夫斯基椭球短半轴（米）/ Krasovsky ellipsoid semi-minor axis (metres)
 *   ee = 0.006 693 42… — 第一偏心率平方 e² = 1 - (b/a)² / First eccentricity squared
 */
package cj_gcoord.transform

import std.math.*

// ---------------------------------------------------------------------------
// 地球椭球参数（克拉索夫斯基 1940，GCJ-02 标准使用）
// Earth-ellipsoid parameters (Krasovsky 1940, used by GCJ-02 standard)
// ---------------------------------------------------------------------------

/** 克拉索夫斯基参考椭球长半轴（米）。Semi-major axis of the Krasovsky reference ellipsoid (metres). */
private let a: Float64 = 6378245.0

/** 第一偏心率平方：e² = 1 − (b/a)²  First eccentricity squared: e² = 1 − (b/a)² */
private let ee: Float64 = 0.00669342162296594323

/** 圆周率，精确匹配 JS Math.PI。Pi — defined explicitly to match JS Math.PI exactly. */
private let PI: Float64 = 3.141592653589793238

// ---------------------------------------------------------------------------
// 内部辅助函数
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * 判断坐标是否在中国大陆范围之外。
 * GCJ-02 / BD-09 偏移量仅适用于中国境内；超出此边界框的坐标原样返回。
 *
 * Returns true when the coordinate lies outside mainland China.
 * The GCJ-02 / BD-09 offsets only apply inside China; coordinates
 * outside this bounding box are returned unchanged.
 */
private func isOutOfChina(lng: Float64, lat: Float64): Bool {
    !(lng > 73.66 && lng < 135.05 && lat > 3.86 && lat < 53.55)
}

/**
 * WGS-84 → GCJ-02 偏移多项式的纬度分量。
 * 参数已预先偏移：x = lng − 105，y = lat − 35。
 *
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
 * WGS-84 → GCJ-02 偏移多项式的经度分量。
 * 参数已预先偏移：x = lng − 105，y = lat − 35。
 *
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
 * 计算 WGS-84 与 GCJ-02 之间转换时应用的偏移量 (dLat, dLng)。
 * 偏移量由中国国家标准 GB/T 20257 的混淆多项式在给定点处求值得到。
 *
 * Computes the (dLat, dLng) offset applied when converting between
 * WGS-84 and GCJ-02.  The offset is derived from the Chinese national
 * standard GB/T 20257 obfuscation polynomial evaluated at the given point.
 *
 * 返回 (dLat, dLng)，单位为十进制度。
 * Returns (dLat, dLng) in decimal degrees.
 */
private func delta(lng: Float64, lat: Float64): (Float64, Float64) {
    var dLat: Float64 = transformLat(lng - 105.0, lat - 35.0)
    var dLng: Float64 = transformLng(lng - 105.0, lat - 35.0)

    let radLat: Float64 = lat / 180.0 * PI
    var magic: Float64  = sin(radLat)
    magic = 1.0 - ee * magic * magic
    let sqrtMagic: Float64 = sqrt(magic)

    // 利用椭球曲率半径将偏移量从弧度缩放到度
    // Scale to degrees using ellipsoidal radii of curvature
    dLat = dLat * 180.0 / ((a * (1.0 - ee)) / (magic * sqrtMagic) * PI)
    dLng = dLng * 180.0 / (a / sqrtMagic * cos(radLat) * PI)

    return (dLat, dLng)
}

// ---------------------------------------------------------------------------
// WGS-84 ↔ GCJ-02
// ---------------------------------------------------------------------------

/**
 * 将 WGS-84 坐标转换为 GCJ-02（火星坐标系）。
 * 中国大陆范围之外的坐标原样返回。
 *
 * Converts WGS-84 coordinates to GCJ-02 (Mars Coordinate System).
 * Coordinates outside mainland China are returned unchanged.
 *
 * @param lng  WGS-84 经度（十进制度）/ WGS-84 longitude in decimal degrees
 * @param lat  WGS-84 纬度（十进制度）/ WGS-84 latitude in decimal degrees
 * @return     (gcj02Lng, gcj02Lat) 单位：十进制度 / in decimal degrees
 */
public func wgs84ToGcj02(lng: Float64, lat: Float64): (Float64, Float64) {
    if (isOutOfChina(lng, lat)) {
        return (lng, lat)
    }
    let (dLat, dLng) = delta(lng, lat)
    return (lng + dLng, lat + dLat)
}

/**
 * 使用迭代逼近法将 GCJ-02 坐标转换回 WGS-84。
 * 迭代 30 次可将误差收敛至厘米级精度（< 1×10⁻⁷ 度）。
 *
 * Converts GCJ-02 coordinates back to WGS-84 using iterative approximation.
 * The iterative Newton-like approach converges to centimetre-level accuracy
 * within 30 iterations for any point on Earth.
 *
 * @param lng  GCJ-02 经度（十进制度）/ GCJ-02 longitude in decimal degrees
 * @param lat  GCJ-02 纬度（十进制度）/ GCJ-02 latitude in decimal degrees
 * @return     (wgs84Lng, wgs84Lat) 单位：十进制度 / in decimal degrees
 */
public func gcj02ToWgs84(lng: Float64, lat: Float64): (Float64, Float64) {
    if (isOutOfChina(lng, lat)) {
        return (lng, lat)
    }
    var wgsLng: Float64 = lng
    var wgsLat: Float64 = lat
    // 迭代 30 次，误差 ≪ 1×10⁻⁷ 度（≈ 1 cm）
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
 * 将 GCJ-02 坐标转换为百度 BD-09 坐标。
 * BD-09 在 GCJ-02 基础上额外施加了极坐标旋转和径向偏移。
 * 偏移常量 0.0065 / 0.006 为百度专有偏移量。
 *
 * Converts GCJ-02 coordinates to Baidu BD-09.
 * BD-09 applies an additional circular rotation and radial offset to GCJ-02
 * coordinates.  The offset constants 0.0065 / 0.006 are the Baidu offsets.
 *
 * @param lng  GCJ-02 经度（十进制度）/ GCJ-02 longitude in decimal degrees
 * @param lat  GCJ-02 纬度（十进制度）/ GCJ-02 latitude in decimal degrees
 * @return     (bd09Lng, bd09Lat) 单位：十进制度 / in decimal degrees
 */
public func gcj02ToBd09(lng: Float64, lat: Float64): (Float64, Float64) {
    let z: Float64     = sqrt(lng * lng + lat * lat) +
                         0.00002 * sin(lat * PI * 3000.0 / 180.0)
    let theta: Float64 = atan2(lat, lng) +
                         0.000003 * cos(lng * PI * 3000.0 / 180.0)
    return (z * cos(theta) + 0.0065, z * sin(theta) + 0.006)
}

/**
 * 将 BD-09 坐标转换回 GCJ-02。
 * 逆向执行 gcj02ToBd09 中的极坐标旋转。
 *
 * Converts BD-09 coordinates back to GCJ-02.
 * Reverses the Baidu circular rotation applied in gcj02ToBd09.
 *
 * @param lng  BD-09 经度（十进制度）/ BD-09 longitude in decimal degrees
 * @param lat  BD-09 纬度（十进制度）/ BD-09 latitude in decimal degrees
 * @return     (gcj02Lng, gcj02Lat) 单位：十进制度 / in decimal degrees
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
// WGS-84 ↔ EPSG:3857（Web Mercator）
// WGS-84 ↔ EPSG:3857  (Web Mercator)
// ---------------------------------------------------------------------------

/**
 * 将 WGS-84 经纬度投影到 EPSG:3857（Web Mercator）。
 * 输出单位为米，基于 WGS-84 赤道周长。
 * 常量 20 037 508.34 = π × 6 378 137（WGS-84 赤道半径）。
 *
 * Projects WGS-84 longitude/latitude to EPSG:3857 (Web Mercator).
 * The output is in metres relative to the WGS-84 equatorial circumference.
 * The constant 20 037 508.34 = π × 6 378 137 (WGS-84 equatorial radius).
 *
 * @param lng  WGS-84 经度（十进制度，范围 [−180, 180]）/ WGS-84 longitude in decimal degrees, range [−180, 180]
 * @param lat  WGS-84 纬度（十进制度，范围 (−90, 90)）/ WGS-84 latitude in decimal degrees, range (−90, 90)
 * @return     (x, y) 单位：米 / in metres
 */
public func wgs84ToEpsg3857(lng: Float64, lat: Float64): (Float64, Float64) {
    let x: Float64 = lng * 20037508.34 / 180.0
    // 墨卡托正投影：y = R · ln(tan(π/4 + φ/2))，缩放与 x 轴一致
    // Mercator forward: y = R · ln(tan(π/4 + φ/2)), scaled to match x scale
    let y: Float64 = log(tan((90.0 + lat) * PI / 360.0)) /
                     (PI / 180.0) * 20037508.34 / 180.0
    return (x, y)
}

/**
 * 将 EPSG:3857（Web Mercator）米坐标反投影回 WGS-84 经纬度。
 * 逆墨卡托：φ = 2·atan(e^(y/R)) − π/2
 *
 * Unprojects EPSG:3857 (Web Mercator) metres back to WGS-84 lon/lat.
 * Inverse Mercator: φ = 2·atan(e^(y/R)) − π/2
 *
 * @param x  东向坐标（米）/ Easting in metres
 * @param y  北向坐标（米）/ Northing in metres
 * @return   (wgs84Lng, wgs84Lat) 单位：十进制度 / in decimal degrees
 */
public func epsg3857ToWgs84(x: Float64, y: Float64): (Float64, Float64) {
    let lng: Float64 = x / 20037508.34 * 180.0
    let lat: Float64 = atan(exp(y / 20037508.34 * PI)) * 360.0 / PI - 90.0
    return (lng, lat)
}

// ---------------------------------------------------------------------------
// 组合便捷函数（经由中间坐标系转换）
// Composite convenience functions (via intermediate CRS)
// ---------------------------------------------------------------------------

/**
 * WGS-84 → BD-09，经由 GCJ-02 中转。
 * Converts WGS-84 to BD-09 via GCJ-02.
 */
private func wgs84ToBd09(lng: Float64, lat: Float64): (Float64, Float64) {
    let (gcjLng, gcjLat) = wgs84ToGcj02(lng, lat)
    return gcj02ToBd09(gcjLng, gcjLat)
}

/**
 * BD-09 → WGS-84，经由 GCJ-02 中转。
 * Converts BD-09 to WGS-84 via GCJ-02.
 */
private func bd09ToWgs84(lng: Float64, lat: Float64): (Float64, Float64) {
    let (gcjLng, gcjLat) = bd09ToGcj02(lng, lat)
    return gcj02ToWgs84(gcjLng, gcjLat)
}

/**
 * GCJ-02 → EPSG:3857，经由 WGS-84 中转。
 * Converts GCJ-02 to EPSG:3857 via WGS-84.
 */
private func gcj02ToEpsg3857(lng: Float64, lat: Float64): (Float64, Float64) {
    let (wLng, wLat) = gcj02ToWgs84(lng, lat)
    return wgs84ToEpsg3857(wLng, wLat)
}

/**
 * EPSG:3857 → GCJ-02，经由 WGS-84 中转。
 * Converts EPSG:3857 to GCJ-02 via WGS-84.
 */
private func epsg3857ToGcj02(x: Float64, y: Float64): (Float64, Float64) {
    let (wLng, wLat) = epsg3857ToWgs84(x, y)
    return wgs84ToGcj02(wLng, wLat)
}

/**
 * BD-09 → EPSG:3857，经由 GCJ-02 → WGS-84 中转。
 * Converts BD-09 to EPSG:3857 via GCJ-02 → WGS-84.
 */
private func bd09ToEpsg3857(lng: Float64, lat: Float64): (Float64, Float64) {
    let (gcjLng, gcjLat) = bd09ToGcj02(lng, lat)
    let (wLng, wLat)     = gcj02ToWgs84(gcjLng, gcjLat)
    return wgs84ToEpsg3857(wLng, wLat)
}

/**
 * EPSG:3857 → BD-09，经由 WGS-84 → GCJ-02 中转。
 * Converts EPSG:3857 to BD-09 via WGS-84 → GCJ-02.
 */
private func epsg3857ToBd09(x: Float64, y: Float64): (Float64, Float64) {
    let (wLng, wLat)     = epsg3857ToWgs84(x, y)
    let (gcjLng, gcjLat) = wgs84ToGcj02(wLng, wLat)
    return gcj02ToBd09(gcjLng, gcjLat)
}
