use warnings;
use strict;
use DBI;

#Database information
my $dbhost=$ARGV[0];
my $database=$ARGV[1];
my $dbuser=$ARGV[2];
my $dbpass=$ARGV[3];
my $dbport=$ARGV[4];

#Input Databases
my $ENSEMBL_FASTA=$ARGV[5];
my $TAXID = $ARGV[6];
my $SCIENTIFIC_NAME = $ARGV[7];
my $COMMON_NAME = $ARGV[8];
my $ENSNAME = $ARGV[9];
my $INPARANNOID = $ARGV[10];
my $UNIPROT = $ARGV[11];
my $IPI_FASTA = $ARGV[12];
my $IPI_HISTORY_PARSED = $ARGV[13];
my $BIOMARTLWP = $ARGV[14];
my $XML_PATH = $ARGV[15];
my $BIOMART_HOST = $ARGV[16];

my $tolerance = 0.05;	# Tolerance in sequence length for two IDs to be considered the same (When evidences support it)
my $relaxtolerance = 0.5;	# Tolerance in sequence length for two IDs to be considered the same (Stronger evidences support it)

#Connecting to the database
my $dbh = DBI->connect('DBI:mysql:database='.$database.";host=".$dbhost.";port=".$dbport, $dbuser, $dbpass, {AutoCommit => 0}) || die "Could not connect to database: $DBI::errstr";
my $errflag=0;

#### ORGANISM #############################

print "\t* Inserting Organism Details...\n";
#preparing Ensembl-related inserts
my $ins_org = $dbh->prepare('INSERT INTO organism(taxid,common_name,scientific_name) VALUES (?,?,?)');
$ins_org->execute($TAXID,$COMMON_NAME,$SCIENTIFIC_NAME);

#### ENSEMBL ##############################
print "\t* Inserting Ensembl...\n";
#preparing Ensembl-related inserts
my $ins_ensp = $dbh->prepare('INSERT INTO ensp(id,sequence,length,taxid) VALUES (?,?,?,?)');

my $ensembl_id="";
my @ensseqlines=();
my %allensembls=();
my %ensp2length;
#my $i;
my $up;
#my @inparanoid;

open(INFILE, $ENSEMBL_FASTA)    or die $!;
while(<INFILE>){
	my $line = $_;
	#print $line;
	if($line=~/^>(\S+)\s/){
		if(scalar(@ensseqlines)){
			my $resultseq=join("",@ensseqlines);
			my $seqlength=scalar(split("",$resultseq));
			$ensp2length{$ensembl_id}=$seqlength;
				#print "$ensembl_id\n";
			unless($ins_ensp->execute($ensembl_id,$resultseq,$seqlength,$TAXID)){
				$errflag=1;
			}
			$allensembls{$ensembl_id}=1;
		}
		$ensembl_id="";
		@ensseqlines=();
		
		$ensembl_id=$1;
	}else{
		chomp($line);
		push(@ensseqlines, $line);
	}
}
if(scalar(@ensseqlines)){
	$allensembls{$ensembl_id}=1;
	my $resultseq=join("",@ensseqlines);
	my $seqlength=scalar(split("",$resultseq));
	$ensp2length{$ensembl_id}=$seqlength;
	#print $ensembl_id;
	unless($ins_ensp->execute($ensembl_id,$resultseq,$seqlength,$TAXID)){
		$errflag=1;
	}
}
close(INFILE);


#### ENSEMBL GENES ##############################
print "\t* Inserting Ensembl Genes...\n";
#preparing Ensembl-related inserts
my $ins_ensp_genes = $dbh->prepare('INSERT INTO ensg(id,name,description,taxid) VALUES (?,?,?,?)');


open(PS,"perl $BIOMARTLWP/biomartLWP.pl $XML_PATH/${COMMON_NAME}_ensg.xml ${BIOMART_HOST} |") || die "Failed: $!\n";
while ( <PS> )
{
	my $line = $_;
	if($line=~/^(\S+)\t(.*)\t(.*)$/){
		$ins_ensp_genes->execute($1,$2,$3,$TAXID);
	}
}	

