cleaning_plan <- list(

  # Svalbard
  # clean community
  tar_target(
    name = community_sv,
    command = clean_sv_communit(raw_community_sv) |>
      filter(gradient != "N")
  ),

  # clean traits
  tar_target(
    name = traits_sv,
    command = clean_sv_traits(raw_traits_sv) |>
      filter(gradient != "N")
  ),

  # Peru
  # clean community
  tar_target(
    name = community_pe,
    command = clean_pe_community(raw_community_pe) |>
      filter(treatment != "B" | site == "pe_B_QUE")
  ),

  # clean traits
  tar_target(
    name = traits_pe,
    command = clean_pe_traits(raw_traits_pe) |>
      filter(treatment != "B" | site == "pe_B_QUE")
  ),

  # China
  # import and clean community
  tar_target(
    name = community_ch,
    command = import_clean_ch_community(raw_meta_ch)
  ),

  # clean traits
  tar_target(
    name = traits_ch,
    command = clean_ch_traits(raw_traits_leaf_ch, raw_traits_chem_ch, raw_meta_ch)
  ),


  # Norway
  # import and clean community
  tar_target(
    name = community_no,
    command = clean_no_comm(raw_community_no, sp_list_no)
  ),

  # clean traits
  tar_target(
    name = traits_no,
    command = clean_no_traits(raw_traits_no, raw_traits_chem_no, raw_community_no)
  ),


  # Colorado
  # import and clean community
  tar_target(
    name = community_co,
    command = clean_colorado_community(raw_community_co, coords_co)
  ),

  # clean traits
  tar_target(
    name = traits_co,
    command = clean_colorado_trait(raw_sp_co, raw_trait_co, coords_co)
  ),

  # South Africa
  # clean community
  tar_target(
    name = community_sa,
    command = clean_sa_community(raw_community_sa, raw_meta_sa_extended)
  ),

  # clean traits
  tar_target(
    name = traits_sa,
    command = clean_sa_traits(raw_traits_sa, raw_traits_chem_sa, raw_meta_sa_extended)
  )
)
