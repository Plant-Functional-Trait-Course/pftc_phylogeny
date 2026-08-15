#!/usr/bin/env Rscript

# This is a helper script to run the pipeline.
# Choose how to execute the pipeline below.
# See https://books.ropensci.org/targets/hpc.html
# to learn about your options.
source("load_libraries.R")
library(targets)

targets::tar_make()

# run only one target
# targets::tar_delete(growing_season_climate)
# targets::tar_make(growing_season_climate)

tar_load_everything()


# output
tar_load(regions_world_map)
ggsave("figures/regions_world_map.png", regions_world_map, width = 10, height = 6)
tar_load(climate_seasonality_fig)
ggsave("figures/climate_seasonality_fig.png", climate_seasonality_fig, width = 10, height = 6)
