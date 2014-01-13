use warnings;
use strict;
use DBI;


#Database information
my $dbhost=$ARGV[0];
my $database=$ARGV[1];
my $dbuser=$ARGV[2];
my $dbpass=$ARGV[3];
my $dbport=$ARGV[4];
#Input Databases
my $TAXID = $ARGV[5];


my $dbh = DBI->connect('DBI:mysql:database='.$database.";host=".$dbhost.";port=".$dbport, $dbuser, $dbpass, {AutoCommit => 0}) || die "Could not connect to database: $DBI::errstr";
my $query = qq`SELECT taxid FROM organism WHERE taxid=?`;      # the query to execute
my $statement = $dbh->prepare($query) || die "Can't prepare a statement: $DBI::errstr";          # prepare the query
$statement->execute($TAXID);                        # execute the query

my $field;
$field = $statement->fetchrow_array();
$statement->finish();
$dbh->disconnect();

if($field)
{
	exit 0;
}
else
{
	exit 1;
}
