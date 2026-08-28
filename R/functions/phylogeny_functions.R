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
#' One row per normalized name AND country, carrying the raw spellings it came
#' from so unresolved names can be traced back. The country is part of the key
#' because partially identified taxa are region-specific: an unidentified
#' `Carex sp` in China is not the same taxon as an unidentified `Carex sp` in
#' Colorado, and [build_taxon_table()] gives them separate tips.
#'
#' @param community Merged community data with `country`, `taxon`.
#' @return Tibble: `taxon_normalized`, `country`, `rank`, `raw_taxa`, `n_records`.
build_species_list <- function(community) {
  community |>
    mutate(taxon_normalized = normalize_taxon_names(taxon)) |>
    filter(
      !is.na(taxon_normalized),
      !str_detect(taxon_normalized, regex(str_c(non_taxon_patterns, collapse = "|"), ignore_case = TRUE))
    ) |>
    group_by(taxon_normalized, country) |>
    summarise(
      raw_taxa = str_c(sort(unique(taxon)), collapse = " | "),
      n_records = n(),
      .groups = "drop"
    ) |>
    mutate(rank = taxon_rank(taxon_normalized)) |>
    arrange(taxon_normalized, country)
}


#' Names to send to TNRS, as a plain sorted character vector.
#'
#' This is deliberately the *only* thing the `taxonomy` target depends on.
#' `species_list` also carries `country`, `raw_taxa` and `n_records`, all of
#' which change whenever the community data changes; hanging the TNRS call off
#' it would re-query the API for edits that cannot possibly change a name.
#' Reducing to the distinct name set means the resolution step re-runs only when
#' the names themselves change.
#'
#' Genus- and family-level taxa submit the bare genus or family, since TNRS
#' cannot match an `sp7` placeholder.
#'
#' @param species_list Output of [build_species_list()].
#' @return Sorted character vector of distinct names.
taxon_names_to_resolve <- function(species_list) {
  species_list |>
    mutate(submitted = if_else(rank == "species", taxon_normalized, word(taxon_normalized, 1))) |>
    pull(submitted) |>
    unique() |>
    sort()
}


#' Columns kept from a TNRS response, with their types.
#'
#' Pinning an explicit subset keeps the cache readable and, more importantly,
#' keeps its column types stable: a full 51-column TNRS frame written to CSV and
#' read back changes type on 15 columns, so a cache hit and a cache miss would
#' otherwise hand downstream code differently-typed objects.
tnrs_cache_cols <- readr::cols(
  submitted = readr::col_character(),
  name_matched = readr::col_character(),
  accepted_name = readr::col_character(),
  accepted_species = readr::col_character(),
  accepted_family = readr::col_character(),
  overall_score = readr::col_double()
)


#' Resolve a vector of names against WCVP/WFO with TNRS.
#'
#' @param names Character vector of names, from [taxon_names_to_resolve()].
#' @param sources TNRS source databases, in priority order.
#' @return Tibble with one row per name TNRS answered for, columns as in
#'   [tnrs_cache_cols]. Names the API did not answer for are absent rather than
#'   present-and-empty, so callers can tell "not resolved" from "not asked".
resolve_taxonomy <- function(names, sources = c("wcvp", "wfo")) {
  names <- unique(names[!is.na(names) & nzchar(names)])
  if (length(names) == 0) {
    return(tibble(!!!setNames(
      list(character(), character(), character(), character(), character(), double()),
      names(tnrs_cache_cols$cols)
    )))
  }

  query <- tibble(id = as.character(seq_along(names)), submitted = names)

  resolved_raw <- TNRS::TNRS(
    taxonomic_names = as.data.frame(query),
    sources = sources,
    classification = "wfo",
    mode = "resolve"
  )

  if (is.null(resolved_raw) || !is.data.frame(resolved_raw) || nrow(resolved_raw) == 0) {
    stop(
      "TNRS name resolution failed: the API returned no results. ",
      "Community and species_list completed successfully; only the external ",
      "taxonomy lookup failed. This usually means a temporary TNRS outage or a ",
      "network/curl problem (see TNRS package README). Try again later or check ",
      "https://tnrs.biendata.org/."
    )
  }

  resolved <- resolved_raw |>
    as_tibble() |>
    clean_names()

  if (!"id" %in% names(resolved)) {
    stop(
      "TNRS name resolution returned an unexpected response (missing id column). ",
      "Try again later or check https://tnrs.biendata.org/."
    )
  }

  resolved <- resolved |>
    mutate(id = as.character(id)) |>
    # TNRS de-duplicates its input: when several ids submit the same name it
    # returns ONE row whose id is the comma-collapsed list ("2,1").
    separate_longer_delim(id, delim = ",") |>
    mutate(id = str_trim(id))

  keep <- names(tnrs_cache_cols$cols)
  for (col in setdiff(keep, c("submitted", names(resolved)))) {
    resolved[[col]] <- NA_character_
  }

  query |>
    inner_join(resolved, by = "id") |>
    select(-id) |>
    mutate(overall_score = suppressWarnings(as.numeric(overall_score))) |>
    select(all_of(keep)) |>
    distinct(submitted, .keep_all = TRUE)
}


