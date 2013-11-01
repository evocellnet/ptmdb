use warnings;
use strict;

my @inlines = <STDIN>;

my $colsRef = parseHeader($inlines[0]);
my %cols = %{$colsRef};

for (my $i=1;$i<scalar(@inlines);$i++){
	chomp($inlines[$i]);
	my @fields = split("\t", $inlines[$i]);
	my $position = matchPeptide($fields[$cols{"simplified_peptide"}], $fields[$cols{"sequence"}]);
	if(defined($position)){
		$fields[$cols{"position"}]=$position;
		print join("\t",@fields)."\n";
	}
}

sub parseHeader{
	my $headerLine = $_[0];
	print $headerLine;
	chomp($headerLine);
	my %cols;
	my @fields=split("\t", $headerLine);
	for (my $i=0;$i<scalar(@fields);$i++){
		$cols{$fields[$i]}=$i;
	}
	return(\%cols);
}

sub matchPeptide{
	my $simplified_peptide = $_[0];
	my $sequence = $_[1];
	
	my $positionInPeptide = getPTMpositionInPeptide($simplified_peptide);
	my $peptidePositionInProtein = getPeptidePositionInProtein($simplified_peptide, $sequence);
	my $ptmPosition;
	if(defined($peptidePositionInProtein)){
		$ptmPosition=$positionInPeptide+$peptidePositionInProtein;
	}
	return($ptmPosition);
}

sub getPTMpositionInPeptide{
	my $peptide=$_[0];
	
	$peptide=~s/_//g;
	
	if($peptide=~/(\()/){
		return($-[0]);
	}
}

sub getPeptidePositionInProtein{
	my $peptide=$_[0];
	my $sequence=$_[1];
	
	$peptide =~s/_//g;
	$peptide =~s/\(.+\)//g;
	my $position;
	if($sequence=~/$peptide/){
		$position=$-[0];
	}
	return($position);
}