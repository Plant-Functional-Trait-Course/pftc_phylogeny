# try to make as few targets as possible as each target is cached.
# With many intermediate steps, it uses a lot of disk space.

transformation_plan <- list(

  # COMMUNITY
  # merge all communities (no climate yet)
  tar_target(
    name = community_raw,
    command = bind_rows(community_sv, community_pe, community_ch, community_no, community_co, community_sa)
  ),

  # Downscaled climate with community keys (one row per plot)
  # Svalbard C1 has no extract; copy C2 climate onto C1 before any community join
  tar_target(
    name = climate,
    command = climate_raw |>
      downscaled_climate_add_site_keys() |>
      filter(!is.na(site), !is.na(plot_id)) |>
      fill_svalbard_c1_climate_from_c2()
  ),
  
  # Join community with downscaled climate.
  # Matching is plot-level first (by harmonized plot_id), then falls back to
  # site-level climate means when plot-level IDs don't match.
  tar_target(
    name = community,
    command = {
      climate_vars <- c("T2m", "relhum", "windspeed", "VPD")

      # Plot-level climate (after site/plot harmonization).
      clim_plot <- climate |>
        select(country, gradient, site, plot_id, all_of(climate_vars)) |>
        rename_with(\(x) paste0(x, "_plot"), all_of(climate_vars))

      # Site-level fallback climate.
      clim_site <- climate |>
        group_by(country, gradient, site) |>
        summarise(across(all_of(climate_vars), ~mean(.x, na.rm = TRUE)), .groups = "drop") |>
        rename_with(\(x) paste0(x, "_site"), all_of(climate_vars))

      community_raw |>
        # China control turfs have a `-C` suffix in community IDs; climate uses base IDs.
        mutate(plot_id_clim = bio_climate_plot_id(country, plot_id)) |>
        left_join(
          clim_plot,
          by = join_by(country, gradient, site, plot_id_clim == plot_id)
        ) |>
        left_join(
          clim_site,
          by = join_by(country, gradient, site)
        ) |>
        mutate(
          climate_scale = case_when(
            !is.na(T2m_plot) ~ "plot",
            !is.na(T2m_site) ~ "site",
            TRUE ~ NA_character_
          ),
          T2m = coalesce(T2m_plot, T2m_site),
          relhum = coalesce(relhum_plot, relhum_site),
          windspeed = coalesce(windspeed_plot, windspeed_site),
          VPD = coalesce(VPD_plot, VPD_site)
        ) |>
        select(-plot_id_clim, -ends_with("_plot"), -ends_with("_site"))
    }
  ),

  # add community data coordinates to all_coordinates
  tar_target(
    name = all_coordinates,
    command = {
      # Extract coordinates from community data for countries that don't have separate meta targets
      coords_from_community <- community_raw |>
        distinct(country, region, gradient, site, plot_id, elevation_m, longitude_e, latitude_n, ecosystem) |>
        filter(!is.na(longitude_e), !is.na(latitude_n))
      coords_from_community
    }
  )
)