#' Bring the on-disk taxonomy lookup up to date and return its path.
#'
#' The lookup is keyed on the submitted name, which is the only thing name
#' resolution depends on, so it stays valid across any change to the community
#' data. Only names missing from it are sent to the API, so adding one species
#' costs one lookup rather than re-resolving everything.
#'
#' The file is tracked in git. TNRS has been unreliable, and a committed lookup
#' means a fresh clone can build the phylogeny with no network access at all.
#' It also pins the taxonomy: results do not shift when WCVP/WFO publish
#' revisions. The cost is that genuine upstream corrections are only picked up
#' when someone sets `refresh = TRUE`, which is the right trade for an analysis
#' that has to stay reproducible.
#'
#' Only names the API actually answered for are written. A partial response
#' therefore leaves the unanswered names absent and they are retried next run,
#' rather than being stored as permanent empty results.
#'
#' Declared as a `format = "file"` target so targets hashes the file itself:
#' pulling a colleague's updated lookup, or correcting a row by hand,
#' invalidates the downstream targets instead of being silently ignored.
#'
#' @param names Character vector, from [taxon_names_to_resolve()].
#' @param cache_path Path to the CSV lookup.
#' @param refresh If `TRUE`, ignore the file and re-resolve every name.
#' @param sources TNRS source databases, passed to [resolve_taxonomy()].
#' @return `cache_path`, so the target can be `format = "file"`.
update_taxonomy_cache <- function(
    names,
    cache_path = "data/taxonomy_tnrs.csv",
    refresh = FALSE,
    sources = c("wcvp", "wfo")) {
  names <- unique(names[!is.na(names) & nzchar(names)])

  cached <- NULL
  if (!refresh && file.exists(cache_path)) {
    cached <- tryCatch(
      readr::read_csv(cache_path, col_types = tnrs_cache_cols),
      error = function(e) NULL
    )
    if (!is.null(cached) && !"submitted" %in% base::names(cached)) {
      cached <- NULL
    }
  }
  if (is.null(cached)) {
    cached <- resolve_taxonomy(character(), sources = sources)
  }

  missing <- setdiff(names, cached$submitted)
  if (length(missing) > 0) {
    message("TNRS: resolving ", length(missing), " new name(s); ",
            length(names) - length(missing), " reused from the committed lookup.")
    fresh <- resolve_taxonomy(missing, sources = sources)
    cached <- bind_rows(cached, fresh)
  }

  if (length(missing) > 0 || !file.exists(cache_path)) {
    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    cached |>
      distinct(submitted, .keep_all = TRUE) |>
      arrange(submitted) |>
      readr::write_csv(cache_path)
  }

  cache_path
}


#' Read the taxonomy lookup, restricted to the names currently in play.
#'
#' @param cache_path Path returned by [update_taxonomy_cache()].
#' @param names Character vector, from [taxon_names_to_resolve()].
#' @return Tibble with one row per resolvable name, columns as in
#'   [tnrs_cache_cols].
read_taxonomy_cache <- function(cache_path, names) {
  readr::read_csv(cache_path, col_types = tnrs_cache_cols) |>
    filter(submitted %in% names) |>
    arrange(submitted)
}


