/**
 * Package: cj_gcoord
 *
 * Public API entry point for the cj-gcoord library.
 *
 * Quick-start
 * -----------
 *
 *   import cj_gcoord.*
 *   import cj_gcoord.crs.*
 *   import cj_gcoord.geojson.*
 *
 *   // Array-based coordinate transform
 *   let gcj = transform([116.404, 39.915], CRS.WGS84, CRS.GCJ02)
 *   // gcj ≈ [116.41028, 39.91637]
 *
 *   // GeoJSON transform
 *   let pt  = Point([116.404, 39.915])
 *   let gcjPt = transformGeoJSON(pt, CRS.WGS84, CRS.GCJ02)
 *
 * Coordinate validation
 * ---------------------
 * For geographic CRS (WGS84 / GCJ02 / BD09):
 *   - longitude must be in [−180, 180]
 *   - latitude  must be in [−90,   90]
 * For EPSG:3857 the values are in metres; no geographic validation is applied.
 *
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
// Private helpers
// ===========================================================================

/**
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
 * Routes a single (lng, lat) pair between any two normalised CRS values.
 *
 * Precondition: `from` and `to` have already been normalised via normalizedCRS
 *               and are known to be different.
 *
 * Throws: Exception for geographic coordinates outside valid ranges.
 *         Exception for unsupported conversion paths (should never happen
 *         given the exhaustive match below).
 */
private func routeConvert(
    lng: Float64, lat: Float64,
    from: CRS, to: CRS
): (Float64, Float64) {
    // Validate geographic coordinates (EPSG:3857 uses metres, skip check)
    if (from != CRS.EPSG3857) {
        // NaN check must come BEFORE range comparisons.
        // IEEE 754 mandates NaN != NaN is true (the only value with this property).
        // Float64.isNaN() existence in Cangjie 0.53.4 is unverified; using (x != x)
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

        // ── Fallback (should be unreachable after alias normalisation) ──────
        case _ =>
            throw Exception(
                "Unsupported coordinate conversion: " +
                from.toString() + " -> " + to.toString()
            )
    }
}

// ===========================================================================
// Public API
// ===========================================================================

/**
 * Transforms a coordinate array from one CRS to another.
 *
 * The input array must contain at least two elements:
 *   coord[0] = longitude (or x for EPSG:3857)
 *   coord[1] = latitude  (or y for EPSG:3857)
 *   coord[2] = altitude / additional dimension (optional, preserved as-is)
 *
 * Examples
 * --------
 *   // WGS84 → GCJ02 (AutoNavi / Google China)
 *   let result = transform([116.404, 39.915], CRS.WGS84, CRS.GCJ02)
 *   // result ≈ [116.41028, 39.91637]
 *
 *   // GCJ02 → BD09 (Baidu Maps)
 *   let result = transform([116.41028, 39.91637], CRS.GCJ02, CRS.BD09)
 *   // result ≈ [116.41714, 39.92275]
 *
 *   // WGS84 → EPSG:3857 (Web Mercator, metres)
 *   let result = transform([116.404, 39.915], CRS.WGS84, CRS.EPSG3857)
 *
 * @param coord  Source coordinate: [lng, lat] or [lng, lat, alt]
 * @param from   Source CRS
 * @param to     Target CRS
 * @return       Transformed coordinate array of the same length as `coord`
 *
 * @throws Exception when coord.size < 2
 * @throws Exception when geographic coordinates are out of valid ranges
 * @throws Exception when the conversion path is not supported
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

    // Same CRS (including alias pairs handled by normalisation below)
    let effFrom = normalizedCRS(from)
    let effTo   = normalizedCRS(to)
    if (effFrom == effTo) {
        return coord
    }

    let (newLng, newLat) = routeConvert(coord[0], coord[1], effFrom, effTo)

    // Preserve altitude or additional dimensions
    if (coord.size >= 3) {
        return [newLng, newLat, coord[2]]
    } else {
        return [newLng, newLat]
    }
}

/**
 * Transforms all coordinates inside a GeoJSON object from one CRS to another.
 *
 * Supports:
 *   Point · MultiPoint · LineString · MultiLineString
 *   Polygon · MultiPolygon · GeometryCollection
 *   Feature · FeatureCollection
 *
 * The function is non-destructive: it returns a *new* GeoJSON tree.
 * Feature properties are preserved unchanged.
 *
 * Example
 * -------
 *   let pt   = Point([116.404, 39.915])
 *   let gcjPt = transformGeoJSON(pt, CRS.WGS84, CRS.GCJ02)
 *   // gcjPt is a Point with coordinates ≈ [116.41028, 39.91637]
 *
 *   let fc = FeatureCollection([
 *       Feature(Some(Point([116.404, 39.915])), None<String>)
 *   ])
 *   let gcjFc = transformGeoJSON(fc, CRS.WGS84, CRS.GCJ02)
 *
 * @param geojson  Source GeoJSON object
 * @param from     Source CRS
 * @param to       Target CRS
 * @return         New GeoJSON object with transformed coordinates
 *
 * @throws Exception for unsupported geometry types
 * @throws Exception when any coordinate is out of the valid range for `from`
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

    // Capture the conversion function as a closure for recursive traversal
    let fn: (Float64, Float64) -> (Float64, Float64) = {
        lng: Float64, lat: Float64 =>
        routeConvert(lng, lat, effFrom, effTo)
    }

    return transformGeoJSONWithFn(geojson, fn)
}
