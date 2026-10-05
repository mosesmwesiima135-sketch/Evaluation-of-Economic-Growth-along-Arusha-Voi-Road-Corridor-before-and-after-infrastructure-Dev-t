# =====================================================================
# 02  Monitoring economic activity growth along the road corridor
#     Arusha-Holili/Taveta-Voi road (AfDB-funded)
#
#     Bayesian spatial model of change (BYM2) in R-INLA, findings
#     tables and story maps.
#     Before = 2013 annual composite; After = mean of 2020-2021
#
# Run from the repository root (open the .Rproj file in RStudio).
# Packages are installed once with scripts/00_install_packages.R.
#
# Input : data/ntl_grid_1km.shp, data/corridor_10km_buffer.shp
# Output: outputs/tables/*.csv, outputs/figures/*.png,
#         outputs/model/ntl_grid_results.gpkg
# =====================================================================

# ---------------- 0. SETUP -------------------------------------------
library(ggplot2)
library(sf)
library(spdep)
library(INLA)

dir.create("outputs/tables",  recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/model",   recursive = TRUE, showWarnings = FALSE)

# =====================================================================
# PART A: DATA, NEIGHBOURS AND MODEL
# =====================================================================

# ---------------- 1. LOAD DATA ---------------------------------------
grid     <- st_read("data/ntl_grid_1km.shp")         |> st_transform(32737)
corridor <- st_read("data/corridor_10km_buffer.shp") |> st_transform(32737)

grid$id      <- seq_len(nrow(grid))
grid$delta   <- log1p(grid$ntl_after) - log1p(grid$ntl_before)   # model response
grid$dist_km <- grid$dist_m / 1000

cat("Cells:", nrow(grid), "\n")
cat("Cells lit in either period:", sum(grid$lit == 1), "\n")
summary(grid[, c("ntl_before", "ntl_after", "delta")] |> st_drop_geometry())

# ---------------- 2. NEIGHBOURS --------------------------------------
# snap = 5 m closes tiny gaps left by the export/reprojection
nb <- poly2nb(grid, queen = TRUE, snap = 5)
cat("Cells with no neighbours:", sum(card(nb) == 0), "\n")   # should be 0
cat("Connected components:", n.comp.nb(nb)$nc, "\n")         # should be 1

nb2INLA("outputs/model/grid.adj", nb)
g <- inla.read.graph("outputs/model/grid.adj")

# Model-free check: is the change spatially clustered?
print(moran.test(grid$delta, nb2listw(nb, style = "W", zero.policy = TRUE),
                 zero.policy = TRUE))

# ---------------- 3. MODEL 1: CHANGE = INTERCEPT + BYM2 --------------
# PC priors: P(sd > 1) = 0.01; P(phi < 0.5) = 2/3
hyper_bym2 <- list(
  prec = list(prior = "pc.prec", param = c(1, 0.01)),
  phi  = list(prior = "pc",      param = c(0.5, 2/3))
)

dat <- st_drop_geometry(grid)

fit1 <- inla(
  delta ~ 1 + f(id, model = "bym2", graph = g, scale.model = TRUE,
                hyper = hyper_bym2),
  family = "gaussian",
  data = dat,
  control.predictor = list(compute = TRUE),
  control.compute   = list(waic = TRUE, dic = TRUE,
                           return.marginals.predictor = TRUE)
)

cat("\n===== MODEL 1: average corridor change =====\n")
print(round(fit1$summary.fixed, 4))
print(round(fit1$summary.hyperpar, 4))


b0 <- fit1$summary.fixed["(Intercept)", c("mean", "0.025quant", "0.975quant")]
cat("\nAverage change in (1 + NTL), percent [95% CrI]:\n")
print(round((exp(unlist(b0)) - 1) * 100, 2))

# Fitted change and probability of a real gain / loss per cell
grid$fit_mean <- fit1$summary.fitted.values$mean
grid$p_gain   <- sapply(fit1$marginals.fitted.values,
                        function(m) 1 - inla.pmarginal(0, m))
grid$class <- cut(grid$p_gain, breaks = c(-Inf, 0.05, 0.95, Inf),
                  labels = c("Likely decline", "No clear change", "Likely gain"))
print(table(grid$class))

# =====================================================================
# PART B: FINDINGS TABLES AND STORY MAPS
# =====================================================================

# ---------------- 4. REFERENCE LAYERS --------------------------------
# Approximate road line (same waypoints used in Earth Engine)
road_xy <- rbind(c(36.683, -3.367), c(36.790, -3.372), c(36.857, -3.368),
                 c(37.130, -3.335), c(37.340, -3.350), c(37.553, -3.388),
                 c(37.630, -3.380), c(37.676, -3.398), c(38.130, -3.400),
                 c(38.300, -3.470), c(38.378, -3.503), c(38.567, -3.396))
road <- st_sfc(st_linestring(road_xy), crs = 4326) |> st_transform(32737)

towns <- data.frame(
  name = c("Arusha", "Moshi", "Holili / Taveta", "Maktau", "Mwatate", "Voi"),
  lon  = c(36.683, 37.340, 37.660, 38.130, 38.378, 38.567),
  lat  = c(-3.367, -3.350, -3.390, -3.400, -3.503, -3.396)
) |> st_as_sf(coords = c("lon", "lat"), crs = 4326) |> st_transform(32737)


# Road sections by longitude of each cell centre (approximate)
lon <- st_coordinates(st_transform(st_centroid(st_geometry(grid)), 4326))[, 1]
grid$section <- cut(lon, breaks = c(-Inf, 36.87, 37.65, 38.38, Inf),
                    labels = c("1. Arusha - Usa River (AfDB: dualling + bypass)",
                               "2. Usa River - Moshi - Holili (not upgraded in this phase)",
                               "3. Taveta - Mwatate (AfDB: upgraded to bitumen)",
                               "4. Mwatate - Voi (existing road)"))


# ---------------- 5. FINDINGS TABLES ---------------------------------
d    <- st_drop_geometry(grid)
pct  <- function(a, b) round((a - b) / b * 100, 1)
fx   <- fit1$summary.fixed["(Intercept)", ]
ci   <- round((exp(c(fx$mean, fx$`0.025quant`, fx$`0.975quant`)) - 1) * 100, 2)
hyp  <- fit1$summary.hyperpar

findings <- data.frame(
  Indicator = c(
    "Grid cells in corridor (1 km)",
    "Cells lit in either period",
    "Cells lit before (2013)",
    "Cells lit after (2020-21)",
    "Newly lit cells (dark in 2013, lit after)",
    "Cells that went dark (lit in 2013, dark after)",
    "Sum of lights before (nW/cm2/sr)",
    "Sum of lights after (nW/cm2/sr)",
    "Change in sum of lights (%)",
    "Mean radiance per cell, before",
    "Mean radiance per cell, after",
    "Model: average change in (1 + NTL), %",
    "Model: 95% credible interval, %",
    "Cells with likely gain (P > 0.95)",
    "Cells with no clear change",
    "Cells with likely decline (P < 0.05)",
    paste("Hyperparameter:", rownames(hyp))),
  Value = c(
    nrow(d),
    sum(d$lit == 1),
    sum(d$ntl_before > 0),
    sum(d$ntl_after > 0),
    sum(d$ntl_before == 0 & d$ntl_after > 0),
    sum(d$ntl_before > 0 & d$ntl_after == 0),
    round(sum(d$ntl_before), 1),
    round(sum(d$ntl_after), 1),
    pct(sum(d$ntl_after), sum(d$ntl_before)),
    round(mean(d$ntl_before), 3),
    round(mean(d$ntl_after), 3),
    ci[1],
    paste(ci[2], "to", ci[3]),
    sum(d$class == "Likely gain"),
    sum(d$class == "No clear change"),
    sum(d$class == "Likely decline"),
    paste0(signif(hyp$mean, 4), " (", signif(hyp$`0.025quant`, 4), " to ",
           signif(hyp$`0.975quant`, 4), ")"))
)


cat("\n================ TABLE 1: KEY FINDINGS ================\n")
print(findings, row.names = FALSE, right = FALSE)
write.csv(findings, "outputs/tables/table1_key_findings.csv", row.names = FALSE)

# Table 2: before vs after by road section
by_section <- do.call(rbind, lapply(split(d, d$section), function(s) data.frame(
  Section            = s$section[1],
  Cells              = nrow(s),
  Lit_before         = sum(s$ntl_before > 0),
  Lit_after          = sum(s$ntl_after > 0),
  Sum_lights_before  = round(sum(s$ntl_before), 1),
  Sum_lights_after   = round(sum(s$ntl_after), 1),
  Change_pct         = pct(sum(s$ntl_after), sum(s$ntl_before)),
  Gain_cells         = sum(s$class == "Likely gain"),
  Decline_cells      = sum(s$class == "Likely decline"))))

cat("\n================ TABLE 2: BY ROAD SECTION ================\n")
print(by_section, row.names = FALSE, right = FALSE)
write.csv(by_section, "outputs/tables/table2_by_road_section.csv", row.names = FALSE)

# ---------------- 6. MAP STYLES --------------------------------------
night_theme <- theme_void(base_size = 11) +
  theme(plot.background   = element_rect(fill = "black", colour = NA),
        panel.background  = element_rect(fill = "black", colour = NA),
        text              = element_text(colour = "white"),
        plot.title        = element_text(face = "bold", size = 14, hjust = 0,
                                         margin = margin(8, 0, 2, 8)),
        plot.subtitle     = element_text(size = 9.5, colour = "grey80", hjust = 0,
                                         margin = margin(0, 0, 6, 8)),
        plot.caption      = element_text(size = 7.5, colour = "grey60",
                                         margin = margin(4, 8, 6, 0)),
        strip.text        = element_text(colour = "white", face = "bold", size = 11,
                                         hjust = 0, margin = margin(6, 0, 3, 8)),
        legend.position   = "bottom",
        legend.title      = element_text(size = 9),
        legend.key.width  = unit(1.6, "cm"),
        legend.key.height = unit(0.3, "cm"))

day_theme <- theme_void(base_size = 11) +
  theme(plot.background  = element_rect(fill = "white", colour = NA),
        plot.title       = element_text(face = "bold", size = 14,
                                        margin = margin(8, 0, 2, 8)),
        plot.subtitle    = element_text(size = 9.5, colour = "grey30",
                                        margin = margin(0, 0, 6, 8)),
        plot.caption     = element_text(size = 7.5, colour = "grey45",
                                        margin = margin(4, 8, 6, 0)),
        legend.position  = "bottom",
        legend.key.width = unit(1.6, "cm"),
        legend.key.height = unit(0.3, "cm"))

src <- "Data: VIIRS annual nighttime lights V2.1 (average_masked). 1 km grid, 10 km buffer each side. Road line approximate."

context <- function(label_col, line_col) list(
  geom_sf(data = corridor, fill = NA, colour = line_col, linewidth = 0.25),
  geom_sf(data = road, colour = line_col, linewidth = 0.3, linetype = "dashed"),
  geom_sf_text(data = towns, aes(label = name), colour = label_col,
               size = 3.1, fontface = "bold", nudge_y = 14500)
)

# ---------------- 7a. MAP 1: BEFORE vs AFTER (same colour scale) -----
g_before <- grid["ntl_before"]; names(g_before)[1] <- "ntl"
g_after  <- grid["ntl_after"];  names(g_after)[1]  <- "ntl"
g_before$period <- "BEFORE construction: 2013"
g_after$period  <- "AFTER construction: 2020-21"
long <- rbind(g_before, g_after)
long$period <- factor(long$period, levels = c("BEFORE construction: 2013",
                                              "AFTER construction: 2020-21"))
top <- ceiling(max(long$ntl))


m1 <- ggplot(long) +
  geom_sf(aes(fill = ntl), colour = NA) +
  context("white", "grey70") +
  facet_wrap(~period, ncol = 1) +
  scale_fill_viridis_c(option = "inferno", trans = "log1p", limits = c(0, top),
                       breaks = c(0, 1, 3, 10, 30, 100)[c(0, 1, 3, 10, 30, 100) <= top],
                       name = "Radiance (nW/cm\u00b2/sr)") +
  labs(title = "Nighttime lights along the Arusha - Holili/Taveta - Voi road",
       subtitle = "Brighter = more light, a proxy for economic activity. Both panels use the same colour scale.",
       caption = src) +
  night_theme
ggsave("outputs/figures/story1_before_after.png", m1, width = 12, height = 6.2, dpi = 300, bg = "black")


# ---------------- 7b. MAP 2: WHERE DID LIGHT CHANGE? -----------------
lim <- 5
m2 <- ggplot(grid) +
  geom_sf(aes(fill = change), colour = NA) +
  context("grey15", "grey35") +
  scale_fill_gradient2(low = "#2166AC", mid = "grey96", high = "#B2182B", midpoint = 0,
                       limits = c(-lim, lim), oob = scales::squish,
                       breaks = c(-lim, -2.5, 0, 2.5, lim),
                       labels = c(paste0("\u2264 -", lim), "-2.5", "0", "+2.5", paste0("\u2265 +", lim)),
                       name = "Change in radiance, 2013 to 2020-21") +
  labs(title = "Where light increased and decreased",
       subtitle = "Red = brighter after construction; blue = dimmer; pale grey = little or no change.",
       caption = src) +
  day_theme

ggsave("outputs/figures/story2_change.png", m2, width = 12, height = 3.8, dpi = 300, bg = "white")


# ---------------- 7c. MAP 3: MODEL HOTSPOTS --------------------------
m3 <- ggplot(grid) +
  geom_sf(aes(fill = class), colour = NA) +
  context("grey15", "grey35") +
  scale_fill_manual(values = c("Likely decline"  = "#2166AC",
                               "No clear change" = "grey90",
                               "Likely gain"     = "#B2182B"),
                    name = NULL, drop = FALSE) +
  labs(title = "Hotspots of gain and decline (BYM2 model)",
       subtitle = "Cells where the probability of a real increase is above 95% (gain) or below 5% (decline).",
       caption = src) +
  day_theme

ggsave("outputs/figures/story3_hotspots.png", m3, width = 12, height = 3.8, dpi = 300, bg = "white")

# ---------------- 7d. MAP 4: NEWLY LIT AREAS -------------------------
grid$status <- factor(
  ifelse(grid$ntl_before == 0 & grid$ntl_after == 0, "Dark in both periods",
         ifelse(grid$ntl_before == 0 & grid$ntl_after >  0, "Newly lit after construction",
                ifelse(grid$ntl_before >  0 & grid$ntl_after == 0, "Went dark", "Lit in both periods"))),
  levels = c("Dark in both periods", "Lit in both periods",
             "Newly lit after construction", "Went dark"))

m4 <- ggplot(grid) +
  geom_sf(aes(fill = status), colour = NA) +
  context("white", "grey70") +
  scale_fill_manual(values = c("Dark in both periods"         = "grey12",
                               "Lit in both periods"          = "#FDB863",
                               "Newly lit after construction" = "#00E5FF",
                               "Went dark"                    = "#D7301F"),
                    name = NULL, drop = FALSE) +
  labs(title = "Where new light appeared",
       subtitle = "Cyan cells had no detectable light in 2013 and were lit by 2020-21.",
       caption = src) +
  night_theme

ggsave("outputs/figures/story4_newly_lit.png", m4, width = 12, height = 3.8, dpi = 300, bg = "black")

print(m1); print(m2); print(m3); print(m4)
cat("\nSaved 2 tables to outputs/tables/ and 4 maps to outputs/figures/.\n")

# ---------------- 8. SAVE CELL-LEVEL RESULTS -------------------------
# One row per grid cell with the fitted change, probability of gain,
# hotspot class, road section and lit status (opens in QGIS).
out <- grid
out$class   <- as.character(out$class)
out$section <- as.character(out$section)
out$status  <- as.character(out$status)
st_write(out, "outputs/model/ntl_grid_results.gpkg", delete_dsn = TRUE, quiet = TRUE)
cat("Saved cell-level results to outputs/model/ntl_grid_results.gpkg\n")
