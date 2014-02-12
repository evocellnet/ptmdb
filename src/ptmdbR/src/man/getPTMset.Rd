\name{getPTMset}
\alias{getPTMset}
\title{Gets a data.frame with the quantifications of a given protein}
\usage{
getPTMset(db, peptideCollapse = "none", onlySingles = FALSE,
  locscoreFilter = NA, na.scores.remove = FALSE)
}
\arguments{
  \item{db}{An object of the class
  \code{\link{MySQLConnection}}}

  \item{onlySingles}{An optional boolean. By default
  ('FALSE'), all the peptides are retrieved. If onlySingles
  is set to TRUE, only the peptides modified once are
  retrieved.}

  \item{peptideCollapse}{An optional character string
  giving a method for collapsing the peptides. This must be
  one of the following strings: "none" (default),
  "identical",...}

  \item{locscoreFilter}{A list containing the
  "loc.probability" and "ASCORE" score filters. By default
  'NA', no threshold is applied.}

  \item{na.scores.remove}{Boolean value. When TRUE the
  sites without localization scores are removed.}
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
The multiple experimental conditions are split into
different columns when they are measured by two independent
experiments. Two different experiments are those publised
in different publications or those produced in the same
publication by two different mass-spec experiments
(reported in independent tables). Those measurements
obtained in different biological replicates published in
the same article under the same experimental conditions are
averaged. Additional phenotypical data such as publication,
experimental setup or the description of the condition can
be found on the \code{\link{ExpressionSet}}.

Each of the rows in the \code{\link{ExpressionSet}}
represents a single peptide. Those peptides belonging to
different products of the same gene are treated as
different entities. In the same way, peptides with the same
sequence and modifications but reported by different
experiments are also considered as independent entities
unless a peptideCollapse option is specified. Additionally,
the metadata of the peptides contains additional
information such as the position of the modifications, the
modified residues, localization scores.

If the 'locscoreFilter' is greater than 0 the peptides
containing no sites with a localization score (localization
probability and ASCORE) greater than the specified
threshold are filtered. Depending on the

When 'onlySingles' is switched to TRUE, the peptides
containing more than one modification are ignored in the
final set.

\code{\link{getPTMset}} can also produce a PTMset with
no-redundant peptides if the peptideCollapse option is
specified. However, this process is not trivial since the
definition of equivalent peptides might change depending on
the biological question trying to answer. Therefore, this
function contains a number of alternative methods designed
to filter the PTMset on the most convenient way. The
options implemented are the following: \itemize{ \item none
(default). Peptides are keeped as independent entities no
matter they have the same peptide sequence and
modifications.  \item identical. Peptides with the same
exact peptide sequence and modifications are merged into
one single entry.  \item samemodifications. Peptides with
the same modifications but not necessarly the same sequence
are merged into one single entry. Using this option might
have as consequence the lost of some peptide sequences in
the ExpressionSet, since not unique peptide sequence can be
related with the given peptide entity.  ... }

This function might take some time to run depending on the
size of the database.
}
\examples{
db <- ptmdbConnect(user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE, port=DBPORT)
eset <- getPTMset(db)
}

