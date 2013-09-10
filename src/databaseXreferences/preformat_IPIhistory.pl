my $IPI_FASTA=$ARGV[0];
my $IPI_HISTORY=$ARGV[1];

my @currentIPIs=();
open(INFILE, $IPI_FASTA);
while(<INFILE>){
	my $line = $_;
	if($line=~/^>IPI\:(\w+)(\.\d+)?[\|\s](SWISS\-PROT\:([\w\-;]+))?[\|\s]?(TREMBL\:([\w\-;]+))?[\|\s]?(ENSEMBL\:([\w\-;]+))?[\|\s]?/){				
		push(@currentIPIs, $1);
	}
}
close(INFILE);

open(INFILE, $IPI_HISTORY);
my @ipiHistoryLines=<INFILE>;
close(INFILE);

my %previousIPIs;
foreach my $line (@ipiHistoryLines){
	if($line=~/Propagated/){
		my @fields=split(/\s+/, $line);
		my $old = $fields[0];
		my $new = $fields[3];
		push(@{$previousIPIs{$new}},$old);
	}
};

foreach my $currentIPI (@currentIPIs){
	my @descendants=();
	if(defined($previousIPIs{$currentIPI})){		
		@descendants = getDescendants($currentIPI,\%previousIPIs,\@descendants);
	}
	push(@descendants, $currentIPI);
	foreach my $descendant (@descendants){
		print $currentIPI."\t".$descendant."\n";
	}
}

sub getDescendants{
	my $curr=$_[0];
	my %previous = %{$_[1]};	
	my @result = @{$_[2]};

	foreach my $desc (@{$previous{$curr}}){
		my $thisdesc = $desc;
		push(@result, $desc);
		if(defined($previous{$desc})){
			@result = getDescendants($desc,\%previous,\@result);
		}
	}
	return(@result);
} 
