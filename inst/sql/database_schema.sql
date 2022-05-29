CREATE TABLE "run_data"
(
   [run_id] INTEGER PRIMARY KEY NOT NULL
      CHECK ([run_id] = 1),
   [run_name] TEXT NOT NULL,
   [run_date] BLOB NOT NULL,
   [sequencing_platform] TEXT NOT NULL,
   [sequencing_software] TEXT NOT NULL,
   [sequencing_software_version] TEXT NOT NULL,
   [author_name] TEXT NOT NULL,
   [run_description] TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS "sample_data"
(
   [sample_id] INTEGER PRIMARY KEY NOT NULL,
   [run_id] INTEGER NOT NULL,
   [sample_name] TEXT UNIQUE NOT NULL,
   [barcode_name] TEXT UNIQUE NOT NULL,
   [library_kit] TEXT NOT NULL,
   [sampling_date] BLOB NOT NULL,
   [mapping_tool] TEXT NOT NULL,
   [mapping_tool_version] TEXT NOT NULL,
   [modification_calling_tool] TEXT NOT NULL,
   [modification_calling_tool_version] TEXT NOT NULL,
   [sample_description] TEXT NOT NULL,
   [modification_calling_model_name] TEXT,
   [reference_genome] TEXT,
   FOREIGN KEY ([run_id])
      REFERENCES "run_data" ([run_id])
         ON DELETE NO ACTION ON UPDATE NO ACTION
);
CREATE TABLE "chromosomes"
(
   [chromosome_id] INTEGER PRIMARY KEY NOT NULL,
   [chromosome_name] TEXT UNIQUE NOT NULL,
   [chromosome_length] INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS "read_data"
(
   [read_id] INTEGER PRIMARY KEY NOT NULL,
   [read_name] TEXT UNIQUE NOT NULL,
   [chromosome_id] INTEGER NOT NULL,
   [start] INTEGER NOT NULL,
   [end] INTEGER NOT NULL,
   [strand] INTEGER NOT NULL,
   [sample_id] INTEGER NOT NULL,
   [mapq] INTEGER NOT NULL,
   FOREIGN KEY ([sample_id])
      REFERENCES "sample_data" ([sample_id])
         ON DELETE NO ACTION ON UPDATE NO ACTION,
   FOREIGN KEY ([chromosome_id])
      REFERENCES "chromosomes" ([chromosome_id])
         ON DELETE NO ACTION ON UPDATE NO ACTION
);
CREATE TABLE IF NOT EXISTS "modifications"
(
   [modification_id] INTEGER PRIMARY KEY NOT NULL,
   [modification_name] TEXT NOT NULL,
   [modification_base] TEXT NOT NULL,
   [canonical_base] TEXT NOT NULL
);
CREATE TABLE "modification_data"
(
   [modification_data_id] INTEGER PRIMARY KEY NOT NULL,
   [read_id] INTEGER NOT NULL,
   [start] INTEGER NOT NULL,
   [end] INTEGER NOT NULL,
   [modification_id] INTEGER NOT NULL,
   [modification_probability] REAL NOT NULL,
   [group_count] INTEGER, 
   [group_sequence] INTEGER, 
   FOREIGN KEY ([read_id]) 
      REFERENCES "read_data" ([read_id])
         ON DELETE NO ACTION ON UPDATE NO ACTION,
   FOREIGN KEY ([modification_id])
      REFERENCES "modifications" ([modification_id])
         ON DELETE NO ACTION ON UPDATE NO ACTION
);
CREATE INDEX [genomic_coordinates_idx] 
   ON "read_data" ([chromosome_id], [start], [end]);
CREATE INDEX [read_name_idx] 
   ON "read_data" ([read_name]);
