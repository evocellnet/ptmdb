\name{getSiteQuantificationsForProtein}
\alias{getSiteQuantificationsForProtein}
\title{Gets a data.frame with the quantifications of a given protein}
\usage{
getSiteQuantificationsForProtein(db, enspid)
}
\arguments{
  \item{db}{An object of the class
  \code{\link{MySQLConnection}}}

  \item{enspid}{A string containing an ensembl protein id}
}
\value{
A dataframe with all the quantifications and some
additional information such as position location, condition
description,...
}
\description{
It collapses information related with the quantifications
obtained for a given protein as well as some additional
information regarding the peptides, the localization
process or the condition description.
}
\examples{
dbConnection <- ptmdbConnect(configFile)
quantifications <- getSiteQuantificationsForProtein(db, 'ENSP00000300093')
}

