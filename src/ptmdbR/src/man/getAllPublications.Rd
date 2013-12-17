\name{getAllPublications}
\alias{getAllPublications}
\title{Connects to ptmdb database}
\usage{
getAllPublications(db)
}
\arguments{
  \item{db}{An object of the class
  \code{\link{MySQLConnection}}}
}
\value{
Produces a dataframe containing each of the publications in
the database
}
\description{
Gets the list of publications on ptmdb
}
\examples{
dbConnection <- ptmdbConnect(configFile)
publications <- getAllPublications(db)
}

