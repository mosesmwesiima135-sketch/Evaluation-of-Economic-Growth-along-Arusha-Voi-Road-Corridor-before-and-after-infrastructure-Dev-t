# Methodology

This document gives the full method behind the results in the main [README](../README.md).

## 1. Study design

The study is a **before-and-after comparison** of nighttime light (NTL) inside a fixed corridor around the Arusha–Holili/Taveta–Voi road. NTL is used as a proxy for local economic activity.

| Design element | Choice | Reason |
|---|---|---|
| Corridor | 10 km each side of the road (20 km wide) | Captures the road, its towns and their immediate hinterland |
| Unit of analysis | 1 km grid cell (4,895 cells) | Close to the sensor's resolution after averaging about four pixels per cell |
| Coordinate system | UTM Zone 37S (EPSG:32737) | The whole road lies south of the equator, between about 36.7°E and 38.6°E |
| Before period | 2013 annual composite | Last full year before works began in February 2014 |
| After period | Mean of 2020 and 2021 annual composites | After the last section was completed in April 2019 |

## 2. Data extraction (Google Earth Engine)

Script: [`scripts/01_gee_extract_ntl.js`](../scripts/01_gee_extract_ntl.js)

1. The road is represented by a line through 12 towns: Arusha, Tengeru, Usa River, Boma Ng'ombe, Moshi, Himo, Holili, Taveta, Maktau, Bura, Mwatate and Voi.
2. The line is buffered by 10,000 m to form the corridor.
3. The `average_masked` band of `NOAA/VIIRS/DNB/ANNUAL_V21` is averaged over each period. In this band the background (non-light) is set to zero, and fires and other temporary lights have been filtered out by the data producer.
4. A 1 km grid is generated over the corridor with `coveringGrid()` in EPSG:32737.
5. The mean radiance of each cell is calculated for both periods with `reduceRegions()` at the native pixel size (463.83 m).
6. Each cell also receives its change, its log change (`delta`), a lit flag and its distance to the road line.
7. The grid (shapefile and CSV), a three-band raster (before, after, change) and the corridor polygon are exported to Google Drive.

The Earth Engine console confirmed 1 image in the before period (`20130101`), 2 images in the after period, and 4,895 grid cells.

## 3. Response variable

For each cell *i*:

```
delta_i = log(1 + NTL_after_i) - log(1 + NTL_before_i)
```

- The log scale stops a few very bright city cells from dominating the result.
- Adding 1 keeps unlit cells in the analysis. A cell that is dark in both periods has `delta = 0`.
- For small values, `delta` is close to the proportional change in (1 + NTL). The reported average change is `exp(b0) - 1`.

## 4. Spatial model

Script: [`scripts/02_bym2_model_tables_maps.R`](../scripts/02_bym2_model_tables_maps.R), Part A

```
delta_i = b0 + u_i + e_i,      e_i ~ Normal(0, 1/tau_e)
```

| Term | Meaning |
|---|---|
| `b0` | Average change across the corridor |
| `u_i` | BYM2 spatial random effect |
| `e_i` | Gaussian observation noise |

**BYM2.** The random effect is written as

```
u_i = (1 / sqrt(tau_u)) * ( sqrt(1 - phi) * v_i + sqrt(phi) * s_i )
```

where `s` is a scaled intrinsic CAR (spatially structured) component, `v` is an unstructured component, `tau_u` is the overall precision and `phi` (between 0 and 1) is the share of variance that is spatially structured (Riebler et al., 2016).

**Neighbours.** Queen contiguity on the 1 km grid, built with `spdep::poly2nb()` using a 5 m snap tolerance to close small gaps left by export and reprojection. Every cell has at least one neighbour and the grid forms a single connected component.

**Moran's I.** Before the model is fitted, a global Moran's I test (`spdep::moran.test()`, row-standardised weights, randomisation assumption) is run on `delta` as a model-free check for spatial clustering.

**Priors.** Penalised-complexity priors (Simpson et al., 2017):

- `tau_u`: P(standard deviation > 1) = 0.01
- `phi`: P(phi < 0.5) = 2/3

**Inference.** Integrated nested Laplace approximation with R-INLA (Rue et al., 2009), version 26.08.07 under R 4.6.1.

**Exceedance probabilities.** For each cell, `P(fitted change > 0)` is computed from the posterior marginal of the fitted value. Cells are classed as likely gain (P > 0.95), likely decline (P < 0.05) or no clear change.

## 5. Descriptive indicators

