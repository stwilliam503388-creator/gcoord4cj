/**
 * Package: cj_gcoord
 *
 * cj-gcoord 库的公开 API 入口。
 * Public API entry point for the cj-gcoord library.
 *
 * 快速上手
 * Quick-start
 * -----------
 *
 *   import cj_gcoord.*
 *   import cj_gcoord.crs.*
 *   import cj_gcoord.geojson.*
 *
 *   // 数组坐标转换 / Array-based coordinate transform
 *   let gcj = transform([116.404, 39.915], CRS.WGS84, CRS.GCJ02)
 *   // gcj ≈ [116.41028, 39.91637]
 *
 *   // GeoJSON 转换 / GeoJSON transform
 *   let pt  = Point([116.404, 39.915])
 *   let gcjPt = transformGeoJSON(pt, CRS.WGS84, CRS.GCJ02)
 *
 * 坐标校验
 * Coordinate validation
 * ---------------------
 * 对于地理坐标系（WGS84 / GCJ02 / BD09）：
 * For geographic CRS (WGS84 / GCJ02 / BD09):
 *   - 经度须在 [−180, 180] 范围内 / longitude must be in [−180, 180]
 *   - 纬度须在 [−90,   90] 范围内 / latitude  must be in [−90,   90]
 * EPSG:3857 坐标单位为米，不执行地理范围校验。
 * For EPSG:3857 the values are in metres; no geographic validation is applied.
 *
 * 坐标系别名
 * CRS aliases
 * -----------
 *   EPSG4326  ≡ WGS84
 *   BD09LL    ≡ BD09
 */
package cj_gcoord

import cj_gcoord.crs.*
import cj_gcoord.transform.*
import cj_gcoord.geojson.*

// ===========================================================================
// 私有辅助函数
// Private helpers
// ===========================================================================

/**
 * 规范化 CRS 别名，使路由表只需处理四种值：
 *   WGS84 · GCJ02 · BD09 · EPSG3857
 *
 * Collapses CRS aliases so the routing table only needs to handle four values:
 *   WGS84 · GCJ02 · BD09 · EPSG3857
 */
private func normalizedCRS(crs: CRS): CRS {
    match (crs) {
        case CRS.EPSG4326 => CRS.WGS84
        case CRS.BD09LL   => CRS.BD09
        case _            => crs
    }
}

/**
 * 在任意两个规范化后的 CRS 值之间路由单个 (lng, lat) 坐标对。
 *
 * 前提条件：`from` 和 `to` 已通过 normalizedCRS 规范化且已知不同。
 *
 * Routes a single (lng, lat) pair between any two normalised CRS values.
 *
 * Precondition: `from` and `to` have already been normalised via normalizedCRS
 *               and are known to be different.
 *
 * 抛出：当地理坐标超出有效范围时；当转换路径不受支持时（规范化后理论上不会出现）。
 * Throws: Exception for geographic coordinates outside valid ranges.
 *         Exception for unsupported conversion paths (should never happen
 *         given the exhaustive match below).
 */
