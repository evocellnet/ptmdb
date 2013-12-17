\name{ptmdbConnect}
\alias{ptmdbConnect}
\title{Connects to ptmdb database}
\usage{
ptmdbConnect(configFile)
}
\arguments{
  \item{configfile}{path to the configuration file of a
  given ptmdb project. This file should contain the DBUSER,
  DBPASS, DBHOST, DATABASE and DBPORT of the database of
  interest}
}
\value{
Produces an object of the class
\code{\link{MySQLConnection}}
}
\description{
This function can be used to directly connect to the
database using a configuration File.
}
\examples{
dbConnection <- ptmdbConnect(configFile)
}

