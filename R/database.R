#' Create empty database according to the base scheme.
#' @param db_dir Output directory where to create the SQLite database.
#' @param db_name Name of the SQLite database.
#' @export

create_database <- function(
    db_dir = NULL, 
    db_name = NULL)
{
  require(DBI)
  require(RSQLite)
  
  if (is.null(db_dir)) {
    stop("Output directory is not specified.")
  }
  
  if (is.null(db_name)) {
    db_name <- 'database'
  }
  
  #FIXME Create directory
  # create database
  db <- dbConnect(RSQLite::SQLite(), paste0(db_dir, "/", db_name, ".db"))
  
  # execute sql commands from file
  file <- system.file("sql", "database_schema.sql", package = "fiber")
  queries <- paste(readLines(file), collapse = " ")
  queries <- unlist(strsplit(queries, "(?<=;)", perl = TRUE))
  silent <- lapply(queries, function(qry) {DBI::dbExecute(db, qry)})
  
  dbDisconnect(db)
}


#' Save configuration file template in a user directory.
#' @param outdir Output directory where to save the template of
#'               the configuration yaml file.
#' @export

get_config <- function(outdir = NULL)
{
  if (is.null(outdir)) { 
    stop("Output directory is not specified.") 
  }
  
  # create output directory
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  # get file from the package
  file <- system.file("yaml", "configuration.yaml", package = "fiber")
  # copy file from the package to the user directory
  file.copy(file, outdir)
}

#' Read configuration yaml file into data frame
#' @param db Path to database
#' @param yaml Path to the configuartion yaml file.
#' @export

#TODO test if NULL data in yaml for NULL allowed column in tables
insert_config_db <- function(
    database = NULL,
    config_yaml = NULL)
{
  require(yaml)
  require(data.table)
  
  if (is.null(config_yaml)) {
    stop("Configuration yaml file is not specified.")
  }
  
  config_data <- yaml::read_yaml(config_yaml)
  
  # insert run_data into the database
  run_data <- as.data.table(config_data$run_data)
  
  db <- dbConnect(RSQLite::SQLite(), database)
  dbSendQuery(db, 
    'INSERT INTO "run_data" (
      [run_name], 
      [run_date], 
      [sequencing_platform], 
      [sequencing_software], 
      [sequencing_software_version], 
      [author_name], 
      [run_description]) 
    VALUES (
      :run_name, 
      :run_date, 
      :sequencing_platform,
      :sequencing_software,
      :sequencing_software_version,
      :author_name,
      :run_description);', run_data )

  # insert sample data
  samples <- config_data$samples

  lapply(samples, function(sample) {
    sample_data <- as.data.table(sample)
    dbSendQuery(db, 
      'INSERT INTO "sample_data" (
        [run_id],
        [sample_name],
        [sampling_date],
        [library_kit],
        [barcode_name],
        [mapping_tool],
        [mapping_tool_version],
        [modification_calling_tool],
        [modification_calling_tool_version],
        [modification_calling_model_name],
        [sample_description],
        [reference_genome] )
      VALUES (
        1,
        :sample_name,
        :sampling_date,
        :library_kit,
        :barcode_name,
        :mapping_tool,
        :mapping_tool_version,
        :modification_calling_tool,
        :modification_calling_tool_version,
        :modification_calling_model_name,
        :sample_description,
        :reference_genome);', sample_data )
  })

  dbDisconnect(db)
}

#' Insert chromosome data from bam file into the database
#' @param database Path to database.
#' @param bam Path to bamfile.
#' @export

insert_bam_db <- function(
    database = NULL,
    bam = NULL)
{
  require(Rsamtools)
  
  bamr <- Rsamtools::BamFile(bam)
  
  # Insert chromosomes into database
  seqinfo <- Rsamtools::seqinfo(bamr)
  
  seqinfo_df <- data.frame(
    chromosome_name   = seqnames(seqinfo),
    chromosome_length = seqlengths(seqinfo) )
  
  db <- dbConnect(RSQLite::SQLite(), database)
  dbSendQuery(db, 
    'INSERT INTO "chromosomes" (
      [chromosome_name], 
      [chromosome_length] ) 
    VALUES (
      :chromosome_name, 
      :chromosome_length);', seqinfo_df)
  
  # Parameters for reading bam
  param <- Rsamtools::ScanBamParam(
    what = c("qname",  # read name 
             "rname",  # chromosome name
             "strand", # strand
             "pos",    # leftmost position
             "qwidth", # read length
             "mapq" )) # mapping quality
  
  # chosen data from the bam file
  bam_data <- as.data.table(Rsamtools::scanBam(bam, param = param)[[1]])
  
  #FIXME DEBUG How to deal with sample_names? each bam came from sample?
  sample_name <- "sample01"
  # calc read end, convert strand to integer
  bam_data <- bam_data[, end := pos + qwidth
                       ][strand == "+", strand_int := 1
                         ][strand == "-", strand_int := -1
                           ][strand == "*", strand_int := 0
                             ][, sample := sample_name
                               ][, .(qname, rname, pos, end, strand_int, mapq, sample)]
  
  dbSendQuery(db, 
    'INSERT INTO "read_data" (
      [read_name],
      [chromosome_id],
      [sample_id],
      [start],
      [end],
      [strand],
      [mapq]) 
    VALUES (
      :qname,
      (SELECT [chromosome_id] from "chromosomes" WHERE [chromosome_name] = :rname),
      (SELECT [sample_id] from "sample_data" WHERE [sample_name] = :sample),
      :pos,
      :end,
      :strand_int,
      :mapq);', bam_data)
  
  dbDisconnect(db)
}

