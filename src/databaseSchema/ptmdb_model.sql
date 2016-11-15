SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

-- -----------------------------------------------------
-- Table `condition`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `condition` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `description` VARCHAR(150) NOT NULL,
  `time_min` INT(11) NULL,
  `control_description` VARCHAR(150) NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `organism`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `organism` (
  `taxid` INT UNSIGNED NOT NULL,
  `common_name` VARCHAR(150) NULL,
  `scientific_name` VARCHAR(150) NULL,
  PRIMARY KEY (`taxid`),
  UNIQUE INDEX `taxid_UNIQUE` (`taxid` ASC),
  UNIQUE INDEX `common_name_UNIQUE` (`common_name` ASC),
  UNIQUE INDEX `scientific_name_UNIQUE` (`scientific_name` ASC))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ensp`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ensp` (
  `id` VARCHAR(30) NOT NULL,
  `sequence` TEXT NOT NULL,
  `length` INT(11) NOT NULL,
  `taxid` INT UNSIGNED NOT NULL,
  `version` INT UNSIGNED NULL,
  PRIMARY KEY (`id`),
  INDEX `org_key_idx` (`taxid` ASC),
  UNIQUE INDEX `id_UNIQUE` (`id` ASC),
  CONSTRAINT `org_key_ensp`
    FOREIGN KEY (`taxid`)
    REFERENCES `organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ipi`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ipi` (
  `id` CHAR(11) NOT NULL,
  `sequence` TEXT NOT NULL,
  `length` INT(11) NOT NULL,
  `taxid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `org_key_idx` (`taxid` ASC),
  CONSTRAINT `org_key_ipi`
    FOREIGN KEY (`taxid`)
    REFERENCES `organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ensembl_ipi`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ensembl_ipi` (
  `ipi` CHAR(11) NOT NULL DEFAULT '',
  `ensembl_id` VARCHAR(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`ipi`, `ensembl_id`),
  INDEX `ensembl_id` (`ensembl_id` ASC),
  CONSTRAINT `ensembl_ipi_ibfk_2`
    FOREIGN KEY (`ensembl_id`)
    REFERENCES `ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `ensembl_ipi_ibfk_1`
    FOREIGN KEY (`ipi`)
    REFERENCES `ipi` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `publication`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `publication` (
  `pub_id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `pubmed_id` INT(11) NOT NULL,
  `fauthor` VARCHAR(50) NOT NULL,
  `publication_date` DATE NOT NULL,
  `journal` VARCHAR(100) NOT NULL,
  `title` TEXT NOT NULL,
  PRIMARY KEY (`pub_id`),
  UNIQUE INDEX `pubmed_id` (`pubmed_id` ASC))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `experiment`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `experiment` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `publication` INT(11) UNSIGNED NULL,
  `organism` INT UNSIGNED NOT NULL,
  `scoring_method` VARCHAR(30) NULL,
  `biological_sample` VARCHAR(140) NULL,
  `comments` TINYTEXT NULL,
  `labelling_type` ENUM('free','metabolic','chemical') NULL,
  `labelling_method` VARCHAR(140) NULL,
  `spectrometer` VARCHAR(140) NULL,
  `enrichment_method` ENUM('TiO2','IMAC','Antibody','TiO2_IMAC') NULL,
  `antibody` VARCHAR(32) NULL,
  `identification_software` VARCHAR(140) NULL,
  `quantification_software` VARCHAR(140) NULL,
  PRIMARY KEY (`id`),
  INDEX `org_key_idx` (`organism` ASC),
  INDEX `key_publication_idx` (`publication` ASC),
  CONSTRAINT `org_key_exp`
    FOREIGN KEY (`organism`)
    REFERENCES `organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `key_publication`
    FOREIGN KEY (`publication`)
    REFERENCES `publication` (`pub_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `peptide`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `peptide` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `max_spectral_count` INT UNSIGNED NULL,
  `peptide` VARCHAR(200) NOT NULL,
  `scored_peptide` VARCHAR(300) NULL,
  `experiment` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `experiment` (`experiment` ASC),
  CONSTRAINT `site_evidence_ibfk_1`
    FOREIGN KEY (`experiment`)
    REFERENCES `experiment` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `peptide_quantification`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `peptide_quantification` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `condition` INT(11) UNSIGNED NOT NULL,
  `spectral_count` INT UNSIGNED NULL,
  `log2` FLOAT NULL,
  `peptide` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `condition` (`condition` ASC),
  INDEX `peptide_id_map_idx` (`peptide` ASC),
  CONSTRAINT `site_quantification_ibfk_1`
    FOREIGN KEY (`condition`)
    REFERENCES `condition` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `peptide_id_map`
    FOREIGN KEY (`peptide`)
    REFERENCES `peptide` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ensp_peptide`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ensp_peptide` (
  `ensembl_id` VARCHAR(30) NOT NULL,
  `peptide_id` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`ensembl_id`, `peptide_id`),
  INDEX `site` (`peptide_id` ASC),
  CONSTRAINT `ensp_site_ibfk_2`
    FOREIGN KEY (`peptide_id`)
    REFERENCES `peptide` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `ensp_site_ibfk_1`
    FOREIGN KEY (`ensembl_id`)
    REFERENCES `ensp` (`id`)
    ON DELETE CASCADE)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `ipi_history`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ipi_history` (
  `current_ipi` CHAR(11) NOT NULL,
  `all_ipi` CHAR(11) NOT NULL,
  PRIMARY KEY (`current_ipi`, `all_ipi`),
  CONSTRAINT `ipi_history_ibfk_1`
    FOREIGN KEY (`current_ipi`)
    REFERENCES `ipi` (`id`)
    ON DELETE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `uniprot_entry`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `uniprot_entry` (
  `id` VARCHAR(32) NOT NULL DEFAULT '',
  `reviewed` TINYINT(1) NOT NULL,
  `taxid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `org_key_entry`
    FOREIGN KEY (`taxid`)
    REFERENCES `organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `uniprot_isoform`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `uniprot_isoform` (
  `accession` VARCHAR(32) NOT NULL DEFAULT '',
  `sequence` TEXT NOT NULL,
  `length` INT(11) NOT NULL,
  `taxid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`accession`),
  INDEX `org_key_idx` (`taxid` ASC),
  CONSTRAINT `org_key_iso`
    FOREIGN KEY (`taxid`)
    REFERENCES `organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `uniprot_acc`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `uniprot_acc` (
  `accession` VARCHAR(32) NOT NULL,
  `id` VARCHAR(30) NOT NULL,
  `reference_accession` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`accession`, `reference_accession`),
  INDEX `id` (`id` ASC),
  INDEX `reference_accession` (`reference_accession` ASC),
  CONSTRAINT `uniprot_acc_ibfk_1`
    FOREIGN KEY (`id`)
    REFERENCES `uniprot_entry` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `uniprot_acc_ibfk_2`
    FOREIGN KEY (`reference_accession`)
    REFERENCES `uniprot_isoform` (`accession`)
    ON DELETE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `uniprot_ensembl`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `uniprot_ensembl` (
  `uniprot_accession` VARCHAR(32) NOT NULL,
  `ensembl_id` VARCHAR(30) NOT NULL,
  PRIMARY KEY (`uniprot_accession`, `ensembl_id`),
  INDEX `ensembl_id` (`ensembl_id` ASC),
  CONSTRAINT `uniprot_ensembl_ibfk_3`
    FOREIGN KEY (`ensembl_id`)
    REFERENCES `ensp` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `uniprot_ensembl_ibfk_2`
    FOREIGN KEY (`uniprot_accession`)
    REFERENCES `uniprot_acc` (`accession`)
    ON DELETE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `uniprot_ipi`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `uniprot_ipi` (
  `ipi_id` CHAR(11) NOT NULL,
  `accession` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`accession`),
  INDEX `ipi_id` (`ipi_id` ASC),
  CONSTRAINT `uniprot_ipi_ibfk_3`
    FOREIGN KEY (`ipi_id`)
    REFERENCES `ipi` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `uniprot_ipi_ibfk_2`
    FOREIGN KEY (`accession`)
    REFERENCES `uniprot_acc` (`accession`)
    ON DELETE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ensg`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ensg` (
  `id` VARCHAR(30) NOT NULL,
  `name` VARCHAR(30) NULL,
  `description` VARCHAR(1000) NULL,
  `taxid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `id_UNIQUE` (`id` ASC),
  INDEX `tax_key_idx` (`taxid` ASC),
  CONSTRAINT `tax_key`
    FOREIGN KEY (`taxid`)
    REFERENCES `organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ensg_ensp`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ensg_ensp` (
  `ensp_id` VARCHAR(30) NOT NULL,
  `ensg_id` VARCHAR(30) NOT NULL,
  UNIQUE INDEX `ensp_UNIQUE` (`ensp_id` ASC),
  INDEX `ensg_key_idx` (`ensg_id` ASC),
  CONSTRAINT `ensg_key`
    FOREIGN KEY (`ensg_id`)
    REFERENCES `ensg` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `ensp_key`
    FOREIGN KEY (`ensp_id`)
    REFERENCES `ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `modification`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `modification` (
  `id` CHAR(1) NOT NULL,
  `description` VARCHAR(85) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `id_UNIQUE` (`id` ASC),
  UNIQUE INDEX `description_UNIQUE` (`description` ASC))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `site`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `site` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `localization_score` FLOAT NULL,
  `modif_type` CHAR(1) NOT NULL,
  `residue` CHAR(1) NOT NULL,
  `experiment` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `key_site_experiment_idx` (`experiment` ASC),
  INDEX `key_modif_type_idx` (`modif_type` ASC),
  CONSTRAINT `key_site_experiment`
    FOREIGN KEY (`experiment`)
    REFERENCES `experiment` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `key_modif_type`
    FOREIGN KEY (`modif_type`)
    REFERENCES `modification` (`id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `peptide_site`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `peptide_site` (
  `peptide_id` INT(11) UNSIGNED NOT NULL,
  `site_id` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`site_id`),
  INDEX `pep_site_map_idx` (`peptide_id` ASC),
  CONSTRAINT `pep_site_map`
    FOREIGN KEY (`peptide_id`)
    REFERENCES `peptide` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `site_pep_map`
    FOREIGN KEY (`site_id`)
    REFERENCES `site` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ensp_site`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ensp_site` (
  `ensp` VARCHAR(30) NOT NULL,
  `site_id` INT(11) UNSIGNED NOT NULL,
  `position` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`ensp`, `site_id`),
  INDEX `map_sitekey_idx` (`site_id` ASC),
  CONSTRAINT `map_enspkey`
    FOREIGN KEY (`ensp`)
    REFERENCES `ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `map_sitekey`
    FOREIGN KEY (`site_id`)
    REFERENCES `site` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `refseq_protein`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `refseq_protein` (
  `id` VARCHAR(30) NOT NULL,
  `organism` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `id_UNIQUE` (`id` ASC),
  INDEX `refseq_organism_idx` (`organism` ASC),
  CONSTRAINT `refseq_organism`
    FOREIGN KEY (`organism`)
    REFERENCES `organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ensp_refseq`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ensp_refseq` (
  `ensp_id` VARCHAR(30) NOT NULL,
  `refseq_id` VARCHAR(30) NOT NULL,
  PRIMARY KEY (`ensp_id`, `refseq_id`),
  INDEX `ensp_refseq2refseq_idx` (`refseq_id` ASC),
  CONSTRAINT `ensp_refseq2ensp`
    FOREIGN KEY (`ensp_id`)
    REFERENCES `ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `ensp_refseq2refseq`
    FOREIGN KEY (`refseq_id`)
    REFERENCES `refseq_protein` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `domain`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `domain` (
  `pfam_id` VARCHAR(7) NOT NULL,
  `name` VARCHAR(32) NOT NULL,
  `description` VARCHAR(80) NULL,
  `type` VARCHAR(32) NULL,
  PRIMARY KEY (`pfam_id`),
  UNIQUE INDEX `pfam_id_UNIQUE` (`pfam_id` ASC))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `domain_ensp`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `domain_ensp` (
  `pfam_id` VARCHAR(7) NOT NULL,
  `ensp_id` VARCHAR(30) NOT NULL,
  `start` INT UNSIGNED NOT NULL,
  `end` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`pfam_id`, `ensp_id`, `start`),
  UNIQUE INDEX `pfam_id_UNIQUE` (`pfam_id` ASC),
  UNIQUE INDEX `ensp_id_UNIQUE` (`ensp_id` ASC),
  CONSTRAINT `from_domain_to_domain_ensp`
    FOREIGN KEY (`pfam_id`)
    REFERENCES `domain` (`pfam_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `from_ensp_to_domain_ensp`
    FOREIGN KEY (`ensp_id`)
    REFERENCES `ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
