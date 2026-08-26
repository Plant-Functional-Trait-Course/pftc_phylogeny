## Phylogeny functions
##
## Pipeline: community taxa -> normalized names -> TNRS resolution ->
## rtrees-ready tip labels -> grafted phylogeny.
##
## Names arrive from six regional cleaners in inconsistent case (China and Peru
## lowercase theirs, the others do not) and at mixed rank. Every name is
## normalized to a single form here, before any taxonomic resolution, so that
## "poa alpina" and "Poa alpina" resolve once rather than twice.
##
## Three ranks survive normalization, because the source data records all three:
##   species  "Poa alpina"              -> tip Poa_alpina
##   genus    "Erigeron", "Carex sp7"   -> tip Erigeron_sp, Carex_sp7
##   family   "Asteraceae sp1"          -> tip Asteraceae_sp1, grafted at family
## Morphospecies numbers are preserved: Carex sp7 and Carex sp8 are different
## taxa and must not collapse onto one tip.


#' Entries that are not vascular plant taxa.
#'
#' Regional recorders use these as cover classes rather than species. Matched
#' case-insensitively against the whole normalized name.
non_taxon_patterns <- c(
  "^unknown", "^unidentified", "^bare", "^litter", "^rock", "^soil", "^dead",
  "^moss", "^bryophyte", "^lichen", "^fungi", "^algae", "^total ", "^sum ",
  "^no id"
)


#' Family names that do not end in `-aceae`.
#'
#' The conserved alternatives still current in older floras.
legacy_family_names <- c(
  "Compositae", "Gramineae", "Leguminosae", "Umbelliferae", "Labiatae",
  "Cruciferae", "Palmae", "Guttiferae"
)


#' Normalize a raw taxon string to a single comparable form.
#'
#' Trims and collapses whitespace, drops qualifiers (`cf.`, `aff.`, hybrid signs,
#' parenthetical authorities), standardizes the many spellings of the
#' morphospecies placeholder (`sp.`, `spp`, `sp. 7`, `SP7`) to a bare `sp` with
#' any number kept, supplies a missing placeholder for names recorded as a bare
#' genus, and applies sentence case.
#'
#' @param x Character vector of raw taxon names.
#' @return Character vector, same length; `NA` for blank input.
normalize_taxon_names <- function(x) {
  out <- x |>
    str_squish() |>
    str_remove_all("\\((.*?)\\)") |>
    str_remove_all(regex("\\b(cf|aff)\\b\\.?", ignore_case = TRUE)) |>
    str_replace_all("\\s[^A-Za-z0-9]+(\\s|$)", " ") |>
    str_remove_all("[×✕]") |>
    str_squish() |>
    # "sp.", "spp", "sp. 7", "sp7" -> "sp" / "sp7"; the number identifies the
    # morphospecies and is kept.
    str_replace(regex("\\b(?:sp|spp)\\.?\\s*(\\d*)$", ignore_case = TRUE), "sp\\1") |>
    str_squish() |>
    str_to_sentence()

  # A single remaining word is a genus (or family) recorded with no epithet at
  # all; give it the placeholder so it takes the genus/family path downstream.
  out <- if_else(str_detect(out, "^[A-Za-z]+$"), str_c(out, " sp"), out)

  na_if(out, "")
}


#' Rank a normalized name: `species`, `genus`, or `family`.
#'
#' @param x Normalized names from [normalize_taxon_names()].
#' @return Character vector of ranks.
taxon_rank <- function(x) {
  first <- word(x, 1)
  placeholder <- str_detect(x, regex("\\ssp\\d*$"))
  is_family <- placeholder &
    (str_detect(first, regex("aceae$", ignore_case = TRUE)) | first %in% legacy_family_names)

  case_when(
    is_family ~ "family",
    placeholder ~ "genus",
    TRUE ~ "species"
  )
}


#' Distinct taxon list for the pooled community data.
#'
#' One row per normalized name, carrying the raw spellings it came from and the
#' countries it was recorded in so unresolved names can be traced back.
#'
#' @param community Merged community data with `country`, `taxon`.
#' @return Tibble: `taxon_normalized`, `rank`, `raw_taxa`, `countries`, `n_records`.
build_species_list <- function(community) {
  community |>
    mutate(taxon_normalized = normalize_taxon_names(taxon)) |>
    filter(
      !is.na(taxon_normalized),
      !str_detect(taxon_normalized, regex(str_c(non_taxon_patterns, collapse = "|"), ignore_case = TRUE))
    ) |>
    group_by(taxon_normalized) |>
    summarise(
      raw_taxa = str_c(sort(unique(taxon)), collapse = " | "),
      countries = str_c(sort(unique(country)), collapse = ","),
      n_records = n(),
      .groups = "drop"
    ) |>
    mutate(rank = taxon_rank(taxon_normalized)) |>
    arrange(taxon_normalized)
}


