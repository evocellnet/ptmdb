use warnings;
use strict;

my $outfs="\t";

#### SETUP #####################

my $infile = $ARGV[0];
my $colnum = $ARGV[1];
my $fs = $ARGV[2];
my $headerBool = $ARGV[3];
my $idCol = $ARGV[4];
my $modificationTypeCol = $ARGV[5];
my $modificationTypeAll = $ARGV[6];
my $aaCol = $ARGV[7];
my $resnumCol = $ARGV[8];
my $locScoreCol = $ARGV[9];
my $peptideCol = $ARGV[10];
my $peptideScoredCol = $ARGV[11];
my $conditionalData = $ARGV[12];
my $spectralCountsCol = $ARGV[13];
#ARGS[14...] are described after

#In case it's a conditional experiment
my @conditionalHeaders;

#The columns that will be printed on the default case (Some modifications will be applied if they are not present)
my @defaultColumns = ("id", "residue", "modification_type", "position", "localization_score", "peptide", "peptide_scored", "simplified_peptide", "spectral_count");

#colnames that will be used in the output
my %colnames;
$colnames{$idCol} = "id";
$colnames{$aaCol} = "residue";
$colnames{$modificationTypeCol} = "modification_type";
$colnames{$resnumCol} = "position";
$colnames{$locScoreCol} = "localization_score";
$colnames{$peptideCol} = "peptide";
$colnames{$peptideScoredCol} = "peptide_scored";
$colnames{$spectralCountsCol}="spectral_count";

if($conditionalData eq "true"){
	for (my $i=14;$i<scalar(@ARGV);$i++){
		my $thiscolname =$ARGV[$i];
		push(@conditionalHeaders, $thiscolname);
		push(@defaultColumns, $thiscolname);
		$colnames{$thiscolname}=$thiscolname;
	}
}

#Field separators
if($fs eq "tab"){
	$fs = "\t";
}

#Modification type
my $modificationType;
if($modificationTypeCol eq "NA"){
	$modificationType=$modificationTypeAll;
}


#### STARTING THE PARSING ############

#Opening input file
open(INFILE, $infile);
my @inlines = <INFILE>;
close(INFILE);


#Parses the header
my ($columnref, $startingRow, $availableDefaultsRef) = headerParsing(\@inlines, \%colnames, \@defaultColumns, $fs);
my %column = %{$columnref};
my %availableDefaults = %{$availableDefaultsRef};

#Gets the format used for the peptide
my @firstEntryFields = split($fs,$inlines[$startingRow]);
my $peptideFormat = getPeptideFormat($firstEntryFields[$column{"peptide"}]);
my ($inlinesref, $ptmString) = standarizePeptides(\@inlines, \%column, $fs, $startingRow,$peptideFormat);
@inlines = @{$inlinesref};


#It looks for the peptides that are repeated (it uses scored peptides in case they are available)
my %repeated;
my %repeatedPositions;
my %excluded;
if($peptideScoredCol ne "NA"){
	my($repeated_ref,$repeatedPositions_ref, $excluded_ref) = getRepeatedPeptideScore(\@inlines,$startingRow,$fs,\%column,$ptmString);
	%repeated = %{$repeated_ref};
	%repeatedPositions = %{$repeatedPositions_ref};
	%excluded = %{$excluded_ref};
}else{
	my($repeated_ref,$repeatedPositions_ref, $excluded_ref) = getRepeatedPeptide(\@inlines,$startingRow,$fs,\%column,$ptmString);
	%repeated = %{$repeated_ref};
	%repeatedPositions = %{$repeatedPositions_ref};
	%excluded = %{$excluded_ref};
}

