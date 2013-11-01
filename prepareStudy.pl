use warnings;
use strict;

my $configfile = $ARGV[0];
my $idformat = $ARGV[1];
my $taxid = $ARGV[2];
my $infile = $ARGV[3];
my $colnum = $ARGV[4];
my $fs = $ARGV[5];
my $headerBool = $ARGV[6];
my $idCol = $ARGV[7];
my $modificationTypeCol = $ARGV[8];
my $modificationTypeAll = $ARGV[9];
my $aaCol = $ARGV[10];
my $resnumCol = $ARGV[11];
my $locScoreCol = $ARGV[12];
my $peptideCol = $ARGV[13];
my $peptideScoredCol = $ARGV[14];
my $conditionalData = $ARGV[15];
my $spectralCount = $ARGV[16];

#In case it's a non-quantitative experiment
my $spectralCountsCol;

#In case it's a conditional experiment
my @conditionalHeaders;

if($conditionalData eq "true"){
	for (my $i=17;$i<scalar(@ARGV);$i++){
		my $thiscolname =$ARGV[$i];
		push(@conditionalHeaders, $thiscolname);
	}
}else{
	$spectralCountsCol = $ARGV[17];
}

#PREFORMATING 
my $preformatScript = "./src/insertingPTMs/preformatPTMs.pl";
my $preformatCommand = "perl ".$preformatScript;
for (my $i=3;$i<scalar(@ARGV);$i++){
	$preformatCommand.=" ";
	$preformatCommand.=("\'".$ARGV[$i]."\'");
}

#MAPPING IDs SCRIPT
my $mappingScript = "./src/insertingPTMs/mappingIDs.R";
my $mappingCommand = "Rscript ".$mappingScript." ".$configfile." ".$idformat." ".$taxid;

#PEPTIDE MATCH
my $peptideMatchScript = "./src/insertingPTMs/peptideMatcher.pl";
my $peptideCommand = "perl ".$peptideMatchScript;

system($preformatCommand." | ".$mappingCommand. " | ".$peptideCommand);