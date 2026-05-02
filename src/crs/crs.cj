/**
 * Package: cj_gcoord.crs
 *
 * 定义贯穿 cj-gcoord 库的坐标参考系（CRS）枚举。
 * 所有公开 API 函数均通过 CRS 值来标识源坐标系和目标坐标系。
 *
 * Defines the CRS (Coordinate Reference System) enumeration used throughout
 * the cj-gcoord library.  Every public API function accepts and returns CRS
 * values to identify the source / target coordinate system.
 *
 * 移植自 JavaScript gcoord 库：
 * Ported from the JavaScript gcoord library:
 *   https://github.com/hujiulong/gcoord
 */
package cj_gcoord.crs

/**
 * 支持的坐标参考系枚举。
 * Supported Coordinate Reference Systems.
 *
 * | 枚举值     | 描述                                                      |
 * |-----------|-----------------------------------------------------------|
 * | WGS84     | 世界大地测量系统 1984，GPS 标准坐标系                          |
 * | GCJ02     | 国测局坐标系（"火星坐标"），高德地图 / Google 中国地图使用        |
 * | BD09      | 百度 09 坐标系（经纬度格式）                                   |
 * | BD09LL    | BD09 的别名，与 BD09 完全等价                                 |
 * | EPSG4326  | EPSG:4326，等同于 WGS84                                    |
 * | EPSG3857  | EPSG:3857，Web Mercator 投影（单位：米）                      |
 *
 * 注意：BD09 与 BD09LL 在本库中视为同一坐标系；EPSG4326 与 WGS84 同理。
 * Note: BD09 and BD09LL are treated as identical by this library.
 *       EPSG4326 and WGS84 are also identical.
 */
public enum CRS <: Equatable<CRS> {
    | WGS84     // 世界大地测量系统 1984（GPS 标准）
    | GCJ02     // 国测局坐标系（火星坐标，中国法定标准）
    | BD09      // 百度坐标系（经纬度）
    | BD09LL    // BD09 别名
    | EPSG4326  // WGS84 别名（EPSG:4326）
    | EPSG3857  // Web Mercator 投影（EPSG:3857，单位：米）

    // ---- Equatable -------------------------------------------------------
    // 相等性比较：仅当两个枚举值名称相同时才相等。
    // 别名（如 BD09LL 与 BD09）不在此处统一——该规范化由公开 transform API 负责。

    /**
     * 结构相等性：两个 CRS 值仅在命名同一坐标系时相等。
     * 别名（如 BD09LL == BD09）不在此处统一，规范化在公开 transform API 中处理。
     *
     * Structural equality: two CRS values are equal iff they name the same
     * coordinate system.  Aliases (e.g. BD09LL == BD09) are NOT unified here
     * – that normalisation happens in the public transform API.
     */
    public operator func ==(other: CRS): Bool {
        match ((this, other)) {
            case (WGS84,    WGS84)    => true
            case (GCJ02,    GCJ02)    => true
            case (BD09,     BD09)     => true
            case (BD09LL,   BD09LL)   => true
            case (EPSG4326, EPSG4326) => true
            case (EPSG3857, EPSG3857) => true
            case _                    => false
        }
    }

    // 不等于运算符：直接对 == 取反
    public operator func !=(other: CRS): Bool {
        !(this == other)
    }

    // ---- ToString --------------------------------------------------------
    // 返回该坐标系的标准字符串名称，用于错误信息和调试输出

    public func toString(): String {
        match (this) {
            case WGS84    => "WGS84"
            case GCJ02    => "GCJ02"
            case BD09     => "BD09"
            case BD09LL   => "BD09LL"
            case EPSG4326 => "EPSG4326"
            case EPSG3857 => "EPSG3857"
        }
    }
}
