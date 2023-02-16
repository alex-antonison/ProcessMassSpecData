Processed Data
================
2023-02-14

``` r
path_list <- fs::path_split(getwd())[[1]]
path_length <- length(path_list)
path_minus_docs <- path_list[1:(path_length - 1)]
path <- fs::path(path_minus_docs)
project_path <- fs::path_join(path)
knitr::opts_knit$set(root.dir = project_path)
```

This RMarkdown file is an example of how to upload source files to the
collaboration bucket.

1.  First, you need to create a `.Renviron` file from the
    `.Renviron-template` file and request access keys from
    `alex@antonison-cg.com`.
2.  Once that is created, you can source the R function
    `upload_file_to_s3` function from `source("R/PutSourceData.R")`
3.  This function takes two arguments
    1.  The first being the path to the file from the main project
        direct.
    2.  The second being the name of the file.

This will upload the file to a similar path in S3. For consistency,
please place all source files in the `data/source/` directory.

``` r
source("R/PutSourceData.R")
returnValue <- upload_file_to_s3("data/source/", "Extraction_Batches_source.xlsx")
```