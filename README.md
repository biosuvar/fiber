---
title: Fiber R package
output:
  html_document:
    toc: true
    toc_depth: 3
    number_sections: true
    theme: united
    highlight: tango
---

# Introduction

`fiber` is an R package for the analysis of long-read sequencing detected post-translational modifications. 

# Installation {#instal}

## Prerequisites

Following packages should be installed for the successful usage of the `fiber` package:  

1. Install `devtools` if not installed. Copy commands into your R script and run using either a command line tool or [RStudio](https://www.rstudio.com/):  
```{r}
install.packages('devtools', dependencies = TRUE)
```

2. Install [**Bioconducor**](https://www.bioconductor.org/install/) and its packages if not installed:

```{r}
if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

BiocManager::install("GenomicRanges")
```

## Installation from the gitlab

Install `fiber` from the [github](https://about.github.com/).  

```{r}
require('devtools')
install_github('biosuvar/fiberseq', force = TRUE)
```

## Installation from sources

Alternatively you can download the package and install it from the local directory.  

```{sh}
git clone https://github.com/biosuvar/fiber.git
tar -czvf  fiber.tar.gz fiber
```
Then install from Rstudio.
```{r}
install.packages("fiber", repos = NULL)
```

## Installation for the development

Alternatively you may want to make some changes in the `fiber` package and install it from the local directory to check if your changes work:  
*Note*: this is just an example. Do not run it directly.  

```{r}
library(devtools)
setwd('~/fiber')
rmarkdown::render("README.md", output_format = "html_document")
document()
install.packages('~/fiber', repos = NULL)
```

