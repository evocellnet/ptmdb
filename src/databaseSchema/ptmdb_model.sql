# ************************************************************
# Sequel Pro SQL dump
# Version 4096
#
# http://www.sequelpro.com/
# http://code.google.com/p/sequel-pro/
#
# Host: 127.0.0.1 (MySQL 5.6.12)
# Database: ptmdb
# Generation Time: 2013-09-11 10:59:41 +0000
# ************************************************************


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


# Dump of table condition
# ------------------------------------------------------------

DROP TABLE IF EXISTS `condition`;

CREATE TABLE `condition` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `description` varchar(40) NOT NULL DEFAULT '',
  `time_min` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table ensembl_ipi
# ------------------------------------------------------------

DROP TABLE IF EXISTS `ensembl_ipi`;

CREATE TABLE `ensembl_ipi` (
  `ipi` char(11) NOT NULL DEFAULT '',
  `ensembl_id` char(15) NOT NULL DEFAULT '',
  PRIMARY KEY (`ipi`,`ensembl_id`),
  KEY `ensembl_id` (`ensembl_id`),
  CONSTRAINT `ensembl_ipi_ibfk_2` FOREIGN KEY (`ensembl_id`) REFERENCES `ensp` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `ensembl_ipi_ibfk_1` FOREIGN KEY (`ipi`) REFERENCES `ipi` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table ensp
# ------------------------------------------------------------

DROP TABLE IF EXISTS `ensp`;

CREATE TABLE `ensp` (
  `id` char(15) NOT NULL DEFAULT '',
  `sequence` text NOT NULL,
  `length` int(11) NOT NULL,
  `taxid` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table ensp_site
# ------------------------------------------------------------

DROP TABLE IF EXISTS `ensp_site`;

CREATE TABLE `ensp_site` (
  `ensembl_id` char(15) NOT NULL DEFAULT '',
  `site` int(11) unsigned NOT NULL,
  `res_number` int(5) unsigned NOT NULL,
  `seq_window` char(13) NOT NULL DEFAULT '',
  PRIMARY KEY (`ensembl_id`,`site`),
  KEY `site` (`site`),
  CONSTRAINT `ensp_site_ibfk_2` FOREIGN KEY (`site`) REFERENCES `site_evidence` (`id`) ON DELETE CASCADE,
  CONSTRAINT `ensp_site_ibfk_1` FOREIGN KEY (`ensembl_id`) REFERENCES `ensp` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table experiment
# ------------------------------------------------------------

DROP TABLE IF EXISTS `experiment`;

CREATE TABLE `experiment` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `organism` varchar(20) NOT NULL DEFAULT '',
  `cell_line` varchar(50) DEFAULT '',
  `time` int(11) DEFAULT NULL,
  `description` varchar(50) NOT NULL DEFAULT '',
  `labelling_type` enum('free','metabolic','chemical') DEFAULT NULL,
  `labelling_method` varchar(11) DEFAULT NULL,
  `spectrometer` varchar(30) NOT NULL DEFAULT '',
  `enrichment_method` enum('TiO2','Antibody') DEFAULT NULL,
  `antibody` varchar(11) DEFAULT NULL,
  `identification_software` varchar(20) DEFAULT NULL,
  `quantification_software` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table inparanoid
# ------------------------------------------------------------

DROP TABLE IF EXISTS `inparanoid`;

CREATE TABLE `inparanoid` (
  `id` char(15) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  CONSTRAINT `inparanoid_ibfk_1` FOREIGN KEY (`id`) REFERENCES `ensp` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table ipi
# ------------------------------------------------------------

DROP TABLE IF EXISTS `ipi`;

CREATE TABLE `ipi` (
  `id` char(11) NOT NULL DEFAULT '',
  `sequence` text NOT NULL,
  `length` int(11) NOT NULL,
  `taxid` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table ipi_history
# ------------------------------------------------------------

DROP TABLE IF EXISTS `ipi_history`;

CREATE TABLE `ipi_history` (
  `current_ipi` char(11) NOT NULL DEFAULT '',
  `all_ipi` char(11) NOT NULL DEFAULT '',
  PRIMARY KEY (`current_ipi`,`all_ipi`),
  CONSTRAINT `ipi_history_ibfk_1` FOREIGN KEY (`current_ipi`) REFERENCES `ipi` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table pub_exp
# ------------------------------------------------------------

DROP TABLE IF EXISTS `pub_exp`;

CREATE TABLE `pub_exp` (
  `experiment` int(11) unsigned NOT NULL,
  `pub_id` int(11) unsigned NOT NULL,
  PRIMARY KEY (`experiment`),
  KEY `pub_id` (`pub_id`),
  CONSTRAINT `pub_exp_ibfk_2` FOREIGN KEY (`pub_id`) REFERENCES `publication` (`pub_id`) ON DELETE CASCADE,
  CONSTRAINT `pub_exp_ibfk_1` FOREIGN KEY (`experiment`) REFERENCES `experiment` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table publication
# ------------------------------------------------------------

DROP TABLE IF EXISTS `publication`;

CREATE TABLE `publication` (
  `pub_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `pubmed_id` int(11) NOT NULL,
  `fauthor` varchar(50) NOT NULL DEFAULT '',
  `publication_date` date NOT NULL,
  `journal` varchar(100) NOT NULL DEFAULT '',
  `title` text NOT NULL,
  PRIMARY KEY (`pub_id`),
  UNIQUE KEY `pubmed_id` (`pubmed_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table site_evidence
# ------------------------------------------------------------

DROP TABLE IF EXISTS `site_evidence`;

CREATE TABLE `site_evidence` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `residue` char(1) NOT NULL DEFAULT '',
  `type` enum('P','U','A','G') NOT NULL DEFAULT 'P',
  `localization_confidence` float NOT NULL,
  `experiment` int(11) unsigned NOT NULL,
  `quantitative_data` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `experiment` (`experiment`),
  KEY `quantitative_data` (`quantitative_data`),
  CONSTRAINT `site_evidence_ibfk_2` FOREIGN KEY (`quantitative_data`) REFERENCES `site_quantification` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `site_evidence_ibfk_1` FOREIGN KEY (`experiment`) REFERENCES `experiment` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table site_quantification
# ------------------------------------------------------------

DROP TABLE IF EXISTS `site_quantification`;

CREATE TABLE `site_quantification` (
  `id` int(11) unsigned NOT NULL,
  `condition` int(11) unsigned NOT NULL,
  `log2` float NOT NULL,
  PRIMARY KEY (`id`),
  KEY `condition` (`condition`),
  CONSTRAINT `site_quantification_ibfk_1` FOREIGN KEY (`condition`) REFERENCES `condition` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table uniprot_acc
# ------------------------------------------------------------

DROP TABLE IF EXISTS `uniprot_acc`;

CREATE TABLE `uniprot_acc` (
  `accession` varchar(15) NOT NULL DEFAULT '',
  `id` varchar(30) NOT NULL DEFAULT '',
  `reference_accession` varchar(15) NOT NULL DEFAULT '',
  PRIMARY KEY (`accession`,`reference_accession`),
  KEY `id` (`id`),
  KEY `reference_accession` (`reference_accession`),
  CONSTRAINT `uniprot_acc_ibfk_1` FOREIGN KEY (`id`) REFERENCES `uniprot_entry` (`id`) ON DELETE CASCADE,
  CONSTRAINT `uniprot_acc_ibfk_2` FOREIGN KEY (`reference_accession`) REFERENCES `uniprot_isoform` (`accession`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table uniprot_ensembl
# ------------------------------------------------------------

DROP TABLE IF EXISTS `uniprot_ensembl`;

CREATE TABLE `uniprot_ensembl` (
  `uniprot_accession` varchar(11) NOT NULL DEFAULT '',
  `ensembl_id` char(15) NOT NULL DEFAULT '',
  PRIMARY KEY (`uniprot_accession`,`ensembl_id`),
  KEY `ensembl_id` (`ensembl_id`),
  CONSTRAINT `uniprot_ensembl_ibfk_3` FOREIGN KEY (`ensembl_id`) REFERENCES `ensp` (`id`) ON DELETE CASCADE,
  CONSTRAINT `uniprot_ensembl_ibfk_2` FOREIGN KEY (`uniprot_accession`) REFERENCES `uniprot_acc` (`accession`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table uniprot_entry
# ------------------------------------------------------------

DROP TABLE IF EXISTS `uniprot_entry`;

CREATE TABLE `uniprot_entry` (
  `id` varchar(15) NOT NULL DEFAULT '',
  `reviewed` tinyint(1) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table uniprot_ipi
# ------------------------------------------------------------

DROP TABLE IF EXISTS `uniprot_ipi`;

CREATE TABLE `uniprot_ipi` (
  `ipi_id` char(11) NOT NULL DEFAULT '',
  `accession` varchar(11) NOT NULL DEFAULT '',
  PRIMARY KEY (`accession`),
  KEY `ipi_id` (`ipi_id`),
  CONSTRAINT `uniprot_ipi_ibfk_3` FOREIGN KEY (`ipi_id`) REFERENCES `ipi` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `uniprot_ipi_ibfk_2` FOREIGN KEY (`accession`) REFERENCES `uniprot_acc` (`accession`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table uniprot_isoform
# ------------------------------------------------------------

DROP TABLE IF EXISTS `uniprot_isoform`;

CREATE TABLE `uniprot_isoform` (
  `accession` varchar(11) NOT NULL DEFAULT '',
  `sequence` text NOT NULL,
  `length` int(11) NOT NULL,
  `taxid` int(11) NOT NULL,
  PRIMARY KEY (`accession`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;




/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
