# Download plan

download_plan <- list(

  # Svalbard Data
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
  # extract the sqlite database from the seedclim zip
  tar_target(
    name = seedclim_db,
    command = {
      contents <- unzip(download_community_no2, list = TRUE)
      db_file <- contents$Name[grepl("[.]sqlite$", contents$Name)][1]
      if (is.na(db_file)) {
        stop("No .sqlite file found in ", download_community_no2)
      }
      unzip(download_community_no2, files = db_file, exdir = "data", junkpaths = TRUE)
      file.path("data", basename(db_file))
    },
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

  # Colorado Data
  # community data from Google Drive folder:
  # https://drive.google.com/drive/folders/1P-ND3-V0SSN7kgB2ia5UW5wB0nkZkvE5
  tar_target(
    name = download_community_co,
    command = {
      dest <- "data/RMBL_2022_abundance.xlsx"
      dir.create("data", showWarnings = FALSE)
      googledrive::drive_deauth()
      googledrive::drive_download(
        file = googledrive::as_id("1c9RP3-BBLrfIjiODFrKSQmrb3e0QJCEP"),
        path = dest,
        overwrite = TRUE
      )
      dest
    },
    format = "file"
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

  # Downscaled climate extract
  # Supplied manually (not on OSF); see README for provenance.
  tar_target(
    name = download_climate,
    command = "data/downscaled_climate.csv",
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
