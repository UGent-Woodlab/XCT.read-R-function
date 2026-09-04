# XCT.read: reading tree-ring width and density data

*A practical guide to the XCT.read R function*

**Louis Verschuren · Vladimir Matskovsky · Jan Van den Bulcke**

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14654939.svg)](https://doi.org/10.5281/zenodo.14654939)

## What does `XCT.read()` do?

`XCT.read()` reads the text files exported by **RingIndicator** and converts them into analysis-ready tree-ring width and X-ray density data.

The function can return:

- annual **ring width**;
- an annual **density parameter** calculated from a selected part of each ring;
- **ring width and density together** in long format;
- the complete **within-ring density profile**; or
- **MXD** values exported from RingIndicator area-of-interest analyses.

The main advantage is that the same RingIndicator exports can be used for several density definitions without having to re-export or manually manipulate the profiles.

`XCT.read()` expects files belonging to the same samples to be together in one folder. For the standard density calculations, filenames are matched by their sample prefix, for example:

``` text
L-722-1_ringwidth.txt
L-722-1_density_corr.txt
L-722-1_zpos_corr.txt
```

### Which RingIndicator files are read

| File | Required for | What it contributes |
|:--|:--|:--|
| `<sample>_ringwidth.txt` | everything | ring width, calendar year, resolution, missing rings, fracture type |
| `<sample>_density_corr.txt` | density outputs | the corrected density profile |
| `<sample>_zpos_corr.txt` | density outputs | the corrected ring boundaries that cut that profile into rings |
| `<sample>_EXCLUDE.txt` | optional | rings the operator took out of densitometry |
| `<sample>_MXD.rwl` | `output = "MXD"` | MXD extracted from areas of interest |

Ring *r* is the wood between boundary *r* and boundary *r*+1, which is the same half-open convention RingIndicator uses for its own annual figures, so the two agree ring for ring.

RingIndicator also writes a `<sample>_density_annual.txt` with its own per-ring mean, minimum and maximum plus `MXD_3D`. `XCT.read()` does not read it: it recomputes from the profile instead, which is what makes the flexible density windows below possible. Use `_density_annual.txt` when you want RingIndicator's own summary, and `XCT.read()` when you want to define the window yourself.

The included `Datafolder` contains example txt files. 

> [!TIP]
> **Most users can start here**
>
> If you want ring width plus the mean density of every ring, the default calculation is enough:
>
> ``` r
> Data <- XCT.read(
>   path = "Datafolder",
>   output = "ringwidth_density",
>   densityType = "fraction",
>   area = c(0, 1),
>   fun = "mean"
> )
> ```


## Setup

Install the required R packages if needed:

``` r
install.packages(c("tidyverse", "dplR"))
```

Load the packages and source the function:

```r
library(tidyverse)
library(dplR)

source("XCT.Read.R")

data_path <- "Datafolder"
```

## Choosing an output

The `output` argument controls the structure returned by `XCT.read()`.

| `output` | What it returns | Typical use |
|----|----|----|
| `"ringwidth"` | Ring-width chronology in `dplR`/RWL-style wide format | Dendrochronological ring-width analyses |
| `"density"` | Annual density parameter in `dplR`/RWL-style wide format | Density chronologies |
| `"ringwidth_density"` | Long table with sample, year, ring width and density | Statistics, plotting and data merging |
| `"density_profile"` | Pixel-level density values within each annual ring | Inspecting within-ring density structure |
| `"MXD"` | MXD chronology read from RingIndicator `*_MXD.rwl` files | Area-of-interest MXD exports |

### Ring width only

```r
RW <- XCT.read(
  path = data_path,
  output = "ringwidth"
)
```

The returned object is convenient for functions in `dplR`: years are row names and individual samples are columns.

### Ring width and density together

For many analyses, `"ringwidth_density"` is the most convenient output because it is already in long format.

```r
RW_density <- XCT.read(
  path = data_path,
  output = "ringwidth_density",
  densityType = "fraction",
  area = c(0.75, 1),
  fun = "mean"
)
```

| Sample | Year | Density | RW |
|:--|--:|--:|--:|
| 2-2-23-1 | 1976 | 788.0560 | 4.9664 |
| 2-2-23-1 | 1977 | 781.5666 | 3.5274 |
| 2-2-23-1 | 1978 | 855.8561 | 0.0140 |
| 2-2-23-1 | 1979 | 858.2529 | 0.0090 |
| 2-2-23-1 | 1980 | 858.2529 | 0.0090 |
| 2-2-23-1 | 1981 | 840.7158 | 1.4911 |

This example defines density as the **mean density in the final 25% of each ring**.

## Defining the density window

A density statistic is only meaningful after defining **which part of the ring** should be used. `XCT.read()` supports two approaches.

### 1. Fraction of each ring

With `densityType = "fraction"`, the window is defined relative to ring width. The ring runs from `0` at its beginning to `1` at its end.

``` text
Ring start                                                          Ring end
0                                                                   1
|----------------|----------------|----------------|----------------|
0              0.25              0.50             0.75              1
                                                   <--------------- >
                                                   area = c(0.75, 1)
```

For example:

``` r
Density_fraction <- XCT.read(
  path = data_path,
  output = "density",
  densityType = "fraction",
  area = c(0.75, 1),
  fun = "mean"
)
```

Because the window scales with the width of every individual ring, `c(0.75, 1)` always means the last quarter, irrespective of whether a ring is narrow or wide.

Common examples are:

| `area`       | Ring section  |
|--------------|---------------|
| `c(0, 1)`    | complete ring |
| `c(0, 0.5)`  | first half    |
| `c(0.5, 1)`  | second half   |
| `c(0.75, 1)` | final quarter |
| `c(0.9, 1)`  | final 10%     |

### 2. Fixed physical width

With `densityType = "fixed"`, the selected window is a fixed number of micrometres from either the beginning or the end of the ring.

For example, the final 100 µm:

``` r
Density_last_100um <- XCT.read(
  path = data_path,
  output = "density",
  densityType = "fixed",
  area = c("end", 100),
  fun = "mean"
)
```

Or the first 200 µm:

``` r
Density_first_200um <- XCT.read(
  path = data_path,
  output = "density",
  densityType = "fixed",
  area = c("start", 200),
  fun = "mean"
)
```

> [!IMPORTANT]
> **Fraction and fixed windows answer different questions**
>
> A **fraction** represents the same relative part of every ring, but its physical width changes with ring width.
>
> A **fixed** window represents the same physical distance in every ring, but it occupies a larger fraction of narrow rings than of wide rings.

## Choosing the density statistic

The `fun` argument determines how the density values inside the selected window are reduced to one value per ring.

| `fun` | Calculation | Example use |
|----|----|----|
| `"mean"` | arithmetic mean | Average earlywood/latewood density |
| `"median"` | median | More robust central density |
| `"min"` | minimum | Minimum density in the selected region |
| `"max"` | maximum | Maximum observed density |
| `"mean_top_x"` | mean of the highest fraction of values | A less pixel-sensitive high-density metric |

### Mean of the highest values

`"mean_top_x"` uses the additional argument `x`. For example, this calculates the mean of the highest 20% of density values found in the final quarter of each ring:

``` r
Density_top20 <- XCT.read(
  path = data_path,
  output = "density",
  densityType = "fraction",
  area = c(0.75, 1),
  fun = "mean_top_x",
  x = 0.20
)
```

This differs from `fun = "max"`: a maximum is determined by one value, whereas `mean_top_x` summarizes a group of high values.

> [!NOTE]
> **Very narrow rings**
>
> A very narrow ring covers few pixels, so its density statistic rests on few values — and with a `fixed` window it can be narrower than the window itself, in which case the whole ring is used. `XCT.read()` reports these rings like any other rather than filtering them, because the threshold is a decision about the analysis, not about the data. Filter them afterwards if you want to:
>
> ``` r
> Data |>
>   mutate(Density = if_else(RW < 0.030, NA_real_, Density))
> ```
>
> A ring the operator judged unmeasurable is a different matter, and belongs in `*_EXCLUDE.txt` where it travels with the sample.

## Rings excluded from densitometry (`*_EXCLUDE.txt`)

In RingIndicator, an operator can take an individual ring out of densitometry when its wood cannot be trusted to give a density — resin, a knot, a stained patch, a damaged surface. Those ring numbers are written to a `*_EXCLUDE.txt` file next to the other exports:

``` text
L-722-1_EXCLUDE.txt
```

The file holds one ring number per line. A ring number is a **position in the ring list**, i.e. the row number in `<sample>_ringwidth.txt`. A core with nothing excluded has no file at all.

`XCT.read()` honours these files by default (`excludeRings = TRUE`):

``` r
Data <- XCT.read(
  path = data_path,
  output = "ringwidth_density"
)
```

An exclusion is a statement about the **density** of that ring and about nothing else, so `XCT.read()` treats it exactly as RingIndicator does:

- the ring keeps its calendar year;
- its **ring width is still reported**;
- its **density is `NA`** — both in the annual density parameter and in the density profile.

The ring is therefore visible in the output as one that could not be measured, rather than silently missing. The example folder ships without exclusions; writing one by hand shows the effect:

``` r
writeLines(c("5", "6", "7"), file.path(data_path, "L-722-1_EXCLUDE.txt"))

XCT.read(data_path, output = "ringwidth_density") |>
  filter(Sample == "L-722-1", Year %in% 1803:1807)
```

| Sample | Year | Density | RW |
|:--|--:|--:|--:|
| L-722-1 | 1803 | 879.5698 | 3.9978 |
| L-722-1 | 1804 | NA | 6.9451 |
| L-722-1 | 1805 | NA | 6.9206 |
| L-722-1 | 1806 | NA | 6.1122 |
| L-722-1 | 1807 | 901.8049 | 5.2415 |

Set `excludeRings = FALSE` to ignore the files and read every ring, which is useful when checking what an exclusion actually removed:

``` r
Compare <- dplyr::full_join(
  XCT.read(data_path, output = "ringwidth_density", excludeRings = FALSE),
  XCT.read(data_path, output = "ringwidth_density", excludeRings = TRUE),
  by = c("Sample", "Year"),
  suffix = c("_all", "_excluded")
)
```

> [!NOTE]
> **Why `XCT.read()` reads the file at all**
>
> RingIndicator already blanks the excluded spans with `NaN` when it writes `*_density_corr.txt`, so a profile exported *after* the exclusions were set is already blank there and this step changes nothing.
>
> The exclusion list can, however, be edited after the densitometry run — or the densitometry run can predate it. In that case the exported profile still contains values for rings the operator has since excluded. Reading `*_EXCLUDE.txt` here makes the R output agree with the operator's intent whichever order the two happened in.

With `verbose = TRUE`, the number of rings read per sample is reported. Ring numbers that no longer exist in the matching `*_ringwidth.txt` — possible with a hand-edited or stale file — are ignored and counted in that summary.

## Resolution handling

Ring width is stored in pixels in the RingIndicator export and converted to physical width using the reported pixel size.

By default, `XCT.read()` uses the resolution stored in the `*_ringwidth.txt` files.

``` r
Data <- XCT.read(
  path = data_path,
  output = "ringwidth_density",
  overruleResolution = FALSE
)
```

### Automatically handling suspicious resolution values

With the default `autoFixWeirdResolution = TRUE`, the function checks for strongly deviating resolution values and can replace obvious factor-of-ten outliers with the most common resolution found among samples.

``` r
Data <- XCT.read(
  path = data_path,
  output = "ringwidth_density",
  autoFixWeirdResolution = TRUE,
  verbose = TRUE
)
```

Keep `verbose = TRUE` when first loading a dataset so that the resolution summary and possible warnings are visible.

### Manually overriding resolution

If you know that all profiles should use a specific resolution, you can force it:

``` r
Data <- XCT.read(
  path = data_path,
  output = "ringwidth_density",
  overruleResolution = TRUE,
  resolution = 1
)
```

Here, `resolution = 1` means **1 µm per pixel**.

> [!WARNING]
> Only override the reported resolution when you know the correct voxel/pixel size. A wrong resolution directly changes calculated ring widths and fixed-width density windows.

## Getting the complete density profile

Use `output = "density_profile"` when you want to analyse or visualise the density variation inside annual rings rather than reducing each ring to a single value.

``` r
Profile <- XCT.read(
  path = data_path,
  output = "density_profile"
)
```

The returned long table contains the sample, year, pixel number along the ring, and density.

## Reading MXD files

When maximum latewood density has already been extracted in RingIndicator using areas of interest, use:

``` r
MXD <- XCT.read(
  path = data_path,
  output = "MXD"
)

head(MXD)
```

This output uses the sample-specific `*_MXD.rwl` files. The combined `ALL_MXD.rwl` file is not needed for this step.

## Function arguments at a glance

| Argument | Purpose | Typical value |
|:--|:--|:--|
| `path` | Folder containing RingIndicator export files | `"Datafolder"` |
| `output` | Choose the returned data structure | `"ringwidth_density"` |
| `densityType` | Use a relative or physical density window | `"fraction"` or `"fixed"` |
| `area` | Start/end of the density window | `c(0.75, 1)` or `c("end", 100)` |
| `fun` | Statistic calculated inside the window | `"mean"` |
| `x` | Highest fraction used by `mean_top_x` | `0.20` |
| `excludeRings` | Honour `*_EXCLUDE.txt`: density of excluded rings returned as `NA` | `TRUE` |
| `overruleResolution` | Force one resolution for all samples | `FALSE` |
| `resolution` | Forced resolution (µm/pixel) | `1` |
| `autoFixWeirdResolution` | Correct obvious factor-of-ten resolution outliers | `TRUE` |
| `verbose` | Print loading and resolution information | `TRUE` |

## A complete analysis example

The following pattern is a good starting point for an analysis script.

``` r
library(tidyverse)
library(dplR)
source("XCT.Read.R")

Data <- XCT.read(
  path = "Datafolder",
  output = "ringwidth_density",
  densityType = "fraction",
  area = c(0.75, 1),
  fun = "mean",
  verbose = TRUE
)

# Inspect the result
summary(Data)

# Rings that have a width but no density: excluded from densitometry,
# blanked by a crack, or with no usable profile span
Data |>
  filter(is.na(Density))

# Plot one sample
sample_to_plot <- Data |>
  count(Sample, sort = TRUE) |>
  slice(1) |>
  pull(Sample)

Data |>
  filter(Sample == sample_to_plot) |>
  ggplot(aes(Year, Density)) +
  geom_line() +
  labs(
    title = paste("Density series:", sample_to_plot),
    x = "Year",
    y = "Density"
  ) +
  theme_minimal()
```

## Troubleshooting

### "No eligible ring width files found"

Check that the folder contains files ending in `_ringwidth.txt` and that `path` points to the correct directory.

### Density output cannot be calculated

For the standard density outputs, each sample should have matching corrected density and ring-position files, normally:

``` text
<sample>_density_corr.txt
<sample>_zpos_corr.txt
<sample>_ringwidth.txt
```

### Some samples disappear

Check the messages printed with `verbose = TRUE`. Differences between sample names across file groups or incomplete exports can prevent matching.

### Density is `NA` for some rings

This is normal and usually intentional. A ring is reported with a width but no density when:

- it is listed in `<sample>_EXCLUDE.txt` (see above) — check with `excludeRings = FALSE`;
- RingIndicator blanked its span in the exported profile, for example a crack or the air filter;
- it has no usable span in `<sample>_density_corr.txt` / `<sample>_zpos_corr.txt`.

### A whole ring is missing from the output

A **border fracture** (break type 2 in `<sample>_ringwidth.txt`) is a spurious sliver at a real ring boundary. It carries no calendar year and no wood, and is dropped. A **mid-ring fracture** (break type 1) splits one ring into three entries; the crack itself is dropped and the two solid halves are reported as the single ring they are.

### Ring widths appear ten times too large or too small

Inspect the resolution summary. Verify the `pixelsize` values in the RingIndicator export and the settings of `autoFixWeirdResolution`, `overruleResolution`, and `resolution`.

`XCT.read()` also warns when a reported resolution falls outside the 0.1–1000 µm/pixel band that RingIndicator itself considers plausible. A value outside that band is almost always a unit mix-up (pixels per centimetre, or DPI, read as µm per pixel) and it rescales every ring width and every fixed-width density window.

## Citation and further information

`XCT.read()` is part of the **UGent-Woodlab X-ray micro-CT tree-ring densitometry workflow**. 

- Project website: <https://dendrochronomics.ugent.be/>
- XCT.read GitHub repository: <https://github.com/UGent-Woodlab/XCT.read-R-function>
- XCT.read Zenodo DOI: <https://doi.org/10.5281/zenodo.14654939>
- XCT Toolchain compiled packages: <https://doi.org/10.5281/zenodo.14677732>
- Pipeline paper: <https://doi.org/10.1016/j.dendro.2025.126343>

When using the XCT toolchain or `XCT.read()` in published work, please cite the relevant software and methods papers:

- [Van den Bulcke et al. (2014)](https://doi.org/10.1016/j.dendro.2013.07.001)
- [De Mil et al. (2016)](https://doi.org/10.1093/aob/mcw063)
- [Van den Bulcke et al. (2019)](https://doi.org/10.1093/aob/mcz126)
- [De Mil & Van den Bulcke (2023)](https://doi.org/10.3791/65208)
- [Verschuren et al. (2025)](https://doi.org/10.1016/j.dendro.2025.126343)

A BibTeX file containing the recommended references is available [here](https://dendrochronomics.ugent.be/downloads/HowToCite.bib).

### Authors

- [Louis Verschuren](https://orcid.org/0000-0002-3102-4588)
- [Vladimir Matskovsky](https://orcid.org/0000-0002-3771-239X)
- [Jan Van den Bulcke](https://orcid.org/0000-0003-2939-5408)

## License

This software is distributed under the **GNU AGPLv3** license. See the repository `LICENSE` file for the full license text.