#### ENSEMBL PROTEIN-GENES ##############################
my $ins_ensp_gen_pep = $dbh->prepare('INSERT INTO ensg_ensp(ensp_id,ensg_id) VALUES (?,?)');

open(PS,"perl $BIOMARTLWP/biomartLWP.pl $XML_PATH/${COMMON_NAME}_ensg_ensp.xml ${BIOMART_HOST} |") || die "Failed: $!\n";
while ( <PS> )
{
	my $line = $_;
	if($line=~/^(\S+)\t(\S+)/){
		if ($allensembls{$2}){
			$ins_ensp_gen_pep->execute($2,$1);
			#print "$1\n";
		}
	}	
}	

#### INPARANOID ############################
print "\t* Inserting Inparanoid...\n";
#preparing Inparanoid-related inserts
my $ins_inparanoid = $dbh->prepare('INSERT INTO inparanoid(id) VALUES (?)');

my $inpara_id="";
my %inInpara=();

open(INFILE, $INPARANNOID)    or die $!;
while(<INFILE>){
	my $line = $_;
	if($line =~/^>(\S+)\n/){
		if ($TAXID == 3702){
			$up = uc $1;
			$inpara_id = $up;
		#if ($allensembls{$up}){
			$ins_inparanoid->execute($inpara_id);
			#}
			$inInpara{$inpara_id}=1;
		}
		
			else{
			$inpara_id = $1;
			$ins_inparanoid->execute($inpara_id);
			$inInpara{$inpara_id}=1;
			}			
	}	
}

#### INPARANOID-ENSEMBL ############################
my $ins_inpara_ensembl = $dbh->prepare('INSERT INTO ensp_inparanoid(ensp,inparanoid_id) VALUES (?,?)');

if ($TAXID == 6239)
{
    open(PS,"perl $BIOMARTLWP/biomartLWP.pl $XML_PATH/${COMMON_NAME}_inparanoid_ensp.xml ${BIOMART_HOST} |") || die "Failed: $!\n";
    while(<PS>){
        my $line = $_;

        if($line=~/^(\S+)\t(\S+)/){
            if ($allensembls{$1}){
				if ($inInpara{$2}){
				$ins_inpara_ensembl->execute($1,$2);
            #print "$1\n";
				}
            }
        }
    }
}

####COMPLETING INPARANOID-ENSEMBL ############################
my $thisensp;
my $thisinpara;
my %thisinpensp;

   my $ensinparaQuery = "SELECT DISTINCT ensp.id, inparanoid.id FROM ensp INNER JOIN inparanoid ON ensp.id = inparanoid.id WHERE ensp.taxid='$TAXID'";   
   my $ensinparaHandle = $dbh->prepare($ensinparaQuery) or die "Cannot prepare: " . $dbh->errstr();
   $ensinparaHandle->execute() or die "Cannot execute: " . $ensinparaHandle->errstr();
   $ensinparaHandle->bind_columns(\$thisensp, \$thisinpara);
        
    while($ensinparaHandle->fetch()){
			#print "2";
		
		if(not defined($thisinpensp{$thisensp."-".$thisinpara})){
			unless($ins_inpara_ensembl->execute($thisensp,$thisinpara)){
				$errflag=1;
			}
			$thisinpensp{$thisensp."-".$thisinpara}=1;
		}
	}    
     
#### UNIPROT ##############################
print "\t* Inserting Uniprot...\n";

#Preparing insertions
my $ins_uniprot_entry = $dbh->prepare('INSERT INTO uniprot_entry(id,reviewed) VALUES (?,?)');
my $ins_uniport_isoform = $dbh->prepare('INSERT INTO uniprot_isoform(accession,sequence,length,taxid) VALUES (?,?,?,?)');
my $ins_uniport_acc = $dbh->prepare('INSERT INTO uniprot_acc(accession,id,reference_accession) VALUES (?,?,?)');
my $ins_uniport_ensembl = $dbh->prepare('INSERT INTO uniprot_ensembl(uniprot_accession,ensembl_id) VALUES (?,?)');

