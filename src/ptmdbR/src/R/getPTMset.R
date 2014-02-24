#' Gets a data.frame with the quantifications of a given protein
#'
#' @description
#' This function access to the database and returns all the quantifications found in a given database in the form of a \code{\link{ExpressionSet}}. The \code{\link{ExpressionSet}} contains the peptides in the rows and the conditions in the columns, being every single cell the log2 quantification of a given peptide in a given conditions. Additional metadata corresponding to rows and columns is also contained in the \code{\link{ExpressionSet}} object.
#'
#' @param db An object of the class \code{\link{MySQLConnection}}
#' @param onlySingles An optional boolean. By default ('FALSE'), all the peptides are retrieved. If onlySingles is set to TRUE, only the peptides modified once are retrieved.  
#' @param peptideCollapse An optional character string giving a method for collapsing the peptides. This must be one of the following strings: "none" (default), "identical",...
#' @param locscoreFilter A list containing the "loc.probability" and "ASCORE" score filters. By default 'NA', no threshold is applied. 
#' @param na.scores.remove Boolean value. When TRUE the sites without localization scores are removed.
#' 
#' @export
#'
#' @details
#'
#' The multiple experimental conditions are split into different columns when they are measured by two independent experiments. Two different experiments are those publised in different publications or those produced in the same publication by two different mass-spec experiments (reported in independent tables). Those measurements obtained in different biological replicates published in the same article under the same experimental conditions are averaged. Additional phenotypical data such as publication, experimental setup or the description of the condition can be found on the \code{\link{ExpressionSet}}.
#'
#' Each of the rows in the \code{\link{ExpressionSet}} represents a single peptide. Those peptides belonging to different products of the same gene are treated as different entities. In the same way, peptides with the same sequence and modifications but reported by different experiments are also considered as independent entities unless a peptideCollapse option is specified. Additionally, the metadata of the peptides contains additional information such as the position of the modifications, the modified residues, localization scores.
#'
#' If the 'locscoreFilter' is greater than 0 the peptides containing no sites with a localization score (localization probability and ASCORE) greater than the specified threshold are filtered. Depending on the 
#'
#' When 'onlySingles' is switched to TRUE, the peptides containing more than one modification are ignored in the final set.
#'
#' \code{\link{getPTMset}} can also produce a PTMset with no-redundant peptides if the peptideCollapse option is specified. However, this process is not trivial since the definition of equivalent peptides might change depending on the biological question trying to answer. Therefore, this function contains a number of alternative methods designed to filter the PTMset on the most convenient way. The options implemented are the following:
#' \itemize{
#'   \item none (default). Peptides are keeped as independent entities no matter they have the same peptide sequence and modifications.  	
#'   \item identical. Peptides with the same exact peptide sequence and modifications are merged into one single entry.
#'   \item samemodifications. Peptides with the same modifications but not necessarly the same sequence are merged into one single entry. Using this option might have as consequence the lost of some peptide sequences in the ExpressionSet, since not unique peptide sequence can be related with the given peptide entity.
#'   ...
#' }
#'
#' This function might take some time to run depending on the size of the database.
#'
#' @return An object of the class \code{\link{ExpressionSet}} containing all the peptides and conditions and their log2 values. Additional information about the phenotypic data of the conditions and the feature data can be accessed using the functions defined in \code{\link{Biobase}}. 
#'
#' @examples
#' db <- ptmdbConnect(user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE, port=DBPORT)
#' eset <- getPTMset(db)
#'

