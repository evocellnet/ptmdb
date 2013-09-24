use warnings;
use strict;

my $charForIncompleteWindows="_";

my @inlines;
while(<STDIN>){
	push(@inlines, $_);
}

chomp($inlines[0]);
my @headers = split(/\t/, $inlines[0]);
my %header;
my $previousIndex;
my $success=0;
my $totalCounter=0;
my $partialCounter=0;
for(my $i=0;$i<scalar(@headers);$i++){
	$header{$headers[$i]}=$i;
}
for(my $i=1; $i<scalar@inlines; $i++){
	my $line = $inlines[$i];
	chomp($line);
	my @fields = split(/\t/,$line);
	my @windows = split(/\;/, $fields[$header{"residueWindow"}]);
	foreach my $window (@windows){
		my @winS = split("", $window);
		my $winLength=scalar(@winS);
		my $shift=0;
		if($window=~/$charForIncompleteWindows+/){
			if($-[0]==0){
				$shift=$+[0];
			}
		}
		$window=~s/$charForIncompleteWindows+//g;
				
		my $query=$window;
		my $foundedposition=$fields[$header{"position"}];
		my $matched="FALSE";
		if($fields[$header{"sequence"}]=~/$query/){
			$foundedposition=$-[0]+$winLength-$shift;
			$matched="TRUE";
			$success=1;
		}
		if($fields[$header{"match"}] eq "TRUE"){
			$matched = "TRUE";
			$success = 1;
		}
		if($matched eq "TRUE"){
			print $fields[0]."\t".$fields[$header{"index"}]."\t".$fields[$header{"residue"}]."\t".$foundedposition."\t".$fields[$header{"ensembl_id"}]."\n";
		}
		if(not defined($previousIndex)){
			$previousIndex=$fields[$header{"index"}];
		}
		if($fields[$header{"index"}] != $previousIndex){
			if($success){
				$partialCounter++;
			}
			$totalCounter++;
			$previousIndex=$fields[$header{"index"}];
			$success=0;
		}
	}
}
if($success){
	$partialCounter++;
}
$totalCounter++;

print STDERR "Number of reported ptms: ".$totalCounter."\n";
print STDERR "% of correctly mapped PTMs to at least one Ensembl isoform: ".sprintf("%.2f",(($partialCounter/$totalCounter)*100))."\%\n";