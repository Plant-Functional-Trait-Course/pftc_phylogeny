#!/usr/bin/env Rscript

# This is a helper script to run the pipeline.
# Choose how to execute the pipeline below.
# See https://books.ropensci.org/targets/hpc.html
# to learn about your options.
source("load_libraries.R")
library(targets)

targets::tar_make()

# run only one target
# targets::tar_delete(community)
# targets::tar_make(community)

# refresh TNRS taxonomy (after setting refresh_taxonomy <- TRUE in R/phylogeny_plan.R)
# targets::tar_invalidate(taxonomy)
# targets::tar_make(names = "taxonomy")

tar_load_everything()

