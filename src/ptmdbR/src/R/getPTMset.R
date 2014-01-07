#' Gets a data.frame with the quantifications of a given protein
#'
#' This function access to the database and returns all the quantifications found in a given database in the form of a \code{\link{ExpressionSet}}. The \code{\link{ExpressionSet}} contains the peptides in the rows and the conditions in the columns, being every single cell the log2 quantification of a given peptide in a given conditions.
#'
#' Each of the rows in the \code{\link{ExpressionSet}} represents a single peptide. Those peptides belonging to different isoforms of the same protein are treated as different entities. 
#'
#' The conditions are split into different columns when they are measured by two independent experiments. Those measurements obtained in different biological replicates obtained by the same group under the same experimental conditions are averaged. Moreover, additional phenotypical data such as publication, experimental setup or the description of the condition can be found on the \code{\link{ExpressionSet}} at the column level.
#'
#' @param db An object of the class \code{\link{MySQLConnection}}
#' @export
#' @examples
#' dbConnection <- ptmdbConnect(configFile)
#' eset <- getPTMset(db)
#' @return An object of the class \code{\link{ExpressionSet}} containing all the peptides and conditions and their log2 values. Additional information about the phenotypic data of the conditions as well as about the different peptides can be accessed used the functions defined in \code{\link{Biobase}}. 

getPTMset <- function(db){
	
	######################################### 
	# DATABASE 
	#########################################
	
	quantificationsQuery <- "SELECT 
		ensg.id AS 'ensg',
		ensg.name AS 'gene_name',
		ensp.id AS 'ensp',
		peptide.peptide AS 'peptide',
		GROUP_CONCAT(DISTINCT(ensp_site.position) ORDER BY ensp_site.position ASC) AS 'positions',
		GROUP_CONCAT(DISTINCT(site.modif_type)) AS 'types',
		experiment.id AS 'experiment',
		peptide_quantification.log2 AS 'log2',
		site.localization_score AS 'locscore',
		condition.id AS 'condition'
	FROM peptide
		INNER JOIN peptide_site ON peptide_site.peptide_id = peptide.id
		INNER JOIN site ON site.id = peptide_site.site_id
		INNER JOIN ensp_site ON site.id = ensp_site.site_id
		INNER JOIN ensp ON ensp.id = ensp_site.ensp
		INNER JOIN ensg_ensp ON ensg_ensp.ensp_id = ensp.id
		INNER JOIN ensg ON ensg_ensp.ensg_id = ensg.id
		INNER JOIN experiment ON peptide.experiment = experiment.id
		INNER JOIN peptide_quantification ON peptide_quantification.peptide = peptide.id
		INNER JOIN ptmdb.condition ON peptide_quantification.condition = condition.id
	WHERE peptide_quantification.log2 IS NOT NULL
	GROUP BY ensp.id,peptide.id,condition.id;";
	
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
	#Add another column with the peptide name i.e ENSPXXXX_POSITION1,POSITION2
	quantifications$peptideName <- paste(quantifications$ensp, quantifications$positions,quantifications$peptide,sep="_")
	
	# Add another column for condition + experiment
	quantifications$condExp <- paste(quantifications$condition, quantifications$experiment,sep="_")	
	
	# Integrate every condition and peptide considering that every peptide in each isoform, condition and experiment is an independent entry. The conditions are also divided in different tracks if they come from different papers. Then, still there might be multiple log2 measures for the same peptide (i.e multiple biological replicas). In that cases they are averaged to get a single number. 
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
	ensps <- sapply(strsplit(rownames(exprs), "_"), function(x) x[1])
	positions <- sapply(strsplit(rownames(exprs), "_"), function(x) x[2])
	peptides <- sapply(strsplit(rownames(exprs), "_"), function(x) x[4])
	protIdM <- unique(quantifications[ ,c("ensg","gene_name","ensp")])
	row.names(protIdM) <- protIdM$ensp
	ensgenes <- protIdM[ensps,"ensg"]
	gene_names <- protIdM[ensps,"gene_name"]
	
	features <- data.frame(row.names=rownames(exprs),
							ensps=ensps,
							ensgs=ensgenes,
							geneNames=gene_names,
							positions=positions,
							peptides=peptides)
	
	featureData <- new("AnnotatedDataFrame",data=features)
	
	
	#WRAPPING THE EXPRESSION SET
	eset <- ExpressionSet(
				assayData=exprs,
				phenoData=phenoData,
				featureData=featureData)
	
	return(eset)
}
