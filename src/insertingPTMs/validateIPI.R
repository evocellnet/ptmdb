#PACKAGES
suppressMessages(library(RMySQL))

args <- commandArgs(TRUE)

configfile <- args[1]	#input file with the 
infile <- args[2]	# input file with the PTMs
colnum <- args[3]	# number of columns 
org <- args[4]		#number of organisms
fieldSeparator <- args[5]	#field separator for the columns
headerBool <-args[6]	#contains header
idCol <- args[7]	#Column containing the protein ids
aaCol <- args[8]	#Column containing the aminoacids
resnumCol <- args[9]	#Column containing the position in the sequence
reswinCol <- args[10]	#Column containing the residue window
reswinWil <- args[11]	#Character used to refer to non-present AAs on the sequence

#PROJECT VARIABLES
source(configfile)

#Defining columns
colnames <- list()
colnames[[as.character(idCol)]] <- "ipi"
colnames[[as.character(aaCol)]] <- "residue"
colnames[[as.character(resnumCol)]] <- "position"
colnames[[as.character(reswinCol)]] <- "residueWindow"
coltypes <- list()
coltype[[as.character(idCol)]] <- "character"
coltype[[as.character(aaCol)]] <- "character"
coltype[[as.character(resnumCol)]] <- "numeric"
coltype[[as.character(reswinCol)]] <- "character"

#FUNCTIONS
#calculates percentage
percentage <- function(value, total){
	return(round((value/total * 100), digits=2))
}
# Checks if a residue-position matches with a given sequence 
match <- function(sequence,residue, position){
	if(is.na(residue) | is.na(sequence) | is.na(position)){
		return(FALSE)
	}
	if(!is.na(sequence)){
		seqarray <- unlist(strsplit(sequence, ""))
		if(length(seqarray)>=as.numeric(position)){
			if(seqarray[as.numeric(position)] == residue){
				return(TRUE)
			}else{
				return(FALSE)
			}
		}else{
			return(FALSE)
		}
	}else{
		return(FALSE)
	}
}
# Function to make it easier to query 
query <- function(...) dbGetQuery(mychannel, ...)
 
#Print statistics about the mapped residues
printStatistics <- function(res){
	total <- length(unique(res$index))
	cat("# of ptms: ",total,"\n")
	coverage <- unique(res[res$inparanoid == res$ensembl_id & (!is.na(res$inparanoid)), c("inparanoid", "sequence")])
	row.names(coverage) <- coverage$inparanoid
	# cat("# of inparanoid proteins covered by the study (considering correct id mapping)", nrow(coverage), "\n")
	val <- length(which(tapply(res$ensembl_id, res$index, function(x) length(which(!is.na(x))) > 0)))
	cat("# of identified ENSP ids: ",val," (",percentage(val,total),"%)\n", sep="")
	val <- length(which(tapply(res$match, res$index, function(x) length(which(x)) > 0)))
	cat("# of correctly mapped residues in at least 1 ENSP isoform of the inparanoid reference: ",val," (",percentage(val,total),"%)\n", sep="")
	val <-  length(which(tapply(res$inparanoid, res$index, function(x) length(which(!is.na(x))) > 0)))
	cat("# of identified Inparanoid ids within the family of isoforms: ",val," (",percentage(val,total),"%)\n", sep="")
	matchInpara <- apply(res,1, function(x) match(coverage[x[6],"sequence"], x[3], x[4]))
	val <- length(which(tapply(matchInpara, res$index, function(x) length(which(x)) > 0)))
	cat("# of correctly mapped residues in the exact inparanoid reference: ",val," (",percentage(val,total),"%)\n", sep="")
}
 
############# 
#MAIN
############

# Set up a connection to your database management system.
# I'm using the public MySQL server for the UCSC genome browser (no password)
mychannel <- dbConnect(MySQL(), user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE)

 
ptms <- read.table(file=infile, sep=fieldSeparator, comment.char="",
						quote="",header=headerBool, col.names=sapply(c(1:colnum), function(x) colnames[[as.character(x)]]),
						colClasses=sapply(c(1:colnum), function(x) coltype[[as.character(x)]]))

#we add a index to keep track of the different reported modifications
ptms <- cbind(1:nrow(ptms), ptms)
names(ptms)[1] <- "index"

#Database Table mapping uniprot 2 ensembl ids
directMappingsQuery <- "SELECT ipihis.all_ipi,ensipi.ensembl_id,ensp.sequence FROM ipi_history AS ipihis INNER JOIN ensembl_ipi AS ensipi ON ipihis.current_ipi = ensipi.ipi INNER JOIN ensp ON ensipi.ensembl_id = ensp.id"
directMapping <- query(directMappingsQuery)

#We add available ensembl references
res <- merge(ptms, unique(directMapping[ ,c("all_ipi", "ensembl_id", "sequence")]), all.x=TRUE, by.x="ipi", by.y="all_ipi")

#check if the residue matches in the exact position to the sequence and report it in "match" column
res$match <- apply(res, 1, function(x) match(x[which(names(res) == "sequence")],x[which(names(res) == "residue")],x[which(names(res) == "position")]))

#Print statistics about the data recovered
# printStatistics(res)

#Print output on file
write.table(res[order(res$index), ], file="", sep="\t",row.names=FALSE,quote=FALSE)
