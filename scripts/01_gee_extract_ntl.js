// =====================================================================
// 01  Extract before/after nighttime lights along the
//     Arusha-Holili/Taveta-Voi road corridor (Google Earth Engine)
//
// Paste into the Earth Engine Code Editor (code.earthengine.google.com),
// click Run, then start each export from the Tasks tab.
// Download the exported files from Google Drive into the data/ folder.
// =====================================================================

// ---------------- 1. SETTINGS (edit these) ---------------------------
var BUFFER_M     = 10000;                        // 10 km each side = 20 km corridor
var CELL_M       = 1000;                         // 1 km grid
var BEFORE       = ['2012-01-01', '2014-01-01']; // returns the 2013 composite, the only
                                                 // pre-construction year (works began Feb 2014)
var AFTER        = ['2020-01-01', '2022-01-01']; // 2020-2021 (last section done Apr 2019)
var BAND         = 'average_masked';             // background noise set to zero
var DRIVE_FOLDER = 'GEE_NTL_Road';

// ---------------- 2. ROAD ALIGNMENT ----------------------------------
// OPTION A (planned refinement): upload the real road centreline
// (e.g. from OpenStreetMap) as an asset and use it here:
// var road = ee.FeatureCollection('users/YOUR_USERNAME/arusha_voi_road').geometry();

// OPTION B (used in this study): APPROXIMATE line through the main towns.
// Straight segments can sit a few km off the true road.
var road = ee.Geometry.LineString([
  [36.683, -3.367],  // Arusha
  [36.790, -3.372],  // Tengeru
  [36.857, -3.368],  // Usa River
  [37.130, -3.335],  // Boma Ng'ombe
  [37.340, -3.350],  // Moshi
  [37.553, -3.388],  // Himo
  [37.630, -3.380],  // Holili (border)
  [37.676, -3.398],  // Taveta
  [38.130, -3.400],  // Maktau
  [38.300, -3.470],  // Bura
  [38.378, -3.503],  // Mwatate
  [38.567, -3.396]   // Voi
]);

var corridor = road.buffer(BUFFER_M);

// ---------------- 3. VIIRS ANNUAL NIGHTTIME LIGHTS -------------------
// V2.1 annual composites run from 2013 to 2021.
// For 2022 onward use 'NOAA/VIIRS/DNB/ANNUAL_V22'.
var viirs = ee.ImageCollection('NOAA/VIIRS/DNB/ANNUAL_V21').select(BAND);

var before = viirs.filterDate(BEFORE[0], BEFORE[1]).mean().unmask(0).rename('ntl_before');
var after  = viirs.filterDate(AFTER[0],  AFTER[1]).mean().unmask(0).rename('ntl_after');
var change = after.subtract(before).rename('ntl_change');

print('Images in BEFORE period:', viirs.filterDate(BEFORE[0], BEFORE[1]).size());
print('Images in AFTER period:',  viirs.filterDate(AFTER[0],  AFTER[1]).size());
print('Before image(s):', viirs.filterDate(BEFORE[0], BEFORE[1]).aggregate_array('system:index'));
print('After image(s):',  viirs.filterDate(AFTER[0],  AFTER[1]).aggregate_array('system:index'));

// ---------------- 4. 1 km GRID IN UTM 37S ----------------------------
var grid = corridor.coveringGrid(ee.Projection('EPSG:32737'), CELL_M)
                   .filterBounds(corridor);
print('Number of grid cells:', grid.size());

// Mean NTL per cell for both periods
var stats = before.addBands(after).reduceRegions({
  collection: grid,
  reducer: ee.Reducer.mean(),
  scale: 463.83,
  tileScale: 4
});

// Add change, log-change (model response) and distance to road
var cells = stats.map(function (f) {
  var b = ee.Number(f.get('ntl_before'));
  var a = ee.Number(f.get('ntl_after'));
  return f.set({
    cell_id: f.id(),
    change:  a.subtract(b),
    delta:   a.add(1).log().subtract(b.add(1).log()),   // log1p(after) - log1p(before)
    lit:     a.max(b).gt(0),                            // 1 if lit in either period
    dist_m:  f.geometry().centroid(1).distance(road, 1)
  });
});

// ---------------- 5. MAP ---------------------------------------------
Map.centerObject(corridor, 9);
var ntlVis = {min: 0, max: 20, palette: ['black', 'purple', 'orange', 'yellow', 'white']};
Map.addLayer(before.clip(corridor), ntlVis, 'NTL before');
Map.addLayer(after.clip(corridor),  ntlVis, 'NTL after');
Map.addLayer(change.clip(corridor),
             {min: -5, max: 5, palette: ['blue', 'white', 'red']}, 'NTL change');
Map.addLayer(ee.Image().paint(corridor, 0, 2), {palette: 'cyan'}, 'Corridor (10 km)');
Map.addLayer(road, {color: 'lime'}, 'Road');

// ---------------- 6. EXPORTS (run them from the Tasks tab) -----------
var props = ['cell_id', 'ntl_before', 'ntl_after', 'change', 'delta', 'lit', 'dist_m'];

// Grid polygons for R (sf::st_read) - this is the modelling dataset
Export.table.toDrive({
  collection: cells.select(props),
  description: 'ntl_grid_1km',
  folder: DRIVE_FOLDER,
  fileFormat: 'SHP'
});

// Same table as CSV (no geometry)
Export.table.toDrive({
  collection: cells.select(props, null, false),
  description: 'ntl_grid_1km_csv',
  folder: DRIVE_FOLDER,
  fileFormat: 'CSV'
});

// Rasters for maps: before, after and change
Export.image.toDrive({
  image: before.addBands(after).addBands(change).clip(corridor).toFloat(),
  description: 'ntl_before_after_change',
  folder: DRIVE_FOLDER,
  region: corridor,
  scale: 463.83,
  crs: 'EPSG:32737',
  maxPixels: 1e9
});

// Corridor polygon
Export.table.toDrive({
  collection: ee.FeatureCollection([ee.Feature(corridor)]),
  description: 'corridor_10km_buffer',
  folder: DRIVE_FOLDER,
  fileFormat: 'SHP'
});

// Road line
Export.table.toDrive({
  collection: ee.FeatureCollection([ee.Feature(road)]),
  description: 'road_alignment',
  folder: DRIVE_FOLDER,
  fileFormat: 'SHP'
});
