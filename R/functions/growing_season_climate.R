## Growing-season climate from the hourly PFTC extract.
##
## Pipeline: hourly_climate -> daily aggregates -> growing-season window per plot
## -> derived growing-season variables -> site-level means for fallback -> join
## into trait/community data.
##
## Growing-season rule (single, consistent across countries): on the daily mean
## temperature series, mark days above `threshold` (5 degC, the conventional
## thermal growing season), bridge short cold snaps (below-threshold runs shorter
## than `bridge` days that sit between warm spells), then take the LONGEST
## continuous warm run as the growing season. This is robust to volatile springs,
## where a brief early-season warm spell followed by a cold snap would otherwise
## truncate the season. Tropical sites with no sustained cold (Peru) approach a
## full year.
##
## Southern Hemisphere sites (Peru, South Africa; latitude < 0) are rotated to a
## July-June year so the austral summer is a contiguous run within the single
## calendar year of data.


#' Aggregate the hourly climate to one row per plot and day.
#'
#' @param hourly `hourly_climate`: `country`, `gradient`, `site`, `plot_id`,
#'   `datetime`, `T2m`, `VPD`, ...
#' @return One row per `country`, `gradient`, `site`, `plot_id`, `date`.
aggregate_climate_to_daily <- function(hourly) {
  hourly |>
    mutate(date = as_date(datetime)) |>
    group_by(country, gradient, site, plot_id, date) |>
    summarise(
      t_mean = mean(T2m, na.rm = TRUE),
      t_min = min(T2m, na.rm = TRUE),
      t_max = max(T2m, na.rm = TRUE),
      vpd_mean = mean(VPD, na.rm = TRUE),
      n_hours = dplyr::n(),
      .groups = "drop"
    )
}


#' Add an ordering key so growing seasons are contiguous in both hemispheres.
#'
#' Northern Hemisphere keeps the calendar date. Southern Hemisphere (Peru, South
#' Africa) is rotated to a July-June year: dates in Jul-Dec keep their year and
#' Jan-Jun are pushed forward one year, so the austral summer (around Dec-Jan)
#' becomes a single contiguous run rather than splitting across the calendar
#' boundary. A constant offset would not work because it leaves the ordering of
#' days within the calendar year unchanged.
add_growing_season_order <- function(daily) {
  daily |>
    mutate(
      is_southern = country %in% c("pe", "sa"),
      gs_order = if_else(
        is_southern & month(date) < 7,
        date + years(1),
        date
      )
    )
}


#' Detect the growing-season window for each plot.
#'
#' Marks days with `t_mean > threshold`, bridges below-threshold runs shorter than
#' `bridge` days that sit between warm spells, then takes the longest remaining
#' continuous warm run (of at least `run_length` days) as the growing season. See
#' the file header for the rationale.
#'
#' @param daily Output of [add_growing_season_order()].
#' @return One row per plot with calendar `gs_start`/`gs_end`, order-space
#'   `gs_order_start`/`gs_order_end` (used for window filtering), `gs_length`,
#'   and `gs_found`.
detect_growing_season <- function(daily, threshold = 5, run_length = 5, bridge = 5) {
  daily |>
    group_by(country, gradient, site, plot_id) |>
    summarise(
      gs = list(detect_growing_season_one(date, gs_order, t_mean, threshold, run_length, bridge)),
      .groups = "drop"
    ) |>
    tidyr::unnest_wider(gs)
}


#' Growing-season window for a single plot's ordered daily series.
#'
#' @param date Calendar dates (returned as the reported start/end).
#' @param gs_order Ordering key from [add_growing_season_order()].
#' @param t_mean Daily mean temperature.
#' @param bridge Below-threshold runs shorter than this (flanked by warm spells)
#'   are merged into the growing season, so short cold snaps do not split it.
#' @return List with `gs_start`, `gs_end`, `gs_order_start`, `gs_order_end`,
#'   `gs_length`, `gs_found`.
detect_growing_season_one <- function(date, gs_order, t_mean, threshold = 5, run_length = 5, bridge = 5) {
  empty <- list(
    gs_start = as.Date(NA),
    gs_end = as.Date(NA),
    gs_order_start = as.Date(NA),
    gs_order_end = as.Date(NA),
    gs_length = NA_integer_,
    gs_found = FALSE
  )

  if (length(t_mean) < run_length) {
    return(empty)
  }

  ord <- order(gs_order)
  date <- date[ord]
  gs_order <- gs_order[ord]
  t_mean <- t_mean[ord]

  above <- t_mean > threshold
  above[is.na(above)] <- FALSE

  runs <- rle(above)
  vals <- runs$values
  lens <- runs$lengths

  # Bridge short cold snaps that sit between warm spells (not leading/trailing).
  for (i in seq_along(vals)) {
    if (!vals[i] && lens[i] < bridge && i > 1L && i < length(vals)) {
      vals[i] <- TRUE
    }
  }

  # Re-run length encoding to merge now-adjacent warm runs.
  merged <- rle(inverse.rle(list(lengths = lens, values = vals)))
  run_end <- cumsum(merged$lengths)
  run_start <- run_end - merged$lengths + 1L

  warm <- which(merged$values & merged$lengths >= run_length)
  if (length(warm) == 0L) {
    return(empty)
  }

  # Longest warm run is the growing season.
  best <- warm[which.max(merged$lengths[warm])]
  start_idx <- run_start[best]
  end_idx <- run_end[best]

  list(
    gs_start = date[start_idx],
    gs_end = date[end_idx],
    gs_order_start = gs_order[start_idx],
    gs_order_end = gs_order[end_idx],
    gs_length = as.integer(end_idx - start_idx + 1L),
    gs_found = TRUE
  )
}


