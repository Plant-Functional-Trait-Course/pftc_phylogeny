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
