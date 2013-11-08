SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

CREATE SCHEMA IF NOT EXISTS `ptmdb` DEFAULT CHARACTER SET latin1 ;
USE `ptmdb` ;

-- -----------------------------------------------------
-- Table `ptmdb`.`condition`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`condition` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `description` VARCHAR(45) NOT NULL,
  `time_min` INT(11) NULL,
  `control_description` VARCHAR(45) NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`organism`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`organism` (
  `taxid` INT UNSIGNED NOT NULL,
  `common_name` VARCHAR(45) NULL,
  `scientific_name` VARCHAR(45) NULL,
  PRIMARY KEY (`taxid`),
  UNIQUE INDEX `taxid_UNIQUE` (`taxid` ASC),
  UNIQUE INDEX `common_name_UNIQUE` (`common_name` ASC),
  UNIQUE INDEX `scientific_name_UNIQUE` (`scientific_name` ASC))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensp`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensp` (
  `id` VARCHAR(30) NOT NULL,
  `sequence` TEXT NOT NULL,
  `length` INT(11) NOT NULL,
  `taxid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `org_key_idx` (`taxid` ASC),
  UNIQUE INDEX `id_UNIQUE` (`id` ASC),
  CONSTRAINT `org_key_ensp`
    FOREIGN KEY (`taxid`)
    REFERENCES `ptmdb`.`organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ipi`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ipi` (
  `id` CHAR(11) NOT NULL,
  `sequence` TEXT NOT NULL,
  `length` INT(11) NOT NULL,
  `taxid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `org_key_idx` (`taxid` ASC),
  CONSTRAINT `org_key_ipi`
    FOREIGN KEY (`taxid`)
    REFERENCES `ptmdb`.`organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensembl_ipi`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensembl_ipi` (
  `ipi` CHAR(11) NOT NULL DEFAULT '',
  `ensembl_id` VARCHAR(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`ipi`, `ensembl_id`),
  INDEX `ensembl_id` (`ensembl_id` ASC),
  CONSTRAINT `ensembl_ipi_ibfk_2`
    FOREIGN KEY (`ensembl_id`)
    REFERENCES `ptmdb`.`ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `ensembl_ipi_ibfk_1`
    FOREIGN KEY (`ipi`)
    REFERENCES `ptmdb`.`ipi` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`publication`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`publication` (
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
-- Table `ptmdb`.`experiment`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`experiment` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `publication` INT(11) UNSIGNED NULL,
  `organism` INT UNSIGNED NOT NULL,
  `scoring_method` VARCHAR(30) NULL,
  `biological_sample` VARCHAR(50) NULL,
  `comments` TINYTEXT NOT NULL,
  `labelling_type` ENUM('free','metabolic','chemical') NULL,
  `labelling_method` VARCHAR(11) NULL,
  `spectrometer` VARCHAR(30) NOT NULL,
  `enrichment_method` ENUM('TiO2','Antibody') NULL,
  `antibody` VARCHAR(11) NULL,
  `identification_software` VARCHAR(20) NULL,
  `quantification_software` VARCHAR(20) NULL,
  PRIMARY KEY (`id`),
  INDEX `org_key_idx` (`organism` ASC),
  INDEX `key_publication_idx` (`publication` ASC),
  CONSTRAINT `org_key_exp`
    FOREIGN KEY (`organism`)
    REFERENCES `ptmdb`.`organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `key_publication`
    FOREIGN KEY (`publication`)
    REFERENCES `ptmdb`.`publication` (`pub_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`peptide`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`peptide` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `spectral_count` INT UNSIGNED NULL,
  `peptide` VARCHAR(200) NOT NULL,
  `scored_peptide` VARCHAR(300) NULL,
  `experiment` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `experiment` (`experiment` ASC),
  CONSTRAINT `site_evidence_ibfk_1`
    FOREIGN KEY (`experiment`)
    REFERENCES `ptmdb`.`experiment` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`peptide_quantification`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`peptide_quantification` (
  `id` INT(11) UNSIGNED NOT NULL,
  `condition` INT(11) UNSIGNED NOT NULL,
  `log2` FLOAT NOT NULL,
  `peptide` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `condition` (`condition` ASC),
  INDEX `peptide_id_map_idx` (`peptide` ASC),
  CONSTRAINT `site_quantification_ibfk_1`
    FOREIGN KEY (`condition`)
    REFERENCES `ptmdb`.`condition` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `peptide_id_map`
    FOREIGN KEY (`peptide`)
    REFERENCES `ptmdb`.`peptide` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensp_peptide`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensp_peptide` (
  `ensembl_id` VARCHAR(30) NOT NULL,
  `peptide_id` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`ensembl_id`, `peptide_id`),
  INDEX `site` (`peptide_id` ASC),
  CONSTRAINT `ensp_site_ibfk_2`
    FOREIGN KEY (`peptide_id`)
    REFERENCES `ptmdb`.`peptide` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `ensp_site_ibfk_1`
    FOREIGN KEY (`ensembl_id`)
    REFERENCES `ptmdb`.`ensp` (`id`)
    ON DELETE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`inparanoid`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`inparanoid` (
  `id` VARCHAR(30) NOT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ipi_history`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ipi_history` (
  `current_ipi` CHAR(11) NOT NULL,
  `all_ipi` CHAR(11) NOT NULL,
  PRIMARY KEY (`current_ipi`, `all_ipi`),
  CONSTRAINT `ipi_history_ibfk_1`
    FOREIGN KEY (`current_ipi`)
    REFERENCES `ptmdb`.`ipi` (`id`)
    ON DELETE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_entry`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_entry` (
  `id` VARCHAR(15) NOT NULL DEFAULT '',
  `reviewed` TINYINT(1) NOT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_isoform`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_isoform` (
  `accession` VARCHAR(11) NOT NULL DEFAULT '',
  `sequence` TEXT NOT NULL,
  `length` INT(11) NOT NULL,
  `taxid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`accession`),
  INDEX `org_key_idx` (`taxid` ASC),
  CONSTRAINT `org_key_iso`
    FOREIGN KEY (`taxid`)
    REFERENCES `ptmdb`.`organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_acc`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_acc` (
  `accession` VARCHAR(15) NOT NULL,
  `id` VARCHAR(30) NOT NULL,
  `reference_accession` VARCHAR(15) NOT NULL,
  PRIMARY KEY (`accession`, `reference_accession`),
  INDEX `id` (`id` ASC),
  INDEX `reference_accession` (`reference_accession` ASC),
  CONSTRAINT `uniprot_acc_ibfk_1`
    FOREIGN KEY (`id`)
    REFERENCES `ptmdb`.`uniprot_entry` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `uniprot_acc_ibfk_2`
    FOREIGN KEY (`reference_accession`)
    REFERENCES `ptmdb`.`uniprot_isoform` (`accession`)
    ON DELETE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_ensembl`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_ensembl` (
  `uniprot_accession` VARCHAR(11) NOT NULL,
  `ensembl_id` VARCHAR(30) NOT NULL,
  PRIMARY KEY (`uniprot_accession`, `ensembl_id`),
  INDEX `ensembl_id` (`ensembl_id` ASC),
  CONSTRAINT `uniprot_ensembl_ibfk_3`
    FOREIGN KEY (`ensembl_id`)
    REFERENCES `ptmdb`.`ensp` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `uniprot_ensembl_ibfk_2`
    FOREIGN KEY (`uniprot_accession`)
    REFERENCES `ptmdb`.`uniprot_acc` (`accession`)
    ON DELETE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_ipi`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_ipi` (
  `ipi_id` CHAR(11) NOT NULL,
  `accession` VARCHAR(11) NOT NULL,
  PRIMARY KEY (`accession`),
  INDEX `ipi_id` (`ipi_id` ASC),
  CONSTRAINT `uniprot_ipi_ibfk_3`
    FOREIGN KEY (`ipi_id`)
    REFERENCES `ptmdb`.`ipi` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `uniprot_ipi_ibfk_2`
    FOREIGN KEY (`accession`)
    REFERENCES `ptmdb`.`uniprot_acc` (`accession`)
    ON DELETE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensg`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensg` (
  `id` VARCHAR(30) NOT NULL,
  `name` VARCHAR(30) NULL,
  `description` VARCHAR(1000) NULL,
  `taxid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `id_UNIQUE` (`id` ASC),
  INDEX `tax_key_idx` (`taxid` ASC),
  CONSTRAINT `tax_key`
    FOREIGN KEY (`taxid`)
    REFERENCES `ptmdb`.`organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensg_ensp`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensg_ensp` (
  `ensp_id` VARCHAR(30) NOT NULL,
  `ensg_id` VARCHAR(30) NOT NULL,
  UNIQUE INDEX `ensp_UNIQUE` (`ensp_id` ASC),
  INDEX `ensg_key_idx` (`ensg_id` ASC),
  CONSTRAINT `ensg_key`
    FOREIGN KEY (`ensg_id`)
    REFERENCES `ptmdb`.`ensg` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `ensp_key`
    FOREIGN KEY (`ensp_id`)
    REFERENCES `ptmdb`.`ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensp_inparanoid`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensp_inparanoid` (
  `ensp` VARCHAR(30) NOT NULL,
  `inparanoid_id` VARCHAR(30) NOT NULL,
  PRIMARY KEY (`ensp`, `inparanoid_id`),
  INDEX `inpara_key_idx` (`inparanoid_id` ASC),
  CONSTRAINT `ensp_inpara_key`
    FOREIGN KEY (`ensp`)
    REFERENCES `ptmdb`.`ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `inpara_ensp_key`
    FOREIGN KEY (`inparanoid_id`)
    REFERENCES `ptmdb`.`inparanoid` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`site`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`site` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `localization_score` FLOAT NULL,
  `modif_type` CHAR(1) NOT NULL,
  `residue` CHAR(1) NOT NULL,
  `experiment` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `key_site_experiment_idx` (`experiment` ASC),
  CONSTRAINT `key_site_experiment`
    FOREIGN KEY (`experiment`)
    REFERENCES `ptmdb`.`experiment` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`peptide_site`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`peptide_site` (
  `peptide_id` INT(11) UNSIGNED NOT NULL,
  `site_id` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`site_id`),
  INDEX `pep_site_map_idx` (`peptide_id` ASC),
  CONSTRAINT `pep_site_map`
    FOREIGN KEY (`peptide_id`)
    REFERENCES `ptmdb`.`peptide` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `site_pep_map`
    FOREIGN KEY (`site_id`)
    REFERENCES `ptmdb`.`site` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensp_site`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensp_site` (
  `ensp` VARCHAR(30) NOT NULL,
  `site_id` INT(11) UNSIGNED NOT NULL,
  `position` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`ensp`, `site_id`),
  INDEX `map_sitekey_idx` (`site_id` ASC),
  CONSTRAINT `map_enspkey`
    FOREIGN KEY (`ensp`)
    REFERENCES `ptmdb`.`ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `map_sitekey`
    FOREIGN KEY (`site_id`)
    REFERENCES `ptmdb`.`site` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`refseq_protein`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`refseq_protein` (
  `id` VARCHAR(30) NOT NULL,
  `organism` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `id_UNIQUE` (`id` ASC),
  INDEX `refseq_organism_idx` (`organism` ASC),
  CONSTRAINT `refseq_organism`
    FOREIGN KEY (`organism`)
    REFERENCES `ptmdb`.`organism` (`taxid`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensp_refseq`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensp_refseq` (
  `ensp_id` VARCHAR(30) NOT NULL,
  `refseq_id` VARCHAR(30) NOT NULL,
  PRIMARY KEY (`ensp_id`, `refseq_id`),
  INDEX `ensp_refseq2refseq_idx` (`refseq_id` ASC),
  CONSTRAINT `ensp_refseq2ensp`
    FOREIGN KEY (`ensp_id`)
    REFERENCES `ptmdb`.`ensp` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `ensp_refseq2refseq`
    FOREIGN KEY (`refseq_id`)
    REFERENCES `ptmdb`.`refseq_protein` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
