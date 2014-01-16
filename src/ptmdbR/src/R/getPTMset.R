#' Gets a data.frame with the quantifications of a given protein
#'
#' This function access to the database and returns all the quantifications found in a given database in the form of a \code{\link{ExpressionSet}}. The \code{\link{ExpressionSet}} contains the peptides in the rows and the conditions in the columns, being every single cell the log2 quantification of a given peptide in a given conditions. Additional metadata corresponding to rows and columns is also contained in the \code{\link{ExpressionSet}} object.
#'
#' Each of the rows in the \code{\link{ExpressionSet}} represents a single peptide. Those peptides belonging to different products of the same gene are treated as different entities. In the same way, peptides with the same sequence and modifications but reported by different experiments are also considered as independent entities at this stage. Further filtering might be required to collapse this information into more biologically relevant results. The metadata of the peptides contains additional information such as the position of the modifications, the modified residues, localization scores,
#'
#' The conditions are split into different columns when they are measured by two independent experiments. Two different experiments are those publised in different publications or those produced in the same publication by two different mass-spec experiments (reported in independent tables). Those measurements obtained in different biological replicates published in the same article under the same experimental conditions are averaged. Additional phenotypical data such as publication, experimental setup or the description of the condition can be found on the \code{\link{ExpressionSet}}.
#'
#' This function might take some time to run depending on the size of the database.
#'
#' @param db An object of the class \code{\link{MySQLConnection}}
#' @export
#' @examples
#' db <- ptmdbConnect(user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE, port=DBPORT)
#' eset <- getPTMset(db)
#' @return An object of the class \code{\link{ExpressionSet}} containing all the peptides and conditions and their log2 values. Additional information about the phenotypic data of the conditions and the feature data can be accessed using the functions defined in \code{\link{Biobase}}. 

getPTMset <- function(db){
	
	######################################### 
	# DATABASE 
	#########################################
	
	quantificationsQuery <- "
		SELECT 
			pepinfo.*,
			ensg.id AS 'ensg',
			ensg.name AS 'gene_name',
			peptide.peptide AS 'peptide',
			experiment.id AS 'experiment',
			peptide_quantification.log2 AS 'log2',
			condition.id AS 'condition'
		FROM peptide	
			INNER JOIN(
				SELECT
					ensp.id AS 'ensp',
					peptide_site.peptide_id AS 'peptide_id',
					GROUP_CONCAT(ensp_site.position ORDER BY ensp_site.position ASC) AS 'positions',
					GROUP_CONCAT(site.residue ORDER BY ensp_site.position) AS 'residues',
					GROUP_CONCAT(site.modif_type ORDER BY ensp_site.position) AS 'types',
					GROUP_CONCAT(site.localization_score ORDER BY ensp_site.position) AS 'locscores'
				FROM site 
					INNER JOIN ensp_site ON site.id = ensp_site.site_id
					INNER JOIN peptide_site ON peptide_site.site_id = site.id
					INNER JOIN ensp ON ensp_site.ensp = ensp.id
				GROUP BY ensp_site.ensp,peptide_site.peptide_id
				) AS pepinfo ON pepinfo.peptide_id = peptide.id
			INNER JOIN ensg_ensp ON ensg_ensp.ensp_id = pepinfo.ensp
			INNER JOIN ensg ON ensg_ensp.ensg_id = ensg.id
			INNER JOIN experiment ON peptide.experiment = experiment.id
			INNER JOIN peptide_quantification ON peptide_quantification.peptide = peptide.id
			INNER JOIN ptmdb.condition ON peptide_quantification.condition = condition.id
		WHERE peptide_quantification.log2 IS NOT NULL
	;";
		
	conditionsQuery <- "SELECT *,id AS condition_id FROM ptmdb.condition;";
	experimentsQuery <- "SELECT *,id AS experiment_id FROM ptmdb.experiment;";		
	publicationsQuery <- "SELECT * FROM ptmdb.publication;";
	
	# querying database
	quantifications <- dbGetQuery(db, quantificationsQuery)
	conditions <- dbGetQuery(db, conditionsQuery);
	conditions <- conditions[ ,!(names(conditions) %in% "id")]
	experiments <- dbGetQuery(db, experimentsQuery);
	experiments <- experiments[ ,!(names(experiments) %in% "id")]
	publications <- dbGetQuery(db, publicationsQuery);
	
	######################################### 
	# FORMATING DATA TO CREATE EXPRESSIONSET
	#########################################
	
	#PREPARING EXPRESSION OBJECT
	
	
	quantifications$peptideName <- paste(quantifications$ensp, quantifications$peptide_id,sep="_")	
	
	# Add another column for condition + experiment
	quantifications$condExp <- paste(quantifications$condition, quantifications$experiment,sep="_")	
	
	# Integrate every condition and peptide considering that every peptide in each isoform, condition and experiment is an independent entry. The conditions are also divided in different tracks if they come from different experiments (either on the different papers or in the same paper multiple mass_spec experiments). Then, still there might be multiple log2 measures for the same peptide (i.e multiple biological replicas). In that cases they are averaged to get a single number. 
	df <- tapply(quantifications$log2, list(quantifications$peptideName,quantifications$condExp), function(y) mean(y,na.rm=TRUE))
	
	exprs <- as.matrix(df)
	
	#PREPARING PHENOTIPIC DATA
	thisconditions <- sapply(strsplit(colnames(exprs), "_"), function(x) x[1])
	row.names(conditions) <- conditions$condition_id
	conds <- conditions[as.character(thisconditions), ]
	
	thisexperiments <- sapply(strsplit(colnames(exprs), "_"), function(x) x[2])
	row.names(experiments) <- experiments$experiment_id
	exps <- experiments[as.character(thisexperiments), ]
	
	row.names(publications) <- publications$pub_id
	pubs <- publications[as.character(experiments[as.character(thisexperiments), "publication"]), ]
	
	pData <- cbind(conds,exps,pubs)
	rownames(pData) <- colnames(exprs)
	phenoData <- new("AnnotatedDataFrame",data=pData)
	
	
	#PREPARING FEATURE DATA
	peptideInfo <- unique(quantifications[ ,!names(quantifications) %in% c("experiment","condition","log2","ensp","condExp")])
	rownames(peptideInfo) <- peptideInfo$peptideName
		
	ensps <- sapply(strsplit(rownames(exprs), "_"), function(x) x[1])
	positions <- peptideInfo[rownames(exprs), "positions"]
	peptides <- peptideInfo[rownames(exprs), "peptide"]
	ensgenes <- peptideInfo[rownames(exprs), "ensg"]
	gene_names <- peptideInfo[rownames(exprs), "gene_name"]
	localization_scores <- peptideInfo[rownames(exprs), "locscores"]
	residues <- peptideInfo[rownames(exprs), "residues"]
	modif_types <- peptideInfo[rownames(exprs), "types"]
	
	features <- data.frame(row.names=rownames(exprs),
							ensps=ensps,
							ensgs=ensgenes,
							geneNames=gene_names,
							positions=positions,
							peptides=peptides,
							locscores=localization_scores,
							residues=residues,
							modif_types=modif_types
							)
	
	featureData <- new("AnnotatedDataFrame",data=features)
	
	#WRAPPING THE EXPRESSION SET
	eset <- ExpressionSet(
				assayData=exprs,
				phenoData=phenoData,
				featureData=featureData)
	
	return(eset)
}