#' Build the raw-name -> tip-label lookup used by the tree and the community data.
#'
#' Accepts a TNRS species match when `overall_score` clears `min_score`;
#' otherwise falls back to the normalized name so the record is not silently
#' lost. Tip labels use the `Genus_species` convention rtrees expects, with
#' genus- and family-level taxa keeping their morphospecies suffix
#' (`Carex_sp7`, `Asteraceae_sp1`).
#'
#' Joining happens here rather than inside the resolution step so that
#' `taxonomy` stays a pure name-to-name lookup: record counts and country
#' coverage change often, names rarely.
#'
#' @param species_list Output of [build_species_list()].
#' @param taxonomy Output of [load_or_resolve_taxonomy()], keyed on `submitted`.
#' @param min_score Minimum TNRS overall score to accept a species match.
#' @return Tibble with one row per `taxon_normalized` and `country`, including
#'   `tip_label`, `genus`, `family`, and a `match_status` of `accepted`,
#'   `genus_only`, `family_only`, or `unresolved`. Genus- and family-level tips
#'   carry a country suffix (`Carex_sp_ch`); species-level tips do not.
build_taxon_table <- function(species_list, taxonomy, min_score = 0.8) {
  species_list |>
    mutate(submitted = if_else(rank == "species", taxon_normalized, word(taxon_normalized, 1))) |>
    left_join(taxonomy, by = "submitted") |>
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
      # Partially identified taxa are region-specific: `Carex sp` in China and
      # `Carex sp` in Colorado are almost certainly different species, so they get
      # separate tips and are grafted independently within Carex. Merging them
      # would make the two regions share a species they do not share, inflating
      # phylogenetic similarity between floras. Fully identified species keep a
      # global name, so genuine shared species still count as shared.
      tip_label = case_when(
        rank == "family" ~ str_c(word(taxon_normalized, 1), placeholder, country, sep = "_"),
        rank == "genus" ~ str_c(genus, placeholder, country, sep = "_"),
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
      taxon_normalized, country, rank, raw_taxa, n_records,
      tip_label, accepted = accepted_sp, genus, family, match_status,
      tnrs_score = overall_score, tnrs_matched_name = name_matched
    ) |>
    arrange(taxon_normalized, country)
}


#' The distinct set of tips to graft, with the genus and family rtrees needs.
#'
#' Split out from [build_taxon_table()] so the 30-minute grafting step depends
#' only on the species going into the tree. `taxon_table` also carries
#' `n_records` and `raw_taxa`, which shift whenever anyone re-cleans the
#' community data; without this reduction the tree would rebuild for edits that
#' cannot change its topology.
#'
#' @param taxon_table Output of [build_taxon_table()].
#' @return Data frame with `species`, `genus`, `family` for [build_phylogeny()].
tree_species_list <- function(taxon_table) {
  taxon_table |>
    distinct(tip_label, genus, family) |>
    filter(!is.na(tip_label), !is.na(genus) | !is.na(family)) |>
    transmute(
      species = tip_label,
      genus = coalesce(genus, word(tip_label, 1, sep = fixed("_"))),
      family = coalesce(family, "")
    ) |>
    arrange(species) |>
    as.data.frame()
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
#' @param tree_species Output of [tree_species_list()].
#' @param scenario rtrees grafting scenario.
#' @param n_tree Number of replicate graftings.
#' @param seed RNG seed, so the replicate set is reproducible.
#' @return A `multiPhylo` of length `n_tree` (or 1), tips labelled with
#'   `tip_label` values. Tip sets are identical across replicates; only the
#'   placement of grafted species differs.
build_phylogeny <- function(tree_species,
                            scenario = "random_below_basal",
                            n_tree = 100,
                            seed = 1) {
  sp_list <- tree_species

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
        select(taxon_normalized, country, tip_label, family_accepted = family, match_status),
      by = join_by(taxon_normalized, country)
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