private func routeConvert(
    lng: Float64, lat: Float64,
    from: CRS, to: CRS
): (Float64, Float64) {
    // 校验地理坐标（EPSG:3857 使用米单位，跳过经纬度校验）
    // Validate geographic coordinates (EPSG:3857 uses metres, skip check)
    if (from != CRS.EPSG3857) {
        // NaN 检测须在范围比较之前进行。
        // IEEE 754 规定 NaN != NaN 为 true（唯一满足此特性的值）。
        // 此处使用 (x != x) 而非依赖可能不存在的 Float64.isNaN() API。
        // NaN check must come BEFORE range comparisons.
        // IEEE 754 mandates NaN != NaN is true (the only value with this property).
        // Float64.isNaN() is not available in Cangjie; using (x != x)
        // which is guaranteed by IEEE 754 and does not depend on any API.
        if (lng != lng || lat != lat) {
            throw Exception(
                "Coordinate contains NaN: lng=" + lng.toString() +
                ", lat=" + lat.toString()
            )
        }
        if (lng < -180.0 || lng > 180.0) {
            throw Exception(
                "Longitude out of range [-180, 180]: " + lng.toString()
            )
        }
        if (lat < -90.0 || lat > 90.0) {
            throw Exception(
                "Latitude out of range [-90, 90]: " + lat.toString()
            )
        }
    }

    match ((from, to)) {
        // ── WGS84 ↔ GCJ02 ──────────────────────────────────────────────────
        case (CRS.WGS84,    CRS.GCJ02)    => wgs84ToGcj02(lng, lat)
        case (CRS.GCJ02,    CRS.WGS84)    => gcj02ToWgs84(lng, lat)

        // ── WGS84 ↔ BD09 ───────────────────────────────────────────────────
        case (CRS.WGS84,    CRS.BD09)     => wgs84ToBd09(lng, lat)
        case (CRS.BD09,     CRS.WGS84)    => bd09ToWgs84(lng, lat)

        // ── GCJ02 ↔ BD09 ───────────────────────────────────────────────────
        case (CRS.GCJ02,    CRS.BD09)     => gcj02ToBd09(lng, lat)
        case (CRS.BD09,     CRS.GCJ02)    => bd09ToGcj02(lng, lat)

        // ── WGS84 ↔ EPSG3857 ───────────────────────────────────────────────
        case (CRS.WGS84,    CRS.EPSG3857) => wgs84ToEpsg3857(lng, lat)
        case (CRS.EPSG3857, CRS.WGS84)    => epsg3857ToWgs84(lng, lat)

        // ── GCJ02 ↔ EPSG3857 ───────────────────────────────────────────────
        case (CRS.GCJ02,    CRS.EPSG3857) => gcj02ToEpsg3857(lng, lat)
        case (CRS.EPSG3857, CRS.GCJ02)    => epsg3857ToGcj02(lng, lat)

        // ── BD09 ↔ EPSG3857 ────────────────────────────────────────────────
        case (CRS.BD09,     CRS.EPSG3857) => bd09ToEpsg3857(lng, lat)
        case (CRS.EPSG3857, CRS.BD09)     => epsg3857ToBd09(lng, lat)

        // ── 兜底（别名规范化后理论上不可达）
        // ── Fallback (should be unreachable after alias normalisation) ──────
        case _ =>
            throw Exception(
                "Unsupported coordinate conversion: " +
                from.toString() + " -> " + to.toString()
            )
    }
}

// ===========================================================================
// 公开 API
// Public API
// ===========================================================================

/**
 * 将坐标数组从一个坐标系转换到另一个坐标系。
 * Transforms a coordinate array from one CRS to another.
 *
 * 输入数组至少须包含两个元素：
 * The input array must contain at least two elements:
 *   coord[0] = 经度（EPSG:3857 时为 x）/ longitude (or x for EPSG:3857)
 *   coord[1] = 纬度（EPSG:3857 时为 y）/ latitude  (or y for EPSG:3857)
 *   coord[2] = 高程 / 附加维度（可选，原样保留）/ altitude / additional dimension (optional, preserved as-is)
 *
 * 示例 / Examples
 * --------
 *   // WGS84 → GCJ02（高德 / Google 中国）
 *   // WGS84 → GCJ02 (AutoNavi / Google China)
 *   let result = transform([116.404, 39.915], CRS.WGS84, CRS.GCJ02)
 *   // result ≈ [116.41028, 39.91637]
 *
 *   // GCJ02 → BD09（百度地图）
 *   // GCJ02 → BD09 (Baidu Maps)
 *   let result = transform([116.41028, 39.91637], CRS.GCJ02, CRS.BD09)
 *   // result ≈ [116.41714, 39.92275]
 *
 *   // WGS84 → EPSG:3857（Web Mercator，单位：米）
 *   // WGS84 → EPSG:3857 (Web Mercator, metres)
 *   let result = transform([116.404, 39.915], CRS.WGS84, CRS.EPSG3857)
 *
 * @param coord  源坐标：[lng, lat] 或 [lng, lat, alt] / Source coordinate: [lng, lat] or [lng, lat, alt]
 * @param from   源坐标系 / Source CRS
 * @param to     目标坐标系 / Target CRS
 * @return       转换后的坐标数组，长度与输入相同 / Transformed coordinate array of the same length as `coord`
 *
 * @throws Exception 当 coord.size < 2 时 / when coord.size < 2
 * @throws Exception 当地理坐标超出有效范围时 / when geographic coordinates are out of valid ranges
 * @throws Exception 当转换路径不受支持时 / when the conversion path is not supported
 */
