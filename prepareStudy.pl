use warnings;
use strict;

my $ptmdbDir = $ARGV[0];
my $configfile = $ARGV[1];
my $dbhost= $ARGV[2];
my $database=$ARGV[3]
my $dbuser=$ARGV[4]
my $dbpass=$ARGV[5]
my $dbport=$ARGV[6]
my $idformat = $ARGV[7];
my $taxid = $ARGV[8];
my $infile = $ARGV[9];
my $colnum = $ARGV[10];
my $fs = $ARGV[11];
my $headerBool = $ARGV[12];
my $idCol = $ARGV[13];
my $modificationTypeCol = $ARGV[14];
my $modificationTypeAll = $ARGV[15];
my $aaCol = $ARGV[16];
my $resnumCol = $ARGV[17];
my $locScoreCol = $ARGV[18];
my $peptideCol = $ARGV[19];
my $peptideFormat = $ARGV[20];
my $peptideScoredCol = $ARGV[21];
my $conditionalData = $ARGV[22];
my $spectralCountsCol = $ARGV[23];

#In case it's a conditional experiment
my @conditionalHeaders;

if($conditionalData eq "true"){
	for (my $i=24;$i<scalar(@ARGV);$i++){
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
my $mappingCommand = "Rscript ".$mappingScript." ".$dbhost." ".$database." ".$dbuser." ".$dbpass." ".$dbport." ".$idformat." ".$taxid;


#PEPTIDE MATCH
my $peptideMatchScript = $ptmdbDir."/src/insertingPTMs/peptideMatcher.pl";
my $peptideCommand = "perl ".$peptideMatchScript;

system($preformatCommand." | ".$mappingCommand. " | ".$peptideCommand);