my %insertedIso=();
my %insertedAcc=();

my %thisENSPinserted=();


#about the sequences
open(INFILE, $UNIPROT)    or die $!;
while(<INFILE>){
	my $line = $_;
	my $thislength="";
	my $thisorg;
	my @acclines=();
	my $id="";
	my $reviewed="";
	my $isvarseq;
	my @varseqlines=();
	my $varstart="";
	my $varend="";
	my $varid="";
	my $seq="";
		
	my $alternative=0;
	my $isAlternative=0;
	
	my @thisEnsps=();
	
	my $isseq=0;
	my @seqlines=();
	my $isoInProgress=0;
	my @isonames=();
	my $lastIso="";
	my %acc2varseqs=();
	
	my %varseq2desc=();
	my %varseq2start=();
	my %varseq2end=();
	my $currentAlternate=0;
	# print $line;
	while($line !~/^\/\//){
		# print $line."\n";
		if($line=~/^ID\s+(\w+)\s+(.+);\s+(\d+)\sAA\.\n$/){
				$id = $1;
				if($2 eq "Reviewed"){
					$reviewed=1;
				}else{
					$reviewed=0;
				}
				$thislength=$3;
		}
		if($id ne ""){
			if($line=~/^AC\s+(.+);\n/){
				push(@acclines,$1);
			}elsif($line=~/^OX\s+NCBI_TaxID=(\d+);/){
				$thisorg=$1;
				if($thisorg != $TAXID){
					last;
				}
			}elsif($line=~/^CC\s+\-\!\-\s(.+)\:/){
				if($1=~/ALTERNATIVE\sPRODUCTS/){
					$alternative=1;
					$isAlternative=1;
				}else{
					$alternative=0;
				}
			}elsif($line=~/^CC\s+(.+)/){
				my $content = $1;
				if($alternative==1){
					my $variants;
					if($content=~/IsoId=([\w\s\,\-]+);(\sSequence\=([\w\s\,]+)\;?)?$/){
						
						my @multipleIsos = split(/\,\s?/,$1);
						
						push(@isonames, $multipleIsos[0]);
						$variants=$3;
						$lastIso=$multipleIsos[0];
						if(not defined($3)){
							$currentAlternate=1;
						}
						# print $1."\t".$2."\t".$3."\n";
					}
					if($content=~/Sequence\=(.+)/){
						if($currentAlternate){
							if($1=~/([\w\s\,]+)\;?/){
								$variants=$1;
								$currentAlternate=0;
							}
						}
						$isoInProgress=1;
						if($line=~/;$/){
							$isoInProgress=0;
						}
					}
					if($isoInProgress && $content=~/\s*([\w\s\,]+)\;?$/){
						$variants=$1;
						if($line=~/;$/){
							$isoInProgress=0;
						}
					}
					if(defined($variants)){
						my @vars = split(/,\s?/, $variants);
						foreach my $var (@vars){
							# print $id."\t".$var."\t".$lastIso."\n";													
							push(@{$acc2varseqs{$lastIso}}, $var);
						}
					}
				}
			}elsif($line=~/^DR\s+Ensembl\S*; (.+)/){
				my @ensemblEntries=split(/;\s/, $1);
				push(@thisEnsps, $ensemblEntries[1]);
			}elsif($line=~/^FT\s{3}(.+)/){
				my $content = $1;
				if($content=~/^VAR_SEQ\s+(\d+)\s+(\d+)\s+(.+)/){
					$isvarseq=1;
					$varstart=$1;
					$varend=$2;
					push(@varseqlines,$3);
					# print $id."\t".$content."\n";
				}elsif(($content=~/^\s+\/FTId=(\w+)/)&&($isvarseq)){
					$varid=$1;
					$varseq2desc{$varid}=join("", @varseqlines);
					$varseq2start{$varid}=$varstart;
					$varseq2end{$varid}=$varend;
					# print $id."\t".$varid."\t".$varstart."\t".$varend."\t".join("", @varseqlines)."\n";
					#empty
					@varseqlines=();
					$isvarseq=0;
					$varstart="";
					$varend="";
					$varid="";
				}elsif(($content=~/^\s+(.+)/)&&($isvarseq)){
					push(@varseqlines,$1);
				}
			}elsif($line=~/^SQ\s{3}(.+)/){
				$isseq=1;
			}elsif(($line=~/^\s{5}/)&&($isseq)){
				chomp($line);
				$line=~s/\s//g;
				push(@seqlines, $line);
			}
			else{
				$alternative=0;
				$isvarseq=0;
				$isseq=0;
			}
		}
		$line = <INFILE>;
	}
	if(defined($thisorg)){
		if($thisorg == $TAXID){
			#inserting into uniprot_entry
			unless($ins_uniprot_entry->execute($id,$reviewed)){
				$errflag=1;
			}
			
			my $allacclines = join("; ", @acclines);
			my @accs = split("; ", $allacclines);
						
			#inserting into uniprot_isoform
			$seq=join("",@seqlines);
			unless($ins_uniport_isoform->execute($accs[0],$seq,$thislength,$thisorg)){
				$errflag=1;
			}
			
			if($isAlternative){				
				foreach my $iso (@isonames){
					my $isoformSeq="";
					my $isoLength="";
					#Inserting uniprot_isoform
					if(!defined($insertedIso{$iso})){
						$isoformSeq=getAlternative($seq,\%varseq2desc,\%varseq2start,\%varseq2end,\@{$acc2varseqs{$iso}});
						$isoLength=scalar(split("",$isoformSeq));						
						unless($ins_uniport_isoform->execute($iso,$isoformSeq,$isoLength,$thisorg)){
							$errflag=1;
						}
						$insertedIso{$iso}=1;
					}
					#inserting into uniprot_acc
					foreach my $acc (@accs){
						#inserting isoforms of alternative splicing
						if($iso=~/\w+\-(\d+)/){
							my $currIsoAcc=$acc."-".$1;
							## FOR THE ISOFORMS ###
							#inserting the isoforms
							if(not defined($insertedAcc{$currIsoAcc})){
								unless($ins_uniport_acc->execute($currIsoAcc,$id,$iso)){
									$errflag=1;
								}
								$insertedAcc{$currIsoAcc}=1;
							}
							#inserting uniprot_ensembl for directly mapped and same length isoforms
							foreach my $ensp (@thisEnsps){
								if(defined($ensp2length{$ensp}) && ($isoLength ne "") && ($isoLength > 0)){
									my $seqLenRatio = $ensp2length{$ensp} / $isoLength;
									if(($seqLenRatio > (1-$tolerance)) && ($seqLenRatio < (1+$tolerance))){
										if(not defined($thisENSPinserted{$currIsoAcc."-".$ensp})){
											unless($ins_uniport_ensembl->execute($currIsoAcc,$ensp)){
												$errflag=1;
											}
										}
										$thisENSPinserted{$currIsoAcc."-".$ensp}=1;
									}
								}
							}
							## FOR THE MAIN ACCESSION ###
							#inserting the main accession
							if(not defined($insertedAcc{$acc."_".$iso})){
								unless($ins_uniport_acc->execute($acc,$id,$iso)){
									$errflag=1;
								}
								$insertedAcc{$acc."_".$iso}=1;
							}
							#inserting uniprot_ensembl
							foreach my $ensp (@thisEnsps){
								if(defined($ensp2length{$ensp})){
									my $seqLenRatio = $ensp2length{$ensp} / $thislength;
									if(($seqLenRatio > (1-$tolerance)) && ($seqLenRatio < (1+$tolerance))){
										if(not defined($thisENSPinserted{$acc."-".$ensp})){
											unless($ins_uniport_ensembl->execute($acc,$ensp)){
												$errflag=1;
											}
										}
										$thisENSPinserted{$acc."-".$ensp}=1;
									}
								}
							}
						}
					}
				}
			}else{
				foreach my $acc (@accs){
					if(!defined($insertedAcc{$acc})){					
						#inserting proteins with no alternative splicing
						unless($ins_uniport_acc->execute($acc,$id,$accs[0])){
							$errflag=1;
						}
						$insertedAcc{$acc}=1;
					}
					if(scalar(@thisEnsps)){
						foreach my $ensp (@thisEnsps){
							#inserting into uniprot_ensembl directly mapped ensembls with no isoforms
							if(not defined($thisENSPinserted{$acc."-".$ensp})){
								if($allensembls{$ensp}){
									unless($ins_uniport_ensembl->execute($acc,$ensp)){
										$errflag=1;
									}
									$thisENSPinserted{$acc."-".$ensp}=1;
								}
							}
						}
					}				
				}
			}			
		}
	}
}
close(INFILE);


