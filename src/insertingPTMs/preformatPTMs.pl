use warnings;
use strict;

my $infile = $ARGV[0];
my $colnum = $ARGV[1];
my $fs = $ARGV[2];
my $headerBool = $ARGV[3];
my $idCol = $ARGV[4];
my $aaCol = $ARGV[5];
my $resnumCol = $ARGV[6];
my $locScoreCol = $ARGV[7];
my $peptideCol = $ARGV[8];
my $peptideScoredCol = $ARGV[9];
my $condRatioCol = $ARGV[10];
my $condSpectralCol = $ARGV[11];

my %colnames;
$colnames{$idCol} = "id";
$colnames{$aaCol} = "residue";
$colnames{$resnumCol} = "position";
$colnames{$locScoreCol} = "localization_score";
$colnames{$peptideCol} = "peptide";
$colnames{$peptideScoredCol} = "peptide_scored";
$colnames{$condSpectralCol} = "cond1_spectra";
$colnames{$condRatioCol} = "cond1_ratio";

open(INFILE, $infile);
my @inlines = <INFILE>;
close(INFILE);

#HEADER
my $startingRow;	#
my @finalheaders=();
my %column;		#contains the column index
if($headerBool eq "true"){
	chomp($inlines[0]);
	my @headerFields = split($fs, $inlines[0]);
	for(my $i=0;$i<scalar(@headerFields);$i++){
		push(@finalheaders, $colnames{$headerFields[$i]});
		$column{$colnames{$headerFields[$i]}}=$i;
	}
	$startingRow=1;
}else{
	my @fields = split($fs, $inlines[0]);
	for(my $i=0;$i<scalar(@fields); $i++){
		push(@finalheaders, $colnames{$i});
		$column{$colnames{$i}}=$i;
	}
	$startingRow=0;
}
print(join($fs, @finalheaders)."\n");

my $peptideFormat;

#Check for repeated peptides
my %checkrepeated;
my %repeated;
for (my $i=$startingRow;$i<scalar(@inlines);$i++){
	my $line=$inlines[$i];
	my @fields = split(",", $line);
	if(defined($fields[$column{"id"}]) && defined(defined($fields[$column{"position"}]))){
		if(not defined($checkrepeated{$fields[$column{"peptide"}]}{$fields[$column{"id"}]})){
			$checkrepeated{$fields[$column{"peptide"}]}{$fields[$column{"id"}]}=1;
		}else{
			$repeated{$fields[$column{"peptide"}]}{$fields[$column{"id"}]}=1;
		}
	}
}

#TABLE BODY
for (my $i=$startingRow;$i<scalar(@inlines);$i++){
	my $line=$inlines[$i];
	chomp($line);
	my @fields = split(",", $line);
	
	if(not defined($peptideFormat)){
		$peptideFormat = getPeptideFormat($fields[$column{"peptide"}]);
	}
	if(defined($peptideFormat)){
	
	}else{
		die "Peptide format not recognised\n";
	}
	
	#It checks if the id is defined
	if(defined($fields[$column{"id"}])){
		#It checks if the id is working
		if(defined($repeated{$fields[$column{"peptide"}]}{$fields[$column{"id"}]})){
			# print $repeated{$fields[$column{"peptide"}]}{$fields[$column{"id"}]}."\n";
			print $fields[$column{"id"}]."\t".$fields[$column{"position"}]."\t".$fields[$column{"localization_score"}]."\t".$fields[$column{"peptide"}]."\t".$fields[$column{"peptide_scored"}]."\n";
		}else{
			## If this peptide is not repeated is prints the peptide at it is 
			#print $fields[$column{"id"}]."\t".$fields[$column{"position"}]."\t".$fields[$column{"peptide"}]."\n";
		}
	}
}


sub getPeptideFormat{
	my $peptide=$_[0];
	my $format; 
	#Format containing the modifications within parenthesis
	if($peptide=~/\(\w+\)/){
		$format="parenthesis";
	}elsif($peptide=~/A-Z+/){
		$format="plain";
	}
	return($format)
}