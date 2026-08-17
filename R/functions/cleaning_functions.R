## cleaning functions

# cleaning Svalbard data
clean_sv_communit <- function(raw_community_sv) {
  raw_community_sv |>
    clean_names() |>
    tidylog::distinct() |>
    mutate(
      country = "sv",
      region = "Svalbard",
      ecosystem = "arctic",
      gradient = if_else(gradient == "B", "N", gradient),
      site = as.character(site),
      site = paste0(country, "_", gradient, "_", site),
      plot_id = paste0(gradient, "_", site, "_", plot_id)
    ) |>
    tidylog::select(country, region, year, date, gradient, site, plot_id, taxon, cover, elevation_m, latitude_n, longitude_e, ecosystem)
}


# Cleaning Peru data
# community
clean_pe_community <- function(raw_community_pe) {
  raw_community_pe |>
    filter(
      !treatment %in% c("NB", "BB"),
      site != "OCC",
      season == "wet_season"
    ) |>
    mutate(
      country = "pe",
      region = "Central Andes",
      ecosystem = "tropic",
      site = paste0(country, "_", treatment, "_", site),
      plot_id = paste0(treatment, "_", site, "_", plot_id),
      taxon = tolower(taxon),
      gradient = "C"
    ) |>
    tidylog::select(country, region, year, month, treatment, gradient, site, plot_id, functional_group, family, taxon, cover, elevation_m = elevation, latitude_n = latitude, longitude_e = longitude, ecosystem)
}


# Import and clean China community data
import_clean_ch_community <- function(raw_meta_ch) {
  con <- dbConnect(dbConnect(SQLite(), dbname = "data/transplant.sqlite"))

  taxon <- tbl(con, "taxon")

  # assemble dataset
  community <- tbl(con, "turfCommunity") |>
    left_join(tbl(con, "turfs"), by = "turfID") |>
    # only control plots
    filter(TTtreat %in% c("C", "0")) |>
    left_join(tbl(con, "plots") |>
      select(-slope, -aspect), by = c("originPlotID" = "plotID")) |>
    left_join(tbl(con, "blocks") %>%
      select(-slope, -aspect), by = c("blockID")) |>
    left_join(tbl(con, "sites") %>%
      select(-slope, -aspect), by = c("siteID")) |>
    left_join(taxon, by = c("species")) |>
    collect()

  community |>
    left_join(raw_meta_ch, by = c("siteID" = "site")) |>
    mutate(
      country = "ch",
      region = "Eastern Himalaya",
      gradient = "C",
      ecosystem = "sub-tropics",
      site = paste0(country, "_", siteID),
      plot_id = paste0(country, "_", originPlotID),
      speciesName = tolower(speciesName)
    ) |>
    filter(year == 2016) |>
    select(country, region, year, gradient, site, plot_id, taxon = speciesName, cover, functional_group = functionalGroup, family, elevation_m = elevation, latitude_n = latitude.y, longitude_e = longitude.y, ecosystem) |>
    mutate(taxon = recode(taxon, "Potentilla stenophylla var. emergens" = "Potentilla stenophylla"))
}


# clean norway community
clean_no_comm <- function(raw_community_no, sp_list_no) {
  threeD_community <- raw_community_no |>
    # filter for 2022 and control treatments
    filter(
      year == 2022,
      warming == "A",
      grazing %in% c("C", "N"),
      Nlevel %in% c(1, 2, 3)
    ) |>
    # group species that are uncertain
    # e.g. Antennaria dioica, Ant alpina and Ant sp
    mutate(species = case_when(
      str_detect(species, "Antennaria") ~ "Antennaria sp",
      str_detect(species, "Luzula") ~ "Luzula sp",
      str_detect(species, "Pyrola") ~ "Pyrola sp",
      TRUE ~ species
    )) |>
    # Remove Carex rupestris and norvegica cf, Carex sp, because they are very uncertain
    filter(
      !str_detect(species, "Unknown"),
      !species %in% c(
        "Carex rupestris", "Carex rupestris cf",
        "Carex norvegica cf", "Carex sp"
      )
    ) |>
    # add variables
    mutate(
      country = "no",
      region = "Southern Scandes",
      gradient = "C",
      ecosystem = "boreal",
      elevation_m = case_when(
        destSiteID == "Joasete" ~ 920,
        TRUE ~ 1290
      ),
      latitude_n = if_else(destSiteID == "Joasete", 60.86183, 60.85994),
      longitude_e = if_else(destSiteID == "Joasete", 7.16800, 7.19504),
      site = paste0(country, "_", destSiteID),
      plot_id = paste0(site, "_", turfID)
    ) |>
    # add taxon information
    left_join(
      sp_list_no |>
        mutate(species = paste(genus, species, sep = " ")),
      by = "species"
    ) |>
    # fix NA's in functional group
    mutate(functional_group = case_when(
      species == "Carex nigra" ~ "graminoid",
      species %in% c("Oxytropa laponica", "Galium verum", "Veronica officinalis", "Erigeron uniflorus", "Epilobium anagallidifolium") ~ "forb",
      TRUE ~ functional_group
    )) |>
    ungroup() |>
    select(country, region, year, date, gradient, site, plot_id, taxon = species, cover, family, functional_group, elevation_m, latitude_n, longitude_e, ecosystem)

  # vcg plant community data
  con <- dbConnect(SQLite(), dbname = "data/seedclim.sqlite")

  # dbListTables(con)

  vcg_community <- tbl(con, "turf_community") |>
    select(-cf, -flag) |>
    left_join(tbl(con, "turfs"), by = "turfID") |>
    # only control plots
    filter(TTtreat %in% c("TTC")) |>
    select(-RTtreat, -GRtreat, -destinationPlotID) |>
    # join plot, block and site IDs
    left_join(tbl(con, "plots"), by = c("originPlotID" = "plotID")) |>
    rename("plotID" = originPlotID) |>
    select(-aspect, -slope) |>
    left_join(tbl(con, "blocks"), by = c("blockID")) |>
    select(-aspect, -slope) |>
    left_join(tbl(con, "sites"), by = c("siteID")) |>
    select(-comment, -norwegian_name, -site_code, -c(biogeographic_zone:precipitation_level)) |>
    # filter 2 sites, and last year
    filter(
      siteID %in% c("Hogsete", "Vikesland"),
      year == 2019
    ) |>
    left_join(tbl(con, "taxon"), by = "species") |>
    group_by(year, siteID, turfID, species_name, family, elevation, latitude, longitude) |>
    summarise(cover = mean(cover)) |>
    rename(taxon = species_name) |>
    collect() |>
    mutate(
      country = "no",
      region = "Southern Scandes",
      gradient = "C",
      ecosystem = "boreal",
      site = paste0(country, "_", siteID),
      plot_id = paste0(site, "_", turfID)
    ) |>
    ungroup() |>
    select(country, region, year, gradient, site, plot_id, taxon, cover, family, elevation_m = elevation, latitude_n = latitude, longitude_e = longitude, ecosystem)

  bind_rows(threeD_community, vcg_community)
}


