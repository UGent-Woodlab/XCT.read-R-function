
#### XCT.read: read XCT Toolchain indication files. version 2026-04-09 ####


XCT.read <- function(
    path,                         # A path to the folder containing the txt files
    output = "ringwidth_density", # "ringwidth", "density", "MXD", "ringwidth_density", "density_profile". This is the output type, it can be "ringwidth" (dplR format of ring width), "density" (dplR format of density parameter), "MXD" (dplR format of MXD, only applicable in the case of MXD extraction by percentile in area of interest),  "ringwidth_density" (long format of the sample, year, ring width, and density), or "density_profile" (long format of the sample, year, and density profile in that year)
    densityType = "fraction",     # "fraction" or "fixed". This is the type of density to calculate. "fraction" calculates the density in a variable width window that corresponds to two fraction numbers that go from 0 (start ring) to 1 (end ring), set in variable area. "fixed" calculates the density in a fixed width window, starting from the beginning or the end of the ring. set in variable area.
    area = c(0.75, 1),            # Fraction window (0-1) or c("start"/"end", microns). This is the fraction of the ring where the density parameter is calculated. If densityType = "fraction" this is a vector of two numbers that go from 0 (start ring) to 1 (end ring). If densityType = "fixed" this is a vector with "start" or "end" as the first variable, and the width of the window in micrometers as the second variable.
    fun = "mean",                 # "mean","median","min","max","mean_top_x". The function to calculate the density in the selected area, can be "mean", "median", "min", "max", or "mean_top_x". "mean_top_x" calculates the mean of the x highest values in the selected area, the variable x should be set to a fraction between 0 and 1.
    x = 0.2,                      # Fraction of the highest values to calculate the mean. Only used if fun = "mean_top_x".
    removeNarrowRings = FALSE,    # TRUE or FALSE. Removes density parameters of rings that are too small, set in minRingWidth. Can be either 
    minRingWidth = 0.030,         # Minimum width of the ring in mm that should be used in density calculations, only if removeNarrowRings = TRUE
    overruleResolution = FALSE,   # Overrule the resolution of the XCT data txts. If TRUE, the resolution of the XCT data is set to the resolution parameter. If FALSE, the resolution is set to the value in the ringwidth.txt file.
    resolution = 1,               # The resolution of the data in µm/pixel. Only used if overruleResolution = TRUE.
    autoFixWeirdResolution = TRUE,# Check and optionally fix weird resolutions (factor 10 off vs most common), TRUE by default
    verbose = TRUE                # Print additional messages about the loading process (e.g. resolution summary)
) {
  
  
  
  # ──────────────────────────────────────────────────────────────────────────
  # 0) Basic input validation + dependency checks
  # ──────────────────────────────────────────────────────────────────────────
  
  # check existence of input path
  if (missing(path) || !is.character(path) || length(path) != 1) {
    stop("`path` must be a single character string pointing to a folder.", call. = FALSE)
  }
  if (!dir.exists(path)) {
    stop(sprintf("Folder not found: '%s'\nCheck the path and try again.", path), call. = FALSE)
  }
  
  # These packages/functions are used throughout; fail early with a helpful message
  required_pkgs <- c("readr", "dplyr", "tidyr", "dplR")
  missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_pkgs) > 0) {
    stop(
      sprintf(
        "Missing required R package(s): %s\nInstall them first, e.g. install.packages(c(%s))",
        paste(missing_pkgs, collapse = ", "),
        paste(sprintf('"%s"', missing_pkgs), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  
  # Validate key arguments
  valid_output <- c("ringwidth", "density", "MXD", "ringwidth_density", "density_profile")
  if (!output %in% valid_output) {
    stop(sprintf("Invalid `output`='%s'. Choose one of: %s",
                 output, paste(valid_output, collapse = ", ")), call. = FALSE)
  }
  
  valid_densityType <- c("fraction", "fixed")
  if (!densityType %in% valid_densityType) {
    stop(sprintf("Invalid `densityType`='%s'. Choose 'fraction' or 'fixed'.", densityType), call. = FALSE)
  }
  
  valid_fun <- c("mean", "median", "min", "max", "mean_top_x")
  if (!fun %in% valid_fun) {
    stop(sprintf("Invalid `fun`='%s'. Choose one of: %s",
                 fun, paste(valid_fun, collapse = ", ")), call. = FALSE)
  }
  if (!is.numeric(x) || length(x) != 1 || is.na(x) || x < 0 || x > 1) {
    stop("`x` must be a single number between 0 and 1.", call. = FALSE)
  }
  if (!is.logical(removeNarrowRings) || length(removeNarrowRings) != 1) {
    stop("`removeNarrowRings` must be TRUE/FALSE.", call. = FALSE)
  }
  if (!is.numeric(minRingWidth) || length(minRingWidth) != 1 || is.na(minRingWidth) || minRingWidth <= 0) {
    stop("`minRingWidth` must be a single positive number (mm).", call. = FALSE)
  }
  if (!is.logical(overruleResolution) || length(overruleResolution) != 1) {
    stop("`overruleResolution` must be TRUE/FALSE.", call. = FALSE)
  }
  if (!is.numeric(resolution) || length(resolution) != 1 || is.na(resolution) || resolution <= 0) {
    stop("`resolution` must be a single positive number (µm/pixel).", call. = FALSE)
  }
  if (!is.logical(autoFixWeirdResolution) || length(autoFixWeirdResolution) != 1) {
    stop("`autoFixWeirdResolution` must be TRUE/FALSE.", call. = FALSE)
  }
  
  
  # ──────────────────────────────────────────────────────────────────────────
  # 1) Discover files and give useful errors if folder is empty / wrong
  # ──────────────────────────────────────────────────────────────────────────
  
  all_txt <- list.files(path, pattern = "\\.txt$", full.names = TRUE)
  if (length(all_txt) == 0) {
    stop(sprintf(
      "No .txt files found in: '%s'\nExpected files like '*_ringwidth.txt', '*_density_corr.txt', '*_zpos_corr.txt'.",
      path
    ), call. = FALSE)
  }
  
  ring_files <- list.files(path, pattern = "_ringwidth\\.txt$", full.names = TRUE)
  if (length(ring_files) == 0) {
    stop(sprintf(
      "No eligible ring width files found in '%s'.\nExpected filenames ending with '_ringwidth.txt'.",
      path
    ), call. = FALSE)
  }
  
  # Density-related outputs require these files
  needs_density <- output %in% c("density", "ringwidth_density", "density_profile")
  dens_files <- list.files(path, pattern = "_density_corr\\.txt$", full.names = TRUE)
  zpos_files <- list.files(path, pattern = "_zpos_corr\\.txt$", full.names = TRUE)
  
  if (needs_density && length(dens_files) == 0) {
    stop(sprintf(
      "Requested output='%s' requires '*_density_corr.txt' files, but none were found in '%s'.",
      output, path
    ), call. = FALSE)
  }
  if (needs_density && length(zpos_files) == 0) {
    stop(sprintf(
      "Requested output='%s' requires '*_zpos_corr.txt' files, but none were found in '%s'.",
      output, path
    ), call. = FALSE)
  }
  
  
  # MXD RWL files
  if (output == "MXD") {
    MXD_files <- list.files(path, pattern = "_MXD\\.rwl$", full.names = TRUE)
    if (length(MXD_files) == 0) {
      stop(sprintf(
        "Requested output='MXD' requires '*_MXD.rwl' files (created using MXD extraction with areas of interest), but none were found in '%s'.",
        path
      ), call. = FALSE)
    }
  }
  
  
  # ──────────────────────────────────────────────────────────────────────────
  # 2) MXD based on RWL files (optional, only if output="MXD"). We read these
  #    first as they don't require resolution info and ringwidth.
  #    - Ignores ALL_MXD.rwl
  #    - Uses long=TRUE only for files that contain years <= -999 (ancient series)
  # ──────────────────────────────────────────────────────────────────────────
  
  if (output == "MXD") {
    
    # Helper: detect "ancient" Tucson-style years (<= -999) from the first token per line.
    # Works by taking the last 4 digits as year and checking if there's a '-' immediately before them.
    is_ancient_rwl <- function(file, cutoff = -999) {
      ln <- readLines(file, n = 80, warn = FALSE)
      if (!length(ln)) return(FALSE)
      
      # take first whitespace-separated token from each line
      tok <- sub("\\s.*$", "", trimws(ln))
      tok <- tok[nzchar(tok)]
      if (!length(tok)) return(FALSE)
      
      parse_year <- function(t) {
        n <- nchar(t)
        if (n < 4) return(NA_integer_)
        last4 <- substr(t, n - 3, n)
        if (!grepl("^\\d{4}$", last4)) return(NA_integer_)
        y <- as.integer(last4)
        sign <- if (n >= 5) substr(t, n - 4, n - 4) else ""
        if (!is.na(y) && sign == "-") y <- -y
        y
      }
      
      yrs <- vapply(tok, parse_year, integer(1))
      any(!is.na(yrs) & yrs <= cutoff)
    }
    
    # Ignore the summary file ALL_MXD.rwl
    MXD_files <- MXD_files[basename(MXD_files) != "ALL_MXD.rwl"]
    
    if (length(MXD_files) == 0) {
      stop(
        "Requested output='MXD' but only 'ALL_MXD.rwl' was found (or no per-sample *_MXD.rwl files remain after filtering).",
        call. = FALSE
      )
    }
    
    MXD_list <- lapply(MXD_files, function(file) {
      sample_name <- sub("_MXD\\.rwl$", "", basename(file))
      
      use_long <- is_ancient_rwl(file)
      
      dat <- tryCatch(
        dplR::read.rwl(
          fname   = file,
          format  = "tucson",
          header  = FALSE,
          long    = use_long,   # <- long=TRUE only for ancient series
          verbose = FALSE
        ),
        error = function(e) {
          message(sprintf("Skipping '%s' due to read.rwl error: %s", basename(file), e$message))
          return(NULL)
        }
      )
      
      if (is.null(dat) || !inherits(dat, "data.frame") || nrow(dat) == 0 || ncol(dat) == 0) {
        message(sprintf("Skipping '%s' because it produced no usable data.", basename(file)))
        return(NULL)
      }
      
      # Convert "0" (NA code) to real NA
      dat[dat == 0] <- NA
      
      
      # name the series like the file name
      colnames(dat) <- sample_name
      
      
      
      dat
    })
    
    MXD_list <- Filter(Negate(is.null), MXD_list)
    
    if (length(MXD_list) == 0) {
      stop(
        "No usable MXD series could be read (all files failed, were empty, or were filtered out).",
        call. = FALSE
      )
    }
    
    MXD <- dplR::combine.rwl(MXD_list)
    return(as.rwl(MXD))
  }
  # ──────────────────────────────────────────────────────────────────────────
  # 3) Read ringwidth files first, because they hold pixelsize (resolution)
  #    We will also do the resolution consistency check here.
  # ──────────────────────────────────────────────────────────────────────────
  
  rings_list <- lapply(ring_files, function(file) {
    sample_name <- sub("_ringwidth\\.txt$", "", basename(file))
    
    # The ringwidth file has comma+space delimiter (", ")
    dat <- readr::read_delim(
      file,
      delim = ", ",
      col_names = c("width", "Year", "pixelsize", "Felldate", "MissingringsBefore", "BrokenRingType"),
      na = "NaN",
      show_col_types = FALSE,
      progress = FALSE
    )
    
    # Add sample id + a row index within this file (used later for joins)
    dat <- dplyr::mutate(dat, Sample = sample_name, row_number = dplyr::row_number())
    
    # Safety: ensure needed columns exist and are numeric where needed
    needed_cols <- c("width", "Year", "pixelsize", "BrokenRingType", "Sample", "row_number")
    missing_cols <- setdiff(needed_cols, names(dat))
    if (length(missing_cols) > 0) {
      stop(sprintf(
        "File '%s' is missing expected columns: %s",
        basename(file), paste(missing_cols, collapse = ", ")
      ), call. = FALSE)
    }
    
    dat
  })
  
  rings <- dplyr::bind_rows(rings_list)
  
  # If everything is NA / empty after reading, fail early
  if (nrow(rings) == 0) {
    stop("Ringwidth files were found but reading them produced no rows. Check file formatting.", call. = FALSE)
  }
  
  
  # ──────────────────────────────────────────────────────────────────────────
  # 3a) Resolution table + optional auto-correction (factor 10 off)
  # ──────────────────────────────────────────────────────────────────────────
  
  # Use one pixelsize per core (Sample). Take the most frequent non-NA per Sample.
  px_by_sample <- rings |>
    dplyr::filter(!is.na(pixelsize)) |>
    dplyr::group_by(Sample) |>
    dplyr::summarise(pixelsize_reported = dplyr::first(pixelsize), .groups = "drop")
  
  # If pixelsize is fully missing, warn (can still proceed if overruleResolution=TRUE)
  if (nrow(px_by_sample) == 0 && !overruleResolution) {
    stop(
      "No non-NA `pixelsize` values found in ringwidth files.\nSet overruleResolution=TRUE and provide `resolution`, or fix the input files.",
      call. = FALSE
    )
  }
  
  # Determine the most common reported resolution among samples
  most_common_px <- NA_real_
  if (nrow(px_by_sample) > 0) {
    tab <- sort(table(px_by_sample$pixelsize_reported), decreasing = TRUE)
    most_common_px <- as.numeric(names(tab)[1])
    
    # Print the requested table: resolutions found + amount of cores
    if (verbose) {
      resolution_table <- data.frame(
        pixelsize_um_per_pixel = as.numeric(names(tab)),
        n_cores = as.integer(tab),
        row.names = NULL
      )
      message("\nResolution summary (reported in *_ringwidth.txt):")
      print(resolution_table)
    }
  }
  
  # Auto-correct weird resolutions if requested and if we are NOT explicitly overruling everything
  if (!overruleResolution && autoFixWeirdResolution && !is.na(most_common_px) && nrow(px_by_sample) > 0) {
    
    px_by_sample <- px_by_sample |>
      dplyr::mutate(
        ratio = pixelsize_reported / most_common_px,
        is_weird = !is.na(ratio) & (ratio >= 10 | ratio <= 0.1),
        pixelsize_used = dplyr::if_else(is_weird, most_common_px, pixelsize_reported)
      )
    
    weird_samples <- px_by_sample |>
      dplyr::filter(is_weird)
    
    if (nrow(weird_samples) > 0) {
      message("\nWARNING: Found cores with a weird resolution (>=10x smaller/larger than the most common).")
      message("These will be loaded using the most common resolution instead (autoFixWeirdResolution=TRUE).")
      message(sprintf("Most common resolution = %s µm/pixel", most_common_px))
      print(weird_samples[, c("Sample", "pixelsize_reported", "pixelsize_used")])
    }
    
    # Apply correction to the rings table
    rings <- rings |>
      dplyr::left_join(px_by_sample[, c("Sample", "pixelsize_used")], by = "Sample") |>
      dplyr::mutate(pixelsize = pixelsize_used) |>
      dplyr::select(-pixelsize_used)
  }
  
  # If user wants to hard-overrule resolution, apply it here (this wins over auto-fix)
  if (overruleResolution) {
    message(sprintf("\nNote: overruleResolution=TRUE → forcing pixelsize=%s µm/pixel for all cores.", resolution))
    rings$pixelsize <- resolution
  }
  
  
  # ──────────────────────────────────────────────────────────────────────────
  # 4) Clean ringwidth data and compute ringwidth in mm (RW)
  # ──────────────────────────────────────────────────────────────────────────
  
  rings <- rings |>
    dplyr::filter(BrokenRingType != 2) |>
    dplyr::group_by(Sample, Year) |>
    dplyr::mutate(width = max(width, na.rm = TRUE)) |>
    dplyr::ungroup() |>
    dplyr::filter(BrokenRingType != 1)
  
  # Convert to mm: width * pixelsize gives microns, divide by 1000 = mm
  rings$RW <- rings$width * rings$pixelsize / 1000
  
  # Output: ringwidth only (does not require density/zpos)
  if (output == "ringwidth") {
    rings_rw <- rings |>
      dplyr::select(Year, Sample, RW) |>
      tidyr::drop_na() |>
      dplyr::group_by(Sample, Year) |>
      dplyr::summarise(RW = max(RW), .groups = "drop") |>
      tidyr::pivot_wider(names_from = "Sample", values_from = "RW") |>
      dplyr::arrange(Year)
    
    # Ensure continuous year index (dplR style)
    rings_rw <- rings_rw |>
      tidyr::complete(Year = seq(min(rings_rw$Year), max(rings_rw$Year), 1))
    
    extent <- as.vector(rings_rw$Year)
    rings_rw$Year <- NULL
    rings_rw <- as.data.frame(rings_rw)
    row.names(rings_rw) <- extent
    return(as.rwl(rings_rw))
  }
  
  # Keep a backup for later "ringwidth_density" join (so RW exists for all rings)
  ringsbackup <- rings
  
  # Optionally remove narrow rings from density calculations (RW is in mm)
  if (removeNarrowRings) {
    rings <- rings |>
      dplyr::filter(RW >= minRingWidth)
  }
  
  # If removal eliminated everything, explain why
  if (nrow(rings) == 0) {
    stop(sprintf(
      "After applying removeNarrowRings=TRUE with minRingWidth=%s mm, no rings remain.\nLower minRingWidth or set removeNarrowRings=FALSE.",
      minRingWidth
    ), call. = FALSE)
  }
  
  
  # ──────────────────────────────────────────────────────────────────────────
  # 5) Read density and zpos files and map density pixels to rings
  # ──────────────────────────────────────────────────────────────────────────
  
  Density_corr <- dplyr::bind_rows(lapply(dens_files, function(file) {
    sample_name <- sub("_density_corr\\.txt$", "", basename(file))
    dat <- readr::read_delim(
      file, delim = "\n", col_names = "Density",
      na = "NaN", show_col_types = FALSE, progress = FALSE
    )
    dplyr::mutate(dat, Sample = sample_name, row_number = dplyr::row_number())
  }))
  
  zpos_corr <- dplyr::bind_rows(lapply(zpos_files, function(file) {
    sample_name <- sub("_zpos_corr\\.txt$", "", basename(file))
    dat <- readr::read_delim(
      file, delim = "\n", col_names = "xpos",
      na = "NaN", show_col_types = FALSE, progress = FALSE
    )
    # A 0-based index so that start/end can be joined as boundaries
    dplyr::mutate(dat, Sample = sample_name, row_number = dplyr::row_number() - 1)
  }))
  
  # Mismatch warning: not fatal, but often indicates incomplete exports
  ring_samples <- sort(unique(rings$Sample))
  dens_samples <- sort(unique(Density_corr$Sample))
  zpos_samples <- sort(unique(zpos_corr$Sample))
  if (!setequal(ring_samples, dens_samples) || !setequal(ring_samples, zpos_samples)) {
    message("\nWARNING: Sample names differ between file groups (ringwidth vs density/zpos).")
    message("This can happen if exports are incomplete. Missing samples will likely be dropped during joins.")
  }
  
  # Merge rings and zpos_corr by Sample and row_number to add start and end pixel positions
  rings <- rings |>
    dplyr::left_join(
      zpos_corr |>
        dplyr::mutate(row_number = row_number + 1) |> # shift for "start"
        dplyr::rename(start = xpos),
      by = c("Sample", "row_number")
    ) |>
    dplyr::left_join(
      zpos_corr |>
        dplyr::rename(end = xpos),
      by = c("Sample", "row_number")
    )
  
  # xpos is the first pixel of the next ring:
  rings$end <- rings$end - 1
  
  
  # Drop incomplete ring boundaries
  rings <- tidyr::drop_na(rings)
  
  if (nrow(rings) == 0) {
    stop(
      "After joining ringwidth with zpos_corr, no valid ring boundaries remain.\nCheck that *_zpos_corr.txt matches *_ringwidth.txt exports.",
      call. = FALSE
    )
  }
  
  # Build a mapping from density pixel rows to (Sample, Year) using start/end ranges
  density_map <- rings |>
    dplyr::select(Sample, Year, start, end, pixelsize) |>
    dplyr::distinct() |>
    dplyr::rowwise() |>
    dplyr::mutate(row_number = list(seq(start, end))) |>
    tidyr::unnest(cols = c(row_number))
  
  Density_corr <- Density_corr |>
    dplyr::left_join(density_map, by = c("Sample", "row_number")) |>
    dplyr::arrange(Sample, row_number) |>
    dplyr::group_by(Sample, Year) |>
    dplyr::mutate(row_number = dplyr::row_number()) |>
    dplyr::ungroup()
  
  # Remove rows not mapped to a ring-year (gaps in density profile)
  Density_corr <- Density_corr[!is.na(Density_corr$Year), ]
  
  if (nrow(Density_corr) == 0) {
    stop(
      "Density data could not be mapped to any rings (no Sample/Year assignments).\nCheck consistency between *_density_corr.txt, *_zpos_corr.txt and *_ringwidth.txt.",
      call. = FALSE
    )
  }
  
  # Output: density profile (long format of pixels along rings)
  if (output == "density_profile") {
    out <- Density_corr |>
      dplyr::select(Sample, Year, row_number, Density) |>
      dplyr::rename(Pixel_nr_along_ring = row_number) |>
      dplyr::arrange(Sample, Year, Pixel_nr_along_ring) |>
      dplyr::group_by(Sample) |>
      dplyr::mutate(row_number_along_sample = dplyr::row_number()) |>
      dplyr::ungroup()
    return(out)
  }
  
  
  # ──────────────────────────────────────────────────────────────────────────
  # 6) Density aggregation helpers + density calculations
  # ──────────────────────────────────────────────────────────────────────────
  
  mean_top_x <- function(vec, x) {
    if (x < 0 || x > 1) stop("x should be a fraction between 0 and 1", call. = FALSE)
    vec <- stats::na.omit(vec)
    n_top <- ceiling(length(vec) * x)
    top_values <- sort(vec, decreasing = TRUE)[1:n_top]
    if (length(top_values) == 0 || all(is.na(top_values))) return(NA_real_)
    mean(top_values, na.rm = TRUE)
  }
  
  calculate_density <- function(density_values, fun, x) {
    if (length(density_values) == 0 || all(is.na(density_values))) return(NA_real_)
    if (fun == "mean") return(mean(density_values, na.rm = TRUE))
    if (fun == "median") return(stats::median(density_values, na.rm = TRUE))
    if (fun == "min") return(min(density_values, na.rm = TRUE))
    if (fun == "max") return(max(density_values, na.rm = TRUE))
    if (fun == "mean_top_x") return(mean_top_x(density_values, x))
    stop("Invalid function specified in `fun` argument.", call. = FALSE)
  }
  
  # Density in fraction window along the ring
  if (densityType == "fraction") {
    if (length(area) != 2 || any(is.na(as.numeric(area))) || area[1] < 0 || area[2] > 1 || area[1] >= area[2]) {
      stop("For densityType='fraction', `area` must be c(startFrac, endFrac) with 0<=start<end<=1.", call. = FALSE)
    }
    
    Density_corr <- Density_corr |>
      dplyr::group_by(Sample, Year) |>
      dplyr::summarise(
        Density = calculate_density(
          Density[
            seq_along(Density) > (area[1] * length(Density)) &
              seq_along(Density) <= (area[2] * length(Density))
          ],
          fun = fun, x = x
        ),
        .groups = "drop"
      )
  }
  
  # Density in fixed micron window from start/end of ring
  if (densityType == "fixed") {
    if (length(area) != 2) {
      stop("For densityType='fixed', `area` must be c('start'/'end', windowMicrons).", call. = FALSE)
    }
    start_or_end <- as.character(area[1])
    lengthMicron <- suppressWarnings(as.numeric(area[2]))
    if (!start_or_end %in% c("start", "end")) {
      stop("For densityType='fixed', area[1] must be 'start' or 'end'.", call. = FALSE)
    }
    if (is.na(lengthMicron) || lengthMicron <= 0) {
      stop("For densityType='fixed', area[2] must be a positive number (microns).", call. = FALSE)
    }
    
    # Convert microns→pixels using the ring's pixelsize (per Sample/Year)
    if (start_or_end == "start") {
      Density_corr <- Density_corr |>
        dplyr::group_by(Sample, Year) |>
        dplyr::summarise(
          Density = calculate_density(
            Density[seq_along(Density) <= round(lengthMicron / dplyr::first(pixelsize))],
            fun = fun, x = x
          ),
          .groups = "drop"
        )
    } else {
      Density_corr <- Density_corr |>
        dplyr::group_by(Sample, Year) |>
        dplyr::summarise(
          Density = calculate_density(
            Density[seq_along(Density) > (length(Density) - round(lengthMicron / dplyr::first(pixelsize)))],
            fun = fun, x = x
          ),
          .groups = "drop"
        )
    }
  }
  
  
  # ──────────────────────────────────────────────────────────────────────────
  # 7) Return formats: density (dplR-like), or combined RW + density
  # ──────────────────────────────────────────────────────────────────────────
  
  if (output == "density") {
    dens <- Density_corr |>
      dplyr::select(Year, Sample, Density) |>
      tidyr::drop_na() |>
      tidyr::pivot_wider(names_from = "Sample", values_from = "Density") |>
      dplyr::arrange(Year) |>
      tidyr::complete(Year = seq(min(Year), max(Year), 1))
    
    extent <- as.vector(dens$Year)
    dens$Year <- NULL
    dens <- as.data.frame(dens)
    row.names(dens) <- extent
    return(as.rwl(dens))
  }
  
  if (output == "ringwidth_density") {
    # For RW we use ringsbackup to keep all rings (even if you removed narrow ones for density)
    rings_rw <- ringsbackup |>
      dplyr::group_by(Sample, Year) |>
      dplyr::summarise(RW = max(RW), .groups = "drop")
    
    out <- Density_corr |>
      dplyr::left_join(rings_rw, by = c("Sample", "Year"))
    
    return(out)
  }
  
  # Should never reach here due to earlier output validation, but keep a guard:
  stop("Internal error: reached end of XCT.read() without returning.", call. = FALSE)
}


