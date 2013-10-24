#!/bin/bash
set -e # Any subsequent commands which fail will cause the shell script to exit immediately


. ./config.sh	#Load config file
	
declare -a organism=()
declare -a scientific=()
declare -a tax=()
declare -a unip=()
declare -a inpara=()
declare -a ipi=()
declare -a ens=()
declare -a biomart=()

while IFS='	' read -r f1 f2 f3 f4 f5 f6 f7 f8	# Set "	" (tab) as the field separator using $IFS and read line by line using while read combo 
do
	organism+=("$f1")	#store all the columns of csv file into arrays
	scientific+=("$f2")
	tax+=("$f3")
	unip+=("$f4")
	inpara+=("$f5")
	ipi+=("$f6")
	ens+=("$f7")
	biomart+=("$f8")
	
done < "$input"


# DOWNLOAD NECESSARY BIOMART DATA ##################################################################################

echo -ne "Downloading datasets from Biomart...\n "	
wget -P ./biomart-perl "http://www.biomart.org/biomart/martservice?type=datasets&mart=ensembl" -O ./biomart-perl/biomart_datasets.txt

echo -ne "Downloading registries from Biomart...\n "	
wget -P ./biomart-perl "http://www.biomart.org/biomart/martservice?type=registry" -O ./biomart-perl/allRegistries.txt

REGISTRIES="./biomart-perl/allRegistries.txt"

for ((i=1; i<${#organism[@]}; i++))

	do

	TAXID="${tax[i]}"
	SCIENTIFIC_NAME="${scientific[i]}"
	COMMON_NAME="${organism[i]}"
	
	#CHECKING IF AN ORGANISM EXISTS IN THE DATABASE
	
	EXIST=`perl ./checkOrganism.pl ${DBHOST} ${DATABASE} ${DBUSER} ${DBPASS} ${TAXID}`
	
		if [[ $EXIST = "TRUE" ]]
			then
				echo -ne "Organism $SCIENTIFIC_NAME already exists in the database\n\n"
			else
			#REQUIRED EXTERNAL DATABASES
				
				echo -ne "\n\t* Inserting new Organism ${scientific[i]}\n\n"
				
					mkdir -p ./proteomes2/${organism[i]}
					
					if [ ! -e ./proteomes2/${organism[i]}/uniprot_${organism[i]}.txt ]
						then
							wget -P ./proteomes2/${organism[i]} ${unip[i]} -O ./proteomes2/${organism[i]}/uniprot_${organism[i]}.txt
						else
							echo "Uniprot download skipped. File already exists."
					fi
					
					if [ ! -e ./proteomes2/${organism[i]}/${inpara[i]} ]
						then
							wget -P ./proteomes2/${organism[i]} "http://inparanoid.sbc.su.se/download/7.0_current/sequences/processed/${inpara[i]}"
						else
							echo "Inparanoid download skipped. File already exists."
					fi 
					
								
				    if [[ ${ipi[i]} = "NA" ]]
						then
							echo "There is no proteome for organism $SCIENTIFIC_NAME in the IPI database"
						 			
						else if [ ! -e ./proteomes2/${organism[i]}/${ipi[i]}.fasta ]
							then
								wget -P ./proteomes2/${organism[i]} ftp://ftp.ebi.ac.uk/pub/databases/IPI/last_release/current/${ipi[i]}.fasta.gz 
								gunzip ./proteomes2/${organism[i]}/${ipi[i]}.fasta.gz
							else
								echo "IPI fasta download skipped. File already exists."
						fi
					fi
					
					
					if [[ ${ipi[i]} = "NA" ]]
						then
							echo "There is no history file for organism $SCIENTIFIC_NAME in the IPI database"	
							
						else if [ ! -e ./proteomes2/${organism[i]}/${ipi[i]}.history ]
							then
								wget -P ./proteomes2/${organism[i]} ftp://ftp.ebi.ac.uk/pub/databases/IPI/last_release/current/${ipi[i]}.history.gz
								gunzip ./proteomes2/${organism[i]}/${ipi[i]}.history.gz
							else
								echo "IPI history download skipped. File already exists."
						fi 	
					fi	
							
					
					if [ ! -e ./proteomes2/${organism[i]}/ensembl_${organism[i]} ]
						then
							wget -P ./proteomes2/${organism[i]} ${ens[i]} -O ./proteomes2/${organism[i]}/ensembl_${organism[i]}.gz
							gunzip ./proteomes2/${organism[i]}/ensembl_${organism[i]}.gz
						else
							echo "Ensembl download skipped. File already exists."
					fi
					
					UNIPROT="./proteomes2/${organism[i]}/uniprot_${organism[i]}.txt" 
					INPARANNOID="./proteomes2/${organism[i]}/${inpara[i]}"
					IPI_FASTA="./proteomes2/${organism[i]}/${ipi[i]}.fasta"
					IPI_HISTORY="./proteomes2/${organism[i]}/${ipi[i]}.history"
					ENSEMBL_FASTA="./proteomes2/${organism[i]}/ensembl_${organism[i]}"
					
									
				mkdir -p ./EnsgData
				
				#perl ./biomart-perl/bin/configure.pl -r conf/apiExampleRegistry.xml
				
				SUB=`expr match "${SCIENTIFIC_NAME}" '.*\_\([a-z]*\)'`	#matches all characters after '_' in the scientific name field of csv file
				ENSEMBL_NAME=${SCIENTIFIC_NAME:0:1}${SUB}	#concatenates the first character of scientific name field with the above
				
				if grep -q ${ENSEMBL_NAME} "./biomart-perl/biomart_datasets.txt"
				then
					ENSNAME=${ENSEMBL_NAME}_gene_ensembl
				else	
					ENSNAME=${ENSEMBL_NAME}_eg_gene		
				fi
				
				perl registryGenerator.pl "${biomart[i]}" ${ENSNAME} ${REGISTRIES}	#Creates the registry file dynamically
				
				
				
				# BUILDING DATABASE SCHEMA ##################################################################################
				echo -ne "Connecting to the database...\n"
				# Building the tables
				# The database and the user need to be created before this step
				mysql -u ${DBUSER} -h ${DBHOST} -p ${DATABASE} -p${DBPASS}< ${DATABASE_SCHEMA}


				# FORMATING AND INSERTING ##################################################################################
			

				echo -ne "Preformatting databases... "
				if [ ! -e ${IPI_HISTORY/.history/_parsed.history} ] && [[ ${ipi[i]} != "NA" ]]
					then
						perl ./src/databaseXreferences/preformat_IPIhistory.pl ${IPI_FASTA} ${IPI_HISTORY} > ${IPI_HISTORY/.history/_parsed.history}
						echo -ne "\n"
					else
						echo -ne "skipped\n"
				fi

				echo -ne "Inserting databases information...\n"
		
				perl ./src/databaseXreferences/insertDatabaseInfo.pl ${DBHOST} ${DATABASE} ${DBUSER} ${DBPASS} ${ENSEMBL_FASTA} ${TAXID} ${SCIENTIFIC_NAME} ${COMMON_NAME} ${ENSNAME} ${INPARANNOID} ${UNIPROT} ${IPI_FASTA} ${IPI_HISTORY/.history/_parsed.history}
		fi
		
		
		###########################################################################################################
	done

echo "Process completed successfully!"