# Colorado data
# clean Colorado meta Community
# clean_colorado_meta_community <- function(metaCommunityCO){
#   metaCommunityCO |>
#     clean_names() |>
#     filter(!is.na(site)) |>
#     mutate(plot_id = recode(plot_id, "plot_3_pct" = "plot3_pct"),
#            gradient = "c") |>
#     mutate(plot_id = recode(plot_id, "plot1_pct" = "1", "plot2_pct" = "2", "plot3_pct" = "3", "plot4_pct" = "4", "plot5_pct" = "5"),
#            plot_id = paste(site, plot_id, sep = "_")) |>
#     pivot_wider(names_from = group, values_from = cover) |>
#     select(-date_y, -mean_height_cm_y) |>
#     rename(date = date_x, mean_height_cm = mean_height_cm_x, graminoid = 'Total Graminoid', herb = 'Total Herb', shrub = 'Total Shrub', bare_soil_litter_dead = 'Bare (Bare soil + Litter + Dead)', bare_soil = 'Bare soil')
#
# }


# clean Colorado community
clean_colorado_community <- function(raw_community_co, coords_co) {
  raw_community_co |>
    clean_names() |>
    filter(!is.na(site), site != "") |>
    mutate(site = recode(site, "Almont (peak)" = "Almont")) |>
    pivot_longer(cols = matches("^plot_[1-5]$"), names_to = "plot_id", values_to = "cover") |>
    rename(taxon = species) |>
    mutate(
      date_chr = as.character(date),
      date = coalesce(
        mdy(date_chr, quiet = TRUE),
        ymd(date_chr, quiet = TRUE),
        as.Date(suppressWarnings(as.numeric(date_chr)), origin = "1899-12-30")
      ),
      country = "co",
      region = "Rocky Mountains",
      ecosystem = "temperate",
      gradient = "C",
      year = year(date)
    ) |>
    select(-date_chr) |>
    mutate(
      plot_id = str_replace(plot_id, "plot_", ""),
      site = paste0(country, "_", site),
      plot_id = paste0(site, "_", plot_id)
    ) |>
    filter(!is.na(cover), cover != 0) |>
    tidylog::left_join(coords_co) |>
    select(country, region, year, date, gradient, site, plot_id, taxon, cover, elevation_m, latitude_n, longitude_e, ecosystem)
}


# clean South Africa community
clean_sa_community <- function(raw_community_sa, raw_meta_sa_extended) {
  raw_community_sa |>
    clean_names() |>
    tidylog::left_join(
      raw_meta_sa_extended |>
        clean_names(),
      by = c("site_id", "plot_id", "aspect", "elevation_m_asl")
    ) |>
    mutate(
      country = "sa",
      region = "Drakensberg",
      ecosystem = "grassland",
      year = year(date),
      gradient = dplyr::recode_values(
        aspect,
        "east" ~ "E",
        "west" ~ "W"
      ),
      site = paste0(country, "_", site_id),
      plot_id = paste0(site, "_", plot_id),
      taxon = species
    ) |>
    # Same species on more than one survey date (rare); keep one row per plot unit
    group_by(gradient, plot_id, taxon) |>
    slice(1) |>
    ungroup() |>
    select(
      country, region, year, date, gradient, site, plot_id, taxon, cover, aspect,
      elevation_m = elevation_m_asl, latitude_n = latitude,
      longitude_e = longitude, ecosystem
    )
}
