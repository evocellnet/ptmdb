#!/bin/bash
#ORGANISMS

# DATABASE
#schema
DATABASE_SCHEMA="src/databaseSchema/ptmdb_model.sql"
#connection
DBHOST="localhost"
DATABASE="ptmdb"
DBUSER="webAdmin"
DBPASS="webAdmin"

# Biomart datasets
MARTS="./src/databaseXreferences/biomart-perl"

# Biomart scripts
ENSG="./src/databaseXreferences/biomart_scripts/ensg.pl"
ENSG_ENSP="./src/databaseXreferences/biomart_scripts/ensg_ensp.pl"
INPARA_ENSP="./src/databaseXreferences/biomart_scripts/inparanoid_ensp.pl"
UNI_ENSP="./src/databaseXreferences/biomart_scripts/uniprot_ensp.pl"
LIB_PATH='./src/databaseXreferences/biomart-perl/lib'
CONF_FILE="./src/databaseXreferences/biomart-perl/conf/registry.xml"

#Proteomes FTPS
INPARAFTP="http://inparanoid.sbc.su.se/download/7.0_current/sequences/processed"
IPIFTP="ftp://ftp.ebi.ac.uk/pub/databases/IPI/last_release/current"

#Proteomes folder
PROTEOMES="./proteomes"





input="organism.csv"
