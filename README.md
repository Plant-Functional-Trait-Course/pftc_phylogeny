# Phylogenetic Structure of Plant Communities Along Elevational Gradients: Context-Dependent Patterns from a Global Mountain Network

This repository contains the code and data pipeline for analyzing phylogenetic structure of plant communitites along elevational gradients. The project leverages the [`targets`](https://docs.ropensci.org/targets/) R package for reproducible workflows.

## Abstract

Phylogenetic structure of communities helps to improve our understanding of biodiversity maintenance by providing insights about how species respond to constraining and changing conditions . Mountain gradients provide a great opportunity to study community assembly processes as they act as environmental filters, shifting from benign to increasingly stressful within relatively short distances. Because tolerance to harsh conditions is often phylogenetically conserved, the phylogenetic structure of communities is expected to change from overdispersed to clustered with increasing elevations. However, other biotic and abiotic pressures might change the expected patterns of the stress gradient model. 

In this study, we asked how community phylogenetic structure changed along elevational gradients, and how this relationship varied with fire history and topography. Across eight field campaigns in South America, North America, Europe, Asia, and Africa, we measured community compositional changes along elevational gradients that collectively span from 0 to 5000 m a.s.l., although each individual gradient covers a narrower range. We quantified community phylogenetic structure using abundance weighted and non-abundance-weighted mean phylogenetic distance and mean nearest taxon distance (MNTD), as well as phylogenetic beta diversity. We then tested multiple predictors to identify which best predicted community phylogenetic structure, and whether “harsher” environmental conditions resulted in the hypothesized increase in clustering due to filtering.

We find that the relationships between phylogenetic structure and elevation were highly heterogeneous, with different gradients showing responses that differed in slope, magnitude, and shape (unimodal vs linear). Site identity explained a large portion of beta-MNTD variation, underscoring that the evolutionary distance between regional floras far exceeds any within-mountain gradient effect. The interaction between fire regime and elevation was consistent with a post-disturbance weakening of environmental filtering: fire reset community composition and resulted in a less
taxonomically-filtered set of species. When comparing topographic effects, we found that aspect structures community phylogenetic structure above and beyond elevation.

Our results suggest that community phylogenetic assembly varies strongly with elevation, but this relationship is not uniform and instead modulated by additional biotic and abiotic factors. Together, these dynamics highlight how the interplay between evolutionary history and ecological processes shapes biodiversity patterns across elevational gradients. 


## Data

The pipeline downloads, imports, cleans, and analyzes data from multiple sources and ecosystems, including:
- Community composition
- Climate data (downscaled extract, summarised per plot)

Most inputs download automatically from OSF. Two are supplied manually and are
not downloaded by the pipeline:

| File | Used by | Notes |
|---|---|---|
| `data/metaCH.csv` | `download_meta_ch` | China site metadata; tracked in git |
| `data/downscaled_climate.csv` | `download_climate` | Downscaled climate extract; **not** in the repo, must be placed by hand |

## Pipeline Structure

The analysis is organized using the `targets` package, with plans for:
- **Download:** Automated retrieval of raw data files
- **Import:** Reading and initial formatting of data
- **Cleaning:** Standardizing and filtering datasets
- **Transformation:** Merging community data and joining downscaled climate
- **Phylogeny:** Taxonomic harmonization (TNRS, against WCVP/WFO) and grafting the
  pooled species list onto the GBOTB megatree with `rtrees`
- **Diversity:** Phylogenetic diversity indices (MPD, MNTD, beta-MNTD)
- **Analysis:** Statistical modeling and visualization

Custom functions for cleaning and processing are located in `R/Functions/`.

## Getting Started

### Prerequisites

- R (>= 4.0)
- R packages: `targets`, `tarchetypes`, `dataDownloader`, `tidyverse`, `DBI`, `RSQLite`, `janitor`, `vegan`, `ggvegan`, `readxl`, `broom`, `broom.mixed`, `glue`, `geodata`, `terra`, `MetBrewer`, `maps`, `performance`, `quarto`, `see`, `rgee`, `sf`, `lmerTest`, `gt`, `ggridges`, `patchwork`, `betapart`, `plotbiomes`, `ape`, `picante`, `TNRS`, and `rtrees` (as specified in `_targets.R`).

### Running the Pipeline

1. **Install dependencies** (in R):
   The project uses [`renv`](https://rstudio.github.io/renv/). From a fresh
   clone, restore the recorded library rather than installing by hand:

   ```r
   renv::restore()
   ```

   `.Rprofile` sources `renv/activate.R`, so starting R from the project root will
   automatically activate the project environment (and may bootstrap `renv` if needed).

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
pftc_phylogeny/
├── _targets.R           # Main targets pipeline definition
├── run.R                # Script to run the pipeline
├── R/                   # R scripts for plans and functions
│   ├── functions/       # Custom function scripts
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