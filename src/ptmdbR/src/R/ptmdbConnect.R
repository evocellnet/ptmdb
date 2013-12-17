#' Connects to ptmdb database
#'
#' This function can be used to directly connect to the database using a configuration File.
#'
#' @param configfile path to the configuration file of a given ptmdb project. This file should contain the DBUSER, DBPASS, DBHOST, DATABASE and DBPORT of the database of interest 
#' @export
#' @examples
#' dbConnection <- ptmdbConnect(configFile)
#' @return Produces an object of the class \code{\link{MySQLConnection}}

ptmdbConnect <- function(configFile){
	source(configFile)
	# Set up a connection to the database
	mychannel <- dbConnect(MySQL(), user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE, port=DBPORT)
	return(mychannel)
}
