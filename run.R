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

tar_load_everything()

