#PACKAGES
suppressMessages(library(RMySQL))

args <- commandArgs(TRUE)

configfile <- args[1]	#input file with the 
# infile <- args[2]	# input file with the PTMs
idType <- args[2]	#idType: [ipi,uniprot]
org <- args[3]		#number of organisms

#PROJECT VARIABLES
source(configfile)

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
	# coverage <- unique(res[res$inparanoid == res$ensembl_id & (!is.na(res$inparanoid)), c("inparanoid", "sequence")])
	# row.names(coverage) <- coverage$inparanoid
	# cat("# of inparanoid proteins covered by the study (considering correct id mapping)", nrow(coverage), "\n")
	val <- length(which(tapply(res$ensembl_id, res$index, function(x) length(which(!is.na(x))) > 0)))
	cat("# of identified ENSP ids: ",val," (",percentage(val,total),"%)\n", sep="")
	# val <- length(which(tapply(res$match, res$index, function(x) length(which(x)) > 0)))
	# cat("# of correctly mapped residues in at least 1 ENSP isoform of the inparanoid reference: ",val," (",percentage(val,total),"%)\n", sep="")
	# val <-  length(which(tapply(res$inparanoid, res$index, function(x) length(which(!is.na(x))) > 0)))
	# cat("# of identified Inparanoid ids within the family of isoforms: ",val," (",percentage(val,total),"%)\n", sep="")
	# matchInpara <- apply(res,1, function(x) match(coverage[x[6],"sequence"], x[3], x[4]))
	# val <- length(which(tapply(matchInpara, res$index, function(x) length(which(x)) > 0)))
	# cat("# of correctly mapped residues in the exact inparanoid reference: ",val," (",percentage(val,total),"%)\n", sep="")
}
 
############# 
#MAIN
############

# Set up a connection to your database management system.
# I'm using the public MySQL server for the UCSC genome browser (no password)
mychannel <- dbConnect(MySQL(), user=DBUSER, password=DBPASS, host=DBHOST, dbname=DATABASE)

#Reading PTM table
ptms <- read.table(file=pipe('cat /dev/stdin'), sep="\t", comment.char="",
						quote="",header=TRUE)

#we add a index to keep track of the different reported modifications
ptms <- cbind(1:nrow(ptms), ptms)
names(ptms)[1] <- "index"

#Database Table mapping uniprot 2 ensembl ids
if(idType == "ipi"){
	#Query database
	directMappingsQuery <- paste("SELECT ipihis.all_ipi,ensipi.ensembl_id,ensp.sequence FROM ipi_history AS ipihis INNER JOIN ensembl_ipi AS ensipi ON ipihis.current_ipi = ensipi.ipi INNER JOIN ensp ON ensipi.ensembl_id = ensp.id WHERE ensp.taxid=\'",org,"\'",sep="")
	directMapping <- query(directMappingsQuery)
	if(length(directMapping)){
		res <- merge(ptms, unique(directMapping[ ,c("all_ipi", "ensembl_id", "sequence")]), all.x=TRUE, by.x="id", by.y="all_ipi")
	}else{
		stop("No results returned from the database")
	}
}else if(idType == "uniprot"){
	directMappingsQuery <- paste("SELECT uniens.uniprot_accession,uniens.ensembl_id,ensp.sequence FROM uniprot_ensembl AS uniens INNER JOIN ensp ON uniens.ensembl_id = ensp.id WHERE ensp.taxid=\'",org,"\'",sep="")
	directMapping <- query(directMappingsQuery)
	#We add available ensembl references
	if(length(directMapping)){
		res <- merge(ptms, unique(directMapping[ ,c("uniprot_accession", "ensembl_id", "sequence")]), all.x=TRUE, by.x="id", by.y="uniprot_accession")
	}else{
		stop("No results returned from the database")
	}
}else if(idType == "ensp"){
	directMappingsQuery <- paste("SELECT ensp.id,ensp.sequence FROM ensp WHERE ensp.taxid=\'", org, "\'", sep="")
	directMapping <- query(directMappingsQuery)
	#We add available ensembl references
	if(length(directMapping)){
		res <- merge(ptms, unique(directMapping[ ,c("id", "sequence")]), all.x=TRUE, by.x="id", by.y="id")
	}else{
		stop("No results returned from the database")
	}
}else if(idType == "gene_name"){
	directMappingsQuery <- paste("SELECT ensg.name,ensp.id,sequence FROM ensg INNER JOIN ensg_ensp ON ensg.id=ensg_ensp.ensg_id INNER JOIN ensp ON ensg_ensp.ensp_id = ensp.id WHERE ensp.taxid=\'", org, "\'", sep="")
	directMapping <- query(directMappingsQuery)
	#We add available ensembl references
	if(length(directMapping)){
		res <- merge(ptms, unique(directMapping[ ,c("name","id", "sequence")]), all.x=TRUE, by.x="id", by.y="name")
	}else{
		stop("No results returned from the database")
	}
}else if(idType == "ensg"){
	directMappingsQuery <- paste("SELECT ensg_ensp.ensg_id,ensp.id,sequence FROM ensg INNER JOIN ensg_ensp ON ensg.id=ensg_ensp.ensg_id INNER JOIN ensp ON ensg_ensp.ensp_id = ensp.id WHERE ensp.taxid=\'", org, "\'", sep="")
	directMapping <- query(directMappingsQuery)
	#We add available ensembl references
	if(length(directMapping)){
		res <- merge(ptms, unique(directMapping[ ,c("name","id", "sequence")]), all.x=TRUE, by.x="id", by.y="ensg_id")
	}else{
		stop("No results returned from the database")
	}
}

#Print statistics about the data recovered
# printStatistics(res)

#Print output on file
write.table(res[order(res$index), ], file="", sep="\t",row.names=FALSE,quote=FALSE)
