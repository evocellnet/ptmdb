use warnings;
use strict;
use DBI;

#Database information
my $dbhost=$ARGV[0];
my $database=$ARGV[1];
my $dbuser=$ARGV[2];
my $dbpass=$ARGV[3];
my $MODIFICATIONS_FILE = $ARGV[4];

#Connecting to the database
my $dbh = DBI->connect('DBI:mysql:'.$database.";".$dbhost, $dbuser, $dbpass, {AutoCommit => 0}) || die "Could not connect to database: $DBI::errstr";
my $errflag=0;

### INSERTING MODIFICATION TYPES #################################################################################

open(MODFILE, $MODIFICATIONS_FILE);
my @modfilelines = <MODFILE>;
close(MODFILE);

foreach my $line (@modfilelines){
	chomp($line);
	my @fields = split("\t", $line);
	my $insModificationsStatement =  $dbh->prepare('INSERT INTO modification(id,description) VALUES (?,?)');
	unless($insModificationsStatement->execute($fields[0], $fields[1])){
		$errflag=1;
	}
}

### FINISHING #################################
if($errflag){
    my $error = DBI->errstr;
    $dbh->rollback();
	$dbh->disconnect();
    die "could not insert rows: $error\n";
}
#$dbh->rollback();

$dbh->commit();
