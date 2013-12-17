## Build the package
## ---------------------------------------------------------------------

args <- commandArgs(TRUE)

configfile <- args[1]	#input file with the 
source(configfile)

## Use roxygen to build the documentation
library(roxygen2)
roxygenize(PTMDBRSRC)

## Build and check the package
# system(paste("R CMD build ",pkgName, sep=""))
system(paste("TAR=/usr/bin/tar R CMD INSTALL",PTMDBRSRC,"-l",PTMDBRLIBLOC,sep=" "))
# system("Rcmd check pkgName")
# system("Rcmd check --as-cran pkgName")