#### IPI ##############################
#preparing IPI-related inserts
print "\t* Inserting IPI...\n";
my $ins_ipi = $dbh->prepare('INSERT INTO ipi(id,sequence,length,taxid) VALUES (?,?,?,?)');
my $ins_uniprot_ipi = $dbh->prepare('INSERT INTO uniprot_ipi(ipi_id,accession) VALUES (?,?)');
my $ins_ensembl_ipi = $dbh->prepare('INSERT INTO ensembl_ipi(ipi,ensembl_id) VALUES (?,?)');

my %acc2ipi;
my %ipi2ens;
my %ipi2inpara;

my @currentIPIs;

my %thisIPIENSPinserted;
my $ipi="";
my @seqlines=();
my $uniprot = "";
my $ensembl = "";


if (-e $IPI_FASTA)
{
	open(INFILE, $IPI_FASTA)    or die $!;

	while(<INFILE>){
		my $line = $_;
		my $generalpattern='^>IPI\:(\w+)(\.\d+)?[\|\s](SWISS\-PROT\:([\w\-;]+))?[\|\s]?(TREMBL\:([\w\-;]+))?[\|\s]?(ENSEMBL\:([\w\-;]+))?[\|\s]?';
		my $arabidopsispattern='^>IPI\:(\w+)(\.\d+)?[\|\s](SWISS\-PROT\:([\w\-;]+))?[\|\s]?(TREMBL\:([\w\-;]+))?[\|\s]?[REFSEQ\:[\w\;]+]?[\|\s]?(TAIR\:([\w\.\-;]+))?[\|\s]?';
		my $pattern="";
		
		if ($TAXID == 3702)
		{
			$pattern = $arabidopsispattern;
		}
		
		else
		{
			$pattern = $generalpattern;
		}
		
		if($line=~/$pattern/){				
			if(scalar(@seqlines)){
				my $resultseq=join("",@seqlines);
				unless($ins_ipi->execute($ipi,$resultseq,scalar(split("",$resultseq)),$TAXID)){
					$errflag=1;
				}
				if(defined($uniprot)){
					my @uniprots = split(";", $uniprot);
					foreach my $uni (@uniprots){
						if($insertedAcc{$uni}){
							unless($ins_uniprot_ipi -> execute($ipi, $uni)){
								$errflag=1;
							}
						}
					}
				}
				if(defined($ensembl)){
					my @ensembls = split(";", $ensembl);
					foreach my $ensembl (@ensembls){
						if($allensembls{$ensembl}){
							unless($ins_ensembl_ipi->execute($ipi,$ensembl)){
								$errflag=1;
							}
						}
						$thisIPIENSPinserted{$ipi."-".$ensembl}=1;
					}
				}
				#print $ipi."\t".$resultseq."\t".scalar(split("",$resultseq))."\t".$TAXID."\n";
			}
			#empty previous
			@seqlines=();
			$ipi="";
			$uniprot="";
			$ensembl="";
			
			#ipi
			$ipi=$1;
			push(@currentIPIs, $ipi);
			
			#ensembl
			$ensembl=$8;
			
			#uniprot
			my $swissprot = $4;
			my $trembl = $6;
			my $ensembl;
			if(defined($swissprot)&&defined($trembl)){
				$uniprot = $swissprot.";".$trembl;
			}elsif(defined($trembl)){
				$uniprot=$trembl;
			}elsif(defined($swissprot)){
				$uniprot=$swissprot;
			}
			
		}else{
			chomp($line);
			push(@seqlines, $line);
		}	
	}
	if(scalar(@seqlines)){
		my $resultseq=join("",@seqlines);
		unless($ins_ipi->execute($ipi,$resultseq,scalar(split("",$resultseq)),$TAXID)){
			$errflag=1;
		}
		
		if(defined($uniprot)){
			my @uniprots = split(";", $uniprot);
			foreach my $uni (@uniprots){
				if($insertedAcc{$uni}){
					unless($ins_uniprot_ipi -> execute($ipi, $uni)){
						$errflag=1;
					}
				}
			}
		}
		if(defined($ensembl)){
			my @ensembls = split(";", $ensembl);
			foreach my $ensembl (@ensembls){
				if($allensembls{$ensembl}){
					unless($ins_ensembl_ipi->execute($ipi,$ensembl)){
						$errflag=1;
					}
					$thisIPIENSPinserted{$ipi."-".$ensembl}=1;
				}	
			}
		}
		#print $ipi."\t".$resultseq."\t".scalar(split("",$resultseq))."\t".$TAXID."\n";
	}
	close(INFILE);


	#We keep track of the historic IPI ids
	my $ins_ipi_history = $dbh->prepare('INSERT INTO ipi_history(current_ipi,all_ipi) VALUES (?,?)');

	open(INFILE, $IPI_HISTORY_PARSED);
	my @ipiHistoryLines=<INFILE>;
	close(INFILE);

	foreach my $history_line (@ipiHistoryLines){
		chomp($history_line);
		my @fields=split(/\t/,$history_line);
		unless($ins_ipi_history->execute($fields[0], $fields[1])){
			$errflag=1;
		}
	}

	#### REFERENCES THAT CAN BE EXPLAINED USING OTHER DATABASES ##############################
	print "\t* Inserting Cross-references...\n";
	#Complete the uniprot_ensembl mapped through IPI
	my $thisensp;
	my $thisacc;
	my $thisipi;



	my $ens2uniprotQuery = "SELECT DISTINCT T.id, UACC.accession FROM (SELECT DISTINCT ensp.id, ensipi.ipi, uniacc.reference_accession, uniso.length FROM ensp INNER JOIN ensembl_ipi AS ensipi ON ensp.id = ensipi.ensembl_id INNER JOIN ipi ON ensipi.ipi = ipi.id INNER JOIN uniprot_ipi AS unipi ON ipi.id = unipi.ipi_id INNER JOIN uniprot_acc AS uniacc ON unipi.accession = uniacc.accession INNER JOIN uniprot_isoform AS uniso ON uniacc.reference_accession = uniso.accession WHERE ensp.taxid = \'$TAXID\' AND uniso.taxid = \'$TAXID\' AND ipi.taxid = \'$TAXID\') AS T INNER JOIN uniprot_acc AS UACC ON T.reference_accession = UACC.reference_accession";
	# my $ens2uniprotQuery = "SELECT DISTINCT T.id, UACC.accession FROM (SELECT DISTINCT ensp.id, ensipi.ipi, uniacc.reference_accession, uniso.length FROM ensp INNER JOIN ensembl_ipi AS ensipi ON ensp.id = ensipi.ensembl_id INNER JOIN ipi ON ensipi.ipi = ipi.id INNER JOIN uniprot_ipi AS unipi ON ipi.id = unipi.ipi_id INNER JOIN uniprot_acc AS uniacc ON unipi.accession = uniacc.accession INNER JOIN uniprot_isoform AS uniso ON uniacc.reference_accession = uniso.accession WHERE ensp.length / ipi.length BETWEEN (1-$relaxtolerance) AND (1+$relaxtolerance) AND ipi.length / uniso.length BETWEEN 1-$tolerance AND 1+$tolerance) AS T INNER JOIN uniprot_acc AS UACC ON T.reference_accession = UACC.reference_accession";
	my $ens2uniprotHandle = $dbh->prepare($ens2uniprotQuery) or die "Cannot prepare: " . $dbh->errstr();
	$ens2uniprotHandle->execute() or die "Cannot execute: " . $ens2uniprotHandle->errstr();
	$ens2uniprotHandle->bind_columns(\$thisensp, \$thisacc);

	while($ens2uniprotHandle->fetch()){
		#print "1";
		if(not defined($thisENSPinserted{$thisacc."-".$thisensp})){
			unless($ins_uniport_ensembl->execute($thisacc,$thisensp)){
				$errflag=1;
			}
			$thisENSPinserted{$thisacc."-".$thisensp}=1;
		}
	}

	#Complete the ipi_ensembl mapped through Uniprot
	my $ens2ipiQuery = "SELECT DISTINCT ipi.id,T.ensembl_id FROM ipi INNER JOIN uniprot_ipi AS unipi ON ipi.id = unipi.ipi_id INNER JOIN uniprot_acc AS uniacc ON unipi.accession = uniacc.accession INNER JOIN (SELECT accession,reference_accession,uniens.ensembl_id FROM uniprot_acc AS uniacc INNER JOIN uniprot_ensembl AS uniens ON uniacc.accession = uniens.uniprot_accession) AS T ON uniacc.reference_accession = T.reference_accession WHERE ipi.taxid = '$TAXID'";
	my $ens2ipiHandle = $dbh->prepare($ens2ipiQuery) or die "Cannot prepare: " . $dbh->errstr();
	$ens2ipiHandle->execute() or die "Cannot execute: " . $ens2ipiHandle->errstr();
	$ens2ipiHandle->bind_columns(\$thisipi, \$thisensp);

	while($ens2ipiHandle->fetch()){
			#print "2";
		
		if(not defined($thisIPIENSPinserted{$thisipi."-".$thisensp})){
			unless($ins_ensembl_ipi->execute($thisipi,$thisensp)){
				$errflag=1;
			}
			$thisIPIENSPinserted{$thisipi."-".$thisensp}=1;
		}
	}

}


