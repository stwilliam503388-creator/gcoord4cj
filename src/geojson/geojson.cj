/**
 * Package: cj_gcoord.geojson
 *
 * GeoJSON 数据结构及递归坐标遍历工具包。
 * GeoJSON data structures and recursive coordinate-traversal utilities.
 *
 * 支持 RFC 7946 定义的全部七种 GeoJSON 几何类型：
 * Supports all seven GeoJSON geometry types defined in RFC 7946:
 *   Point · MultiPoint · LineString · MultiLineString
 *   Polygon · MultiPolygon · GeometryCollection
 *
 * 以及两种容器类型：
 * Plus the two container types:
 *   Feature · FeatureCollection
 *
 * 坐标遍历 API 仅暴露一个入口：
 * The coordinate-traversal API exposes a single entry point:
 *
 *   transformGeoJSONWithFn(geojson, fn)
 *
 * 其中 `fn: (Float64, Float64) -> (Float64, Float64)` 会作用于对象中的每一个
 * (lng, lat) 坐标对。高程值（数组第三个元素）保持不变。
 * where `fn: (Float64, Float64) -> (Float64, Float64)` is applied to every
 * (lng, lat) pair in the object.  Altitude values (third array element) are
 * preserved unchanged.
 *
 * 设计说明——静态坐标嵌套类型：
 * Design note – typed coordinate nesting:
 *   不同几何类型的坐标嵌套深度各不相同，本库采用静态强类型字段而非动态 Any 类型树：
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
// 抽象基类
// Abstract base classes
// ===========================================================================

/**
 * 所有 GeoJSON 对象的根类型。
 * Root type for all GeoJSON objects.
 *
 * 注意：仓颉中 `abstract class` 不能直接实例化，且隐式开放子类化。
 * 若编译器要求显式 `open` 修饰符，可在 `abstract` 前添加 `open`。
 * Note: `abstract class` in Cangjie cannot be instantiated directly and is
 * implicitly open for subclassing.  If the compiler requires an explicit
 * `open` modifier, add `open` before `abstract`.
 */
public abstract class GeoJSON {
    /** 返回该 GeoJSON 对象的 RFC 7946 "type" 字符串。
     *  Returns the RFC 7946 "type" string for this GeoJSON object. */
    public abstract func getType(): String
}

/** 七种几何类型的公共基类。Common base for the seven geometry types. */
public abstract class Geometry <: GeoJSON {}

// ===========================================================================
// 几何类型
// Geometry types
// ===========================================================================

/**
 * GeoJSON 点（Point）。
 * GeoJSON Point.
 * `coordinates` = [经度, 纬度] 或 [经度, 纬度, 高程]
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
 * GeoJSON 多点（MultiPoint）。
 * GeoJSON MultiPoint.
 * `coordinates` = [[经度, 纬度], [经度, 纬度], …]
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
 * GeoJSON 线串（LineString）。
 * GeoJSON LineString.
 * `coordinates` = [[经度, 纬度], [经度, 纬度], …]
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
 * GeoJSON 多线串（MultiLineString）。
 * GeoJSON MultiLineString.
 * `coordinates` = [[[经度, 纬度], …], [[经度, 纬度], …], …]
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
 * GeoJSON 多边形（Polygon）。
 * GeoJSON Polygon.
 * `coordinates` = [环0, 环1, …]，其中每个环 = [[经度, 纬度], …]
 * `coordinates` = [ring0, ring1, …] where each ring = [[lng, lat], …]
 * 环0 为外环，后续环为内孔（holes）。
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
 * GeoJSON 多多边形（MultiPolygon）。
 * GeoJSON MultiPolygon.
 * `coordinates` = [[多边形0], [多边形1], …]
 * `coordinates` = [[polygon0], [polygon1], …]
 * 每个多边形的嵌套方式与 Polygon.coordinates 相同。
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
 * GeoJSON 几何集合（GeometryCollection）。
 * GeoJSON GeometryCollection.
 * 包含一组有序的 Geometry 对象。
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
// 容器类型
// Container types
// ===========================================================================

/**
 * GeoJSON 要素（Feature）。
 * GeoJSON Feature.
 *
 * `geometry`   – 几何对象（可缺失，用 Option<Geometry> 表示）
 *                the geometry (may be absent, represented as Option<Geometry>)
 * `properties` – 任意 JSON 对象；此处存储为原始字符串。
 *                arbitrary JSON object; stored as a raw String here.
 *                未来版本可使用合适的 JSON 值类型替代。
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
 * GeoJSON 要素集合（FeatureCollection）。
 * GeoJSON FeatureCollection.
 * 包含一组有序的 Feature 对象。
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
// 底层坐标变换辅助函数
// Low-level coordinate transformation helpers
// ===========================================================================

/**
 * 对单个位置数组 [lng, lat] 或 [lng, lat, alt] 应用 fn。
 * 高程分量（若存在）原样传递。
 * Applies `fn` to a single position array [lng, lat] or [lng, lat, alt].
 * The altitude component, if present, is passed through unchanged.
 *
 * 抛出：当 coord 元素个数少于 2 时。
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
    // 保留可选高程 / 附加维度
    // Preserve optional altitude / additional dimensions
    if (coord.size >= 3) {
        return [newLng, newLat, coord[2]]
    } else {
        return [newLng, newLat]
    }
}

/**
 * 对一维位置数组中的每个位置应用 fn。
 * 用于 MultiPoint 和 LineString。
 * Applies `fn` to every position in a 1-D array of positions.
 * Used by MultiPoint and LineString.
 */
