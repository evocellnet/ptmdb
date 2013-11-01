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
MARTS="./src/databaseXreferences"
XML_PATH="./src/databaseXreferences/xmlTemplates"
BIOMARTLWP="./src/databaseXreferences"

#Proteomes FTPS
INPARAFTP="http://inparanoid.sbc.su.se/download/7.0_current/sequences/processed"
IPIFTP="ftp://ftp.ebi.ac.uk/pub/databases/IPI/last_release/current"

#Proteomes folder
PROTEOMES="./proteomes"


input="organism.csv"
