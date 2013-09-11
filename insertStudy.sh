. ./config.sh

set -e # Any subsequent commands which fail will cause the shell script to exit immediately

# ## INSERT A GIVEN UNIPROT DATASET ########################################################################

echo -ne "Preparing dataset for insertion...\n"
uniprotPtms="/Users/dochoa/Downloads/test.csv"
#Mapping and validating the ids
Rscript ./src/insertingPTMs/validateUniprot.R  ${uniprotPtms} ${TAXID} | perl ./src/insertingPTMs/windowParsing.pl > ${uniprotPtms/./_out.}

# #########################################################################################################
# 
# ## INSERT A GIVEN IPI DATASET ############################################################################

echo -ne "Preparing dataset for insertion...\n"
ipiPtms="/Users/dochoa/Downloads/testIPI.csv"
#Mapping and validating the ids | mapping the residues to the correct place
Rscript ./src/insertingPTMs/validateIPI.R  ${ipiPtms} ${TAXID} | perl ./src/insertingPTMs/windowParsing.pl > ${ipiPtms/./_out.}

############################################################################################################