#!/bin/bash
set -e # Any subsequent commands which fail will cause the shell script to exit immediately

. ./config.sh	#Load config file

# BUILDING DATABASE SCHEMA ##################################################################################
echo -ne "Connecting to the database...\n"
# Building the tables
# The database and the user need to be created before this step
mysql -u root -h ${DBHOST} -p ${DATABASE} < ${DATABASE_SCHEMA}


# FORMATING AND INSERTING ##################################################################################
# TODO: Adapt to run with multiple organisms

echo -ne "Preformatting databases... "
if [ ! -e ${IPI_HISTORY/.history/_parsed.history} ]
	then
		perl ./src/databaseXreferences/preformat_IPIhistory.pl ${IPI_FASTA} ${IPI_HISTORY} > ${IPI_HISTORY/.history/_parsed.history}
		echo -ne "\n"
	else
		echo -ne "skipped\n"
fi

echo -ne "Inserting databases information...\n"
perl ./src/databaseXreferences/insertDatabaseInfo.pl ${DBHOST} ${DATABASE} ${DBUSER} ${DBPASS} ${UNIPROT} ${IPI_FASTA} ${IPI_HISTORY/.history/_parsed.history} ${INPARANNOID_HUMAN} ${ENSEMBL_FASTA} ${TAXID}

###########################################################################################################
