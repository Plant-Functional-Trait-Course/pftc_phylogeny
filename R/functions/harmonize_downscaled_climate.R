#' Harmonize the hourly climate extract to trait/community keys.
#'
#' Adds `country`, `gradient`, `site`, and a trait-matching `plot_id` so the hourly
#' climate (`hourly_climate`) can be joined to community and trait data.

#' Add `country`, `gradient`, `site`, and trait-matching `plot_id` from raw `area` / `plot_id`.
#'
#' `site` strings match those built in [cleaning_functions.R] (e.g. `no_Liahovden`,
#' `co_CBT`, `pe_B_ACJ`, `sv_C_2`). Svalbard N/B plots and Peru NB/BB bands are
#' dropped (`site` is `NA`). Peru uses `gradient = "C"` like other regions.
#'
#' @return Input plus `area_raw`, `plot_id_raw`, `country`, `gradient`, `site`, `plot_id`.
downscaled_climate_add_site_keys <- function(dat) {
  dat |>
    rename(area_raw = area, plot_id_raw = plot_id) |>
    mutate(
      country = recode_values(
        area_raw,
        "China" ~ "ch",
        "Colorado" ~ "co",
        "Norway" ~ "no",
        "Peru" ~ "pe",
        "SouthAfrica" ~ "sa",
        "Svalbard" ~ "sv"
      )
    ) |>
    mutate(
      site = pmap_chr(list(country, plot_id_raw), dc_trait_site_chr),
      gradient = pmap_chr(list(country, plot_id_raw), dc_trait_gradient_chr)
    ) |>
    mutate(
      plot_id = pmap_chr(
        list(country, site, gradient, plot_id_raw),
        dc_trait_plot_id_chr
      )
    )
}


#' Trait/community `plot_id` used to join climate at plot resolution.
#'
#' China community uses a `-C` suffix on control turfs; climate and traits use the
#' base id (e.g. `ch_A1`).
bio_climate_plot_id <- function(country, plot_id) {
  dplyr::if_else(
    country == "ch",
    stringr::str_remove(plot_id, "-C$"),
    plot_id
  )
}


dc_trait_plot_id_chr <- function(cnt, site, grad, raw) {
  if (any(is.na(c(cnt, site, raw)))) {
    return(NA_character_)
  }

  if (cnt == "co") {
    num <- stringr::str_extract(raw, "[0-9]+$")
    if (is.na(num)) {
      return(NA_character_)
    }
    return(paste0(site, "_", num))
  }

  if (cnt == "ch") {
    m <- stringr::str_match(raw, "^CH_([AMLH])([0-9]+)")
    if (any(is.na(m[1, ]))) {
      return(NA_character_)
    }
    return(paste0("ch_", m[1, 2], m[1, 3]))
  }

  if (cnt == "no") {
    turf <- dplyr::case_when(
      stringr::str_detect(raw, "^NO_Hog_") ~ stringr::str_remove(raw, "^NO_Hog_"),
      stringr::str_detect(raw, "^NO_Joa_") ~ stringr::str_remove(raw, "^NO_Joa_"),
      stringr::str_detect(raw, "^NO_Lia_") ~ stringr::str_remove(raw, "^NO_Lia_"),
      stringr::str_detect(raw, "^NO_Vik_") ~ stringr::str_remove(raw, "^NO_Vik_"),
      TRUE ~ NA_character_
    )
    if (is.na(turf)) {
      return(NA_character_)
    }
    return(paste0(site, "_", turf))
  }

  if (cnt == "pe") {
    core <- stringr::str_sub(raw, 4L)
    parts <- stringr::str_split(core, "_")[[1]]
    n <- length(parts)
    if (n < 3L) {
      return(NA_character_)
    }
    band <- parts[n - 1L]
    num <- parts[n]
    if (!band %in% c("B", "C")) {
      return(NA_character_)
    }
    return(paste0(band, "_", site, "_", num))
  }

  if (cnt == "sa") {
    m <- stringr::str_match(raw, "^SA_(\\d+)(east|west)(\\d+)$")
    if (any(is.na(m[1, ]))) {
      return(NA_character_)
    }
    return(paste0(site, "_", m[1, 4]))
  }

  if (cnt == "sv") {
    core <- stringr::str_remove(raw, "^SV_")
    m <- stringr::str_match(core, "^C(\\d+)([A-Z])$")
    if (any(is.na(m[1, ]))) {
      return(NA_character_)
    }
    return(paste0("C_", site, "_", m[1, 3]))
  }

  NA_character_
}


