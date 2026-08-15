# try to make as few targets as possible as each target is cached.
# With many intermediate steps, it uses a lot of disk space.

transformation_plan <- list(

  # COMMUNITY
  # merge all communities
  tar_target(
    name = community,
    command = bind_rows(community_sv, community_pe, community_ch, community_no, community_co, community_sa)
  ),

  # Hourly PFTC extract with community keys (one row per plot x timestep)
  tar_target(
    name = hourly_climate,
    command = hourly_climate_raw |>
      downscaled_climate_add_site_keys() |>
      filter(!is.na(site), !is.na(plot_id))
  ),

  # calculate diversity indices
  tar_target(
    name = diversity,
    command = {
      # First aggregate community data to plot level
      community_agg <- community |>
        group_by(country, region, season, gradient, site, plot_id, ecosystem, elevation_m, longitude_e, latitude_n) |>
        summarise(
          diversity = diversity(cover),
          sum_abundance = sum(cover),
          .groups = "drop"
        )

      # Growing-season climate (plot-level, site-level fallback)
      community_agg |>
        join_growing_season_climate(growing_season_climate, growing_season_climate_site) |>
        pivot_longer(cols = c(diversity, sum_abundance), names_to = "diversity_index", values_to = "value") |>
        # Ensure region is ordered consistently (north to south)
        mutate(region = factor(region, levels = c(
          "Svalbard", "Southern Scandes", "Rocky Mountains",
          "Eastern Himalaya", "Central Andes", "Drakensberg"
        ))) |>
        # Shannon diversity + sum cover (plot sizes differ; richness omitted — see README/results text)
        mutate(diversity_index = factor(diversity_index, levels = c("diversity", "sum_abundance")))
    }
  ),

  # add community data coordinates to all_coordinates
  tar_target(
    name = all_coordinates,
    command = {
      # Extract coordinates from community data for countries that don't have separate meta targets
      coords_from_community <- community |>
        distinct(country, region, gradient, site, plot_id, elevation_m, longitude_e, latitude_n, ecosystem) |>
        filter(!is.na(longitude_e), !is.na(latitude_n))
      coords_from_community
    }
  )
)