#TABLE BODY
my %printedEntries;	#If they have already been printed using multiplyEntry ID - PEPTIDE/SCOREDPEPTIDE
for (my $i=$startingRow;$i<scalar(@inlines);$i++){
	my $line=$inlines[$i];
	chomp($line);
	my @fields = split($fs, $line);
	
	#It checks if the id is defined
	if(defined($fields[$column{"id"}]) && ($fields[$column{"position"}] ne '')){			
		#check if the position is excluded because an ambiguity problem
		if(!defined($excluded{$fields[$column{"id"}]}{$fields[$column{"position"}]})){
			#It checks if we have columns for the scored peptides
			if($peptideScoredCol ne "NA"){
				#if there is an entry for each site on the peptide and they match their relative positions
				if(checkEntrySitePositionAgreement($fields[$column{"peptide"}], \@{$repeatedPositions{$fields[$column{"id"}]}{$fields[$column{"peptide_scored"}]}}, \%{$excluded{$fields[$column{"id"}]}}, $ptmString)){
					printLine(\@fields, \%column, \@defaultColumns, \%availableDefaults, \%repeatedPositions, $ptmString);
				}else{
					%printedEntries = %{multiplyEntry(\@fields, \%column, \%printedEntries, $ptmString, \%availableDefaults)};
				}			
			}else{
				#if there is an entry for each site on the peptide and they match their relative positions
				if(checkEntrySitePositionAgreement($fields[$column{"peptide"}], \@{$repeatedPositions{$fields[$column{"id"}]}{$fields[$column{"peptide"}]}}, \%{$excluded{$fields[$column{"id"}]}}, $ptmString)){
					printLine(\@fields, \%column, \@defaultColumns, \%availableDefaults, \%repeatedPositions, $ptmString);
				}else{	#if not they are saved for later processing
					%printedEntries = %{multiplyEntry(\@fields, \%column, \%printedEntries, $ptmString, \%availableDefaults)};
				}							
			}
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
	my @defaultColumns = @{$_[2]};
	my %availableDefaults = %{$_[3]};
	my %repeatedPositions = %{$_[4]};
	my $ptmString=$_[5];
	
	my $refcolumn="peptide_scored";
	if(! defined($column{"peptide_scored"})){
		$refcolumn="peptide";
	}
	my $aa = "NA";
	if(defined($availableDefaults{"residue"})){
		$aa = $fields[$column{"residue"}];
	}
	
	
	my ($simplified, $validatedAa) = simplifiedPeptideFromPosition($fields[$column{"peptide"}],\@{$repeatedPositions{$fields[$column{"id"}]}{$fields[$column{$refcolumn}]}},$fields[$column{"position"}], \%{$excluded{$fields[$column{"id"}]}}, $ptmString, $aa);
	
	#Skips in case the modified aminoacid is not the same as the one detected in the peptide  
	if($validatedAa eq "NA"){
		return(); 
	}
	
	my @toprint;
	foreach my $defaultCol (@defaultColumns){
		if(defined($availableDefaults{$defaultCol})){
			if(defined($fields[$column{$defaultCol}])){
				push(@toprint,$fields[$column{$defaultCol}]);
			}else{
				push(@toprint,"NA");
			}
		}else{
			if($defaultCol eq "modification_type"){
				push(@toprint, $modificationType);
			}elsif($defaultCol eq "residue"){
				push(@toprint, $validatedAa)
			}elsif($defaultCol eq "simplified_peptide"){
				push(@toprint, $simplified)
			}else{
				push(@toprint,"NA");
			}
		}
	}
	print(join($outfs, @toprint)."\n");
	
}

#Changes the original peptides to a more common format with the type of modification within parenthesis
sub standarizePeptides{
	my @lines=@{$_[0]};
	my %column=%{$_[1]};
	my $fs=$_[2];
	my $startingRow=$_[3];
	my $peptideFormat=$_[4];
	
	my @newlines=();
	my $ptmString;
	#We add the header as it is
	if($startingRow>0){
		for(my $i=0;$i<$startingRow;$i++){
			push(@newlines, $lines[$i]);
		}
	}
	#We modify the peptide column
	for(my $i=$startingRow;$i<scalar(@lines);$i++){
		my @fields=split($fs, $lines[$i]);
		$fields[$column{"peptide"}]=~s/_//g;
		if($peptideFormat eq "phospho_parenthesis"){
			#next
			$ptmString="(ph)";
		}
		elsif($peptideFormat eq "arginineAmp"){
			$ptmString="(ar)";
			$fields[$column{"peptide"}]=~s/#/\(ar\)/g;
			$fields[$column{"peptide"}]="_".$fields[$column{"peptide"}]."_";
		}
		push(@newlines, join($fs,@fields));
	}
	return(\@newlines, $ptmString);
}

#Return the format of the peptide according to a list of predefined peptides
sub getPeptideFormat{
	my $peptide=$_[0];
	my $format; 
	#Format containing the modifications within parenthesis
	if($peptide=~/\(ph\)/){
		$format="phospho_parenthesis";
	}if($peptide=~/R#/){
		$format="arginineAmp";
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
	my %colnames = %{$_[1]};
	my @defaultColumns = @{$_[2]};
	my $fs=$_[3];
	
	my $startingRow;	#The line containing the first entry of the data
	my %column;		#contains the column index
	my %availableHeaders; #headers in the default that are present in the file
	
	if($headerBool eq "true"){
		chomp($inlines[0]);
		my @headerFields = split($fs, $inlines[0]);
		for(my $i=0;$i<scalar(@headerFields);$i++){
			my $thisheader = $headerFields[$i];
			if($headerFields[$i] ne "NA"){
				#Checks if the column is in the default set of headers
				my $flag;
				foreach (my $x=0;$x<scalar(@defaultColumns);$x++){
					if($colnames{$headerFields[$i]} eq $defaultColumns[$x]){
						$flag=$x;
					}
				}
				if(defined($flag)){
					$availableHeaders{$defaultColumns[$flag]}=1;
				}
				#Saves the position of the interesting column
				$column{$colnames{$headerFields[$i]}}=$i;
			}
		}
		$startingRow=1;
	}else{
		my @fields = split($fs, $inlines[0]);
		for(my $i=0;$i<scalar(@fields); $i++){
			my $flag;
			foreach (my $x=0;$x<scalar(@defaultColumns);$x++){
				if($colnames{$i} eq $defaultColumns[$x]){
					$flag=$x;
				}
			}
			if(defined($flag)){
				$availableHeaders{$defaultColumns[$flag]}=1;
			}
			#Saves the position of the interesting column
			$column{$colnames{$i}}=$i;			
		}
		$startingRow=0;
	}
	#Prints the new header
	foreach my $col (@defaultColumns){
		$col=~s/\s/_/g;
	}
	print(join($outfs, @defaultColumns)."\n");
	
	return(\%column, $startingRow, \%availableHeaders);
}

#GETS THE REPEATED ENTRIES BASED ON 1 COLUMN
sub getRepeated{
	my @inlines = @{$_[0]};
	my $startingRow=$_[1];
	my $fs=$_[2];
	my %column = %{$_[3]};
	my $refColName = $_[4];
	my $ptmString = $_[5];
	
	#Check for repeated peptides
	my %checkrepeated;
	my %repeatedPositions;
	my %repeated;
	#loops the file: LOOKING FOR REPEATED ENTRIES AND THEIR POSITIONS
	for (my $i=$startingRow;$i<scalar(@inlines);$i++){
		my $line=$inlines[$i];
		my @fields = split($fs, $line);
		#if the id is defined
		if(defined($fields[$column{"id"}])){
			#if it's not already repeated
			if(not defined($repeated{$fields[$column{"id"}]}{$fields[$column{$refColName}]})){				
				$repeated{$fields[$column{"id"}]}{$fields[$column{$refColName}]}=1;
			}else{
				$repeated{$fields[$column{"id"}]}{$fields[$column{$refColName}]}++;
			}
			#push the positions that are repeated
			if(defined($fields[$column{"position"}])){
				push(@{$repeatedPositions{$fields[$column{"id"}]}{$fields[$column{$refColName}]}},$fields[$column{"position"}]);
			}
		}
	}
	
	#loops the file: LOOKING FOR AMBIGOUS POSITIONS TO BE EXCLUDED
	my %excluded;
	for (my $i=$startingRow;$i<scalar(@inlines);$i++){
		my $line=$inlines[$i];
		my @fields = split($fs, $line);
		#if the id is defined		
		if(defined($fields[$column{"id"}]) && ($fields[$column{"position"}] ne '')){			
			my @repeated = sort {$a <=> $b} @{$repeatedPositions{$fields[$column{"id"}]}{$fields[$column{$refColName}]}};
			my @relativeInEntries = @{relativePositionsInEntries(\@repeated, \%excluded)};
			my @relativeInPeptide = @{relativePositionsInPeptide($fields[$column{"peptide"}], $ptmString)};
			my %inPeptide;
			foreach my $p (@relativeInPeptide){
				$inPeptide{$p}=1;
			}
			for(my $i=0;$i<scalar(@relativeInEntries);$i++){
				if(not defined($inPeptide{$relativeInEntries[$i]})){
					my $ambigousPos = $repeated[$i];
					$excluded{$fields[$column{"id"}]}{$ambigousPos}=1;
				}
			}
		}
	}
	
	return(\%repeated,\%repeatedPositions,\%excluded);
}

# GETS IN A HASH THE ENTRIES THAT HAVE REPEATED PEPTIDES
sub getRepeatedPeptide{
	my @inlines = @{$_[0]};
	my $startingRow=$_[1];
	my $fs=$_[2];
	my %column = %{$_[3]};
	my $ptmString = $_[4];
	my $refColName = "peptide";
	
	my ($peptideRepeatedRef, $repeatedPositionsRef, $excludedRef) = getRepeated(\@inlines, $startingRow, $fs, \%column, $refColName, $ptmString);
	return($peptideRepeatedRef, $repeatedPositionsRef, $excludedRef); 
}

# GETS IN A HASH THE ENTRIES THAT HAVE REPEATED SCORED PEPTIDES
sub getRepeatedPeptideScore{
	my @inlines = @{$_[0]};
	my $startingRow=$_[1];
	my $fs=$_[2];
	my %column = %{$_[3]};
	my $ptmString = $_[4];
	my $refColName = "peptide_scored";
	
	my ($peptideRepeatedRef,$repeatedPositionsRef, $excludedRef) = getRepeated(\@inlines, $startingRow, $fs, \%column, $refColName, $ptmString);
	return($peptideRepeatedRef,$repeatedPositionsRef, $excludedRef);
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

# What's the rank of the modification among the different observed modifications
sub rankWithinPeptide{
	my @positions = sort {$a <=> $b} @{$_[0]};
	my $thispostion = $_[1];
	
	for(my $i=0;$i<scalar(@positions);$i++){
		if($thispostion == $positions[$i]){
			return(($i+1))
		}
	}
}

# Returns a peptide containing only the specified modification
sub simplifiedPeptideFromPosition{
	my $peptide = $_[0];		#the peptide
	my @positions = @{$_[1]};	#Positions with reported PTMs
	my $thispostion = $_[2];	#Position under investigation
	my %excludedForThisId = %{$_[3]};	#Positions excluded for being ambigous in this protein
	my $ptmString = $_[4];
	my $aa = $_[5];
	
	my @validpositions;
	foreach my $pos (@positions){
		if(not defined($excludedForThisId{$pos})){
			push(@validpositions, $pos);
		}
	}
	my $rank = rankWithinPeptide(\@validpositions,$thispostion);
	my $i=1;
	my %toexcludeForPositionCounting;

	while($peptide=~/(\(\w+?\))/g){
		if($1 eq $ptmString){
			if($i!=$rank){
				for(my $j=$-[0];$j<$+[0];$j++){
					$toexcludeForPositionCounting{$j}=1;
				}
			}
			$i++;
		}else{
			for(my $j=$-[0];$j<$+[0];$j++){
				$toexcludeForPositionCounting{$j}=1;
			}
		}
	}
	my @outchars;
	my @chars=split('',$peptide);
	for(my $x=0;$x<scalar@chars;$x++){
		if(not defined($toexcludeForPositionCounting{$x})){
			push(@outchars,$chars[$x]);
		}
	}
	my $simplified = join("",@outchars);
	
	#checks if the modified residue is the same of the one the table is reporting
	my @res = split('', $simplified);
	my $modifiedResidue;
	if($simplified=~/\(/){
		$modifiedResidue=$res[($-[0]-1)];
	}
	if($aa ne "NA"){
		if($aa ne $modifiedResidue){
			$modifiedResidue="NA";
		}
	}
	#returns the simplified peptide and the modified residue
	return($simplified, $modifiedResidue);
}


# Checks if the  modified residues' relative positions within the peptide are equivalent to the positions in the different entries
sub checkEntrySitePositionAgreement{
	my $peptide = $_[0];				#the peptide
	my @repeatedPositions = sort {$a <=> $b} @{$_[1]};	#the repeated entries positions
	my %excluded = %{$_[2]};
	my $ptmString = $_[3];
	
	my @relativePositionsInEntries = @{relativePositionsInEntries(\@repeatedPositions, \%excluded)};
	my @relativePositionsInPeptide = @{relativePositionsInPeptide($peptide, $ptmString)};
	my @exactPositionsInPeptide = @{exactPositionsInPeptide($peptide, $ptmString)};
	
	# print "\n".join(";",@relativePositionsInPeptide)."\t";
	# print join(";",@relativePositionsInEntries)."\n";
	# print join(";",@exactPositionsInPeptide)."\n";
	
	#Cross-check
	my $agreement=1;
	if(scalar(@relativePositionsInEntries) == scalar(@relativePositionsInPeptide)){
		for(my $x=0;$x<scalar(@relativePositionsInEntries);$x++){
			if($relativePositionsInPeptide[$x] != $relativePositionsInEntries[$x]){
				$agreement=0;
			}
		}
	}else{
		$agreement=0;
	}
	return($agreement);
}

#It gets the positions of the phosphosites within the peptide
sub exactPositionsInPeptide{
	my $peptide = $_[0];		#the peptide
	my $ptmString = $_[1];		#the string that contains the pattern to be matched 
	
	#For the positions in the peptide
	my @positionsInPeptide;
	my %toexclude;
	my %onsite;
	while($peptide=~/\(\w+\)/g){
		for(my $j=$-[0];$j<$+[0];$j++){
			$toexclude{$j}=1;
		}
	}
	while($peptide=~/$ptmString/g){
		for(my $j=$-[0];$j<$+[0];$j++){
			$onsite{$j}=1;
		}
	}
	my @res = split('', $peptide);
	my $flag=0;
	my $counter=0;
	for(my $i=0;$i<scalar(@res);$i++){
		if(defined($toexclude{$i})){
			if(defined($onsite{$i})){
				if($flag==0){
					push(@positionsInPeptide, ($counter-1));
					$flag=1;
				}
			}else{
				$flag=0;
			}
		}else{
			$flag=0;
			$counter++;
		}
	}
	return(\@positionsInPeptide);
}

# It returns the relative positions of the modified residues within a given peptide
sub relativePositionsInPeptide{
	my $peptide = $_[0];				#the peptide
	my $ptmString = $_[1];
	
	#It gets the position of the modifications within the peptides
	my @positionsInPeptide = @{exactPositionsInPeptide($_[0],$ptmString)};
		
	my @relativePositionsInPeptide=();
	for(my $y=0;$y<scalar(@positionsInPeptide);$y++){
		push(@relativePositionsInPeptide, (($positionsInPeptide[$y]-$positionsInPeptide[0] + 1)));
	}
	
	return(\@relativePositionsInPeptide);
}

# It returns the relative positions of the modifications (rows) in a list of repeated peptides
sub relativePositionsInEntries{
	my @repeatedPositions = @{$_[0]};
	my %excluded = %{$_[1]};
	
	#For the entries
	my @relativeRepeated=();
	for(my $z=0;$z<scalar(@repeatedPositions);$z++){
		if(! defined($excluded{$repeatedPositions[$z]})){
			push(@relativeRepeated, (($repeatedPositions[$z]-$repeatedPositions[0] + 1)));
		}
	}
	return(\@relativeRepeated);
}


#The ptms that encode for multiple modifications in the same peptide but not represented as mulitple entries are propagated
# (scores are positions are not accurately defined if the scored peptide is not provided)
sub multiplyEntry{
	my @fields = @{$_[0]};
	my %column = %{$_[1]};
	my %visited = %{$_[2]};
	my $ptmString = $_[3];
	my %availableDefaults = %{$_[4]};
	
	my $refcolumn="peptide";	#Column that will be used as reference 
	if(defined($availableDefaults{"peptide_scored"})){
		$refcolumn="peptide_scored";
	}
	
	if(! defined($visited{$fields[$column{"id"}]}{$fields[$column{$refcolumn}]})){
		printMultipliedLines(\@fields, \%column, \@defaultColumns, \%availableDefaults,$ptmString);
		$visited{$fields[$column{"id"}]}{$fields[$column{$refcolumn}]}=1;
	}
		
	return(\%visited);
}

sub printMultipliedLines{
	my @fields=@{$_[0]};
	my %column=%{$_[1]};
	my @defaultColumns = @{$_[2]};
	my %availableDefaults = %{$_[3]};
	my $ptmString=$_[4];
	
	my $peptide = $fields[$column{"peptide"}];
	my $scored_peptide;
	my @modPositions = @{exactPositionsInPeptide($peptide,$ptmString)};
	my ($simplifiedPepsRef, $modifiedResRef) = getSimplifiedPeptidesForIndexes($peptide,\@modPositions);
	my @simplifiedPeps=@{$simplifiedPepsRef};
	my @modifiedRes = @{$modifiedResRef};
	
	my @scores=();
	if(defined($availableDefaults{"peptide_scored"})){
		$scored_peptide=$fields[$column{"peptide_scored"}];
		@scores = @{getScoresForIndexes($scored_peptide, \@modPositions)};		#This is only posible if you have the scores
	}
	
	for(my $i=0;$i<scalar(@modPositions);$i++){
		my @toprint=();
		foreach my $defaultCol (@defaultColumns){
			if(defined($availableDefaults{$defaultCol})){
				if($defaultCol eq "localization_score"){
					if(scalar(@scores)>0){
						push(@toprint,$scores[$i]);
					}else{
						push(@toprint,"NA");
					}
				}elsif($defaultCol eq "position"){
					push(@toprint,"NA");
				}elsif($defaultCol eq "residue"){
					push(@toprint,$modifiedRes[$i]);
				}else{
					if(defined($fields[$column{$defaultCol}])){
						push(@toprint,$fields[$column{$defaultCol}]);
					}else{
						push(@toprint,"NA");
					}
				}
			}else{
				if($defaultCol eq "modification_type"){
					push(@toprint, $modificationType);
				}elsif($defaultCol eq "position"){
					push(@toprint,"NA");
				}elsif($defaultCol eq "residue"){
					push(@toprint,$modifiedRes[$i]);
				}elsif($defaultCol eq "simplified_peptide"){
					push(@toprint,$simplifiedPeps[$i]);
				}else{
					push(@toprint,"NA");
				}
			}
		}
		print(join($outfs, @toprint)."\n");
	}	
}


sub getSimplifiedPeptidesForIndexes{
	my $peptide=$_[0];
	my @positionsToGet=@{$_[1]};
	my @allSimplifiedPeptides;
	my @allModifiedResidues;
	
	my %toexclude;
	my %onsite;
	while($peptide=~/\(\w+?\)/g){
		for(my $j=$-[0];$j<$+[0];$j++){
			$toexclude{$j}=1;
		}
	}
	my @residues = split('',$peptide);
	
	foreach my $positionToGet (@positionsToGet){
		my $counter=0;
		my $scoreIndex=0;
		my @resulting=();
		my $flag=0;
		my $finished=0;
		
		
		for(my $i=0;$i<scalar(@residues);$i++){
			#If this is a position marked to get marked as flagged
			if($counter==($positionToGet+1)){
				if($flag == 0){
					push(@allModifiedResidues,$residues[$i-1]);
				}
				$flag=1;
			}
			# print $residues[$i]."\t".$counter."\t".$positionToGet."\t".$flag."\t".$finished."\n";
			
			if(not defined($toexclude{$i})){
				$counter++;
				push(@resulting, $residues[$i]);
			}else{
				if($flag && (!$finished)){
					push(@resulting, $residues[$i]);
				}
			}
			if($flag){
				if($residues[$i]=~/\)/){
					$finished=1;
				}
			}
		}
		push(@allSimplifiedPeptides, join("",@resulting));
	}	
	return(\@allSimplifiedPeptides, \@allModifiedResidues);
}

#It returns the scores of the sites in a peptide scored by asking their positions
sub getScoresForIndexes{
	my $scored_peptide=$_[0];
	my @positionsToGet=@{$_[1]};
	my @scores;
	my %toGet;
	foreach my $pos (@positionsToGet){
		$toGet{$pos}=1;
	}
	
	my %toexclude;
	my %onsite;
	my @allscores;
	while($scored_peptide=~/\((.+?)\)/g){
		push(@allscores,$1);
		my $index=($-[0] - 1);
		$onsite{$index}=1;
		for(my $j=$-[0];$j<$+[0];$j++){
			$toexclude{$j}=1;
		}
	}
	my @residues = split('',$scored_peptide);
	my $flag=0;
	my $counter=0;
	my $scoreIndex=0;
	for(my $i=0;$i<scalar(@residues);$i++){
		if(defined($onsite{$i})){
			if(defined($toGet{$counter})){
				push(@scores, $allscores[$scoreIndex]);
			}
			$scoreIndex++;
		}
		if(!defined($toexclude{$i})){
			$counter++;
		}		
	}
	# print join(",", @positionsToGet)."\t".$scored_peptide."\t".join(",", @scores)."\t".join(",", @allscores)."\n";
	
	return(\@scores);
}
