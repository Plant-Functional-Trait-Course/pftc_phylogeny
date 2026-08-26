# Phylogeny plan
# Harmonize taxonomy and assemble phylogeny.

phylogeny_plan <- list(

  # Distinct, case-normalized taxon list across all six regions.
  # Built from community_raw, not community: taxonomy does not depend on the
  # climate join, and this keeps the whole phylogeny branch buildable without
  # the downscaled climate extract.
  tar_target(
    name = species_list,
    command = build_species_list(community_raw)
  ),

  # Resolve names against WCVP/WFO. Hits the TNRS API, so this is the one
  # target here that needs network access.
  tar_target(
    name = taxonomy,
    command = resolve_taxonomy(species_list)
  ),

  # raw name -> tip label lookup, plus match diagnostics.
  tar_target(
    name = taxon_table,
    command = build_taxon_table(taxonomy)
  ),

  # Graft onto the plant megatree. Species missing from the backbone are placed
  # at a random point below their genus's basal node, so this is 100 replicate
  # trees rather than one; diversity metrics must be computed per replicate.
  tar_target(
    name = phylogeny,
    command = build_phylogeny(taxon_table, scenario = "random_below_basal", n_tree = 100)
  ),

  # Community data restricted to taxa that made it onto the tree.
  # This is the input for the diversity plan.
  tar_target(
    name = community_phylo,
    command = attach_tip_labels(community, taxon_table, phylogeny)
  ),

  # How many names resolved, by country and match status.
  tar_target(
    name = taxonomy_summary,
    command = taxon_table |>
      count(match_status, name = "n_taxa") |>
      mutate(prop = n_taxa / sum(n_taxa))
  )
)