#' Add modifications to the database.
#' @param database Path to the database.
#' @export
mod_db <- function(
    database = NULL )
{
  db <- dbConnect(RSQLite::SQLite(), database)
  
  df <- data.frame(modification_name = c('Y','Z'),
                   modification_base = c('m6A', 'CpG'),
                   canonical_base = c('A', 'C'))
  
  dbSendQuery(db, 
    'INSERT INTO "modifications" (
      [modification_name],
      [modification_base],
      [canonical_base]) 
    VALUES (
      :modification_name,
      :modification_base,
      :canonical_base);', df)
  
  dbDisconnect(db)
}

#' Insert methylation data into the database from Megalodon output.
#' @param database Path to database.
#' @param mod_data Modifications database file.
#' @param chunk_size The numer of lines to take and insert 
#'                   from/into database. Default value is 10 millions.
#' @export

insert_mod_db <- function (
    database = NULL,
    mod_data = NULL,
    chunk_size = 1e7)
{
  require(RSQLite)
  
  db_in <- dbConnect(RSQLite::SQLite(), mod_data)
  db_out <- dbConnect(RSQLite::SQLite(), database)
  
  # count rows in input database
  n <- dbGetQuery(db_in, 'SELECT COUNT(*) FROM "data";')
  n_chunks <- n %/% chunk_size + 1
  format <- paste0("%0", nchar(n_chunks), "d")
  
  res <- dbSendQuery(db_in, 'SELECT read_id, pos, mod_log_prob, mod_base FROM "data";')
  counter <- 1
  print("Insert data into the database by chunks takes time...")
  while (!dbHasCompleted(res)) {
    # Print current chunk
    print(paste0("Chunk: ", sprintf(format, counter), " of ", n_chunks, " : ", Sys.time() )) 
    
    # get chunk data
    chunk <- dbFetch(res, n = chunk_size)

    dbSendQuery(db_out, 
      'INSERT INTO "modification_data" (
         [read_id],
         [start],
         [end],
         [modification_id],
         [modification_probability]) 
       VALUES (
         (SELECT [read_id] FROM "read_data" WHERE [read_name] = :read_id),
         :pos,
         :pos,
         (SELECT [modification_id] FROM "modifications" WHERE [modification_name] = :mod_base),
         :mod_log_prob);', chunk )
    
    counter <- counter + 1
  }
  
  # Clear the result
  dbClearResult(res)
  dbDisconnect(db_in)
  dbDisconnect(db_out)
}

#' Build database from config yaml, bam file and Megalodon database.
#' db_dir Database output directory.
#' db_name Name of the database.
#' config_yaml Path to the configuration.yaml file.
#'             To get the file template please use get_config() function.
#' bam Input bam file.
#' mod_data Modification database output from Megalodon.
#' @param ... Other parameters, e.g. chunk_size
#' @export

build_database <- function(
    db_dir = NULL, 
    db_name = NULL, 
    config_yaml = NULL,
    bam = NULL,
    mod_data = NULL,
    ... )
{ 
  # Create database
  create_database(
    db_dir = db_dir,
    db_name = db_name )
  
  db <- paste0(db_dir, "/", db_name, ".db")
  
  # Insert configuration yaml data
  insert_config_db(
    database = db,
    config_yaml = config_yaml )
  
  # Insert bam data
  insert_bam_db(
    database = db,
    bam = bam )
  
  # Add modification spec
  mod_db(
    database = db)
  
  # Insert modification data
  insert_mod_db(
    database = db,
    mod_data = mod_data,
    ... )
}

