use warnings;
use strict;

my $ptmdbDir = $ARGV[0];
my $configfile = $ARGV[1];
my $idformat = $ARGV[2];
my $taxid = $ARGV[3];
my $infile = $ARGV[4];
my $colnum = $ARGV[5];
my $fs = $ARGV[6];
my $headerBool = $ARGV[7];
my $idCol = $ARGV[8];
my $modificationTypeCol = $ARGV[9];
my $modificationTypeAll = $ARGV[10];
my $aaCol = $ARGV[11];
my $resnumCol = $ARGV[12];
my $locScoreCol = $ARGV[13];
my $peptideCol = $ARGV[14];
my $peptideScoredCol = $ARGV[15];
my $conditionalData = $ARGV[16];
my $spectralCountsCol = $ARGV[17];

#In case it's a conditional experiment
my @conditionalHeaders;

if($conditionalData eq "true"){
	for (my $i=18;$i<scalar(@ARGV);$i++){
		my $thiscolname =$ARGV[$i];
		push(@conditionalHeaders, $thiscolname);
	}
}

#PREFORMATING 
my $preformatScript = $ptmdbDir."/src/insertingPTMs/preformatPTMs.pl";
my $preformatCommand = "perl ".$preformatScript;
for (my $i=4;$i<scalar(@ARGV);$i++){
	$preformatCommand.=" ";
	$preformatCommand.=("\'".$ARGV[$i]."\'");
}

#MAPPING IDs SCRIPT
my $mappingScript = $ptmdbDir."/src/insertingPTMs/mappingIDs.R";
my $mappingCommand = "Rscript ".$mappingScript." ".$configfile." ".$idformat." ".$taxid;

#PEPTIDE MATCH
my $peptideMatchScript = $ptmdbDir."/src/insertingPTMs/peptideMatcher.pl";
my $peptideCommand = "perl ".$peptideMatchScript;

system($preformatCommand." | ".$mappingCommand. " | ".$peptideCommand);