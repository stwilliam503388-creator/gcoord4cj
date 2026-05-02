/**
 * Package: cj_gcoord.geojson
 *
 * GeoJSON data structures and recursive coordinate-traversal utilities.
 *
 * Supports all seven GeoJSON geometry types defined in RFC 7946:
 *   Point · MultiPoint · LineString · MultiLineString
 *   Polygon · MultiPolygon · GeometryCollection
 *
 * Plus the two container types:
 *   Feature · FeatureCollection
 *
 * The coordinate-traversal API exposes a single entry point:
 *
 *   transformGeoJSONWithFn(geojson, fn)
 *
 * where `fn: (Float64, Float64) -> (Float64, Float64)` is applied to every
 * (lng, lat) pair in the object.  Altitude values (third array element) are
 * preserved unchanged.
 *
 * Design note – typed coordinate nesting:
 *   GeoJSON nests coordinates at different depths for each geometry type.
 *   Rather than using a dynamic Any-typed tree, each class declares its own
 *   statically-typed coordinates field:
 *     Point            → Array<Float64>
 *     MultiPoint / LineString → Array<Array<Float64>>
 *     Polygon / MultiLineString → Array<Array<Array<Float64>>>
 *     MultiPolygon     → Array<Array<Array<Array<Float64>>>>
 *   This keeps the library dependency-free while remaining type-safe.
 */
package cj_gcoord.geojson

import std.collection.*

// ===========================================================================
// Abstract base classes
// ===========================================================================

/**
 * Root type for all GeoJSON objects.
 *
 * Note: `abstract class` in Cangjie cannot be instantiated directly and is
 * implicitly open for subclassing.  If the compiler requires an explicit
 * `open` modifier, add `open` before `abstract`.
 */
public abstract class GeoJSON {
    /** Returns the RFC 7946 "type" string for this GeoJSON object. */
    public abstract func getType(): String
}

/** Common base for the seven geometry types. */
public abstract class Geometry <: GeoJSON {}

// ===========================================================================
// Geometry types
// ===========================================================================

/**
 * GeoJSON Point.
 * `coordinates` = [longitude, latitude]  or  [longitude, latitude, altitude]
 */
public class Point <: Geometry {
    public var coordinates: Array<Float64>

    public init(coordinates: Array<Float64>) {
        this.coordinates = coordinates
    }

    public override func getType(): String { "Point" }
}

/**
 * GeoJSON MultiPoint.
 * `coordinates` = [[lng, lat], [lng, lat], …]
 */
public class MultiPoint <: Geometry {
    public var coordinates: Array<Array<Float64>>

    public init(coordinates: Array<Array<Float64>>) {
        this.coordinates = coordinates
    }

    public override func getType(): String { "MultiPoint" }
}

/**
 * GeoJSON LineString.
 * `coordinates` = [[lng, lat], [lng, lat], …]
 */
public class LineString <: Geometry {
    public var coordinates: Array<Array<Float64>>

    public init(coordinates: Array<Array<Float64>>) {
        this.coordinates = coordinates
    }

    public override func getType(): String { "LineString" }
}

/**
 * GeoJSON MultiLineString.
 * `coordinates` = [[[lng, lat], …], [[lng, lat], …], …]
 */
public class MultiLineString <: Geometry {
    public var coordinates: Array<Array<Array<Float64>>>

    public init(coordinates: Array<Array<Array<Float64>>>) {
        this.coordinates = coordinates
    }

    public override func getType(): String { "MultiLineString" }
}

/**
 * GeoJSON Polygon.
 * `coordinates` = [ring0, ring1, …] where each ring = [[lng, lat], …]
 * ring0 is the exterior ring; subsequent rings are holes.
 */
public class Polygon <: Geometry {
    public var coordinates: Array<Array<Array<Float64>>>

    public init(coordinates: Array<Array<Array<Float64>>>) {
        this.coordinates = coordinates
    }

    public override func getType(): String { "Polygon" }
}

/**
 * GeoJSON MultiPolygon.
 * `coordinates` = [[polygon0], [polygon1], …]
 * Each polygon follows the same nesting as Polygon.coordinates.
 */
public class MultiPolygon <: Geometry {
    public var coordinates: Array<Array<Array<Array<Float64>>>>

    public init(coordinates: Array<Array<Array<Array<Float64>>>>) {
        this.coordinates = coordinates
    }

    public override func getType(): String { "MultiPolygon" }
}

/**
 * GeoJSON GeometryCollection.
 * Contains an ordered list of Geometry objects.
 */
public class GeometryCollection <: Geometry {
    public var geometries: Array<Geometry>

    public init(geometries: Array<Geometry>) {
        this.geometries = geometries
    }

    public override func getType(): String { "GeometryCollection" }
}

// ===========================================================================
// Container types
// ===========================================================================

/**
 * GeoJSON Feature.
 *
 * `geometry`   – the geometry (may be absent, represented as Option<Geometry>)
 * `properties` – arbitrary JSON object; stored as a raw String here.
 *                A future version could use a proper JSON value type.
 */
public class Feature <: GeoJSON {
    public var geometry:   Option<Geometry>
    public var properties: Option<String>

    public init(geometry: Option<Geometry>, properties: Option<String>) {
        this.geometry   = geometry
        this.properties = properties
    }

    public override func getType(): String { "Feature" }
}

/**
 * GeoJSON FeatureCollection.
 * Contains an ordered list of Feature objects.
 */
