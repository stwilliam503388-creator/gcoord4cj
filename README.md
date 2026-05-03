# gcoord4cj — cj-gcoord

> **Cangjie（仓颉）语言实现的地理坐标转换库**，对标 JavaScript 版 [gcoord](https://github.com/hujiulong/gcoord)。

[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## 功能特性

| 功能 | 说明 |
|------|------|
| 坐标系转换 | WGS84 ↔ GCJ02 ↔ BD09 ↔ EPSG:3857 全路径互转 |
| 别名支持 | EPSG4326 ≡ WGS84，BD09LL ≡ BD09 |
| GeoJSON 支持 | Point / MultiPoint / LineString / MultiLineString / Polygon / MultiPolygon / GeometryCollection / Feature / FeatureCollection |
| 高精度逆向算法 | GCJ02→WGS84 使用 30 次迭代逼近，误差 < 1×10⁻⁶ 度（≈1 cm） |
| 纯仓颉实现 | 仅使用标准库 `std.math` / `std.collection`，零外部依赖 |

---

## 支持的坐标系

| `CRS` 枚举值 | 描述 |
|------------|------|
| `WGS84` | 世界大地测量系统 1984（GPS 标准） |
| `GCJ02` | 国测局坐标系（高德、Google 中国地图） |
| `BD09` | 百度坐标系（经纬度） |
| `BD09LL` | BD09 别名 |
| `EPSG4326` | WGS84 别名 |
| `EPSG3857` | Web Mercator（单位：米） |

---

## 项目结构

```
gcoord4cj/
├── cjpm.toml                   # 包管理配置
├── BENCHMARK.md                # 性能基准测试报告（JS 实测 + 仓颉估算）
└── src/
    ├── crs/
    │   └── crs.cj              # package cj_gcoord.crs  — CRS 枚举
    ├── transform/
    │   └── transform.cj        # package cj_gcoord.transform  — 转换算法
    ├── geojson/
    │   └── geojson.cj          # package cj_gcoord.geojson  — GeoJSON 类型
    ├── gcoord.cj               # package cj_gcoord  — 公开 API 入口
    └── test/
        ├── gcoord_test.cj      # CRS 枚举 / 算法 / 公开 API / GeoJSON / 错误处理
        ├── transform_test.cj   # JS ground-truth 精确值对比 / 健壮性 / 安全性
        └── extra_test.cj       # 多城市往返 / 全路径 / 境内外边界 / 别名 / 3D 坐标
```

---

## 安装与集成

### 1. 将本库作为本地依赖引入

在你的仓颉项目的 `cjpm.toml` 中添加依赖：

```toml
[dependencies]
cj_gcoord = { path = "../gcoord4cj" }
```

### 2. 从源码直接使用

将本仓库克隆到本地，然后在项目中通过相对路径引用：

```bash
git clone https://github.com/stwilliam503388-creator/gcoord4cj.git
```

---

## 快速上手

```cangjie
import cj_gcoord.*
import cj_gcoord.crs.*
import cj_gcoord.geojson.*

// ── 1. 数组坐标转换 ────────────────────────────────────────────────────────
// WGS84（GPS）→ GCJ02（高德 / Google 中国）
let gcj = transform([116.404, 39.915], CRS.WGS84, CRS.GCJ02)
// gcj ≈ [116.41028, 39.91637]

// GCJ02 → BD09（百度地图）
let bd09 = transform([116.41028, 39.91637], CRS.GCJ02, CRS.BD09)
// bd09 ≈ [116.41714, 39.92275]

// WGS84 → EPSG:3857（Web Mercator，单位：米）
let merc = transform([116.404, 39.915], CRS.WGS84, CRS.EPSG3857)
// merc ≈ [12958430.18, 4852278.95]

// EPSG4326（= WGS84）→ GCJ02
let gcj2 = transform([116.404, 39.915], CRS.EPSG4326, CRS.GCJ02)

// 保留高程
let with_alt = transform([116.404, 39.915, 50.0], CRS.WGS84, CRS.GCJ02)
// with_alt[2] == 50.0

// ── 2. GeoJSON 转换 ────────────────────────────────────────────────────────
// Point
let pt    = Point([116.404, 39.915])
let gcjPt = transformGeoJSON(pt, CRS.WGS84, CRS.GCJ02)

// FeatureCollection
let fc = FeatureCollection([
    Feature(Some<Geometry>(Point([116.404, 39.915])), Some<String>("{\"name\":\"北京\"}")),
    Feature(Some<Geometry>(Point([121.4737, 31.2304])), None<String>)
])
let gcjFc = transformGeoJSON(fc, CRS.WGS84, CRS.GCJ02)
```

---

## 构建与测试

```bash
# 初始化（首次）
cjpm build

# 运行单元测试
cjpm test
```

### 测试覆盖说明

| 测试文件 | 测试类 | 覆盖内容 |
|---------|-------|---------|
| `gcoord_test.cj` | `CRSTest` | CRS 枚举等值 / 不等值 / toString |
| | `TransformAlgorithmTest` | 低层算法函数（wgs84ToGcj02 等）数值精度 |
| | `RoundTripTest` | 六条对称路径往返误差 < 1e-6° |
| | `GeoJSONTest` | Point / MultiPoint / LineString / Polygon / MultiLineString / MultiPolygon / GeometryCollection / Feature / FeatureCollection |
| | `ErrorHandlingTest` | 坐标不足 / 经纬度越界异常 |
| `transform_test.cj` | `GroundTruthTest` | 与 JS gcoord 1.0.7 参考值精确对比（误差 < 1e-6°） |
| | `GeoJSONStructureTest` | GeoJSON 转换后 type 不变 / 坐标层次不变 |
| | `RobustnessTest` | 空数组 / 单元素 / NaN / Infinity / 极坐标不崩溃 |
| | `SafetyTest` | 迭代上界 30 次 / 5 层嵌套 / 10,000 Feature 无内存异常 |
| `extra_test.cj` | `MoreCitiesTest` | 广州 / 成都 / 哈尔滨 / 拉萨 / 乌鲁木齐五城市精确值+往返 |
| | `AllConvertPathsTest` | 全部 12 条有向转换路径覆盖 |
| | `ChinaBoundaryTest` | 境内有偏移 / 境外无偏移 / 东京 / 圣保罗 |
| | `AliasPathsTest` | EPSG4326 ≡ WGS84 / BD09LL ≡ BD09 全方向等值验证 |
| | `GeoJson3DTest` | Point / MultiPoint / LineString / Polygon / Feature 3D 高程保留 |

---

## API 参考

### `transform(coord, from, to)`

| 参数 | 类型 | 说明 |
|------|------|------|
| `coord` | `Array<Float64>` | 源坐标 `[lng, lat]` 或 `[lng, lat, alt]` |
| `from` | `CRS` | 源坐标系 |
| `to` | `CRS` | 目标坐标系 |
| 返回值 | `Array<Float64>` | 转换后坐标（长度与输入相同） |

**异常情况：**
- `coord.size < 2`：坐标数组元素不足，抛出异常
- 地理坐标系下经度超出 `[-180, 180]` 或纬度超出 `[-90, 90]`：抛出异常
- 不支持的转换路径：抛出异常

### `transformGeoJSON(geojson, from, to)`

| 参数 | 类型 | 说明 |
|------|------|------|
| `geojson` | `GeoJSON` | 任意 GeoJSON 对象 |
| `from` | `CRS` | 源坐标系 |
| `to` | `CRS` | 目标坐标系 |
| 返回值 | `GeoJSON` | 坐标已转换的新 GeoJSON 对象（原对象不变） |

**支持的 GeoJSON 类型：**
Point · MultiPoint · LineString · MultiLineString · Polygon · MultiPolygon · GeometryCollection · Feature · FeatureCollection

---

## GeoJSON 类型用法示例

### Point（点）

```cangjie
import cj_gcoord.geojson.*

let pt = Point([116.404, 39.915])          // [经度, 纬度]
let ptWithAlt = Point([116.404, 39.915, 50.0])  // [经度, 纬度, 高程]
```

### LineString（线串）

```cangjie
let ls = LineString([
    [116.404, 39.915],
    [121.4737, 31.2304]
])
```

### Polygon（多边形）

```cangjie
// coordinates[0] 为外环，后续为内孔
let ring: Array<Array<Float64>> = [
    [116.0, 39.5], [116.8, 39.5],
    [116.8, 40.3], [116.0, 40.3], [116.0, 39.5]  // 首尾相同以闭合
]
let pg = Polygon([ring])
```

### GeometryCollection（几何集合）

```cangjie
let gc = GeometryCollection([
    Point([116.404, 39.915]),
    LineString([[116.404, 39.915], [121.4737, 31.2304]])
])
let gcjGc = transformGeoJSON(gc, CRS.WGS84, CRS.GCJ02)
```

### Feature（要素）

```cangjie
// geometry 和 properties 均可为 None
let feat = Feature(
    Some<Geometry>(Point([116.404, 39.915])),
    Some<String>("{\"name\":\"北京\",\"type\":\"城市\"}")
)
let gcjFeat = transformGeoJSON(feat, CRS.WGS84, CRS.GCJ02)
// 转换后 properties 原样保留，geometry 坐标被转换
```

### FeatureCollection（要素集合）

```cangjie
let fc = FeatureCollection([
    Feature(Some<Geometry>(Point([116.404, 39.915])),  Some<String>("{\"name\":\"北京\"}")),
    Feature(Some<Geometry>(Point([121.4737, 31.2304])), None<String>),
    Feature(None<Geometry>, None<String>)  // 无几何要素
])
let gcjFc = transformGeoJSON(fc, CRS.WGS84, CRS.GCJ02)
```

---

## 坐标系转换速查表

| 源坐标系 | 目标坐标系 | 调用示例 |
|---------|---------|---------|
| WGS84（GPS）| GCJ02（高德/谷歌中国）| `transform(coord, CRS.WGS84, CRS.GCJ02)` |
| GCJ02 | WGS84 | `transform(coord, CRS.GCJ02, CRS.WGS84)` |
| WGS84 | BD09（百度）| `transform(coord, CRS.WGS84, CRS.BD09)` |
| BD09 | WGS84 | `transform(coord, CRS.BD09, CRS.WGS84)` |
| GCJ02 | BD09 | `transform(coord, CRS.GCJ02, CRS.BD09)` |
| BD09 | GCJ02 | `transform(coord, CRS.BD09, CRS.GCJ02)` |
| WGS84 | EPSG:3857（Web Mercator）| `transform(coord, CRS.WGS84, CRS.EPSG3857)` |
| EPSG:3857 | WGS84 | `transform(coord, CRS.EPSG3857, CRS.WGS84)` |
| GCJ02 | EPSG:3857 | `transform(coord, CRS.GCJ02, CRS.EPSG3857)` |
| EPSG:3857 | GCJ02 | `transform(coord, CRS.EPSG3857, CRS.GCJ02)` |
| BD09 | EPSG:3857 | `transform(coord, CRS.BD09, CRS.EPSG3857)` |
| EPSG:3857 | BD09 | `transform(coord, CRS.EPSG3857, CRS.BD09)` |

---

## 性能参考

仓颉版编译为 LLVM 原生二进制，单点转换速度预计约 JS (V8) 的 **3–5×**。
以下为 JS gcoord 1.0.7 在 Node.js v20.20.2 上的实测基准（作为参照基线）：

| 转换路径 | JS 平均耗时 | JS 吞吐量 |
|---------|-----------|---------|
| WGS84 → GCJ02 | 138.5 ms/10万次 | 722k ops/s |
| GCJ02 → WGS84 | 201.4 ms/10万次 | 496k ops/s |
| WGS84 → BD09 | 160.3 ms/10万次 | 624k ops/s |
| WGS84 → EPSG:3857 | 110.5 ms/10万次 | 905k ops/s |

仓颉版实测数据需本地安装 `cjc 1.0.0` 后运行：

```bash
cd bench
cjpm build --release
cjpm run
```

完整性能分析（算法优化说明 / 估算方法 / 数据不确定度）见 [BENCHMARK.md](BENCHMARK.md)。

---

## 算法说明

### WGS84 ↔ GCJ02

基于国测局坐标偏移多项式（GB/T 20257）：
- 正向（WGS84→GCJ02）：直接计算偏移量 `(dLng, dLat)` 并叠加
- 逆向（GCJ02→WGS84）：收敛迭代逼近（阈值 1×10⁻¹⁰ 度，仓颉版中国境内约 4 次收敛，JS 版约 3 次，安全上界 30 次），精度 < 1×10⁻⁷ 度（≈1 cm）

椭球参数（克拉索夫斯基椭球）：
- 长半轴 `a = 6 378 245.0 m`
- 第一偏心率平方 `ee = 0.006 693 421 622 96…`

### GCJ02 ↔ BD09

百度坐标系在 GCJ02 基础上做了极坐标旋转与径向偏移：
```
z     = sqrt(x² + y²) + 0.00002·sin(y·π·3000/180)
theta = atan2(y, x) + 0.000003·cos(x·π·3000/180)
BD09  = (z·cos(theta)+0.0065,  z·sin(theta)+0.006)
```

### WGS84 ↔ EPSG:3857

标准 Web Mercator 公式：
```
x = lng × 20037508.34 / 180
y = ln(tan((90+lat)·π/360)) / (π/180) × 20037508.34 / 180
```

---

## 与 JavaScript gcoord 的对应关系

| JS gcoord | cj-gcoord |
|-----------|-----------|
| `gcoord.WGS84` | `CRS.WGS84` |
| `gcoord.GCJ02` | `CRS.GCJ02` |
| `gcoord.BD09` | `CRS.BD09` |
| `gcoord.EPSG4326` | `CRS.EPSG4326` |
| `gcoord.EPSG3857` | `CRS.EPSG3857` |
| `gcoord.transform(coord, from, to)` | `transform(coord, from, to)` |
| `gcoord.transform(geojson, from, to)` | `transformGeoJSON(geojson, from, to)` |

---

## 注意事项

1. **中国境外坐标**：GCJ02/BD09 偏移量仅适用于中国大陆（经度 73.66°–135.05°，纬度 3.86°–53.55°），境外坐标原样返回。
2. **EPSG:3857 输入验证**：Web Mercator 坐标单位为米，不执行经纬度范围校验。
3. **仓颉版本**：代码以 `cjc-version = "1.0.0"` 为目标编写。若编译器版本不同，`Hashable` 接口方法名（`hashCode` vs `hashValue`）或 `ArrayList.toArray()` API 可能需小幅调整，详见源码注释。
4. **非破坏性 API**：`transformGeoJSON` 始终返回新对象，原始 GeoJSON 对象不会被修改。
5. **高程保留**：`transform` 和 `transformGeoJSON` 均会原样保留坐标数组中的高程（第三个元素）及更多附加维度。

---

## 许可证

MIT License — 与原始 JavaScript gcoord 库保持一致。