Script: [`scripts/02_bym2_model_tables_maps.R`](../scripts/02_bym2_model_tables_maps.R), Part B

These do not depend on the model:

- **Sum of lights:** the sum of cell-mean radiance over the corridor. Cells are equal in area, so this is proportional to total light.
- **Lit cells:** cells with mean `average_masked` radiance above zero.
- **Newly lit / went dark:** cells that changed between zero and non-zero radiance.
- **Road sections:** cells grouped by the longitude of their centre.

| Section | Longitude range | AfDB works in this phase |
|---|---|---|
| 1. Arusha – Usa River | west of 36.87°E | Sakina–Tengeru dualling; Arusha bypass |
| 2. Usa River – Moshi – Holili | 36.87°E to 37.65°E | None |
| 3. Taveta – Mwatate | 37.65°E to 38.38°E | Upgraded from gravel to bitumen; Taveta bypass |
| 4. Mwatate – Voi | east of 38.38°E | None (existing road) |

## 6. Model results and how to read them

**Moran's I.** The statistic is 0.790 against an expectation of about 0 under no spatial pattern, with a standard deviate of 107.7 (p < 0.001). Change in nighttime light is strongly positively autocorrelated.

**BYM2 model.**

| Parameter | Posterior mean | 95% interval |
|---|---|---|
| Average change in (1 + NTL), `exp(b0) - 1` | 8.55% | 8.53% to 8.56% |
| Precision of the Gaussian noise, `tau_e` | 61,310 | 21,690 to 135,700 |
| Precision of the random effect, `tau_u` | 21.21 | 20.39 to 22.08 |
| `phi` | 1.00 | 1.00 to 1.00 |

**What this shows**

- `phi` at 1 means the variation in change is entirely spatially structured. Change is clustered, not scattered at random, which agrees with Moran's I.
- The random-effect precision of 21.2 corresponds to a standard deviation of about 0.22 on the log scale.

**What needs care**

- The noise precision of about 61,000 corresponds to a noise standard deviation of about 0.004. The model therefore fits the observed `delta` values almost exactly, and performs very little smoothing.
- With a sum-to-zero constraint on the random effect and almost no noise, `b0` is pinned to the mean of the observed values. The narrow interval (8.53% to 8.56%) is a consequence of that. It is not a measure of how certain the road's effect is.
- The hotspot classes follow the sign of each cell's observed change closely. Counting by raw sign, 1,545 cells rose and 203 fell. The model classes 1,494 as likely gain and 175 as likely decline, so it moves only 79 cells with small changes into "no clear change".

The underlying cause is that the BYM2 unstructured component and the Gaussian noise term play overlapping roles when the likelihood is Gaussian, combined with a response that is exactly zero for about two thirds of the cells.

## Planned refinements

1. **Add a comparison group.** Extend the extraction to a band 10–30 km from the road and estimate a difference-in-differences effect (near versus far, before versus after). This is the step needed for any statement about attribution.
2. **Model lit cells separately.** Use a two-part (hurdle) model: one part for whether a cell is lit, one for the change in radiance where it is.
3. **Fix the noise term.** Replace the BYM2 with a purely structured (ICAR) effect plus Gaussian noise, or fix the noise precision from the sensor's known variability, so the structured effect smooths the data.
4. **Test distance decay.** Add distance to the road as a covariate to check whether gains fade away from the road. This needs the true alignment to be meaningful.
5. **Use the true road alignment.** Replace the 12-waypoint line with the OpenStreetMap centreline, including the Arusha bypass.
6. **Extend the after period.** Add 2022 onward from `NOAA/VIIRS/DNB/ANNUAL_V22` to reduce the weight of the 2020 pandemic year.
7. **Test the border.** Add a Kenya/Tanzania term using the official boundary, returning to the original question of why the Kenyan side gained more.

## References

- Riebler, A., Sørbye, S.H., Simpson, D. and Rue, H. (2016). An intuitive Bayesian spatial model for disease mapping that accounts for scaling. *Statistical Methods in Medical Research*, 25(4), 1145–1165.
- Rue, H., Martino, S. and Chopin, N. (2009). Approximate Bayesian inference for latent Gaussian models by using integrated nested Laplace approximations. *Journal of the Royal Statistical Society: Series B*, 71(2), 319–392.
- Simpson, D., Rue, H., Riebler, A., Martins, T.G. and Sørbye, S.H. (2017). Penalising model component complexity: a principled, practical approach to constructing priors. *Statistical Science*, 32(1), 1–28.
