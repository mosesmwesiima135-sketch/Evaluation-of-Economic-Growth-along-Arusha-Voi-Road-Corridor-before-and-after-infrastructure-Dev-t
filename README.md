# Data

This folder holds the files exported from Google Earth Engine by `scripts/01_gee_extract_ntl.js`. The R script reads them from here.

## Files

| File | Type | Contents |
|---|---|---|
| `ntl_grid_1km.shp` (+ `.shx`, `.dbf`, `.prj`, `.cpg`, `.fix`) | Polygon shapefile, UTM Zone 37S (EPSG:32737) | The 1 km analysis grid: 4,895 cells with the attributes below. This is the modelling dataset. |
| `ntl_grid_1km_csv.csv` | Table | The same attributes without geometry. It also carries two Earth Engine columns, `system:index` and `.geo`, which are not used. |
| `corridor_10km_buffer.shp` (+ parts) | Polygon shapefile, WGS84 | The 10 km buffer around the road line |
| `ntl_before_after_change.tif` | GeoTIFF, EPSG:32737, about 464 m pixels | Band 1: before (2013). Band 2: after (2020–21 mean). Band 3: change (after minus before). |

Keep all the parts of each shapefile together and do not rename them individually. The `.fix` files are written by Earth Engine and are not needed by R or QGIS.

The road line itself is not stored as a file. Its 12 waypoints are listed in `scripts/01_gee_extract_ntl.js`, which also contains an export task for it.

## Grid attributes

| Column | Unit | Description |
|---|---|---|
| `cell_id` | – | Unique cell identifier assigned by Earth Engine |
| `ntl_before` | nW/cm²/sr | Mean `average_masked` radiance in the cell, 2013 annual composite |
| `ntl_after` | nW/cm²/sr | Mean `average_masked` radiance in the cell, mean of the 2020 and 2021 annual composites |
| `change` | nW/cm²/sr | `ntl_after - ntl_before` |
| `delta` | log scale | `log(1 + ntl_after) - log(1 + ntl_before)`; the model response |
| `lit` | 0 / 1 | 1 if the cell has radiance above zero in either period |
| `dist_m` | metres | Distance from the cell centre to the road line |

## Source and licence

Nighttime lights: VIIRS Nighttime Day/Night Annual Band Composites V2.1, Earth Observation Group, Payne Institute for Public Policy, Colorado School of Mines. Accessed through Google Earth Engine as `NOAA/VIIRS/DNB/ANNUAL_V21`. The dataset is in the public domain.

Citation: Elvidge, C.D., Zhizhin, M., Ghosh, T., Hsu, F.C. and Taneja, J. (2021). Annual time series of global VIIRS nighttime lights derived from monthly averages: 2012 to 2019. *Remote Sensing*, 13(5), 922. https://doi.org/10.3390/rs13050922

The road line, corridor and grid are derived by the author.
