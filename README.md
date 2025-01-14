<p align="center">
    <h1 align="center">XCT.read</h1>
</p>

[Verschuren, Louis![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0002-3102-4588)[^aut][^cre][^UG-WL];
[Matskovsky, Vladimir![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0002-3771-239X)[^aut][^UG-WL];
[Van den Bulcke, Jan![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0003-2939-5408)[^aut][^UG-WL]

[^aut]: author
[^cre]: contact person
[^UG-WL]: UGent-Woodlab



This is the repository for the XCT.Read R-function. This function was created to easily read and calculate ring width and density parameters using the txt-formatted ring indications and density profile output from the MATLAB-based [RingIndicator software](https://dendrochronomics.ugent.be/), created at UGent-Woodlab. The section of the profile where a density parameter is calculated can be set by the user: either a fraction of the ring (e.g. the second quarter of each ring) or a fixed width (e.g. the last 100 µm of each ring). The output of the function is a dplR or a long format data frame.


#####  Table of Contents

- [ XCT.read](#function-xctreadr)
- [ Example use](#example-use-xctreadrmd)
- [ Test data](#test-data-folder)
- [ Getting Started](#getting-started)
- [ Cite our work](#cite-our-work)
- [ License](#license)

---

##  Function: XCT.Read.R
bla 

---

## Example use: XCT.Read.Rmd
bla

---

## Test data folder
bla
---

## Getting started

Before running the function, ensure that you have the following packages installed and loaded:
library("tidyverse")
library("dplR")
dplR is not used within the function itself but is needed to process the output which can be set to dplR dataframe. 

---

## Cite our work

You can find the paper where the entire pipeline is described [here](TO DO), or cite our work with the following bibtex snippet:

```tex
TODO
```

When using any of the software, also cite the proper Zenodo DOI ([here for analysis](https://doi.org/10.5281/zenodo.14637855) and [here for imaging](https://doi.org/10.5281/zenodo.14637832)) related to the releases of the software.

---

##  License

This software is protected under the [GNU AGPLv3](https://choosealicense.com/licenses/agpl-3.0/) license. 

---
