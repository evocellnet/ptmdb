#' Connects to ptmdb database
#'
#' Gets the list of publications on ptmdb
#'
#' @param db An object of the class \code{\link{MySQLConnection}} 
#' @export
#' @examples
#' dbConnection <- ptmdbConnect(configFile)
#' publications <- getAllPublications(db)
#' @return Produces a dataframe containing each of the publications in the database

getAllPublications <- function(db){
	publications <- dbGetQuery(db, "SELECT * FROM publication")
	return(publications)
}