#' Resolve the species list against WCVP/WFO with TNRS.
#'
#' Genus- and family-level names are submitted as the bare genus or family, since
#' TNRS cannot match an `sp7` placeholder; the placeholder is restored downstream
#' by [build_taxon_table()].
#'
#' @param species_list Output of [build_species_list()].
#' @param sources TNRS source databases, in priority order.
#' @return The raw TNRS result joined to the submitted names.
resolve_taxonomy <- function(species_list, sources = c("wcvp", "wfo")) {
  query <- species_list |>
    mutate(
      submitted = if_else(rank == "species", taxon_normalized, word(taxon_normalized, 1)),
      id = as.character(row_number())
    )

  resolved <- TNRS::TNRS(
    taxonomic_names = query |> select(id, submitted),
    sources = sources,
    classification = "wfo",
    mode = "resolve"
  ) |>
    as_tibble() |>
    clean_names() |>
    mutate(id = as.character(id)) |>
    # TNRS de-duplicates its input: when several ids submit the same name it
    # returns ONE row whose id is the comma-collapsed list ("2,1"). Expand that
    # back to one row per submitted id, or every repeated submission -- which is
    # every genus shared by more than one morphospecies -- joins to NA.
    separate_longer_delim(id, delim = ",") |>
    mutate(id = str_trim(id))

  query |>
    left_join(resolved, by = "id") |>
    select(-id)
}


#' Build the raw-name -> tip-label lookup used by the tree and the community data.
#'
#' Accepts a TNRS species match when `overall_score` clears `min_score`;
#' otherwise falls back to the normalized name so the record is not silently
#' lost. Tip labels use the `Genus_species` convention rtrees expects, with
#' genus- and family-level taxa keeping their morphospecies suffix
#' (`Carex_sp7`, `Asteraceae_sp1`).
#'
#' @param taxonomy Output of [resolve_taxonomy()].
#' @param min_score Minimum TNRS overall score to accept a species match.
#' @return Tibble with one row per `taxon_normalized`, including `tip_label`,
#'   `genus`, `family`, and a `match_status` of `accepted`, `genus_only`,
#'   `family_only`, or `unresolved`.
build_taxon_table <- function(taxonomy, min_score = 0.8) {
  taxonomy |>
    mutate(
      matched = !is.na(accepted_species) & accepted_species != "" &
        coalesce(overall_score, 0) >= min_score,
      # The trailing placeholder, e.g. "sp7", kept verbatim for genus/family ranks.
      placeholder = str_extract(taxon_normalized, regex("sp\\d*$")),
      accepted_sp = if_else(matched, str_squish(accepted_species), taxon_normalized),
      family = coalesce(na_if(accepted_family, ""), NA_character_),
      genus = case_when(
        rank == "family" ~ NA_character_,
        rank == "genus" ~ coalesce(na_if(accepted_name, ""), submitted),
        TRUE ~ word(accepted_sp, 1)
      ),
      genus = str_squish(genus),
      # A family-level morphospecies has no genus; fall back to the family name
      # so rtrees grafts it at the family node.
      family = case_when(
        rank == "family" ~ coalesce(family, word(taxon_normalized, 1)),
        TRUE ~ family
      ),
      tip_label = case_when(
        rank == "family" ~ str_c(word(taxon_normalized, 1), placeholder, sep = "_"),
        rank == "genus" ~ str_c(genus, placeholder, sep = "_"),
        matched ~ str_c(word(accepted_sp, 1), word(accepted_sp, 2), sep = "_"),
        TRUE ~ str_replace_all(taxon_normalized, "\\s+", "_")
      ),
      match_status = case_when(
        rank == "family" ~ "family_only",
        rank == "genus" ~ "genus_only",
        matched ~ "accepted",
        TRUE ~ "unresolved"
      )
    ) |>
    select(
      taxon_normalized, rank, raw_taxa, countries, n_records,
      tip_label, accepted = accepted_sp, genus, family, match_status,
      tnrs_score = overall_score, tnrs_matched_name = name_matched
    ) |>
    arrange(taxon_normalized)
}


