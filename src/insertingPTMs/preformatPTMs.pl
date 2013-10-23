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

#colnames that will be used in the output
my %colnames;
$colnames{$idCol} = "id";
$colnames{$aaCol} = "residue";
$colnames{$resnumCol} = "position";
$colnames{$locScoreCol} = "localization_score";
$colnames{$peptideCol} = "peptide";
$colnames{$peptideScoredCol} = "peptide_scored";
$colnames{$condSpectralCol} = "cond1_spectra";
$colnames{$condRatioCol} = "cond1_ratio";

#Opening input file
open(INFILE, $infile);
my @inlines = <INFILE>;
close(INFILE);

#Parses the header
my ($columnref, $startingRow) = headerParsing(\@inlines);
my %column = %{$columnref};

#Gets the format used for the peptide
my @firstEntryFields = split($fs,$inlines[$startingRow]);
my $peptideFormat = getPeptideFormat($firstEntryFields[$column{"peptide"}]);

#It looks for the peptides that are repeated (it uses scored peptides in case they are available)
my %repeated;
my %repeatedPositions;
if(defined($peptideScoredCol)){
	my($repeated_ref,$repeatedPositions_ref) = getRepeatedPeptideScore(\@inlines,$startingRow,$fs,\%column);
	%repeated = %{$repeated_ref};
	%repeatedPositions = %{$repeatedPositions_ref};
	
}else{
	my($repeated_ref,$repeatedPositions_ref) = getRepeatedPeptide(\@inlines,$startingRow,$fs,\%column);
	%repeated = %{$repeated_ref};
	%repeatedPositions = %{$repeatedPositions_ref};
}

#TABLE BODY
for (my $i=$startingRow;$i<scalar(@inlines);$i++){
	my $line=$inlines[$i];
	chomp($line);
	my @fields = split(",", $line);
	
	#It checks if the id is defined
	if(defined($fields[$column{"id"}]) && ($fields[$column{"position"}] ne '')){
		#It checks if we have columns for the scored peptides
		if(defined($peptideScoredCol)){
			#if there is an entry for each site on the peptide
			if(getNumberOfSites($fields[$column{"peptide"}], $peptideFormat) == $repeated{$fields[$column{"id"}]}{$fields[$column{"peptide_scored"}]}){
				printLine(\@fields, \%column);
			}else{
				# printLine(\@fields, \%column);
			}
			
			
			# #If the peptide appears more than once
			# if($repeated{$fields[$column{"id"}]}{$fields[$column{"peptide_scored"}]} > 1){
			# 	printLine(\@fields, \%column);
			# }else{
			# 	printLine(\@fields, \%column);
			# }
		}
	}
}





######################
### SUBROUTINES
######################

#PRINTS AN ENTRY LINE
sub printLine{
	my @fields=@{$_[0]};
	my %column=%{$_[1]};
	
	print $fields[$column{"id"}]."\t".$fields[$column{"position"}]."\t".$fields[$column{"localization_score"}]."\t".$fields[$column{"peptide"}]."\t".$fields[$column{"peptide_scored"}]."\t".$repeated{$fields[$column{"id"}]}{$fields[$column{"peptide_scored"}]}."\t".getNumberOfSites($fields[$column{"peptide"}], $peptideFormat)."\t".join(";", @{$repeatedPositions{$fields[$column{"id"}]}{$fields[$column{"peptide_scored"}]}})."\t".simplifiedPeptide($fields[$column{"peptide"}],\@{$repeatedPositions{$fields[$column{"id"}]}{$fields[$column{"peptide_scored"}]}},$fields[$column{"position"}])."\n";
	
}

sub getPeptideFormat{
	my $peptide=$_[0];
	my $format; 
	#Format containing the modifications within parenthesis
	if($peptide=~/\(ph\)/){
		$format="phospho_parenthesis";
	}elsif($peptide=~/A-Z+/){
		$format="plain";
	}
	return($format)
}

