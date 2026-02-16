<p align="center">
    <h1 align="center">XCT.read</h1>
</p>



[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14654939.svg)](https://doi.org/10.5281/zenodo.14654939)



[Verschuren, Louis![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0002-3102-4588)[^aut][^cre][^UG-WL];
[Matskovsky, Vladimir![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0002-3771-239X)[^aut][^UG-WL];
[Van den Bulcke, Jan![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0003-2939-5408)[^aut][^UG-WL]

[^aut]: author
[^cre]: contact person
[^UG-WL]: UGent-Woodlab



This is the repository for the XCT.Read R-function. This function was created to easily read and calculate ring width and density parameters using the txt-formatted ring indications and density profile output from the MATLAB-based [RingIndicator software](https://github.com/UGent-Woodlab/XCT-toolchain-compiled), created at UGent-Woodlab (more info on our [website](https://dendrochronomics.ugent.be/) and in [this paper](https://doi.org/10.1016/j.dendro.2025.126343)). The section of the profile where a density parameter is calculated can be set by the user: either a fraction of the ring (e.g. the second quarter of each ring) or a fixed width (e.g. the last 100 µm of each ring). The output of the function is a dplR or a long format data frame.



#####  Table of Contents

- [ XCT.Read](#function-xctreadr)
- [ Example use](#example-use-xctreadrmd)
- [ Test data](#test-data-folder)
- [ Getting Started](#getting-started)
- [ Cite our work](#cite-our-work)
- [ License](#license)

---

##  Function: XCT.Read.R
XCT.Read function reads and calculates ring width and density parameters from txt-formatted ring indications and density profile output. The parameters are: 
- path: A path to the folder containing the txt files. 
- output: The output type, can be "ringwidth" (dplR format of ring width), "density" (dplR format of density parameter), "ringwidth_density" (long format of the sample, year, ring width, and density), or "density_profile" (long format of the sample, year, and density profile in that year)
- densityType: The type of density to calculate, can be "fraction" or "fixed". "fraction" calculates the density in a variable width window that corresponds to two fraction numbers that go from 0 (start ring) to 1 (end ring), set in variable area. "fixed" calculates the density in a fixed width window, starting from the beginning or the end of the ring. set in variable area.
- area: Fraction of the ring to calculate the density parameter. If densityType = "fraction" this is a vector of two numbers that go from 0 (start ring) to 1 (end ring). If densityType = "fixed" this is a vector with "start" or "end" as the first variable, and the width of the window in micrometers as the second variable.
- fun: The function to calculate the density in the selected area, can be "mean", "median", "min", "max", or "mean_top_x". "mean_top_x" calculates the mean of the x highest values in the selected area, the variable x should be set to a fraction between 0 and 1.
- x: Fraction of the highest values to calculate the mean. Only used if fun = "mean_top_x".
- removeNarrowRings: Removes density parameters of rings that are too small, set in minRingWidth. Can be either TRUE or FALSE.
- minRingWidth: Minimum width of the ring in mm that should be used in density calculations, only if removeNarrowRings = TRUE.
- overruleResolution: Overrule the resolution of the XCT data txts. If TRUE, the resolution of the XCT data is set to the resolution parameter. If FALSE, the resolution is set to the value in the ringwidth.txt file.
- resolution: The resolution of the data in µm/pixel. Only used if overruleResolution = TRUE.


---

## Example use: XCT.Read.Rmd
An example R Markdown file that showcases the different possible outputs and calculations. 

---

## Test data folder
Some example txt indication files. 

---

## Getting started

Before running the function, ensure that you have the following packages installed and loaded:
- library("tidyverse")
- library("dplR")

dplR is not used within the function itself but is needed to process the output which can be set to dplR dataframe. 

---

## Cite our work

You can find the paper where the entire pipeline is described [here](https://doi.org/10.1016/j.dendro.2025.126343). Please cite the following papers when using our toolchain or software: [Van den Bulcke et al. 2014](https://doi.org/10.1016/j.dendro.2013.07.001), [De Mil et al. 2016](https://doi.org/10.1093/aob/mcw063), [Van den Bulcke et al. 2019](https://doi.org/10.1093/aob/mcz126), [De Mil and Van den Bulcke 2023](https://dx.doi.org/10.3791/65208), and [Verschuren et al. 2025](https://doi.org/10.1016/j.dendro.2025.126343).

When using the software, also cite the proper Zenodo DOI: [XCT Toolchain compiled packages](https://doi.org/10.5281/zenodo.14677732) and [XCT.Read R function](https://doi.org/10.5281/zenodo.14654939). 

A bib file of all these can be downloaded [here](https://dendrochronomics.ugent.be/downloads/HowToCite.bib).

---

##  License

This software is protected under the [GNU AGPLv3](https://choosealicense.com/licenses/agpl-3.0/) license. 

---
