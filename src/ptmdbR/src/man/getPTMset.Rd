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
conditions. Additional metadata corresponding to rows and
columns is also contained in the
\code{\link{ExpressionSet}} object.
}
\details{
Each of the rows in the \code{\link{ExpressionSet}}
represents a single peptide. Those peptides belonging to
different products of the same gene are treated as
different entities. In the same way, peptides with the same
sequence and modifications but reported by different
experiments are also considered as independent entities at
this stage. Further filtering might be required to collapse
this information into more biologically relevant results.
The metadata of the peptides contains additional
information such as the position of the modifications, the
modified residues, localization scores,

The conditions are split into different columns when they
are measured by two independent experiments. Two different
experiments are those publised in different publications or
those produced in the same publication by two different
mass-spec experiments (reported in independent tables).
Those measurements obtained in different biological
replicates published in the same article under the same
experimental conditions are averaged. Additional
phenotypical data such as publication, experimental setup
or the description of the condition can be found on the
\code{\link{ExpressionSet}}.

This function might take some time to run depending on the
size of the database.
}
\examples{
db <- ptmdbConnect(user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE, port=DBPORT)
eset <- getPTMset(db)
}

