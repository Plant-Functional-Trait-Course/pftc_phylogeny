import_plan <- list(

  # Svalbard Data
  # community data
  tar_target(
    name = raw_community_sv,
    command = read_csv(download_community_sv)
  ),

  # Peru Data
  # community data
  tar_target(
    name = raw_community_pe,
    command = read_csv(download_community_pe)
  ),

  # China Data
  # community data
  # imported in cleaning code

  # meta
  tar_target(
    name = raw_meta_ch,
    command = read_delim(download_meta_ch) |>
      clean_names() |>
      select(-country, -gradient)
  ),

  # Norway Data
  # community
  tar_target(
    name = raw_community_no,
    command = read_csv(download_community_no)
  ),

  # sp list
  tar_target(
    name = sp_list_no,
    command = read_csv(download_sp_no)
  ),

  # Colorado Data

  # community
  tar_target(
    name = raw_community_co,
    command = read_excel(download_community_co)
  ),

  # meta
  tar_target(
    name = coords_co,
    command = {
      plot_id <- 1:5
      meta <- tibble(
        site = c("CBT", "Road", "Pfeiler", "Cinnamon", "Almont", "PBM"),
        elevation_m = c(2699, 2810, 3171, 3458, 2475, 3380),
        latitude_n = c(38.8817327, 38.89680392, 38.96044646, 38.99159151, 38.655455, 39.0),
        longitude_e = c(-106.9799521, -106.978584, -107.0323667, -107.0663821, -106.861632, -107.03)
      )
      crossing(meta, plot_id) |>
        mutate(
          country = "co",
          gradient = "C",
          site = paste0(country, "_", site),
          plot_id = paste0(site, "_", plot_id)
        )
    }
  ),

  # South Africa Data
  # community data
  tar_target(
    name = raw_community_sa,
    command = read_csv(download_community_sa)
  ),

  # meta data
  tar_target(
    name = raw_meta_sa,
    command = read_csv(download_meta_sa) |>
      filter(site_id != 6)
  ),

  # meta data extended - needed to provide coordinates for all plots (1-5)
  tar_target(
    name = raw_meta_sa_extended,
    command = {
      # Get the existing plots 1 and 5 data
      plots_1_5 <- raw_meta_sa
      
      # Create lookup tables for plot 1 and plot 5 coordinates
      plot_1_coords <- plots_1_5 |>
        filter(plot_id == 1) |>
        select(site_id, aspect, latitude_plot1 = latitude, longitude_plot1 = longitude)
      
      plot_5_coords <- plots_1_5 |>
        filter(plot_id == 5) |>
        select(site_id, aspect, latitude_plot5 = latitude, longitude_plot5 = longitude)
      
      # Identify which plots are missing for each site and aspect
      existing_plots <- plots_1_5 |>
        select(site_id, aspect, plot_id) |>
        distinct()
      
      # Create all possible plot combinations (1-5) for each site and aspect
      all_plots <- plots_1_5 |>
        select(site_id, aspect, elevation_m_asl) |>
        distinct() |>
        crossing(plot_id = 1:5)
      
      # Find missing plots (plots that don't exist in the original data)
      missing_plots <- all_plots |>
        anti_join(existing_plots, by = c("site_id", "aspect", "plot_id")) |>
        # Join back with the original data to get all other columns (take first row to avoid duplicates)
        left_join(
          plots_1_5 |> 
            select(-plot_id, -latitude, -longitude) |>
            distinct(site_id, aspect, elevation_m_asl, .keep_all = TRUE),
          by = c("site_id", "aspect", "elevation_m_asl")
        ) |>
        # Join with coordinate lookup tables
        left_join(plot_1_coords, by = c("site_id", "aspect")) |>
        left_join(plot_5_coords, by = c("site_id", "aspect")) |>
        # Fill in latitude and longitude based on plot mapping rules
        mutate(
          latitude = case_when(
            plot_id %in% c(2, 3) ~ latitude_plot1,
            plot_id == 4 ~ latitude_plot5,
            TRUE ~ NA_real_
          ),
          longitude = case_when(
            plot_id %in% c(2, 3) ~ longitude_plot1,
            plot_id == 4 ~ longitude_plot5,
            TRUE ~ NA_real_
          )
        ) |>
        # Remove the temporary coordinate columns
        select(-latitude_plot1, -longitude_plot1, -latitude_plot5, -longitude_plot5)
      
      # Combine original data with missing plots
      bind_rows(plots_1_5, missing_plots) |>
        arrange(site_id, aspect, plot_id)
    }
  ),

  # import hourly climate data
  tar_target(
    name = hourly_climate_raw,
    command = read_csv("data/PFTC_downscaled_climate.csv")
  )

)
