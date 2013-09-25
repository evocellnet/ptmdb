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
  `description` VARCHAR(40) NOT NULL DEFAULT '',
  `time_min` INT(11) NULL DEFAULT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensp`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensp` (
  `id` VARCHAR(30) NOT NULL DEFAULT '',
  `sequence` TEXT NOT NULL,
  `length` INT(11) NOT NULL,
  `taxid` INT(11) NOT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`ipi`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ipi` (
  `id` CHAR(11) NOT NULL DEFAULT '',
  `sequence` TEXT NOT NULL,
  `length` INT(11) NOT NULL,
  `taxid` INT(11) NOT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


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
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`site_quantification`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`site_quantification` (
  `id` INT(11) UNSIGNED NOT NULL,
  `condition` INT(11) UNSIGNED NOT NULL,
  `log2` FLOAT NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `condition` (`condition` ASC),
  CONSTRAINT `site_quantification_ibfk_1`
    FOREIGN KEY (`condition`)
    REFERENCES `ptmdb`.`condition` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`experiment`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`experiment` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `organism` VARCHAR(20) NOT NULL DEFAULT '',
  `cell_line` VARCHAR(50) NULL DEFAULT '',
  `time` INT(11) NULL DEFAULT NULL,
  `description` VARCHAR(50) NOT NULL DEFAULT '',
  `labelling_type` ENUM('free','metabolic','chemical') NULL DEFAULT NULL,
  `labelling_method` VARCHAR(11) NULL DEFAULT NULL,
  `spectrometer` VARCHAR(30) NOT NULL DEFAULT '',
  `enrichment_method` ENUM('TiO2','Antibody') NULL DEFAULT NULL,
  `antibody` VARCHAR(11) NULL DEFAULT NULL,
  `identification_software` VARCHAR(20) NULL DEFAULT NULL,
  `quantification_software` VARCHAR(20) NULL DEFAULT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`site_evidence`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`site_evidence` (
  `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `residue` CHAR(1) NOT NULL DEFAULT '',
  `type` ENUM('P','U','A','G') NOT NULL DEFAULT 'P',
  `localization_confidence` FLOAT NOT NULL,
  `spectral_count` INT UNSIGNED NOT NULL,
  `experiment` INT(11) UNSIGNED NOT NULL,
  `quantitative_data` INT(11) UNSIGNED NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `experiment` (`experiment` ASC),
  INDEX `quantitative_data` (`quantitative_data` ASC),
  CONSTRAINT `site_evidence_ibfk_2`
    FOREIGN KEY (`quantitative_data`)
    REFERENCES `ptmdb`.`site_quantification` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `site_evidence_ibfk_1`
    FOREIGN KEY (`experiment`)
    REFERENCES `ptmdb`.`experiment` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`ensp_site`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ensp_site` (
  `ensembl_id` VARCHAR(30) NOT NULL DEFAULT '',
  `site` INT(11) UNSIGNED NOT NULL,
  `res_number` INT(5) UNSIGNED NOT NULL,
  `seq_window` CHAR(13) NOT NULL DEFAULT '',
  PRIMARY KEY (`ensembl_id`, `site`),
  INDEX `site` (`site` ASC),
  CONSTRAINT `ensp_site_ibfk_2`
    FOREIGN KEY (`site`)
    REFERENCES `ptmdb`.`site_evidence` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `ensp_site_ibfk_1`
    FOREIGN KEY (`ensembl_id`)
    REFERENCES `ptmdb`.`ensp` (`id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`inparanoid`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`inparanoid` (
  `id` VARCHAR(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  CONSTRAINT `inparanoid_ibfk_1`
    FOREIGN KEY (`id`)
    REFERENCES `ptmdb`.`ensp` (`id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`ipi_history`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`ipi_history` (
  `current_ipi` CHAR(11) NOT NULL DEFAULT '',
  `all_ipi` CHAR(11) NOT NULL DEFAULT '',
  PRIMARY KEY (`current_ipi`, `all_ipi`),
  CONSTRAINT `ipi_history_ibfk_1`
    FOREIGN KEY (`current_ipi`)
    REFERENCES `ptmdb`.`ipi` (`id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`publication`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`publication` (
  `pub_id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `pubmed_id` INT(11) NOT NULL,
  `fauthor` VARCHAR(50) NOT NULL DEFAULT '',
  `publication_date` DATE NOT NULL,
  `journal` VARCHAR(100) NOT NULL DEFAULT '',
  `title` TEXT NOT NULL,
  PRIMARY KEY (`pub_id`),
  UNIQUE INDEX `pubmed_id` (`pubmed_id` ASC))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`pub_exp`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`pub_exp` (
  `experiment` INT(11) UNSIGNED NOT NULL,
  `pub_id` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`experiment`),
  INDEX `pub_id` (`pub_id` ASC),
  CONSTRAINT `pub_exp_ibfk_2`
    FOREIGN KEY (`pub_id`)
    REFERENCES `ptmdb`.`publication` (`pub_id`)
    ON DELETE CASCADE,
  CONSTRAINT `pub_exp_ibfk_1`
    FOREIGN KEY (`experiment`)
    REFERENCES `ptmdb`.`experiment` (`id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_entry`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_entry` (
  `id` VARCHAR(15) NOT NULL DEFAULT '',
  `reviewed` TINYINT(1) NOT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_isoform`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_isoform` (
  `accession` VARCHAR(11) NOT NULL DEFAULT '',
  `sequence` TEXT NOT NULL,
  `length` INT(11) NOT NULL,
  `taxid` INT(11) NOT NULL,
  PRIMARY KEY (`accession`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_acc`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_acc` (
  `accession` VARCHAR(15) NOT NULL DEFAULT '',
  `id` VARCHAR(30) NOT NULL DEFAULT '',
  `reference_accession` VARCHAR(15) NOT NULL DEFAULT '',
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
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_ensembl`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_ensembl` (
  `uniprot_accession` VARCHAR(11) NOT NULL DEFAULT '',
  `ensembl_id` VARCHAR(30) NOT NULL DEFAULT '',
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
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


-- -----------------------------------------------------
-- Table `ptmdb`.`uniprot_ipi`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `ptmdb`.`uniprot_ipi` (
  `ipi_id` CHAR(11) NOT NULL DEFAULT '',
  `accession` VARCHAR(11) NOT NULL DEFAULT '',
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
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
