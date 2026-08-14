# Gradient Traits: Community and Functional Diversity Across Elevational Gradients

This repository contains the code and data pipeline for analyzing plant community assemblage and functional diversity across elevational gradients, spanning ecosystems from the tropics to the arctic. The project leverages the [`targets`](https://docs.ropensci.org/targets/) R package for reproducible workflows.

## Project Overview

We assess plant species diversity (Shannon diversity and sum of cover; richness and evenness are omitted because plot sizes differ across studies) and functional diversity (community weighted means and variance in leaf functional traits) along five elevational gradients in the following ecosystems/countries:

- **Arctic:** Svalbard (PFTC4)
- **Boreal:** Norway (PFTC6)
- **Temperate:** Colorado (RMBL)
- **Sub-tropics:** China (PFTC1 & 2)
- **Tropics:** Peru (PFTC3, Puna, PFTC5)

The main research questions are:
- How do plant communities respond to environmental drivers along elevational gradients in terms of species and functional diversity?
- How consistent are these patterns across a broad latitudinal gradient from the tropics to the arctic?

## Data

The pipeline downloads, imports, cleans, and analyzes data from multiple sources and ecosystems, including:
- Community composition
- Functional leaf traits
- Climate data (hourly climate extract, summarised to growing-season variables)

## Pipeline Structure

The analysis is organized using the `targets` package, with plans for:
- **Download:** Automated retrieval of raw data files
- **Import:** Reading and initial formatting of data
- **Cleaning:** Standardizing and filtering datasets
- **Transformation:** Merging, calculating diversity indices, trait imputation, and bootstrapping
- **Analysis:** Statistical modeling and visualization

Custom functions for cleaning and processing are located in `R/Functions/`.

## Getting Started

### Prerequisites

- R (>= 4.0)
- R packages: `targets`, `tarchetypes`, `tidyverse`, `dataDownloader`, `DBI`, `RSQLite`, `janitor`, `vegan`, `ggvegan`, `traitstrap`, `dataDocumentation`, `readxl`, `broom`, `glue`, and others as specified in `_targets.R`.

### Running the Pipeline

1. **Install dependencies** (in R):
   ```r
   install.packages(c("targets", "tarchetypes", "tidyverse", "dataDownloader", "DBI", "RSQLite", "janitor", "vegan", "ggvegan", "traitstrap", "dataDocumentation", "readxl", "broom", "glue"))
   ```

2. **Run the pipeline** (from the project root):
   ```r
   source("run.R")
   ```
   Or, in the shell:
   ```sh
   Rscript run.R
   ```

3. **Inspect results**:
   - Main results and figures are generated in `results.qmd` and `results_files/`.

## Project Structure

```
gradient_traits/
├── _targets.R           # Main targets pipeline definition
├── run.R                # Script to run the pipeline
├── R/                   # R scripts for plans and functions
│   ├── Functions/       # Custom function scripts
│   └── ...              # Plan scripts (analysis, cleaning, etc.)
├── data/                # Raw and processed data (mostly gitignored)
├── results_files/       # Output files (gitignored)
├── results.qmd          # Quarto/Markdown results document
└── ...                  # Other supporting files
```

## Reproducibility

- The pipeline is fully reproducible using the `targets` workflow.
- Data files are managed via automated download scripts.
- Intermediate and final results are cached for efficiency.

## References

- Maitner, B. S., et al. (2023). traitstrap: An R package for trait imputation and bootstrapping.
- [targets package documentation](https://docs.ropensci.org/targets/) 