#PARSES THE HEADER
# It might parse present or absent headers but prints always a common header using
# a set of standard labels for the headers 
sub headerParsing{
	my @inlines = @{$_[0]};
	my $startingRow;	#The line containing the first entry of the data
	my @finalheaders=();	#headers that will be used on the output file
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
	#Prints the new header
	print(join($fs, @finalheaders)."\n");
	
	return(\%column, $startingRow);
}

#GETS THE REPEATED ENTRIES BASED ON 1 COLUMN
sub getRepeated{
	my @inlines = @{$_[0]};
	my $startingRow=$_[1];
	my $fs=$_[2];
	my %column = %{$_[3]};
	my $refColName = $_[4];
	#Check for repeated peptides
	my %checkrepeated;
	my %repeatedPositions;
	my %repeated;
	for (my $i=$startingRow;$i<scalar(@inlines);$i++){
		my $line=$inlines[$i];
		my @fields = split($fs, $line);
		if(defined($fields[$column{"id"}])){
			if(not defined($repeated{$fields[$column{"id"}]}{$fields[$column{$refColName}]})){
				$repeated{$fields[$column{"id"}]}{$fields[$column{$refColName}]}=1;
			}else{
				$repeated{$fields[$column{"id"}]}{$fields[$column{$refColName}]}++;
			}
			if(defined($fields[$column{"position"}])){
				push(@{$repeatedPositions{$fields[$column{"id"}]}{$fields[$column{$refColName}]}},$fields[$column{"position"}]);
			}
		}
	}
	return(\%repeated,\%repeatedPositions);
}

# GETS IN A HASH THE ENTRIES THAT HAVE REPEATED PEPTIDES
sub getRepeatedPeptide{
	my @inlines = @{$_[0]};
	my $startingRow=$_[1];
	my $fs=$_[2];
	my %column = %{$_[3]};
	my $refColName = "peptide";
	
	my ($peptideRepeatedRef, $repeatedPositionsRef) = getRepeated(\@inlines, $startingRow, $fs, \%column, $refColName);
	return($peptideRepeatedRef, $repeatedPositionsRef); 
}

# GETS IN A HASH THE ENTRIES THAT HAVE REPEATED SCORED PEPTIDES
sub getRepeatedPeptideScore{
	my @inlines = @{$_[0]};
	my $startingRow=$_[1];
	my $fs=$_[2];
	my %column = %{$_[3]};
	my $refColName = "peptide_scored";
	
	my ($peptideRepeatedRef,$repeatedPositionsRef) = getRepeated(\@inlines, $startingRow, $fs, \%column, $refColName);
	return($peptideRepeatedRef,$repeatedPositionsRef);
}

sub getNumberOfSites{
	my $peptide = $_[0];
	my $format = $_[1];
	my $pattern;
	if($format eq "phospho_parenthesis"){
		$pattern="\(ph\)";
	}
	my $c = () = $peptide=~/$pattern/g;
	return($c);
}

# How the residue is located within the peptide
sub rankWithinPeptide{
	my @positions = sort {$a <=> $b} @{$_[0]};
	my $thispostion = $_[1];
	
	for(my $i=0;$i<scalar(@positions);$i++){
		if($thispostion == $positions[$i]){
			return(($i+1))
		}
	}
}

#Returns a peptide containing only the specified modification
sub simplifiedPeptide{
	my $peptide = $_[0];
	my @positions = @{$_[1]};
	my $thispostion = $_[2];
	
	my $rank = rankWithinPeptide(\@positions,$thispostion);
	my $currPosition;
	my $i=1;
	my %toexclude;

	while($peptide=~/\(ph\)/g){
		if($i!=$rank){
			$currPosition=$-[0];
			for(my $j=$-[0];$j<$+[0];$j++){
				$toexclude{$j}=1;
			}
		}
		$i++;
	}
	my @outchars;
	my @chars=split('',$peptide);
	for(my $x=0;$x<scalar@chars;$x++){
		if(not defined($toexclude{$x})){
			push(@outchars,$chars[$x]);
		}
	}
	return(join("",@outchars));
}