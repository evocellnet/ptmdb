

. ./config.sh	#Load config file


# BUILDING DATABASE SCHEMA ##################################################################################
echo -ne "Connecting to the database...\n"
# Building the tables
# The database and the user need to be created before this step
mysql -u ${DBUSER} -h ${DBHOST} -p ${DATABASE} -p${DBPASS} -P${DBPORT}< ${DATABASE_SCHEMA}