#' Derive growing-season climate variables per plot.
#'
#' Keeps daily rows inside each plot's window (in `gs_order` space, so seasons that
#' wrap the calendar boundary are handled) and summarises temperature, VPD, growing
#' degree days (base `threshold`) and the mean diurnal range.
#'
#' @param daily Output of [add_growing_season_order()].
#' @param gs Output of [detect_growing_season()].
#' @param threshold Growing degree day base temperature (matches the
#'   growing-season detection threshold).
summarise_growing_season_climate <- function(daily, gs, threshold = 5) {
  windows <- gs |>
    filter(gs_found) |>
    select(country, gradient, site, plot_id, gs_start, gs_end, gs_length, gs_order_start, gs_order_end)

  daily |>
    inner_join(windows, by = c("country", "gradient", "site", "plot_id")) |>
    filter(gs_order >= gs_order_start, gs_order <= gs_order_end) |>
    group_by(country, gradient, site, plot_id, gs_start, gs_end, gs_length) |>
    summarise(
      gs_temperature = mean(t_mean, na.rm = TRUE),
      gs_vpd = mean(vpd_mean, na.rm = TRUE),
      gdd = sum(pmax(t_mean - threshold, 0), na.rm = TRUE),
      gs_diurnal_range = mean(t_max - t_min, na.rm = TRUE),
      .groups = "drop"
    )
}


#' Site-level growing-season climate (mean across plots) used as a join fallback.
summarise_growing_season_climate_site <- function(gs_climate) {
  gs_climate |>
    group_by(country, gradient, site) |>
    summarise(
      gs_length = mean(gs_length, na.rm = TRUE),
      gs_temperature = mean(gs_temperature, na.rm = TRUE),
      gs_vpd = mean(gs_vpd, na.rm = TRUE),
      gdd = mean(gdd, na.rm = TRUE),
      gs_diurnal_range = mean(gs_diurnal_range, na.rm = TRUE),
      .groups = "drop"
    )
}


#' Join growing-season climate to trait/community data, plot-level then site-level.
#'
#' Adds the plot-level values where the harmonized `plot_id` matches (using
#' [bio_climate_plot_id()] for China control turfs), otherwise falls back to the
#' site mean. `climate_scale` records which source was used (`"plot"`, `"site"`,
#' or `NA` when neither is available).
#'
#' @param bio Data with `country`, `gradient`, `site`, `plot_id`.
#' @param gs_plot Output of [summarise_growing_season_climate()].
#' @param gs_site Output of [summarise_growing_season_climate_site()].
join_growing_season_climate <- function(bio, gs_plot, gs_site) {
  gs_vars <- c("gs_length", "gs_temperature", "gs_vpd", "gdd", "gs_diurnal_range")

  plot_join <- gs_plot |>
    select(country, gradient, site, plot_id, all_of(gs_vars)) |>
    rename_with(\(x) paste0(x, "_plot"), all_of(gs_vars))

  site_join <- gs_site |>
    select(country, gradient, site, all_of(gs_vars)) |>
    rename_with(\(x) paste0(x, "_site"), all_of(gs_vars))

  bio |>
    mutate(plot_id_clim = bio_climate_plot_id(country, plot_id)) |>
    left_join(plot_join, by = join_by(country, gradient, site, plot_id_clim == plot_id)) |>
    left_join(site_join, by = join_by(country, gradient, site)) |>
    mutate(
      climate_scale = case_when(
        !is.na(gs_temperature_plot) ~ "plot",
        !is.na(gs_temperature_site) ~ "site",
        TRUE ~ NA_character_
      ),
      gs_length = coalesce(gs_length_plot, gs_length_site),
      gs_temperature = coalesce(gs_temperature_plot, gs_temperature_site),
      gs_vpd = coalesce(gs_vpd_plot, gs_vpd_site),
      gdd = coalesce(gdd_plot, gdd_site),
      gs_diurnal_range = coalesce(gs_diurnal_range_plot, gs_diurnal_range_site)
    ) |>
    select(-plot_id_clim, -ends_with("_plot"), -ends_with("_site"))
}