#' Graft the species list onto the plant megatree with rtrees.
#'
#' Species absent from the backbone are grafted below the basal node of their
#' genus (or family, when the genus is absent too) at a random position.
#' Placement is random, so the function is called `n_tree` times to produce a
#' posterior-style set of replicate trees; downstream phylogenetic metrics should
#' be computed on each replicate and summarized, rather than on a single tree.
#'
#' `scenario = "at_basal_node"` is deterministic, so `n_tree` is ignored there.
#'
#' @param taxon_table Output of [build_taxon_table()].
#' @param scenario rtrees grafting scenario.
#' @param n_tree Number of replicate graftings.
#' @param seed RNG seed, so the replicate set is reproducible.
#' @return A `multiPhylo` of length `n_tree` (or 1), tips labelled with
#'   `tip_label` values. Tip sets are identical across replicates; only the
#'   placement of grafted species differs.
build_phylogeny <- function(taxon_table,
                            scenario = "random_below_basal",
                            n_tree = 100,
                            seed = 1) {
  sp_list <- taxon_table |>
    distinct(tip_label, genus, family) |>
    filter(!is.na(tip_label), !is.na(genus) | !is.na(family)) |>
    transmute(
      species = tip_label,
      genus = coalesce(genus, word(tip_label, 1, sep = fixed("_"))),
      family = coalesce(family, "")
    ) |>
    as.data.frame()

  # rtrees carries its own genus -> family classification. Use it to fill
  # families TNRS did not supply (recently erected genera, mostly) so those taxa
  # graft at the family node instead of being dropped from the tree.
  needs_family <- sp_list$family == "" | is.na(sp_list$family)
  if (any(needs_family)) {
    lookup <- rtrees::sp_list_df(sp_list$species[needs_family], taxon = "plant")
    lookup <- lookup[!is.na(lookup$family), ]
    lookup <- lookup[!duplicated(lookup$species), ]
    hit <- match(sp_list$species, lookup$species)
    fill <- needs_family & !is.na(hit)
    sp_list$family[fill] <- lookup$family[hit[fill]]
  }

  if (identical(scenario, "at_basal_node")) {
    n_tree <- 1L
  }

  set.seed(seed)
  trees <- lapply(seq_len(n_tree), function(i) {
    rtrees::get_tree(
      sp_list = sp_list,
      taxon = "plant",
      scenario = scenario,
      show_grafted = FALSE,
      # 100 replicates would otherwise emit 100 progress bars into the log.
      .progress = "none"
    )
  })

  class(trees) <- "multiPhylo"
  trees
}


#' Tip labels shared by every replicate tree.
#'
#' @param phylogeny A `phylo` or `multiPhylo`.
#' @return Character vector of tip labels.
phylogeny_tip_labels <- function(phylogeny) {
  if (inherits(phylogeny, "multiPhylo")) {
    phylogeny[[1]]$tip.label
  } else {
    phylogeny$tip.label
  }
}


#' Attach harmonized tip labels to the community data.
#'
#' Drops records whose taxon did not make it onto the tree (non-taxon cover
#' classes, unresolvable names with no usable genus), then collapses each plot to
#' one row per tip. The collapse matters: two raw names that TNRS resolves to the
#' same accepted species (synonyms, or the same species spelled differently in
#' two regions) would otherwise appear twice in one plot and both double-count
#' cover and break any later `pivot_wider` into a site-by-species matrix.
#'
#' @param community Merged community data.
#' @param taxon_table Output of [build_taxon_table()].
#' @param phylogeny Output of [build_phylogeny()]; `phylo` or `multiPhylo`.
#' @return One row per plot, year and tip: `community` plus `tip_label`,
#'   `family_accepted`, `match_status`, and `taxa_merged` (the raw names that
#'   collapsed into that tip), restricted to taxa present in `phylogeny`.
attach_tip_labels <- function(community, taxon_table, phylogeny) {
  community |>
    mutate(taxon_normalized = normalize_taxon_names(taxon)) |>
    left_join(
      taxon_table |>
        select(taxon_normalized, tip_label, family_accepted = family, match_status),
      by = "taxon_normalized"
    ) |>
    filter(tip_label %in% phylogeny_tip_labels(phylogeny)) |>
    # `year` is part of the key: Peru resurveys the same plots in 2018-2020, and
    # collapsing across years would sum cover over repeat visits.
    group_by(country, gradient, site, plot_id, year, tip_label) |>
    summarise(
      cover = sum(cover, na.rm = TRUE),
      taxa_merged = str_c(sort(unique(taxon)), collapse = " | "),
      across(!c(taxon, taxon_normalized, cover), first),
      .groups = "drop"
    )
}
