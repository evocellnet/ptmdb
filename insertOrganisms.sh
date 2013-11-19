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
	
done < "$ORGANISMSFILE"


# DOWNLOAD NECESSARY BIOMART DATA ##################################################################################

echo -ne "Downloading datasets from Biomart...\n "	
wget -P ${MARTS} "http://www.biomart.org/biomart/martservice?type=datasets&mart=ensembl" -O ${MARTS}/biomart_datasets.txt

echo -ne "Inserting modifications...\n "	
perl ./src/databaseXreferences/insertModifications.pl ${DBHOST} ${DATABASE} ${DBUSER} ${DBPASS} ${MODTYPESFILE}

for ((i=1; i<${#organism[@]}; i++))

	do

	TAXID="${tax[i]}"
	SCIENTIFIC_NAME="${scientific[i]}"
	COMMON_NAME="${organism[i]}"
	
	#CHECKING IF AN ORGANISM EXISTS IN THE DATABASE
	
	EXIST=`perl ./src/databaseXreferences/checkOrganism.pl ${DBHOST} ${DATABASE} ${DBUSER} ${DBPASS} ${TAXID}`
	
		if [[ $EXIST = "TRUE" ]]
			then
				echo -ne "Organism $SCIENTIFIC_NAME already exists in the database\n\n"
			else
			#REQUIRED EXTERNAL DATABASES
				
				echo -ne "\n\t* Inserting new Organism ${scientific[i]}\n\n"
				
					mkdir -p ${PROTEOMES}/${organism[i]}
					
					if [ ! -e ${PROTEOMES}/${organism[i]}/uniprot_${organism[i]}.txt ]
						then
							wget -P ${PROTEOMES}/${organism[i]} ${unip[i]} -O ${PROTEOMES}/${organism[i]}/uniprot_${organism[i]}.txt
						else
							echo "Uniprot download skipped. File already exists."
					fi
					
					if [ ! -e ${PROTEOMES}/${organism[i]}/${inpara[i]} ]
						then
							wget -P ${PROTEOMES}/${organism[i]} ${INPARAFTP}/${inpara[i]}
						else
							echo "Inparanoid download skipped. File already exists."
					fi 
					
								
				    if [[ ${ipi[i]} = "NA" ]]
						then
							echo "There is no proteome for organism $SCIENTIFIC_NAME in the IPI database"
						 			
						else if [ ! -e ${PROTEOMES}/${organism[i]}/${ipi[i]}.fasta ]
							then
								wget -P ${PROTEOMES}/${organism[i]} ${IPIFTP}/${ipi[i]}.fasta.gz 
								gunzip ${PROTEOMES}/${organism[i]}/${ipi[i]}.fasta.gz
							else
								echo "IPI fasta download skipped. File already exists."
						fi
					fi
					
					
					if [[ ${ipi[i]} = "NA" ]]
						then
							echo "There is no history file for organism $SCIENTIFIC_NAME in the IPI database"	
							
						else if [ ! -e ${PROTEOMES}/${organism[i]}/${ipi[i]}.history ]
							then
								wget -P ${PROTEOMES}/${organism[i]} ${IPIFTP}/${ipi[i]}.history.gz
								gunzip ${PROTEOMES}/${organism[i]}/${ipi[i]}.history.gz
							else
								echo "IPI history download skipped. File already exists."
						fi 	
					fi	
							
					
					if [ ! -e ${PROTEOMES}/${organism[i]}/ensembl_${organism[i]} ]
						then
							wget -P ${PROTEOMES}/${organism[i]} ${ens[i]} -O ${PROTEOMES}/${organism[i]}/ensembl_${organism[i]}.gz
							gunzip ${PROTEOMES}/${organism[i]}/ensembl_${organism[i]}.gz
						else
							echo "Ensembl download skipped. File already exists."
					fi
					
					UNIPROT="${PROTEOMES}/${organism[i]}/uniprot_${organism[i]}.txt" 
					INPARANNOID="${PROTEOMES}/${organism[i]}/${inpara[i]}"
					IPI_FASTA="${PROTEOMES}/${organism[i]}/${ipi[i]}.fasta"
					IPI_HISTORY="${PROTEOMES}/${organism[i]}/${ipi[i]}.history"
					ENSEMBL_FASTA="${PROTEOMES}/${organism[i]}/ensembl_${organism[i]}"
				
				SUB=$(echo ${SCIENTIFIC_NAME} | sed 's/[a-zA-Z]*_\([a-zA-Z]*\)/\1/')
				# SUB=`expr match "${SCIENTIFIC_NAME}" '.*\_\([a-z]*\)'`	#matches all characters after '_' in the scientific name field of csv file				
				ENSEMBL_NAME=${SCIENTIFIC_NAME:0:1}${SUB}	#concatenates the first character of scientific name field with the above
				if grep -q ${ENSEMBL_NAME} "${MARTS}/biomart_datasets.txt"
				then
					ENSNAME=${ENSEMBL_NAME}_gene_ensembl
				else	
					ENSNAME=${ENSEMBL_NAME}_eg_gene		
				fi
				
				mkdir -p ./src/databaseXreferences/xmlTemplates
				perl ./src/databaseXreferences/xmlQueryGenerator.pl ${ENSNAME} ${XML_PATH} ${TAXID}	#Creates the xml file dynamically
				
				

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
		
				perl ./src/databaseXreferences/insertDatabaseInfo.pl ${DBHOST} ${DATABASE} ${DBUSER} ${DBPASS} ${ENSEMBL_FASTA} ${TAXID} ${SCIENTIFIC_NAME} ${COMMON_NAME} ${ENSNAME} ${INPARANNOID} ${UNIPROT} ${IPI_FASTA} ${IPI_HISTORY/.history/_parsed.history} ${BIOMARTLWP} ${XML_PATH}
		fi
		
		
		###########################################################################################################
	done

echo "Process completed successfully!"