private func transformPositionArray(
    coords: Array<Array<Float64>>,
    fn: (Float64, Float64) -> (Float64, Float64)
): Array<Array<Float64>> {
    var result = ArrayList<Array<Float64>>()
    for (coord in coords) {
        result.append(transformPosition(coord, fn))
    }
    return result.toArray()
}

/**
 * 对二维位置数组中的每个位置应用 fn。
 * 用于 Polygon（环）和 MultiLineString。
 * Applies `fn` to every position in a 2-D array of position arrays.
 * Used by Polygon (rings) and MultiLineString.
 */
private func transformPositionArray2D(
    coords: Array<Array<Array<Float64>>>,
    fn: (Float64, Float64) -> (Float64, Float64)
): Array<Array<Array<Float64>>> {
    var result = ArrayList<Array<Array<Float64>>>()
    for (ring in coords) {
        result.append(transformPositionArray(ring, fn))
    }
    return result.toArray()
}

/**
 * 对三维位置数组中的每个位置应用 fn。
 * 用于 MultiPolygon。
 * Applies `fn` to every position in a 3-D array of position arrays.
 * Used by MultiPolygon.
 */
private func transformPositionArray3D(
    coords: Array<Array<Array<Array<Float64>>>>,
    fn: (Float64, Float64) -> (Float64, Float64)
): Array<Array<Array<Array<Float64>>>> {
    var result = ArrayList<Array<Array<Array<Float64>>>>()
    for (polygon in coords) {
        result.append(transformPositionArray2D(polygon, fn))
    }
    return result.toArray()
}

// ===========================================================================
// 高层 GeoJSON 变换
// High-level GeoJSON transformation
// ===========================================================================

/**
 * 递归地对 Geometry 中的每个 (lng, lat) 坐标对应用 fn。
 * 返回新的 Geometry 对象，原对象不被修改。
 * Recursively applies `fn` to every (lng, lat) pair inside a Geometry.
 * Returns a *new* Geometry object; the original is not mutated.
 *
 * 抛出：当遇到不支持的几何子类型时。
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
            // 递归处理集合中的每个几何对象
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
 * 递归地对任意 GeoJSON 对象中的每个 (lng, lat) 坐标对应用 fn。
 * 支持的类型：所有 Geometry 子类、Feature、FeatureCollection。
 * 返回新的 GeoJSON 对象，原对象不被修改。
 * Recursively applies `fn` to every (lng, lat) pair in any GeoJSON object.
 * Supported types: all Geometry subtypes, Feature, FeatureCollection.
 * Returns a *new* GeoJSON object; the original is not mutated.
 *
 * 抛出：当遇到不支持的 GeoJSON 类型时。
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
            // 变换 Feature 的几何，属性 (properties) 原样保留
            let newGeom: Option<Geometry> = match (feat.geometry) {
                case Some(g) => Some(transformGeometry(g, fn))
                case None    => None<Geometry>
            }
            Feature(newGeom, feat.properties)

        case fc: FeatureCollection =>
            // 遍历并变换集合中的每个 Feature
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