public func transform(
    coord: Array<Float64>,
    from: CRS,
    to: CRS
): Array<Float64> {
    if (coord.size < 2) {
        throw Exception(
            "Coordinate array must have at least 2 elements [lng, lat], got size: " +
            coord.size.toString()
        )
    }

    // 源坐标系与目标坐标系相同（包含别名对经规范化后的情形）
    // Same CRS (including alias pairs handled by normalisation below)
    let effFrom = normalizedCRS(from)
    let effTo   = normalizedCRS(to)
    if (effFrom == effTo) {
        return coord
    }

    let (newLng, newLat) = routeConvert(coord[0], coord[1], effFrom, effTo)

    // 保留高程或其他附加维度
    // Preserve altitude or additional dimensions
    if (coord.size >= 3) {
        return [newLng, newLat, coord[2]]
    } else {
        return [newLng, newLat]
    }
}

/**
 * 将 GeoJSON 对象内所有坐标从一个坐标系转换到另一个坐标系。
 * Transforms all coordinates inside a GeoJSON object from one CRS to another.
 *
 * 支持的类型：
 * Supports:
 *   Point · MultiPoint · LineString · MultiLineString
 *   Polygon · MultiPolygon · GeometryCollection
 *   Feature · FeatureCollection
 *
 * 本函数是非破坏性的：返回新的 GeoJSON 树，原对象不被修改。
 * Feature 的 properties 属性原样保留。
 * The function is non-destructive: it returns a *new* GeoJSON tree.
 * Feature properties are preserved unchanged.
 *
 * 示例 / Example
 * -------
 *   let pt   = Point([116.404, 39.915])
 *   let gcjPt = transformGeoJSON(pt, CRS.WGS84, CRS.GCJ02)
 *   // gcjPt 是坐标约为 [116.41028, 39.91637] 的 Point
 *   // gcjPt is a Point with coordinates ≈ [116.41028, 39.91637]
 *
 *   let fc = FeatureCollection([
 *       Feature(Some(Point([116.404, 39.915])), None<String>)
 *   ])
 *   let gcjFc = transformGeoJSON(fc, CRS.WGS84, CRS.GCJ02)
 *
 * @param geojson  源 GeoJSON 对象 / Source GeoJSON object
 * @param from     源坐标系 / Source CRS
 * @param to       目标坐标系 / Target CRS
 * @return         坐标已转换的新 GeoJSON 对象 / New GeoJSON object with transformed coordinates
 *
 * @throws Exception 当几何类型不受支持时 / for unsupported geometry types
 * @throws Exception 当任意坐标超出 from 坐标系的有效范围时 / when any coordinate is out of the valid range for `from`
 */
public func transformGeoJSON(
    geojson: GeoJSON,
    from: CRS,
    to: CRS
): GeoJSON {
    let effFrom = normalizedCRS(from)
    let effTo   = normalizedCRS(to)
    if (effFrom == effTo) {
        return geojson
    }

    // 将转换函数捕获为闭包，用于递归遍历
    // Capture the conversion function as a closure for recursive traversal
    let fn: (Float64, Float64) -> (Float64, Float64) = {
        lng: Float64, lat: Float64 =>
        routeConvert(lng, lat, effFrom, effTo)
    }

    return transformGeoJSONWithFn(geojson, fn)
}
