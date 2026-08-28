# Phylogeny plan
# Harmonize taxonomy and assemble phylogeny.
#
# The two expensive steps here are the TNRS lookup (~6 min) and the 100-replicate
# grafting (~30 min). Both are deliberately hung off the narrowest possible
# input, so that re-cleaning the community data does not re-run them:
#
#   community_raw -> species_list -> taxon_names -> taxonomy_cache -> taxonomy
#                                 \-> taxon_table -> tree_species -> phylogeny
#
# `taxon_names` is just the distinct character vector of names sent to TNRS, and
# `tree_species` is just the distinct tips with their genus and family. Editing
# a cleaner so that record counts or country coverage change will rebuild
# species_list and taxon_table (both seconds), but leaves taxonomy and phylogeny
# untouched unless the names or the tip set actually changed.

# Set TRUE to re-resolve every name against TNRS on the next tar_make(), then
# set back to FALSE. Normal rebuilds resolve only names missing from
# data/taxonomy_tnrs.csv, which is committed -- so a fresh clone needs no
# network access, and the taxonomy stays pinned rather than drifting with
# upstream WCVP/WFO revisions.
refresh_taxonomy <- FALSE

phylogeny_plan <- list(

  # Distinct, case-normalized taxon list across all six regions.
  # Built from community_raw, not community: taxonomy does not depend on the
  # climate join, and this keeps the whole phylogeny branch buildable without
  # the downscaled climate extract.
  tar_target(
    name = species_list,
    command = build_species_list(community_raw)
  ),

  # The names, and nothing else. This target is what gates the TNRS call.
  tar_target(
    name = taxon_names,
    command = taxon_names_to_resolve(species_list)
  ),

  # The committed name -> accepted-name lookup, brought up to date. Depends only
  # on taxon_names, so TNRS is called only when the set of names changes -- and
  # even then only for the new ones. Tracked as a file so that pulling someone
  # else's updated lookup, or hand-correcting a row, invalidates what follows.
  tar_target(
    name = taxonomy_cache,
    command = update_taxonomy_cache(
      taxon_names,
      refresh = refresh_taxonomy
    ),
    format = "file"
  ),

  # The lookup restricted to the names currently in play.
  tar_target(
    name = taxonomy,
    command = read_taxonomy_cache(taxonomy_cache, taxon_names)
  ),

  # raw name -> tip label lookup, plus match diagnostics.
  tar_target(
    name = taxon_table,
    command = build_taxon_table(species_list, taxonomy)
  ),

  # The tips to graft, with genus and family. Gates the grafting step.
  tar_target(
    name = tree_species,
    command = tree_species_list(taxon_table)
  ),

  # Graft onto the plant megatree. Species missing from the backbone are placed
  # at a random point below their genus's basal node, so this is 100 replicate
  # trees rather than one; diversity metrics must be computed per replicate.
  tar_target(
    name = phylogeny,
    command = build_phylogeny(tree_species, scenario = "random_below_basal", n_tree = 100)
  ),

  # Community data restricted to taxa that made it onto the tree.
  # This is the input for the diversity plan.
  tar_target(
    name = community_phylo,
    command = attach_tip_labels(community, taxon_table, phylogeny)
  ),

  # How many names resolved, by match status. Counts distinct taxa, not rows:
  # taxon_table is keyed by taxon AND country, so a species recorded in four
  # regions occupies four rows but is one taxon.
  tar_target(
    name = taxonomy_summary,
    command = taxon_table |>
      distinct(taxon_normalized, match_status) |>
      count(match_status, name = "n_taxa") |>
      mutate(prop = n_taxa / sum(n_taxa))
  )
)
