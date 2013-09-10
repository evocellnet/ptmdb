#ORGANISMS
TAXID="9606"	#TODO: Do it feasible for more organisms

#REQUIRED EXTERNAL DATABASES
UNIPROT="/Users/dochoa/Databases/uniprot/uniprot-taxonomy%3A9606.txt" #It's only for human
INPARANNOID_HUMAN="/Users/dochoa/Databases/Inparanoid/7.0_current/sequences/processed/H.sapiens.fa"
IPI_FASTA="/Users/dochoa/Databases/IPI/last_release/current/ipi.HUMAN.fasta"
IPI_HISTORY="/Users/dochoa/Databases/IPI/last_release/current/ipi.HUMAN.history"
ENSEMBL_FASTA="/Users/dochoa/Databases/ensembl/pub/current_fasta/homo_sapiens/pep/Homo_sapiens.GRCh37.72.pep.all.fa"

# DATABASE
#schema
DATABASE_SCHEMA="src/databaseSchema/ptmdb_model.sql"
#connection
DBHOST="localhost"
DATABASE="ptmdb"
DBUSER="webAdmin"
DBPASS="webAdmin"