dc_trait_site_chr <- function(cnt, raw) {
  if (is.na(cnt) || is.na(raw)) {
    return(NA_character_)
  }
  dc_trait_site_gradient(cnt, raw)$site
}


dc_trait_gradient_chr <- function(cnt, raw) {
  if (is.na(cnt) || is.na(raw)) {
    return(NA_character_)
  }
  dc_trait_site_gradient(cnt, raw)$gradient
}


dc_trait_site_gradient <- function(cnt, raw) {
  out <- list(site = NA_character_, gradient = NA_character_)
  if (is.na(cnt) || is.na(raw)) {
    return(out)
  }

  if (cnt == "ch") {
    # CH_H1 and CH_HO1 (etc.) both map to ch_H, ch_A, ch_L, ch_M
    m <- str_match(raw, "^CH_([AMLH])O?")
    if (!is.na(m[1, 2])) {
      out$site <- paste0("ch_", m[1, 2])
      out$gradient <- "C"
    }
    return(out)
  }

  if (cnt == "co") {
    out$gradient <- "C"
    out$site <- case_when(
      str_detect(raw, "^US_cbt") ~ "co_CBT",
      str_detect(raw, "^US_almont") ~ "co_Almont",
      str_detect(raw, "^US_cinnamon") ~ "co_Cinnamon",
      str_detect(raw, "^US_pfeiler") ~ "co_Pfeiler",
      str_detect(raw, "^US_road") ~ "co_Road",
      str_detect(raw, "^US_pbm") ~ "co_PBM",
      TRUE ~ NA_character_
    )
    return(out)
  }

  if (cnt == "no") {
    out$gradient <- "C"
    out$site <- case_when(
      str_detect(raw, "^NO_Lia_") ~ "no_Liahovden",
      str_detect(raw, "^NO_Joa_") ~ "no_Joasete",
      str_detect(raw, "^NO_Hog_") ~ "no_Hogsete",
      str_detect(raw, "^NO_Vik_") ~ "no_Vikesland",
      TRUE ~ NA_character_
    )
    return(out)
  }

  if (cnt == "pe") {
    return(pe_trait_site_gradient_from_raw(raw))
  }

  if (cnt == "sa") {
    return(sa_trait_site_gradient_from_raw(raw))
  }

  if (cnt == "sv") {
    return(sv_trait_site_gradient_from_raw(raw))
  }

  out
}


pe_trait_site_gradient_from_raw <- function(raw) {
  out <- list(site = NA_character_, gradient = NA_character_)
  if (!str_detect(raw, "^PE_")) {
    return(out)
  }
  core <- str_sub(raw, 4L)
  parts <- str_split(core, "_")[[1]]
  n <- length(parts)
  if (n < 3L) {
    return(out)
  }
  band <- parts[n - 1L]
  if (band %in% c("NB", "BB")) {
    return(out)
  }
  if (!band %in% c("B", "C")) {
    return(out)
  }
  sitecode <- str_flatten(parts[seq_len(n - 2L)], collapse = "_")
  out$site <- paste0("pe_", band, "_", sitecode)
  out$gradient <- "C"
  out
}


sa_trait_site_gradient_from_raw <- function(raw) {
  out <- list(site = NA_character_, gradient = NA_character_)
  m <- str_match(raw, "^SA_(\\d+)(east|west)")
  if (any(is.na(m[1, ]))) {
    return(out)
  }
  elev <- m[1, 2]
  asp <- m[1, 3]
  lu <- c(`2000` = 1L, `2200` = 2L, `2400` = 3L, `2600` = 4L, `2800` = 5L)
  sid <- lu[[elev]]
  if (is.na(sid)) {
    return(out)
  }
  out$site <- paste0("sa_", sid)
  out$gradient <- if (asp == "east") "E" else "W"
  out
}


sv_trait_site_gradient_from_raw <- function(raw) {
  out <- list(site = NA_character_, gradient = NA_character_)
  core <- str_remove(raw, "^SV_")
  if (str_detect(core, regex("^ITEX", ignore_case = TRUE))) {
    return(out)
  }
  if (str_detect(core, "^C\\d+")) {
    m <- str_match(core, "^C(\\d+)")
    if (!is.na(m[1, 2])) {
      out$site <- paste0("sv_C_", m[1, 2])
      out$gradient <- "C"
    }
    return(out)
  }
  out
}


