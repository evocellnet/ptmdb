#' Gets the list of publications on ptmdb
#'
#' The publications available in a given database are listed ordered by publication date
#'
#' @param db An object of the class \code{\link{MySQLConnection}} 
#' @export
#' @examples
#' dbConnection <- ptmdbConnect(configFile)
#' publications <- getAllPublications(db)
#' @return Produces a dataframe containing each of the publications in the database

getAllPublications <- function(db){
	publications <- dbGetQuery(db, "SELECT * FROM publication ORDER BY publication_date DESC")
	return(publications)
}