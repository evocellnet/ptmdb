use warnings;
use strict;

my $ptmdbDir = $ARGV[0];
my $dbhost= $ARGV[1];
my $database=$ARGV[2];
my $dbuser=$ARGV[3];
my $dbpass=$ARGV[4];
my $dbport=$ARGV[5];
my $idformat = $ARGV[6];
my $taxid = $ARGV[7];
my $infile = $ARGV[8];
my $colnum = $ARGV[9];
my $fs = $ARGV[10];
my $headerBool = $ARGV[11];
my $idCol = $ARGV[12];
my $modificationTypeCol = $ARGV[13];
my $modificationTypeAll = $ARGV[14];
my $aaCol = $ARGV[15];
my $resnumCol = $ARGV[16];
my $locScoreCol = $ARGV[17];
my $peptideCol = $ARGV[18];
my $peptideFormat = $ARGV[19];
my $peptideScoredCol = $ARGV[20];
my $conditionalData = $ARGV[21];
my $spectralCountsCol = $ARGV[22];

#In case it's a conditional experiment
my @conditionalHeaders;

if($conditionalData eq "true"){
	for (my $i=23;$i<scalar(@ARGV);$i++){
		my $thiscolname =$ARGV[$i];
		push(@conditionalHeaders, $thiscolname);
	}
}




#PREFORMATING 
my $preformatScript = $ptmdbDir."/src/insertingPTMs/preformatPTMs.pl";
my $preformatCommand = "/usr/local/bin/perl ".$preformatScript;
for (my $i=8;$i<scalar(@ARGV);$i++){
	$preformatCommand.=" ";
	$preformatCommand.=("\'".$ARGV[$i]."\'");
}

#MAPPING IDs SCRIPT
my $mappingScript = $ptmdbDir."/src/insertingPTMs/mappingIDs.R";
my $mappingCommand = "/usr/local/bin/Rscript ".$mappingScript." ".$dbhost." ".$database." ".$dbuser." ".$dbpass." ".$dbport." ".$idformat." ".$taxid;


#PEPTIDE MATCH
my $peptideMatchScript = $ptmdbDir."/src/insertingPTMs/peptideMatcher.pl";
my $peptideCommand = "/usr/local/bin/perl ".$peptideMatchScript;

system($preformatCommand." | ".$mappingCommand. " | ".$peptideCommand);
