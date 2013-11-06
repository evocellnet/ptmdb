use warnings;
use strict;
use DBI;

my @inlines =<STDIN>;

#Database information
my $dbhost=$ARGV[0];
my $database=$ARGV[1];
my $dbuser=$ARGV[2];
my $dbpass=$ARGV[3];

my $colsRef = parseHeader($inlines[0]);
my %cols = %{$colsRef};

# TODO CHANGE EXPERIMENT
my $experiment="1";

#Connecting to the database
my $dbh = DBI->connect('DBI:mysql:'.$database.";".$dbhost, $dbuser, $dbpass, {AutoCommit => 0}) || die "Could not connect to database: $DBI::errstr";
my $errflag=0;

my $quantitativeStudy;
if(!defined($cols{"spectral_count"})){
	$quantitativeStudy=1;
}else{
	$quantitativeStudy=0;
}

my $pepRefColumn;
my %peptideRegistry;
my %siteRegistry;

#INSERTION INSTRUCTIONS
my $ins_peptide;
my $ins_ensp_peptide=$dbh->prepare('INSERT INTO ensp_peptide(ensembl_id, peptide_id) VALUES (?,?)');
my $ins_site;
my $ins_peptide_site=$dbh->prepare('INSERT INTO peptide_site(peptide_id, site_id) VALUES (?,?)');
my $ins_ensp_site=$dbh->prepare('INSERT INTO ensp_site(ensp, site_id, position) VALUES (?,?,?)');

#reading the table content
for (my $i=1;$i<scalar(@inlines);$i++){
	chomp($inlines[$i]);
	my @fields=split("\t", $inlines[$i]);
	# Defines which is the column that will be used for identified not identical peptides
	if(! defined($pepRefColumn)){
		if($inlines[$i]){
			if($fields[$cols{"peptide_scored"}] ne "NA"){
				$pepRefColumn="peptide_scored";
			}else{
				$pepRefColumn="peptide";
			}
		}
	}
	
	#Inserting the peptide and ensp_peptide relationship
	if(! defined($peptideRegistry{$fields[$cols{"id"}]}{$fields[$cols{$pepRefColumn}]})){
		if($quantitativeStudy){
			$ins_peptide= $dbh->prepare('INSERT INTO peptide(experiment, peptide) VALUES (?,?)');
			unless($ins_peptide->execute($experiment,$fields[$cols{"peptide"}])){
				$errflag=1;
			}
		}else{
			$ins_peptide= $dbh->prepare('INSERT INTO peptide(experiment, peptide, spectral_count) VALUES (?,?,?)');
			unless($ins_peptide->execute($experiment,$fields[$cols{"peptide"}],$fields[$cols{"spectral_count"}])){
				$errflag=1;
			}
		}
		
		my $peptide_id = $ins_peptide->{mysql_insertid};
		
		#Inserting ensp_peptide relationship
		unless($ins_ensp_peptide->execute($fields[$cols{"ensembl_id"}],$peptide_id)){
			$errflag=1;
		}
		
		#Peptide register number
		$peptideRegistry{$fields[$cols{"id"}]}{$fields[$cols{$pepRefColumn}]}=$peptide_id;
	}
	
	#Inserting the site and peptide_site relationship
	if(!defined($siteRegistry{$fields[$cols{"index"}]})){
		if($fields[$cols{"localization_score"}] ne "NA"){
			$ins_site=$dbh->prepare('INSERT INTO site(experiment,localization_score,modif_type,residue) VALUES (?,?,?,?)');
			unless($ins_site->execute($experiment, $fields[$cols{"localization_score"}],$fields[$cols{"modification_type"}],$fields[$cols{"residue"}])){
				$errflag=1;
			}
			
		}else{
			$ins_site=$dbh->prepare('INSERT INTO site(experiment, modif_type,residue) VALUES (?,?,?)');
			unless($ins_site->execute($experiment, $fields[$cols{"localization_score"}],$fields[$cols{"modification_type"}],$fields[$cols{"residue"}])){
				$errflag=1;
			}
		}
		my $site_id=$ins_site->{mysql_insertid};
		#Inserting ensp_peptide relationship
		unless($ins_peptide_site->execute($peptideRegistry{$fields[$cols{"id"}]}{$fields[$cols{$pepRefColumn}]},$site_id)){
			$errflag=1;
		}
		$siteRegistry{$fields[$cols{"index"}]}=$site_id;
	}
	
	#Inserting the site-prortein relationship (position)
	unless($ins_ensp_site->execute($fields[$cols{"ensembl_id"}],$siteRegistry{$fields[$cols{"index"}]}, $fields[$cols{"position"}])){
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
# $dbh->rollback();

$dbh->commit();




# FUNCTIONS ########################

sub parseHeader{
	my $headerLine = $_[0];
	chomp($headerLine);
	my %cols;
	my @fields=split("\t", $headerLine);
	for (my $i=0;$i<scalar(@fields);$i++){
		$cols{$fields[$i]}=$i;
	}
	return(\%cols);
}

