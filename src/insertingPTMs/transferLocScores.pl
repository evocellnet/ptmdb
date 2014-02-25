use warnings;
use strict;
use DBI;

#ptmdb
my $ptmdbhost = "mysql-beltrao-ptmdb";
my $ptmdbdb = "ptmdb";
my $ptmdbuser = "admin";
my $ptmdbpass = "NvmPv65M";
my $ptmdbport = 4434;


# Looking for all uniprot-ensembls conversion in ptmdb
my $ptmdb = DBI->connect('DBI:mysql:database='.$ptmdbdb.";host=".$ptmdbhost.";port=".$ptmdbport, $ptmdbuser, $ptmdbpass, {AutoCommit => 0}) || die "Could not connect to database: $DBI::errstr";

my $query = "SELECT residue,peptide_id,site.id,peptide,scored_peptide,ensp,position FROM site INNER JOIN peptide_site ON peptide_site.site_id = site.id INNER JOIN peptide ON peptide.id = peptide_site.peptide_id INNER JOIN ensp_site ON ensp_site.site_id = site.id WHERE peptide.scored_peptide IS NOT NULL AND site.localization_score IS NULL;";

my $ptmdbhandle = $ptmdb->prepare($query) or die "Cannot prepare: " . $ptmdb->errstr();
$ptmdbhandle->execute() or die "Cannot execute: " . $ptmdbhandle->errstr();
my $errflag=0;
my $residue;
my $peptide_id;
my $siteid;
my $peptide;
my $scored_peptide;
my $ensp;
my $position;
my %visitedPosition;
my %peptidePositions;
my %siteScore;
my @allsites;
$ptmdbhandle->bind_columns(\$residue, \$peptide_id, \$siteid, \$peptide, \$scored_peptide,\$ensp, \$position);
while ($ptmdbhandle->fetch()){
	if(! defined($visitedPosition{$ensp}{$peptide}{$position})){
		$visitedPosition{$ensp}{$peptide}{$position}=1;
		push(@{$peptidePositions{$ensp}{$peptide}}, $position);
	}
}

$ptmdbhandle->execute() or die "Cannot execute: " . $ptmdbhandle->errstr();
while ($ptmdbhandle->fetch()){
	my @positionsOnThisPeptide = sort { $a <=> $b } @{getPositions($peptide)};
	my @allpositionsInPeptide = sort { $a <=> $b } @{$peptidePositions{$ensp}{$peptide}};
	my @result = grep($position, @allpositionsInPeptide);
	my @indexes = grep { $allpositionsInPeptide[$_] == $position } (0..$#allpositionsInPeptide);
	# print $positionsOnThisPeptide[$indexes[0]]."\n";
	# print $siteid."\t".getScore($scored_peptide,$positionsOnThisPeptide[$indexes[0]])."\n";
	# print $siteid."\t".$scored_peptide."\t".$peptide."\t".$position."\t".join(",",@positionsOnThisPeptide)."\t".join(",",@allpositionsInPeptide)."\n";
	if(!defined($siteScore{$siteid})){
		$siteScore{$siteid}=getScore($scored_peptide,$positionsOnThisPeptide[$indexes[0]]);
		if(defined($siteScore{$siteid})){
			push(@allsites, $siteid);
		}
	}
}


my $updatequery = "UPDATE site SET localization_score=? WHERE id=?;";
my $statement = $ptmdb->prepare($updatequery) || die "Can't prepare a statement: $DBI::errstr";          # prepare the query
foreach my $site (@allsites){
	unless($statement->execute($siteScore{$site}, $site)){
		$errflag=1;
	}
}

if($errflag){
    my $error = DBI->errstr;
    $ptmdb->rollback();
    die "could not insert rows: $error\n";
}
else{
	$ptmdb->commit();
}
#$dbh->rollback();


$ptmdb->disconnect();

sub getPositions{
	my $peptide=$_[0];
	my @allchars = split("", $peptide);
	my $positionCounter=1;
	my @positions;
	for(my $i=0;$i<scalar(@allchars);$i++){
		if($allchars[$i]=~/\(/){
			push(@positions, $positionCounter-1);
		}
		
		if($allchars[$i]!~/[\(ph\)]/){
			$positionCounter++;
		}
	}
	return(\@positions);
}

sub getScore{
	my $peptide=$_[0];
	my $targetPosition=$_[1];
	my @allchars = split("", $peptide);
	my $result;
	my $positionCounter=1;
	my $parenthesisCounter=0;
	my @matches = ( $peptide =~/\(([\d\.]+)\)/g);
	for(my $i=0;$i<scalar(@allchars);$i++){
		if($allchars[$i]=~/\(/){
			if(($positionCounter-1) == $targetPosition){
				$result=$matches[$parenthesisCounter];
			}
			$parenthesisCounter++;
		}

		if($allchars[$i]!~/[\(\d\.\)]/){
			$positionCounter++;
		}
	}
	return($result);
}


