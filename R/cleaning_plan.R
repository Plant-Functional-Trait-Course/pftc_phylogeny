cleaning_plan <- list(

  # Svalbard
  # clean community
  tar_target(
    name = community_sv,
    command = clean_sv_communit(raw_community_sv) |>
      filter(gradient != "N")
  ),

  # Peru
  # clean community
  tar_target(
    name = community_pe,
    command = clean_pe_community(raw_community_pe)
  ),

  # China
  # import and clean community
  tar_target(
    name = community_ch,
    command = import_clean_ch_community(raw_meta_ch)
  ),

  # Norway
  # import and clean community
  tar_target(
    name = community_no,
    command = clean_no_comm(raw_community_no, sp_list_no)
  ),

  # Colorado
  # import and clean community
  tar_target(
    name = community_co,
    command = clean_colorado_community(raw_community_co, coords_co)
  ),

  # South Africa
  # clean community
  tar_target(
    name = community_sa,
    command = clean_sa_community(raw_community_sa, raw_meta_sa_extended)
  )
)
