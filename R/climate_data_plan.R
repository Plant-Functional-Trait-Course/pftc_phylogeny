# Growing-season climate derived from the hourly PFTC extract.
# See R/Functions/growing_season_climate.R for the underlying functions.

climate_data_plan <- list(

  # Daily aggregates per plot (+ hemisphere-aware ordering key)
  tar_target(
    name = daily_climate,
    command = aggregate_climate_to_daily(hourly_climate) |>
      add_growing_season_order()
  ),

  # Growing-season window per plot: longest warm run (daily mean > 5 degC),
  # bridging short cold snaps (< 5 days) between warm spells
  tar_target(
    name = growing_season,
    command = detect_growing_season(daily_climate, threshold = 5, run_length = 5, bridge = 5)
  ),

  # Derived growing-season climate variables per plot (GDD base 5 degC)
  tar_target(
    name = growing_season_climate,
    command = summarise_growing_season_climate(daily_climate, growing_season, threshold = 5)
  ),

  # Site-level means used as a fallback for plots without plot-level climate
  tar_target(
    name = growing_season_climate_site,
    command = summarise_growing_season_climate_site(growing_season_climate)
  ),

  # Mean annual temperature (from downscaled daily data) and annual
  # precipitation (WorldClim bio_12, cached raster) per site, used for
  # the Whittaker biome plot.
  tar_target(
    name = annual_climate_site,
    command = {
      # MAT: mean of all available daily means per site
      mat <- daily_climate |>
        group_by(country, gradient, site) |>
        summarise(mat_c = mean(t_mean, na.rm = TRUE), .groups = "drop")

      # Annual precipitation from WorldClim 2.5-min bio_12 (mm)
      precip_rast <- terra::rast(
        "data/worldclim_cache/climate/wc2.1_2.5m/wc2.1_2.5m_bio_12.tif"
      )

      # One representative coordinate per site (mean of plot coordinates)
      site_coords <- community |>
        filter(!is.na(latitude_n), !is.na(longitude_e)) |>
        group_by(country, region, gradient, site) |>
        summarise(
          longitude_e = mean(longitude_e, na.rm = TRUE),
          latitude_n  = mean(latitude_n,  na.rm = TRUE),
          .groups = "drop"
        )

      pts <- terra::vect(
        site_coords,
        geom  = c("longitude_e", "latitude_n"),
        crs   = "EPSG:4326"
      )

      extracted <- terra::extract(precip_rast, pts) |>
        dplyr::rename(precip_mm = 2) |>
        dplyr::mutate(precip_cm = precip_mm / 10)

      site_coords |>
        dplyr::bind_cols(extracted |> dplyr::select(precip_cm)) |>
        dplyr::left_join(mat, by = c("country", "gradient", "site")) |>
        dplyr::mutate(
          region = factor(region, levels = climate_region_levels())
        ) |>
        dplyr::select(country, region, gradient, site, latitude_n, longitude_e,
                      mat_c, precip_cm)
    }
  ),

  # Region-level climate summary table (growing season temperature, MAT,
  # annual precipitation) formatted for the methods section.
  tar_target(
    name = region_climate_summary_table,
    command = {
      fmt <- function(mean, lo, hi, digits = 1) {
        sprintf(paste0("%.", digits, "f (%.", digits, "f\u2013%.", digits, "f)"),
                mean, lo, hi)
      }

      region_lkp <- community |>
        dplyr::distinct(country, region)

      gs <- growing_season_climate_site |>
        dplyr::left_join(region_lkp, by = "country") |>
        dplyr::group_by(region) |>
        dplyr::summarise(
          gs_temp = fmt(mean(gs_temperature, na.rm = TRUE),
                        min(gs_temperature,  na.rm = TRUE),
                        max(gs_temperature,  na.rm = TRUE)),
          .groups = "drop"
        )

      ann <- annual_climate_site |>
        dplyr::group_by(region) |>
        dplyr::summarise(
          mat    = fmt(mean(mat_c,    na.rm = TRUE),
                       min(mat_c,     na.rm = TRUE),
                       max(mat_c,     na.rm = TRUE)),
          precip = fmt(mean(precip_cm, na.rm = TRUE),
                       min(precip_cm,  na.rm = TRUE),
                       max(precip_cm,  na.rm = TRUE),
                       digits = 0),
          .groups = "drop"
        )

      gs |>
        dplyr::left_join(ann, by = "region") |>
        dplyr::mutate(region = factor(region, levels = climate_region_levels())) |>
        dplyr::arrange(region) |>
        gt::gt() |>
        gt::cols_label(
          region   = "Region",
          gs_temp  = "Growing season temperature (\u00b0C)",
          mat      = "Mean annual temperature (\u00b0C)",
          precip   = "Annual precipitation (cm)"
        ) |>
        gt::tab_header(
          title    = gt::md("**Climate overview by region**"),
          subtitle = "Mean (min\u2013max) across sites within each region."
        ) |>
        gt::tab_source_note(gt::md(
          "_Growing season temperature_: downscaled hourly climate data. _MAT and precipitation_: WorldClim 2.5 arcmin (bio\\_1, bio\\_12)."
        )) |>
        gt::tab_options(table.font.size = 13)
    }
  )

)
