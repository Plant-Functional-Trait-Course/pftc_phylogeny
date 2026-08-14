# Download plan

download_plan <- list(

  # Svalbard Data
  # trait data
  tar_target(
    name = download_traits_sv,
    command = get_file(
      node = "smbqh",
      file = "PFTC4_Svalbard_2018_Gradient_Traits.csv",
      path = "data/",
      remote_path = "Traits"
    ),
    format = "file"
  ),

  # community data
  tar_target(
    name = download_community_sv,
    command = get_file(
      node = "smbqh",
      file = "PFTC4_Svalbard_2018_Community_Gradient.csv",
      path = "data",
      remote_path = "Community"
    ),
    format = "file"
  ),

  # Peru Data
  # trait data
  tar_target(
    name = download_traits_pe,
    command = get_file(
      node = "gs8u6",
      file = "PFTC3-Puna-PFTC5_Peru_2018-2020_FunctionalTraits_clean.csv",
      path = "data/",
      remote_path = "traits"
    ),
    format = "file"
  ),

  # community data
  tar_target(
    name = download_community_pe,
    command = get_file(
      node = "gs8u6",
      file = "PFTC3-Puna-PFTC5_Peru_2018-2020_CommunityCover_clean.csv",
      path = "data",
      remote_path = "community"
    ),
    format = "file"
  ),

  # China Data
  # trait data
  tar_target(
    name = download_traits_leaf_ch,
    command = get_file(
      node = "f3knq",
      file = "PFTC1.2_China_2015_2016_LeafTraits.csv",
      path = "data/",
      remote_path = "Traits"
    ),
    format = "file"
  ),
  tar_target(
    name = download_traits_chem_ch,
    command = get_file(
      node = "f3knq",
      file = "PFTC1.2_China_2015_2016_ChemicalTraits.csv",
      path = "data/",
      remote_path = "Traits"
    ),
    format = "file"
  ),

  # community data
  tar_target(
    name = download_community_ch,
    command = get_file(
      node = "f3knq",
      file = "transplant.sqlite",
      path = "data",
      remote_path = "Community"
    ),
    format = "file"
  ),

  # meta data
  tar_target(
    name = download_meta_ch,
    command = "data/metaCH.csv",
    format = "file"
  ),

  # Norway Data
  # vegetation
  tar_target(
    name = download_community_no,
    command = get_file(
      node = "pk4bg",
      file = "7_Three-D_clean_cover_2019-2022.csv",
      path = "data"
    ),
    format = "file"
  ),

  # Seedclim comm data for Høgsete and Vikesland
  # file needs to be unziped
  tar_target(
    name = download_community_no2,
    command = get_file(
      node = "npfa9",
      file = "seedclim.2020.4.15.zip",
      path = "data",
      remote_path = "3_Community_data"
    ),
    format = "file"
  ),
  tar_target(
    name = download_sp_no,
    command = get_file(
      node = "pk4bg",
      file = "7_Three-D_clean_taxonomy.csv",
      path = "data"
    ),
    format = "file"
  ),

  # traits
  tar_target(
    name = download_traits_no,
    command = get_file(
      node = "fcbw4",
      file = "PFTC6_clean_ElevationGradient_GlobalChangeExperiment_morphological_traits_2022.csv", # nolint: line_length_linter.
      path = "data",
      remote_path = "i. trait_data"
    ),
    format = "file"
  ),

  # chemical traits (elevation gradient / global change experiment)
  tar_target(
    name = download_traits_chem_no,
    command = get_file(
      node = "fcbw4",
      file = "PFTC6_clean_ElevationGradient_GlobalChangeExperiment_chemical_traits_2022.csv", # nolint: line_length_linter.
      path = "data",
      remote_path = "i. trait_data"
    ),
    format = "file"
  ),

  # meta data
  tar_target(
    name = metaTurfID_no,
    command = create_threed_meta_data()
  ),

  # South Africa Data
  # community data
  tar_target(
    name = download_community_sa,
    command = get_file(
      node = "hk2cy",
      file = "i_PFTC7_clean_elevationgradient_community_2023.csv",
      path = "data",
      remote_path = "i_plant_community_composition"
    ),
    format = "file"
  ),

  # trait data
  tar_target(
    name = download_traits_sa,
    command = get_file(
      node = "hk2cy",
      file = "iv_PFTC7_clean_elevationgradient_traits_2023.csv",
      path = "data/",
      remote_path = "iv_aboveground_traits"
    ),
    format = "file"
  ),

  # chemical traits
  tar_target(
    name = download_traits_chem_sa,
    command = get_file(
      node = "hk2cy",
      file = "iv_PFTC7_clean_elevationgradient_chemical_traits_2023.csv",
      path = "data/",
      remote_path = "iv_aboveground_traits"
    ),
    format = "file"
  ),

  # meta data
  tar_target(
    name = download_meta_sa,
    command = get_file(
      node = "hk2cy",
      file = "0_PFCT7_clean_coordinates_2023.csv",
      path = "data/",
      remote_path = "0_coordinates"
    ),
    format = "file"
  )
)
