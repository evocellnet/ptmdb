#' Gets a data.frame with the quantifications of a given protein
#'
#' It collapses information related with the quantifications obtained for a given protein as well as some additional information regarding the peptides, the localization process or the condition description.
#'
#' @param db An object of the class \code{\link{MySQLConnection}}
#' @param enspid A string containing an ensembl protein id 
#' @export
#' @examples
#' dbConnection <- ptmdbConnect(configFile)
#' quantifications <- getSiteQuantificationsForProtein(db, 'ENSP00000300093')
#' @return A dataframe with all the quantifications and some additional information such as position location, condition description,...

getSiteQuantificationsForProtein <- function(db, enspid){
	
	sqlString <- paste("SELECT ensp.id,peptide.peptide,ensp_site.position,site.localization_score, peptide_quantification.log2, condition.description, condition.control_description, condition.time_min
	FROM ensp
		INNER JOIN ensp_peptide ON ensp.id = ensp_peptide.ensembl_id
		INNER JOIN peptide ON ensp_peptide.peptide_id = peptide.id
		INNER JOIN peptide_site ON peptide.id = peptide_site.peptide_id
		INNER JOIN site ON site.id = peptide_site.site_id
		INNER JOIN ensp_site ON ensp_site.site_id=site.id AND ensp.id = ensp_site.ensp
		INNER JOIN peptide_quantification ON peptide.id = peptide_quantification.peptide
		INNER JOIN ptmdb.condition ON peptide_quantification.condition = condition.id
		INNER JOIN experiment ON peptide.experiment = experiment.id
	WHERE ensp.id = '",enspid,"' AND peptide_quantification.log2 IS NOT NULL ORDER BY ensp_site.position", sep="");
	
	quantifications <- dbGetQuery(db, sqlString)
	
	return(quantifications)
}