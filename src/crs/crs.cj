/**
 * Package: cj_gcoord.crs
 *
 * Defines the CRS (Coordinate Reference System) enumeration used throughout
 * the cj-gcoord library.  Every public API function accepts and returns CRS
 * values to identify the source / target coordinate system.
 *
 * Ported from the JavaScript gcoord library:
 *   https://github.com/hujiulong/gcoord
 */
package cj_gcoord.crs

/**
 * Supported Coordinate Reference Systems.
 *
 * | Value     | Description                                               |
 * |-----------|-----------------------------------------------------------|
 * | WGS84     | World Geodetic System 1984 – the GPS standard             |
 * | GCJ02     | Guojia Cehui Ju 02 ("Mars") – AutoNavi / Google China     |
 * | BD09      | Baidu 09 coordinate system (longitude / latitude)         |
 * | BD09LL    | Alias for BD09 (same geographic lon/lat encoding)         |
 * | EPSG4326  | EPSG:4326 – equivalent to WGS84                          |
 * | EPSG3857  | EPSG:3857 – Web Mercator projection (values in metres)    |
 *
 * Note: BD09 and BD09LL are treated as identical by this library.
 *       EPSG4326 and WGS84 are also identical.
 */
public enum CRS <: Equatable<CRS> {
    | WGS84
    | GCJ02
    | BD09
    | BD09LL
    | EPSG4326
    | EPSG3857

    // ---- Equatable -------------------------------------------------------

    /**
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

    public operator func !=(other: CRS): Bool {
        !(this == other)
    }

    // ---- ToString --------------------------------------------------------

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