#### COMPLETE UNIPROT_ENSEMBL WITH POTENTIAL MISSING MAPPINGS USING BIOMART ##############################

open(PS,"perl $BIOMARTLWP/biomartLWP.pl $XML_PATH/${COMMON_NAME}_uniprot_ensp.xml ${BIOMART_HOST} |") || die "Failed: $!\n";
while(<PS>){
	my $line = $_;
	if($line =~/^(\S+)\t(.*)\t(.*)/){

	my $th = $dbh->prepare(qq{SELECT uniprot_accession FROM uniprot_ensembl WHERE uniprot_ensembl.uniprot_accession='$2'});
	$th->execute() or die "Cannot execute: " . $th->errstr();
	my $found = 0;
	
			while ($th->fetch()){
					$found = 1;
				}
				if ($found!=1) 
				{
					if ($allensembls{$1}){
						if ($insertedAcc{$2}){
							$ins_uniport_ensembl->execute($2,$1);
						}	
					}
				}	
		
	$th = $dbh->prepare(qq{SELECT uniprot_accession FROM uniprot_ensembl WHERE uniprot_ensembl.uniprot_accession='$3'});
	$th->execute() or die "Cannot execute: " . $th->errstr();
	$found = 0;
	
			while ($th->fetch()){
					$found = 1;
				}
				if ($found!=1) 
				{
					if ($allensembls{$1}){
						if ($insertedAcc{$3}){
							$ins_uniport_ensembl->execute($3,$1);
						}	
					}
				}		
	
	}   
	
}		
	

