#' Filters the PTMset peptides by the minimum number of publications
#'
#' @description
#' The peptides that do not contain a minimum number of valid quantifications (non-NA) for the given minimum number of publications are removed from the \code{\link{ExpressionSet}}.
#'
#' @param eset An object of the class \code{\link{ExpressionSet}}
#' @param n A minimum number of publications with valid quantifications. The default value (n=1) removes all the peptides without quantifications.
#'
#' @export
#'
#' @return An object of the class \code{\link{ExpressionSet}} containing the peptides (rows) fullfilling the condition. Additional information about the phenotypic data of the conditions and the feature data can be accessed using the functions defined in \code{\link{Biobase}}. 
#'
#' @examples
#' db <- ptmdbConnect(user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE, port=DBPORT)  #database connection
#' eset <- getPTMset(db) #gets the PTMset
#' filteredEset <- filterPTMsetByMinPubs(eset, n=1)])  #returns the PTMset filtered


filterPTMsetByMinPubs <- function(eset, n=1){
	
    if (!is.numeric(pubEvidence))
        stop("invalid 'n' argument")
	
	#Filters the P
	pubs <- pData(eset)$publication
	indexes <- apply(exprs(eset), 1, function(x) length(unique(pubs[!is.na(x)]))) >= n
	eset <- eset[indexes, ]
	
	return(eset)
}
