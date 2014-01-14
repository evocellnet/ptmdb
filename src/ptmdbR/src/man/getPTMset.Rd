\name{getPTMset}
\alias{getPTMset}
\title{Gets a data.frame with the quantifications of a given protein}
\usage{
getPTMset(db)
}
\arguments{
  \item{db}{An object of the class
  \code{\link{MySQLConnection}}}
}
\value{
An object of the class \code{\link{ExpressionSet}}
containing all the peptides and conditions and their log2
values. Additional information about the phenotypic data of
the conditions and the feature data can be accessed using
the functions defined in \code{\link{Biobase}}.
}
\description{
This function access to the database and returns all the
quantifications found in a given database in the form of a
\code{\link{ExpressionSet}}. The
\code{\link{ExpressionSet}} contains the peptides in the
rows and the conditions in the columns, being every single
cell the log2 quantification of a given peptide in a given
conditions.
}
\details{
Each of the rows in the \code{\link{ExpressionSet}}
represents a single peptide. Those peptides belonging to
different isoforms of the same protein are treated as
different entities.

The conditions are split into different columns when they
are measured by two independent experiments. Those
measurements obtained in different biological replicates
obtained by the same group under the same experimental
conditions are averaged. Moreover, additional phenotypical
data such as publication, experimental setup or the
description of the condition can be found on the
\code{\link{ExpressionSet}} at the column level.

This function might take some time to run depending on the
size of the database.
}
\examples{
db <- ptmdbConnect(user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE, port=DBPORT)
eset <- getPTMset(db)
}

