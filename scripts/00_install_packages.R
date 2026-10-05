# =====================================================================
# 00  One-time package installation
# =====================================================================
# sf, terra and INLA are large downloads. R's default 60-second limit
# is often too short, so raise it first.
options(timeout = 1200)

install.packages(c("sf", "spdep", "ggplot2", "terra"))

install.packages("INLA",
  repos = c(getOption("repos"),
            INLA = "https://inla.r-inla-download.org/R/stable"),
  dep = TRUE)

# Check that everything loads
library(sf); library(spdep); library(ggplot2); library(INLA)