getPTMset <- function(db, peptideCollapse="none", onlySingles=FALSE, locscoreFilter=NA, na.scores.remove=FALSE){
	
    na.method <- pmatch(peptideCollapse, c("none", "identical", "samemodifications"))
    if (is.na(na.method)) 
        stop("invalid 'peptideCollapse' argument")
    if (!is.logical(onlySingles)) 
        stop("TRUE/FALSE value expected on 'onlySingles' argument")
	if (!is.list(locscoreFilter)){
		if(!is.na(locscoreFilter)){
	        stop("List or NA expected on 'locscoreFilter' argument")
		}
	}
    if (!is.logical(na.scores.remove)) 
        stop("TRUE/FALSE value expected on 'na.scores.remove' argument")
	
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
	row.names(experiments) <- experiments$experiment_id
	publications <- dbGetQuery(db, publicationsQuery);
	row.names(publications) <- publications$pub_id
	
	
	######################################### 
	# ONLY SINGLES PARAMETER
	#########################################
	
	if(onlySingles){
		quantifications <- quantifications[sapply(strsplit(quantifications$types, ","), length) == 1, ]
	}
	
	######################################### 
	# COLLAPSING PEPTIDES
	#########################################
	
	#This column would be used to select unique peptides. The values of all the peptides sharing this would have the same id
	if(peptideCollapse == "identical"){
		quantifications$peptideName <- paste(quantifications$ensp, quantifications$positions,quantifications$types, quantifications$peptide,sep="_")	
	}else if(peptideCollapse == "samemodifications"){
		quantifications$peptideName <- paste(quantifications$ensp, quantifications$positions,quantifications$types,sep="_")	
	}else if(peptideCollapse == "none"){
		quantifications$peptideName <- paste(quantifications$ensp, quantifications$positions,quantifications$types, quantifications$peptide, quantifications$peptide_id,sep="_")	
	}
	
	######################################### 
	# FILTERING BY LOCALIZATION SCORE
	#########################################
	if(is.list(locscoreFilter)){
		scoresValues <- as.data.frame(cbind(experiments[quantifications$experiment, "scoring_method"], quantifications$locscore))
		scoresValues[scoresValues == "NA"] <- NA
		scoresValues$max <- sapply(strsplit(as.character(scoresValues[ ,2]), ","), function(x) max(as.numeric(x)))
		scoresValues$probBool <- scoresValues$V1 == "Localization Probability"
		scoresValues$ascoreBool <- scoresValues$V1 == "Localization Probability"
		scoresValues$probBoolPos <- scoresValues$max > locscoreFilter[["loc.probability"]]
		scoresValues$ascoreBoolPos <- scoresValues$max > locscoreFilter[["ASCORE"]]
		indexes <- (scoresValues$probBool & scoresValues$probBoolPos) | (scoresValues$ascoreBool & scoresValues$ascoreBoolPos)
		if(na.scores.remove){
			indexes[is.na(indexes)] <- FALSE
		}else{
			indexes[is.na(indexes)] <- TRUE
		}
		quantifications <- quantifications[indexes, ]
	}
	
	######################################### 
	# FORMATING DATA TO CREATE EXPRESSIONSET
	#########################################
		
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
	exps <- experiments[as.character(thisexperiments), ]
	
	pubs <- publications[as.character(experiments[as.character(thisexperiments), "publication"]), ]
	
	pData <- cbind(conds,exps,pubs)
	pData$scoring_method[pData$scoring_method == "NA"] <- NA #Correcting NA values
	
	rownames(pData) <- colnames(exprs)
	phenoData <- new("AnnotatedDataFrame",data=pData)	
	
	#PREPARING FEATURE DATA
		
	#peptideCollapse identical
	if(peptideCollapse == "identical"){
		# Peptide information when each peptide have different sequence/modifications
		thepeptideInfo <- unique(quantifications[ ,!names(quantifications) %in% c("experiment","condition","log2","ensp","condExp","peptide_id")])
		peptideInfo <- aggregate(thepeptideInfo, by=list(thepeptideInfo$peptideName), unique)
		peptideInfo$locscores <- sapply(tapply(thepeptideInfo$locscores, thepeptideInfo$peptideName, function (x) if(length(which(!is.na(x)))>0){sapply(x[!is.na(x)],function(y) as.numeric(unlist(strsplit(y, ","))))}else{x}), function(z) if(is.matrix(z)){paste(apply(z,1,function(b) max(b,na.rm=TRUE)),collapse=",")}else{if(length(z[!is.na(z)])>0){max(unlist(z), na.rm=TRUE)}else{NA}})
	
	#peptideCollapse samemodifications	
	}else if(peptideCollapse == "samemodifications"){
		thepeptideInfo <- unique(quantifications[ ,!names(quantifications) %in% c("experiment","condition","log2","ensp","condExp","peptide_id","peptide")])
		peptideInfo <- aggregate(thepeptideInfo, by=list(thepeptideInfo$peptideName), unique)
		peptideInfo$peptide <- tapply(quantifications$peptide, quantifications$peptideName, function (x) if(length(unique(x)) == 1){return(unique(x))}else{return(NA)})
		peptideInfo$locscores <- sapply(tapply(thepeptideInfo$locscores, thepeptideInfo$peptideName, function (x) if(length(which(!is.na(x)))>0){sapply(x[!is.na(x)],function(y) as.numeric(unlist(strsplit(y, ","))))}else{x}), function(z) if(is.matrix(z)){paste(apply(z,1,function(b) max(b,na.rm=TRUE)),collapse=",")}else{if(length(z[!is.na(z)])>0){max(unlist(z), na.rm=TRUE)}else{NA}})
	
	#peptideCollapse none	
	}else if(peptideCollapse == "none"){
		peptideInfo <- unique(quantifications[ ,!names(quantifications) %in% c("experiment","condition","log2","ensp","condExp","peptide_id")])
		
	}
	rownames(peptideInfo) <- peptideInfo$peptideName
	
	
	features <- cbind(sapply(strsplit(rownames(exprs), "_"), function(x) x[1]), peptideInfo[rownames(exprs), c("positions", "peptide", "ensg","gene_name","locscores","residues","types")])
	names(features) <- c("ensp","positions", "peptide", "ensg","gene_name","locscores","residues","types")
	
	featureData <- new("AnnotatedDataFrame",data=features)
	
	#WRAPPING THE EXPRESSION SET
	eset <- ExpressionSet(
				assayData=exprs,
				phenoData=phenoData,
				featureData=featureData)
	
	return(eset)
}