

#### make XCT.read function ####
XCT.read <- function(path,# A path to the folder containing the txt files
                     output = "ringwidth_density", # The output type, can be "ringwidth" (dplR format of ring width), "density" (dplR format of density parameter), "ringwidth_density" (long format of the sample, year, ring width, and density), or "density_profile" (long format of the sample, year, and density profile in that year)
                     densityType = "fraction", # The type of density to calculate, can be "fraction" or "fixed". "fraction" calculates the density in a variable width window that corresponds to two fraction numbers that go from 0 (start ring) to 1 (end ring), set in variable area. "fixed" calculates the density in a fixed width window, starting from the beginning or the end of the ring. set in variable area.
                     area = c(0.75, 1), # Fraction of the ring to calculate the density parameter. If densityType = "fraction" this is a vector of two numbers that go from 0 (start ring) to 1 (end ring). If densityType = "fixed" this is a vector with "start" or "end" as the first variable, and the width of the window in micrometers as the second variable.
                     fun = "mean", # The function to calculate the density in the selected area, can be "mean", "median", "min", "max", or "mean_top_x". "mean_top_x" calculates the mean of the x highest values in the selected area, the variable x should be set to a fraction between 0 and 1.
                     x = 0.2,  # Fraction of the highest values to calculate the mean. Only used if fun = "mean_top_x".
                     removeNarrowRings = FALSE, # Removes density parameters of rings that are too small, set in minRingWidth. Can be either TRUE or FALSE.
                     minRingWidth = 0.030 #  Minimum width of the ring in mm that should be used in density calculations, only if removeNarrowRings = TRUE
){
  
  
  
  
  
  # Load all ringwidth.txt files
  files <- list.files(path, pattern = "_ringwidth.txt", full.names = TRUE)
  
  # Function to read each file, add the file name, and combine all into one data frame
  rings <- lapply(files, function(file) {
    # Extract the file name before "_density_corr"
    file_name <- sub("_ringwidth.txt$", "", basename(file))
    
    # Read the file, treat "NaN" as NA, and specify numeric columns
    data <- read_delim(file, delim = ", ", 
                       col_names = c("width", "Year", "pixelsize", "Felldate", "MissingringsBefore", "BrokenRingType"),
                       na = "NaN", show_col_types = FALSE)  
    # Add the file name as a new column
    data <- data %>% mutate(Sample = file_name, row_number = row_number())
    data <- data %>% filter(BrokenRingType != 2) # remove type 2 broken rings rows
    data <- data %>% group_by(Year) %>% mutate(width = max(width)) %>% ungroup() # set ringwidth to the max ringwidth: relevant for ring a type 1 broken ring present
    data <- data %>% filter(BrokenRingType != 1) # remove type 1 broken rings rows
    data$RW <- data$width * data$pixelsize /1000 # calculate ring width in mm
    return(data)
  }) %>% bind_rows() # Combine all data frames into one
  
  if (output == "ringwidth") {
    # Return the ring width data frame in dplR format
    rings <- rings[, c("Year", "Sample", "RW")]
    rings <- rings %>% na.omit()
    rings <- rings %>% group_by(Sample, Year) %>% summarise(RW = max(RW), .groups = "drop") # merge duplicate rows (relevant for type 1 broken rings)
    rings <- pivot_wider(rings, names_from = "Sample", values_from = "RW")
    rings <- rings %>% arrange(Year)
    rings <- rings %>% complete(Year = seq(min(rings$Year), max(rings$Year), 1)) # insert NA column in years that are skipped so there is a column for each year
    extent <- as.vector(rings$Year) # year extent data
    rings$Year <- NULL # delete year column
    row.names(rings) <- extent # change row names to years
    return(rings)
  }
  
  
  
  # Load all _density_corr.txt files
  files <- list.files(path, pattern = "_density_corr.txt", full.names = TRUE)
  
  # Function to read each file, add the file name, and combine all into one data frame
  Density_corr <- lapply(files, function(file) {
    # Extract the file name before "_density_corr"
    file_name <- sub("_density_corr.txt$", "", basename(file))
    
    # Read the file, treat "NaN" as NA
    data <- read_delim(file, delim = "\n", col_names = "Density", na = "NaN",  show_col_types = FALSE)
    
    # Add the file name as a new column
    data <- data %>% mutate(Sample = file_name, row_number = row_number())
    
    return(data)
  }) %>% bind_rows() # Combine all data frames into one
  
  
  
  
  # Load all _zpos_corr files
  files <- list.files(path, pattern = "_zpos_corr.txt", full.names = TRUE)
  
  # Function to read each file, add the file name, and combine all into one data frame
  zpos_corr <- lapply(files, function(file) {
    # Extract the file name before "_density_corr"
    file_name <- sub("_zpos_corr.txt$", "", basename(file))
    
    # Read the file, treat "NaN" as NA
    data <- read_delim(file, delim = "\n", col_names = "xpos", na = "NaN",  show_col_types = FALSE)
    
    # Add the file name as a new column
    data <- data %>% mutate(Sample = file_name, row_number = row_number()-1)
    
    return(data)
  }) %>% bind_rows() # Combine all data frames into one
  
  
  
  
  # Merge rings and zpos_corr by Sample and row_number to add start and end columns
  rings <- rings %>%
    left_join(zpos_corr %>% 
                mutate(row_number = row_number + 1) %>% # Shift row_number for "start"
                rename(start = xpos), 
              by = c("Sample", "row_number")) %>%
    left_join(zpos_corr %>% rename(end = xpos), by = c("Sample", "row_number"))
  rings$start <- rings$start + 1 # first pixel is the pixel after the end of the last one, otherwise this pixel is accounted twice
  rings <- rings %>% na.omit()   # remove NAs
  ringsbackup <- rings
  if (removeNarrowRings) {
    rings <- rings %>% filter(RW >= minRingWidth)  # remove rings with width smaller than minRingWidth
  }
  
  
  
  # put year and Sample in density_corr
  density_map <- rings %>% # Create a helper data frame to link `Density_corr` with `rings`, This creates a mapping of Sample, Year, and the range of row_numbers for each ring
    select(Sample, Year, start, end) %>%
    distinct() %>%
    rowwise() %>%
    mutate(row_number = list(seq(start, end))) %>%  # Generate a sequence for each range
    unnest(cols = c(row_number))  # Expand each sequence to individual rows
  Density_corr <- Density_corr %>%   # Join this mapping to `Density_corr` by Sample and row_number
    left_join(density_map, by = c("Sample", "row_number")) %>%
    arrange(Sample, row_number) %>%
    group_by(Sample, Year) %>%
    mutate(row_number = row_number()) %>% # Recalculate row_number continuously within each ring
    ungroup()
  Density_corr <- Density_corr[!is.na(Density_corr$Year),]   # remove NAs (gaps in density profile)
  
  
  if (output == "density_profile") {
    # Return the density profile data frame in long format
    Density_corr <- Density_corr[, c("Sample", "Year", "row_number", "Density")] %>% 
      rename(Pixel_nr_along_ring = row_number)   %>%  
      arrange(Sample, Year, Pixel_nr_along_ring) %>%
      group_by(Sample) %>% mutate(row_number_along_sample = row_number()) %>% ungroup()    # extra column that gives the pixel number along one whole sample
    return(Density_corr)
  }
  
  
  
  
  
  # Function to calculate the mean of the top x values in a vector
  mean_top_x <- function(vec, x) {
    # Ensure x is between 0 and 100
    if (x < 0 || x > 1) {
      stop("x should be a fraction between 0 and 1")}
    # Remove any NA values
    vec <- na.omit(vec)
    # Calculate the number of top values to consider
    n_top <- ceiling(length(vec) * x)
    # Sort the vector in descending order and take the top n values
    top_values <- sort(vec, decreasing = TRUE)[1:n_top]
    # Calculate and return the mean of the top values
    return(ifelse( !all(is.na(top_values)), mean(top_values, na.rm=TRUE), NA))
  }
  
  
  # Custom function for calculating the density based on `fun` parameter
  calculate_density <- function(density_values, fun, x) {
    if (fun == "mean") {
      return(ifelse( !all(is.na(density_values)), mean(density_values, na.rm=TRUE), NA))
    } else if (fun == "median") {
      return(ifelse( !all(is.na(density_values)), median(density_values, na.rm=TRUE), NA))
    } else if (fun == "min") {
      return(ifelse( !all(is.na(density_values)), min(density_values, na.rm=TRUE), NA))
    } else if (fun == "max") {
      return(ifelse( !all(is.na(density_values)), max(density_values, na.rm=TRUE), NA))
    } else if (fun == "mean_top_x") {
      # Use mean_top_x function for the top x% of values
      return(mean_top_x(density_values, x))
    } else {
      stop("Invalid function specified in `fun` argument.")
    }
  }
  
  
  # calculate density of fraction
  if (densityType == "fraction") {
    Density_corr <- Density_corr %>%
      group_by(Sample, Year) %>%
      summarise(
        Density = calculate_density(Density[seq_along(Density) > ((area[1]) * length(Density)) & seq_along(Density) <= ((area[2]) * length(Density))], fun = fun, x = x),
        .groups = "drop"  # Ungroups the output completely
      )
  }
  
  
  # calculate density in fixed area
  if (densityType == "fixed") {
    start_or_end <- area[1]
    lengthMicron <- as.numeric(area[2])
    if (start_or_end == "start") {
      Density_corr <- Density_corr %>%
        group_by(Sample, Year) %>%
        summarise(
          Density = calculate_density(Density[seq_along(Density) <= round(lengthMicron / (mean(rings$pixelsize)))], fun = fun, x = x),
          .groups = "drop"  # Ungroups the output completely
        )
    }
    if (start_or_end == "end") {
      Density_corr <- Density_corr %>%
        group_by(Sample, Year) %>%
        summarise(
          Density = calculate_density(Density[seq_along(Density) > (length(Density) - round(lengthMicron / (mean(rings$pixelsize))))], fun = fun, x = x),
          .groups = "drop"  # Ungroups the output completely
        )
    }
  }
  
  
  if (output == "density") {
    # Return the density data frame in dplR format
    Density_corr <- Density_corr[, c("Year", "Sample", "Density")]
    Density_corr <- Density_corr %>% na.omit()
    Density_corr <- pivot_wider(Density_corr, names_from = "Sample", values_from = "Density")
    Density_corr <- Density_corr %>% arrange(Year)
    Density_corr <- Density_corr %>% complete(Year = seq(min(Density_corr$Year), max(Density_corr$Year), 1)) # insert NA column in years that are skipped so there is a column for each year
    extent <- as.vector(Density_corr$Year) # year extent data
    Density_corr$Year <- NULL # delete year column
    row.names(Density_corr) <- extent # change row names to years
    return(Density_corr)
  }
  
  if (output == "ringwidth_density") {
    # Return the ring width and density data frame in long format
    rings <- ringsbackup  %>%  group_by(Sample, Year) %>% summarise(RW = max(RW), .groups = "drop")  # merge duplicate rows (relevant for type 1 broken rings)
    Data <- Density_corr %>% left_join(rings %>% select(Sample, Year, RW), by = c("Sample", "Year"))
    return(Data)
  }
  
}
