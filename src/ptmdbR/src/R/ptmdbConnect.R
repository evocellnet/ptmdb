#' Connects to ptmdb database
#'
#' This function can be used to directly connect to the database using a configuration File.
#'
#' @param ... Arguments necessary to connect to the database. The arguments are inherited from the \code{\link{dbConnect}} function (see example)
#' @export
#' @examples
#' dbConnection <- ptmdbConnect(user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE, port=DBPORT)
#' @return Produces an object of the class \code{\link{MySQLConnection}}

ptmdbConnect <- function(...){
	# Set up a connection to the database
	mychannel <- dbConnect(MySQL(), ...)
	return(mychannel)
}