public class FeatureCollection <: GeoJSON {
    public var features: Array<Feature>

    public init(features: Array<Feature>) {
        this.features = features
    }

    public override func getType(): String { "FeatureCollection" }
}

// ===========================================================================
// Low-level coordinate transformation helpers
// ===========================================================================

/**
 * Applies `fn` to a single position array [lng, lat] or [lng, lat, alt].
 * The altitude component, if present, is passed through unchanged.
 *
 * Throws: Exception when `coord` has fewer than 2 elements.
 */
private func transformPosition(
    coord: Array<Float64>,
    fn: (Float64, Float64) -> (Float64, Float64)
): Array<Float64> {
    if (coord.size < 2) {
        throw Exception(
            "A GeoJSON position must have at least 2 elements [lng, lat], got: " +
            coord.size.toString()
        )
    }
    let (newLng, newLat) = fn(coord[0], coord[1])
    // Preserve optional altitude / additional dimensions
    if (coord.size >= 3) {
        return [newLng, newLat, coord[2]]
    } else {
        return [newLng, newLat]
    }
}

/**
 * Applies `fn` to every position in a 1-D array of positions.
 * Used by MultiPoint and LineString.
 *
 * [O3] Pre-allocated Array(n, lambda) replaces ArrayList+toArray(),
 * eliminating one heap allocation and one copy per call.
 */
private func transformPositionArray(
    coords: Array<Array<Float64>>,
    fn: (Float64, Float64) -> (Float64, Float64)
): Array<Array<Float64>> {
    return Array<Array<Float64>>(coords.size, { i => transformPosition(coords[i], fn) })
}

/**
 * Applies `fn` to every position in a 2-D array of position arrays.
 * Used by Polygon (rings) and MultiLineString.
 *
 * [O3] Pre-allocated Array(n, lambda) replaces ArrayList+toArray().
 */
private func transformPositionArray2D(
    coords: Array<Array<Array<Float64>>>,
    fn: (Float64, Float64) -> (Float64, Float64)
): Array<Array<Array<Float64>>> {
    return Array<Array<Array<Float64>>>(coords.size, { i => transformPositionArray(coords[i], fn) })
}

/**
 * Applies `fn` to every position in a 3-D array of position arrays.
 * Used by MultiPolygon.
 *
 * [O3] Pre-allocated Array(n, lambda) replaces ArrayList+toArray().
 */
private func transformPositionArray3D(
    coords: Array<Array<Array<Array<Float64>>>>,
    fn: (Float64, Float64) -> (Float64, Float64)
): Array<Array<Array<Array<Float64>>>> {
    return Array<Array<Array<Array<Float64>>>>(coords.size, { i => transformPositionArray2D(coords[i], fn) })
}

// ===========================================================================
// High-level GeoJSON transformation
// ===========================================================================

/**
 * Recursively applies `fn` to every (lng, lat) pair inside a Geometry.
 *
 * Returns a *new* Geometry object; the original is not mutated.
 *
 * Throws: Exception for unknown geometry subtypes.
 */
private func transformGeometry(
    geometry: Geometry,
    fn: (Float64, Float64) -> (Float64, Float64)
): Geometry {
    match (geometry) {
        case pt: Point =>
            Point(transformPosition(pt.coordinates, fn))

        case mp: MultiPoint =>
            MultiPoint(transformPositionArray(mp.coordinates, fn))

        case ls: LineString =>
            LineString(transformPositionArray(ls.coordinates, fn))

        case mls: MultiLineString =>
            MultiLineString(transformPositionArray2D(mls.coordinates, fn))

        case pg: Polygon =>
            Polygon(transformPositionArray2D(pg.coordinates, fn))

        case mpg: MultiPolygon =>
            MultiPolygon(transformPositionArray3D(mpg.coordinates, fn))

        case gc: GeometryCollection =>
            var newGeoms = ArrayList<Geometry>()
            for (g in gc.geometries) {
                newGeoms.append(transformGeometry(g, fn))
            }
            GeometryCollection(newGeoms.toArray())

        case _ =>
            throw Exception("Unsupported geometry type: " + geometry.getType())
    }
}

/**
 * Recursively applies `fn` to every (lng, lat) pair in any GeoJSON object.
 *
 * Supported types: all Geometry subtypes, Feature, FeatureCollection.
 * Returns a *new* GeoJSON object; the original is not mutated.
 *
 * Throws: Exception for unknown GeoJSON types.
 */
public func transformGeoJSONWithFn(
    geojson: GeoJSON,
    fn: (Float64, Float64) -> (Float64, Float64)
): GeoJSON {
    match (geojson) {
        case geom: Geometry =>
            transformGeometry(geom, fn)

        case feat: Feature =>
            let newGeom: Option<Geometry> = match (feat.geometry) {
                case Some(g) => Some(transformGeometry(g, fn))
                case None    => None<Geometry>
            }
            Feature(newGeom, feat.properties)

        case fc: FeatureCollection =>
            var newFeatures = ArrayList<Feature>()
            for (feature in fc.features) {
                let transformed = transformGeoJSONWithFn(feature, fn)
                match (transformed) {
                    case f: Feature => newFeatures.append(f)
                    case _ =>
                        throw Exception("Expected Feature after transformation")
                }
            }
            FeatureCollection(newFeatures.toArray())

        case _ =>
            throw Exception("Unsupported GeoJSON type: " + geojson.getType())
    }
}