### FINISHING #################################

if($errflag){
    my $error = DBI->errstr;
    $dbh->rollback();
	$dbh->disconnect();
    die "could not insert rows: $error\n";
}
#$dbh->rollback();

$dbh->commit();

#FUNCTIONS
#it gets an alternative splicing description from uniprot and returns the sequences. 
sub getAlternative{
	my $originalSeq=$_[0];
	my %varseq2desc=%{$_[1]};
	my %varseq2start=%{$_[2]};
	my %varseq2end=%{$_[3]};
	my @varseqs=@{$_[4]};
	
	my @original = split("", $originalSeq);
	my %next;
	my $begining=0;
	my $end=scalar(@original)-1;
	for(my $i=$begining;$i<$end;$i++){
		$next{$i}=$i+1;
	}
	my @previousends=();
	my $lastgapstart;
	my @previousismiss=();
	
	foreach my $varseq (@varseqs){
		if($varseq=~/^Displayed/){
			return($originalSeq)
		}elsif(($varseq=~/External/)||($varseq=~/^Not described/)){
			#TODO: deal with Externals in uniprot
			return("");
		}else{
			if($varseq2desc{$varseq}=~/^Missing/){
				if($varseq2start{$varseq} == ($begining+1)){	#if the variation starts at the begining
					$begining=$varseq2end{$varseq};
					$lastgapstart=$varseq2start{$varseq};
				}
				elsif($varseq2end{$varseq} == ($end+1)){		#if the variation goes until the end
					my $concat=0;
					my $newend;
					for(my $i=0;$i<scalar(@previousends); $i++){			#check if concatenates with a previous variation
						if($previousends[$i]==($varseq2start{$varseq}-1)){
							if($previousismiss[$i] == "1"){	#check if is also a missing
								$newend=$end;
							}else{
								$newend=(scalar(@original)-1);
							}
						}
					}
					if(defined($newend)){
						$end=$newend;
					}else{
						$end=($varseq2start{$varseq}-2);
					}
				}else{
					my $concat=0;
					for(my $i=0;$i<scalar(@previousends); $i++){			#check if concatenates with a previous variation
						if($previousends[$i]==($varseq2start{$varseq}-1)){
							$concat=1;
							if($previousismiss[$i] == "1"){
								$next{($lastgapstart-2)}=$varseq2end{$varseq};
								$lastgapstart=$lastgapstart;
							}else{
								$next{(scalar(@original)-1)}=$varseq2end{$varseq};
								$lastgapstart=scalar(@original);
							}
						}
					}
					if(!$concat){
						$next{($varseq2start{$varseq}-2)}=$varseq2end{$varseq};
						$lastgapstart=$varseq2start{$varseq};
					}
				}
				push(@previousismiss, "1");
			}elsif($varseq2desc{$varseq}=~/(\w+)\s?\-\>\s?(\w+)\s?\(/){
				my $currsize = scalar(@original);
				my @newres = split("",$2);
				if($varseq2start{$varseq} == 1){	#if starts at the begining
					$begining=$currsize;
				}else{
					my $theprev;							#attach the begining of the insertion
					for(my $i=0;$i<scalar(@previousends); $i++){			#check if concatenates with a previous variation
						if($previousends[$i]==($varseq2start{$varseq}-1)){
							if($previousismiss[$i] == 1){
								if($lastgapstart == 1){
									$begining=$currsize;
								}else{
									$theprev=($lastgapstart-2);
								}
							}else{
								$theprev=($currsize-1);
							}
						}
					}
					if(defined($theprev)){
						$next{$theprev}=$currsize;
					}else{
						$next{($varseq2start{$varseq}-2)}=$currsize;
					}
				}
				if($varseq2end{$varseq} == ($end+1)){	#if finishes at the end
					$end=$currsize+scalar(@newres)-1;
				}
				for (my $i=0; $i<scalar(@newres);$i++){
					push(@original, $newres[$i]);
					if($i==(scalar(@newres)-1)){
						$next{$currsize+$i}=$varseq2end{$varseq};
					}else{
						$next{$currsize+$i}=$currsize+$i+1;
					}
				}
				push(@previousismiss, "0");			
			}
			push(@previousends, $varseq2end{$varseq});
		}
	}
	my @result = ();
	my $i = $begining;
	while($i != $end){
		push(@result,$original[$i]);
		$i = $next{$i};
		# print $i."\t".$end."\n";
		if(not defined($i)){
			print STDERR "Error in $originalSeq"."\n";
			die;
		}
	}
	push(@result,$original[$i]);
	return(join("",@result));	
}


### NECESSARY TO RECURSIVELY RECONSTRUCT ANCESTRAL IPIs 
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
