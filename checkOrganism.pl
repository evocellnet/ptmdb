use warnings;
use strict;
use DBI;


#Database information
my $dbhost=$ARGV[0];
my $database=$ARGV[1];
my $dbuser=$ARGV[2];
my $dbpass=$ARGV[3];

#Input Databases
my $TAXID = $ARGV[4];


my $dbh = DBI->connect('DBI:mysql:'.$database.";".$dbhost, $dbuser, $dbpass, {AutoCommit => 0}) || die "Could not connect to database: $DBI::errstr";               # connect
my $query = qq`SELECT taxid FROM organism WHERE taxid=?`;      # the query to execute
my $statement = $dbh->prepare($query) || die "Can't prepare a statement: $DBI::errstr";          # prepare the query
$statement->execute($TAXID);                        # execute the query

my $field;
$field = $statement->fetchrow_array();


if($field)
{
	print 'TRUE';
}
else
{
	print 'FALSE';
}



$statement->finish();
$dbh->disconnect();
