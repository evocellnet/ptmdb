
use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use DBI qw(:sql_types);
use Getopt::Long;

my ($resource, $enshost, $ensuser, $ensport, $enspass, $organismsFile, $martDirectory,
    $ptmdbhost, $ptmdbDB, $newptmdbDB, $ptmdbuser, $ptmdbport, $ptmdbpass);
my $help = '';

if ( !GetOptions( 'organismsFile=s'      => \$organismsFile,
		  'martDirectory=s'      => \$martDirectory,
                  'ensembluser=s'        => \$ensuser,
                  'ensemblport=s'        => \$ensport,
                  'ensemblpass=s'        => \$enspass,
		  'ptmdbhost=s'          => \$ptmdbhost,
		  'ptmdbDB=s'            => \$ptmdbDB,
		  'newptmdbDB=s'         => \$newptmdbDB,
                  'ptmdbuser=s'          => \$ptmdbuser,
                  'ptmdbport=s'          => \$ptmdbport,
                  'ptmdbpass=s'          => \$ptmdbpass,
                  'help|h!'     => \$help )
     || !defined($organismsFile && $martDirectory && $newptmdbDB && $ptmdbDB && $ptmdbhost && $ptmdbuser && $ptmdbport && $ptmdbpass)
     || $help )
{
  print <<END_USAGE;

Usage:
      $0 --ptmdbhost=host
      
      $0 --help

      --organismsFile        Csv file containing the organisms (see template)

      --martDirectory        File containing the marts contained in biomart
      
      --ptmdbhost            Database host (defaults to public ensembldb)

      --ptmdbDB              Name of the old database

      --newptmdbDB           Name of the new database

      --ptmdbuser            User for the database connection

      --ptmdbport            Port number for the database connection

      --ptmdbpass            Password for the database connection

      --ensembluser          (Optional) User for the database connection

      --ensemblport          (Optional) Port number for the database connection

      --ensemblpass          (Optional) Password for the database connection

      --help    / -h  To see this text.

Example usage:

  $0 -s mouse

END_USAGE

  exit(1);
}


# use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

# my $host = 'ensembldb.ensembl.org';
# my $user   = 'anonymous';
# my $port   = 5306;
# my $dbname = 'ensembl_compara_86';

# my $comparadb= new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
#     -host   => $host,
#     -port   => $port,
#     -user   => $user,
#     -dbname => $dbname,
#     -species => 'Multi',
#     );

# print 
# my %pairs = %{ $comparadb->get_available_adaptors() };
# while ( my ( $key, $value ) = each(%pairs) ) {
#     print $key."\t".$value."\n";
# }

# print $allavailable."\n";
# foreach my $adaptor (%{$allavailable}){
#     print $adaptor."\n";
# }
# my $all_genome_dbs = $comparadb->fetch_all();
# foreach my $this_genome_db (@{$all_genome_dbs}) {
#   print $this_genome_db->name, "\n";
# }


my $registry = 'Bio::EnsEMBL::Registry';

#Connecting to the old PTM database
my $olddbh = DBI->connect('DBI:mysql:database='.$ptmdbDB.";host=".$ptmdbhost.";port=".$ptmdbport,
			  $ptmdbuser,
			  $ptmdbpass,
			  {AutoCommit => 0}) || die "Could not connect to database: $DBI::errstr";

my $newdbh = DBI->connect('DBI:mysql:database='.$newptmdbDB.";host=".$ptmdbhost.";port=".$ptmdbport,
			  $ptmdbuser,
			  $ptmdbpass,
			  {AutoCommit => 0}) || die "Could not connect to database: $DBI::errstr";

# Mapping from taxid 2 host and mart
my ($taxid2hostref,$taxid2martref) = getTaxid2marts($martDirectory);
my %taxid2host = %{$taxid2hostref};
my %taxid2mart = %{$taxid2martref};

#updating tables without considering the organisms
updatingCommonTables($olddbh, $newdbh);

#Updating organism specific table
#Select organisms in old database
my $organismsQuery = "SELECT taxid,common_name,scientific_name FROM organism;";
my $orgh = $olddbh->prepare($organismsQuery) or die "Cannot prepare: " . $olddbh->errstr();
$orgh->execute() or die "Cannot execute: " . $orgh->errstr();
my ($taxid,$common_name,$scientific_name);
$orgh->bind_columns(\$taxid, \$common_name, \$scientific_name);

#Loop through organisms
while($orgh->fetch()){
    # if($taxid eq "7227"){
    # 	#problem with fruitfly. I can't remap the protein ids from versions
    # 	#possible solution will be to remap using gene names or match peptides
    # 	next;
    # }
    # if($taxid eq "9606"){
    # 	#skip human for the moment. Too slow
    # 	next;
    # }
    # if($taxid eq "4932"){
    # 	next;
    # }
    # if(!checkIfHistoryAvailable($taxid,$taxid2host{$taxid})){
    # 	print "\t* $common_name SKIPPED due to absence of ID history...\n";
    # 	next;
    # }


    #translator from old ensp id to new enspid
    print "\t* Retrieving ID history for $common_name...\n";
    my $updateIdByEnsemblRef = updateIdByOrg($taxid,$taxid2host{$taxid});
    my $updateIdByUniprotRef = updateIdByOrgUsingUniprot($olddbh, $newdbh, $taxid);
    my %oldID2newID = %{unifyTranslators($updateIdByEnsemblRef,$updateIdByUniprotRef,$olddbh,$newdbh, $taxid)};
	
    #fastas for the new ids
    print "\t* Reading FASTA sequences for $common_name...\n";
    my %newid2fasta = %{getSequences($newdbh,$taxid)};
    my %oldid2fasta = %{getSequences($olddbh,$taxid)};
    
    #update peptides table
    print "\t* Updating tables for $common_name...\n";
    my $matchedPeptides = updatePeptides($olddbh, $newdbh, $taxid, \%oldID2newID, \%newid2fasta);
    
    updatePeptideQuantifications($olddbh, $newdbh, $taxid, $matchedPeptides);
    my $matchedSites = sitesWithMatchedPeptides($olddbh, $taxid, $matchedPeptides);
    updateSites($olddbh, $newdbh, $taxid, \%oldID2newID, \%newid2fasta, \%oldid2fasta, $matchedSites, $matchedPeptides);

    # Necessary to commit the changes. Comment it for debugging
    $newdbh->commit();
    
}

$olddbh->disconnect();
$newdbh->disconnect();

exit;


sub unifyTranslators{
    my %updateByEnsembl = %{$_[0]};
    my %updateByUniprot = %{$_[1]};
    my $olddbh=$_[2];
    my $newdbh=$_[3];
    my $taxid=$_[4];

    my %unified;
    
    my $select = "SELECT id FROM ensp WHERE taxid = ?";
    my $new_stable_id;
    my $newidssth = $newdbh->prepare($select) or die "Cannot prepare: " . $newdbh->errstr();
    $newidssth -> execute($taxid) or die "Cannot execute:" . $newidssth->errstr();
    $newidssth->bind_columns(\$new_stable_id);
    my %isNewId;
    while($newidssth->fetch()){
	$isNewId{$new_stable_id}=1;
    }

    #get all old stable ids
    my $old_stable_id;
    my $oldidssth = $olddbh->prepare($select) or die "Cannot prepare: " . $olddbh->errstr();
    $oldidssth -> execute($taxid) or die "Cannot execute:" . $oldidssth->errstr();
    $oldidssth->bind_columns(\$old_stable_id);
    my @all_old_ids;
    while($oldidssth->fetch()){
	if(defined($isNewId{$old_stable_id})){
	    push(@{$unified{$old_stable_id}}, $old_stable_id);
	}elsif(defined($updateByEnsembl{$old_stable_id})){
	    push(@{$unified{$old_stable_id}}, $updateByEnsembl{$old_stable_id});
	}else{
	    foreach my $newid (@{$updateByUniprot{$old_stable_id}}){
		push(@{$unified{$old_stable_id}}, $newid);
	    }
	}
    }
    return(\%unified)
}


##################
### Subroutines
##################

sub getWindow{
    my $sequence = $_[0];
    my $position = ($_[1]-1);
    my $window = $_[2];
    my $windowshift = $_[3];
    
    my $shift;
    if($windowshift eq "center"){
  	$shift = (($window - 1)/2);
    }elsif($windowshift eq "left"){
	$shift = ($window-1);
    }elsif($windowshift eq "right"){
	$shift = 0;
    }
    my @residues = split("",$sequence);
    my @out;
    for(my $i=($position-$shift);$i<=(($position-$shift)+($window-1));$i++){
	if(defined($residues[$i])){
	    push(@out, $residues[$i]);
	}else{
	    push(@out,"_");
	}
    }
    my $peptide = join("",@out);
    return($peptide);
}


sub matchPeptide{
    my $sequence = $_[0];
    my $peptide = $_[1];
    my $window = $_[2];
    my $windowshift = $_[3];
    
    my $shift;
    if($windowshift eq "center"){
  	$shift = ($window-1)/2;
    }
    if($windowshift eq "right"){
  	$shift = 0;
    }
    if($windowshift eq "left"){
  	$shift = ($window-1);
    }
    
    my $position;
    if($peptide !~/\_/){
  	if($sequence=~/$peptide/){
	    $position=$-[0]+$shift+1;
  	}
    }
    return($position);
}


sub getNewPosition{
    my $oldposition=$_[0];
    my $oldsequence=$_[1];
    my $newsequence=$_[2];
    my $windowsize=$_[3];

    my $centerSequence = getWindow($oldsequence,$oldposition,$windowsize,"center");
    my $newposition = matchPeptide($newsequence, $centerSequence, $windowsize, "center");
    if(!defined($newposition)){
	$centerSequence = getWindow($oldsequence,$oldposition,$windowsize,"left");
	$newposition = matchPeptide($newsequence, $centerSequence, $windowsize, "left");
    }
    if(!defined($newposition)){
	$centerSequence = getWindow($oldsequence,$oldposition,$windowsize,"right");
	$newposition = matchPeptide($newsequence, $centerSequence, $windowsize, "right");
    }
    return($newposition);
}

#New Ensembl ID from the old one
# sub getNewID{
#     my $oldID=$_[0];
#     my %oldID2newID=%{$_[1]};

#     my $newID = $oldID2newID{$oldID};
#     if(defined($newID)){
# 	return($newID)
#     }else{
# 	return()
#     }
# }

#Update peptide information tables
sub updatePeptides{
    my $olddbh = $_[0];
    my $newdbh = $_[1];
    my $taxid = $_[2];
    my %oldID2newID = %{$_[3]};
    my %id2fasta = %{$_[4]};

    my %availablePeptideIds;
    my %availablePeptideEnsp;

    my $peptidequery = (
	{
	    selectEnsPeptide => "SELECT ensp_peptide.ensembl_id, ensp_peptide.peptide_id FROM ensp_peptide INNER JOIN ensp ON ensp.id = ensp_peptide.ensembl_id WHERE ensp.taxid = ?;",
	    selectPeptide => "SELECT DISTINCT peptide.* FROM peptide INNER JOIN ensp_peptide ON peptide.id = ensp_peptide.peptide_id INNER JOIN ensp ON ensp.id = ensp_peptide.ensembl_id WHERE ensp.taxid = ?;",
	    insert => "INSERT INTO peptide (id,max_spectral_count,peptide,scored_peptide,experiment) VALUES (?,?,?,?,?)",
	    insertLink => "INSERT INTO ensp_peptide (ensembl_id,peptide_id) VALUES (?,?)"
	});
	
    my $selectEnsPeptide = $olddbh->prepare($peptidequery->{selectEnsPeptide} );
    my $select = $olddbh->prepare($peptidequery->{selectPeptide} );
    my $insert = $newdbh->prepare($peptidequery->{insert} );
    my $insertLink = $newdbh->prepare($peptidequery->{insertLink} );

    my %peptideProteins;
    $selectEnsPeptide->execute($taxid) or die "Cannot execute: " . $selectEnsPeptide->errstr();
    my ($thisensembl_id, $thispeptide_id);
    $selectEnsPeptide->bind_columns(\$thisensembl_id, \$thispeptide_id);
    while(my $row = $selectEnsPeptide->fetch){
	push(@{$peptideProteins{$thispeptide_id}}, $thisensembl_id);
    }
    
    #Inserting peptides
    my $remappedPeptidesCounter=0;
    my $totalPeptidesCounter=0;
    $select->execute($taxid) or die "Cannot execute: " . $select->errstr();
    my ($id, $spectral_count,$peptide, $scored_peptide, $experiment);
    $select->bind_columns(\$id, \$spectral_count,\$peptide,\$scored_peptide,\$experiment);
    while(my $row = $select->fetch){
	#for all proteins with this peptid
	foreach my $ensembl_id (@{$peptideProteins{$id}}){
	    if(defined($oldID2newID{$ensembl_id})){
		foreach my $newID (@{$oldID2newID{$ensembl_id}}){
		    if($newID ne "<retired>"){
			my $sequence = $id2fasta{$newID};
			if(defined(getPeptidePositionInProtein($peptide,$sequence))){
			    $availablePeptideIds{$id}=1; #keep track of the peptide IDs reinserted
			    ${$availablePeptideEnsp{$id}}{$ensembl_id}=$newID;
			}
		    }
		}
	    }
	}
	if(defined($availablePeptideIds{$id})){
	    $insert->execute($id, $spectral_count,$peptide, $scored_peptide, $experiment) or die "Cannot execute: " . $insert->errstr();
	    $remappedPeptidesCounter++;
	}
	$totalPeptidesCounter++;
    }
    print "\t\t* ".$remappedPeptidesCounter." out of ".$totalPeptidesCounter." peptides remapped\n";

    #Inserting links between peptides and proteins
    my $remappedLinks=0;
    my $totalLinks=0;
    $selectEnsPeptide->execute($taxid) or die "Cannot execute: " . $selectEnsPeptide->errstr();
    $selectEnsPeptide->bind_columns(\$thisensembl_id, \$thispeptide_id);
    while(my $row = $selectEnsPeptide->fetch){
	if(defined(${$availablePeptideEnsp{$thispeptide_id}}{$thisensembl_id})){
	    $insertLink ->execute(${$availablePeptideEnsp{$thispeptide_id}}{$thisensembl_id}, $thispeptide_id)  or die "Cannot execute: " . $insertLink->errstr();
	    $remappedLinks++;
	}
	$totalLinks++;
    }
    print "\t\t* ".$remappedLinks." out of ".$totalLinks." protein-peptides remapped\n";
    
    return(\%availablePeptideIds);
}

sub updateSites{
    my $olddbh = $_[0];
    my $newdbh = $_[1];
    my $taxid = $_[2];
    my %oldID2newID = %{$_[3]};
    my %newid2fasta = %{$_[4]};
    my %oldid2fasta = %{$_[5]};
    my %matchedSites = %{$_[6]};
    my %matchedPeptides = %{$_[7]};
    my $windowsize=11;
    
    my $sitequery = (
	{
	    selectSite => "SELECT DISTINCT site.* FROM site INNER JOIN ensp_site ON site.id = ensp_site.site_id INNER JOIN ensp ON ensp.id = ensp_site.ensp WHERE ensp.taxid = ?",
	    selectEnspSite => "SELECT ensp_site.* FROM ensp_site INNER JOIN ensp ON ensp_site.ensp = ensp.id WHERE taxid = ?",
	    selectPeptideSite => "SELECT DISTINCT peptide_site.* FROM peptide_site INNER JOIN peptide ON peptide.id = peptide_site.peptide_id INNER JOIN ensp_peptide ON peptide.id = ensp_peptide.peptide_id INNER JOIN ensp ON ensp.id = ensp_peptide.ensembl_id WHERE ensp.taxid = ?",
	    insert => "INSERT INTO site (id,localization_score,modif_type,residue,experiment) VALUES (?,?,?,?,?)",
	    insertLinkToEnsp => "INSERT INTO ensp_site (ensp,site_id,position) VALUES (?,?,?)",
	    insertLinkToPeptide => "INSERT INTO peptide_site (peptide_id,site_id) VALUES (?,?)"
	});

    my $selectSite = $olddbh->prepare($sitequery->{selectSite});
    my $selectEnspSite = $olddbh->prepare($sitequery->{selectEnspSite});
    my $selectPeptideSite = $olddbh->prepare($sitequery->{selectPeptideSite});
    my $insert = $newdbh->prepare($sitequery->{insert});
    my $insertLinkToEnsp = $newdbh->prepare($sitequery->{insertLinkToEnsp});
    my $insertLinkToPeptide = $newdbh->prepare($sitequery->{insertLinkToPeptide});

    #remap to new positions
    $selectSite->execute($taxid) or die "Cannot execute: " . $selectSite->errstr();
    my ($id, $localization_score, $modif_type, $residue, $experiment);
    $selectSite->bind_columns(\$id,\$localization_score,\$modif_type,\$residue,\$experiment);
    my $totalSitesCounter=0;
    my $matchedSite=0;
    while(my $row = $selectSite->fetch){
	$totalSitesCounter++;
	#sites for which the peptide has been matched
	if(defined($matchedSites{$id})){
	    $insert->execute($id, $localization_score, $modif_type, $residue, $experiment) or die "Cannot execute: " . $insert->errstr();
	    $matchedSite++;
	}
	    # my $oldensembl_id = $oldEnsemblID{$id}; 
	    # #if there is a new ID mapping if not use the same
	    # my $newID = $oldID2newID{$oldensembl_id} || $oldensembl_id;
	    # print $oldensembl_id."\t".$oldPositions{$id}."\t".$newID."\n";
	    # my $newposition=getNewPosition($oldPositions{$id}, $oldid2fasta{$oldensembl_id}, $newid2fasta{$newID},$windowsize);
	    # if(!defined($newposition)){
	    # 	$notremapped++;
	    # }else{
	    # 	$insert->execute($id, $localization_score, $modif_type, $residue, $experiment) or die "Cannot execute: " . $insert->errstr();
	    # 	$insertLinkToEnsp->execute($newID,$id,$newposition);
	    # }
    }
    print "\t\t* ".$matchedSite." out of ".$totalSitesCounter." sites remapped\n";

    #remap sites to peptides
    $selectPeptideSite->execute($taxid) or die "Cannot execute: " . $selectPeptideSite->errstr();
    my ($peptide_id,$site_id);
    $selectPeptideSite->bind_columns(\$peptide_id, \$site_id);
    my $peptideSiteTotal=0;
    my $peptideSiteMatched=0;
    while(my $row = $selectPeptideSite->fetch){
	if(defined($matchedPeptides{$peptide_id}) && defined($matchedSites{$site_id})){
	    $insertLinkToPeptide->execute($peptide_id, $site_id);
	    $peptideSiteMatched++;
	}
	$peptideSiteTotal++;
    }
    print "\t\t* ".$peptideSiteMatched." out of ".$peptideSiteTotal." peptide-site remapped\n";

    #get old site positions
    $selectEnspSite->execute($taxid) or die "Cannot execute: " . $selectEnspSite->errstr();
    my ($oldensembl_id,$thissite_id,$oldposition);
    $selectEnspSite->bind_columns(\$oldensembl_id, \$thissite_id ,\$oldposition);
    my $enspSiteTotal=0;
    my $enspSiteMatched=0;
    my %avoidDuplicates;
    while(my $row = $selectEnspSite->fetch){
	$enspSiteTotal++;
	if($matchedSites{$thissite_id}){
	    if(defined($oldID2newID{$oldensembl_id})){
		my $matched=0;
		foreach my $newID (@{$oldID2newID{$oldensembl_id}}){
		    if($newID ne "<retired>"){
			if(not defined(${$avoidDuplicates{$newID}}{$thissite_id})){
			    my $newposition=getNewPosition($oldposition, $oldid2fasta{$oldensembl_id}, $newid2fasta{$newID},$windowsize);
			    if(defined($newposition)){
				$matched=1;
				${$avoidDuplicates{$newID}}{$thissite_id}=1;
				$insertLinkToEnsp->execute($newID,$thissite_id,$newposition);
			    }
			}
		    }
		}
		if($matched){
		    $enspSiteMatched++;
		}
	    }
	    # my $newID = $oldID2newID{$oldensembl_id} || $oldensembl_id;
	    # if($newID ne "<retired>"){
	    # 	if(not defined(${$avoidDuplicates{$newID}}{$thissite_id})){
	    # 	    my $newposition=getNewPosition($oldposition, $oldid2fasta{$oldensembl_id}, $newid2fasta{$newID},$windowsize);
	    # 	    if(defined($newposition)){
	    # 		${$avoidDuplicates{$newID}}{$thissite_id}=1;
	    # 		$insertLinkToEnsp->execute($newID,$thissite_id,$newposition);
	    # 		$enspSiteMatched++;
	    # 	    }
	    # 	}
	    # }
	}
    }
    print "\t\t* ".$enspSiteMatched." out of ".$enspSiteTotal." protein-site remapped\n";
}




#updating common tables without checking organism
sub updatingCommonTables{
    my $olddbh = $_[0];
    my $newdbh = $_[1];

    #Updating tables that do not change
    print "\t* Updating common tables...\n";
    my @allsql =(
	{
	    select => 'SELECT pub_id,pubmed_id,fauthor,`leading`,publication_date,journal,title,pride FROM publication',
	    insert => "INSERT INTO publication (pub_id,pubmed_id,fauthor,`leading`,publication_date,journal,title,pride) VALUES(?,?,?,?,?,?,?,?)"
	},
	{
	    select => 'SELECT id,organism,publication,scoring_method,biological_sample,comments,labelling_type,labelling_method,spectrometer,enrichment_method,antibody,identification_software,quantification_software FROM experiment',
	    insert => "INSERT INTO experiment (id,organism,publication,scoring_method,biological_sample,comments,labelling_type,labelling_method,spectrometer,enrichment_method,antibody,identification_software,quantification_software) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);"
	},
	{
	    select => 'SELECT id,description,time_min,control_description FROM `condition`',
	    insert => "INSERT INTO `condition` (id,description,time_min,control_description) VALUES (?,?,?,?);"
	}
    );
    foreach my $tablequery (@allsql){
	my $select = $olddbh->prepare($tablequery->{select} );
	my $insert = $newdbh->prepare($tablequery->{insert} );
	$select->execute() or die "Cannot execute: " . $select->errstr();
	while(my $row = $select->fetch){
	    $insert->execute(@$row) or die "Cannot execute: " . $insert->errstr();;
	}
    }
}

#match peptide in protein sequence
sub getPeptidePositionInProtein{
	my $peptide=$_[0];
	my $sequence=$_[1];
	
	$peptide =~s/_//g;
	$peptide =~s/\(.+?\)//g;
	my $position;
	if($sequence=~/$peptide/){
		$position=$-[0];
	}
	return($position);
}

#get protein sequence from DB 
sub getSequences{
    my $dbh = $_[0];
    my $taxid = $_[1];

    my %ensp2fasta;

    my $seqQuery = "SELECT id,sequence FROM ensp WHERE taxid = ?";

    my $select = $dbh->prepare($seqQuery);
    $select->execute($taxid) or die "Cannot execute: " . $select->errstr();
    my ($id, $sequence);
    $select->bind_columns(\$id, \$sequence);
    while(my $row = $select->fetch){
	$ensp2fasta{$id}=$sequence;
    }
    return(\%ensp2fasta);
}

#### Get all old ensembl protein ids in organism ###
sub getENSPbyorg {
    my $thisspecies = $_[0];

    my ($id, $sequence, $length, $taxid);
    my $enspSelectQuery = q(
    SELECT ensp.*
    FROM ensp
    JOIN organism USING (taxid)
    WHERE common_name = ?
    );

    my $sth = $olddbh->prepare($enspSelectQuery) or die "Cannot prepare: " . $olddbh->errstr();
    $sth->bind_param( 1, $thisspecies, SQL_VARCHAR );
    $sth->execute() or die "Cannot execute: " . $sth->errstr();
    $sth->bind_columns(\$id, \$sequence, \$length, \$taxid);

    my @allensps;
    while($sth->fetch()){
	push(@allensps, $id);
    }
    return(\@allensps);
}


sub checkIfHistoryAvailable{
    my $species = $_[0];
    my $ensemblhost = $_[1];
    
    my ($host, $port, $user, $pass);
    if($ensemblhost ne "ensembl.org"){
	$host = "mysql-eg-publicsql.ebi.ac.uk";
	$port = 4157;
    }

    $registry->load_registry_from_db( -host => $host || 'ensembldb.ensembl.org',
					 -user => $user || 'anonymous',
					 -port => $port || 3306,
					 -pass => $pass || '' );
    
    my $adaptor = $registry->get_DBAdaptor( $species, 'Core' ) or die  "Cannot get Adaptor for $species\n" . $registry->errstr();;
    my $statement = q(SELECT * FROM stable_id_event LIMIT 10);
    my $sth = $adaptor->dbc()->db_handle()->prepare($statement)  or die "Cannot prepare: " . $adaptor->errstr();
    $sth->execute();
    if($sth->rows > 0){
	return(1)
    }
    return(0);
}

sub updateIdByOrgUsingUniprot {
    my $olddbh = $_[0];
    my $newdbh = $_[1];
    my $taxid = $_[2];
    my %oldID2newID;
    
    #get all old stable ids
    my $allOldIdsselect = "SELECT id FROM ensp WHERE taxid = ?";
    my $old_stable_id;
    my $oldidssth = $olddbh->prepare($allOldIdsselect) or die "Cannot prepare: " . $olddbh->errstr();
    $oldidssth -> execute($taxid) or die "Cannot execute:" . $oldidssth->errstr();
    $oldidssth->bind_columns(\$old_stable_id);
    my @all_old_ids;
    while($oldidssth->fetch()){
	push(@all_old_ids, $old_stable_id);
    }
	
    #get mapping from old stable to old uniprot
    my $select = "SELECT uniprot_accession, ensembl_id FROM uniprot_ensembl INNER JOIN ensp ON ensp.id = uniprot_ensembl.ensembl_id WHERE ensp.taxid = ?";
    my ($old_uniprot_acc, $old_enspid);
    my $oldsth = $olddbh->prepare($select) or die "Cannot prepare: " . $olddbh->errstr();
    $oldsth->execute($taxid) or die "Cannot execute: " . $oldsth->errstr();
    $oldsth->bind_columns(\$old_uniprot_acc, \$old_enspid);
    my %oldensp2uniprot;
    while($oldsth->fetch()){
	push(@{$oldensp2uniprot{$old_enspid}}, $old_uniprot_acc);
    }

    #get mapping from new uniprot to new stable
    my ($new_uniprot_acc, $new_enspid);
    my $newsth = $newdbh->prepare($select) or die "Cannot prepare: " . $newdbh->errstr();
    $newsth->execute($taxid) or die "Cannot execute: " . $newsth->errstr();
    $newsth->bind_columns(\$new_uniprot_acc, \$new_enspid);
    my %newuniprot2ensp;
    while($newsth->fetch()){
	push(@{$newuniprot2ensp{$new_uniprot_acc}}, $new_enspid);
    }

    #Search of the equivalent id using uniprot as proxy
    #it gives priority to the conserved id
    foreach my $thisold_stable (@all_old_ids){
	my $done=0;
	if(defined($oldensp2uniprot{$thisold_stable})){
	    foreach my $thisold_uniprot (@{$oldensp2uniprot{$thisold_stable}}){
		if(defined($newuniprot2ensp{$thisold_uniprot})){
		    foreach my $thisnew (@{$newuniprot2ensp{$thisold_uniprot}}){
			if($thisnew eq $thisold_stable){
			    push(@{$oldID2newID{$thisold_stable}}, $thisnew);
			    $done=1;
			}
		    }
		    if(!$done){
			foreach my $thisnew (@{$newuniprot2ensp{$thisold_uniprot}}){
			    push(@{$oldID2newID{$thisold_stable}}, $thisnew);
			    $done=1;
			}
		    }
		}
	    }
	}
    }
    return(\%oldID2newID);
}
    
#Returns translator from old Ensembl IDs to the newest version
sub updateIdByOrg {
    my $species = $_[0]; #i.e drosophila_melanogaster_core_86_602
    my $ensemblhost = $_[1]; #i.e. ensembldb.ensembl.org

    my ($host, $port, $user, $pass);
    if($ensemblhost ne "ensembl.org"){
	$host = "mysql-eg-publicsql.ebi.ac.uk";
	$port = 4157;
    }

    $registry->load_registry_from_db( -host => $host || 'ensembldb.ensembl.org',
					 -user => $user || 'anonymous',
					 -port => $port || 3306,
					 -pass => $pass || '' );
    
    my $adaptor = $registry->get_DBAdaptor( $species, 'Core' ) or die  "Cannot get Adaptor for $species\n" . $registry->errstr();;

    # #all stable ids for current version
    # my $allCurrentIdsStatement = q(SELECT DISTINCT stable_id FROM translation);
    # my $idshandle = $adaptor->dbc()->db_handle()->prepare($allCurrentIdsStatement)  or die "Cannot prepare: " . $allCurrentIdsStatement->errstr();
    # $idshandle->execute() or die "Cannot execute: " . $idshandle->errstr();
    # my $thisstableid;
    # $idshandle->bind_columns(\$thisstableid);
    # my %isCurrentVersion;
    # while(my $row = $idshandle->fetch){
    # 	$isCurrentVersion{$thisstableid}=1;
    # }
    
    my %translator;
    
    # We could do what we want to do with the API, but this is simpler and
    # quicker, at the moment.  As always, when using plain SQL against our
    # databases, the user should not be surprised to see the code break when
    # we update the schema...
    my $statement = q(
SELECT old_stable_id,
old_version,
old_release,
new_stable_id,
new_version,
new_release,
score
FROM stable_id_event
JOIN mapping_session USING (mapping_session_id)
ORDER BY new_release ASC, CAST(new_release AS UNSIGNED)
	);

    my $sth = $adaptor->dbc()->db_handle()->prepare($statement)  or die "Cannot prepare: " . $adaptor->errstr();

    my ( $old_stable_id, $version, $release, $new_stable_id, $new_version, $new_release, $score );

    $sth->execute() or die "Cannot execute: " . $sth->errstr();
    $sth->bind_columns(\$old_stable_id, \$version, \$release, \$new_stable_id, \$new_version, \$new_release, \$score);
    
    my @allIds;
    my %visitedId;
    while ( $sth->fetch() ) {
	my $stable_id;
	if(defined($old_stable_id)){
	    if(! defined($visitedId{$old_stable_id})){
		push(@allIds,$old_stable_id);
	    }
	    if (defined($new_stable_id)) {
		$translator{$old_stable_id}=$new_stable_id;
		$translator{$old_stable_id.".".$version}=$new_stable_id;
	    }elsif( !defined($new_stable_id) ){
		$translator{$old_stable_id}="<retired>";
		$translator{$old_stable_id.".".$version}="<retired>";
	    }
	}else{
	    if(! defined($visitedId{$new_stable_id})){
		push(@allIds,$new_stable_id);
	    }
	    $translator{$new_stable_id}=$new_stable_id;
	    $translator{$new_stable_id.".".$new_version}=$new_stable_id;   
	}
    }
    #recursive translator
    my %resultTranslator;
    foreach my $thisid (@allIds){
	my $newId = $translator{$thisid};
	while(defined($translator{$newId}) && $translator{$newId} ne $newId){
	    $newId = $translator{$newId};
	}
	$resultTranslator{$thisid}=$newId;
    }
    
    return(\%resultTranslator);
}


# Mapping from taxid 2 scientific name
sub getTaxid2marts{
    my $infile = $_[0];
    
    my %taxid2host;
    my %taxid2mart;
    
    open(INFILE, $infile);
    my @lines = <INFILE>;
    close(INFILE);
    for(my $i=1;$i<scalar(@lines);$i++){
	chomp($lines[$i]);
	my @fields=split(",", $lines[$i]);
	$taxid2host{$fields[6]}=$fields[4];
	$taxid2mart{$fields[6]}=$fields[1];
    }
    return(\%taxid2host, \%taxid2mart);
}

#it returns sites with peptides that have been matched to a new protein sequence
sub sitesWithMatchedPeptides{
    my $olddbh = $_[0];
    my $taxid = $_[1];
    my %matchedPeptides = %{$_[2]};

    my %matchedSites;
    
    my $peptide_site_query = "SELECT peptide_site.* FROM peptide_site INNER JOIN peptide ON peptide.id = peptide_site.peptide_id INNER JOIN ensp_peptide ON peptide.id = ensp_peptide.peptide_id INNER JOIN ensp ON ensp.id = ensp_peptide.ensembl_id WHERE ensp.taxid = ?";
    
    my $select = $olddbh->prepare($peptide_site_query);
    $select->execute($taxid) or die "Cannot execute: " . $select->errstr();
    my ($peptide_id,$site_id);
    $select->bind_columns(\$peptide_id, \$site_id);
    while(my $row = $select->fetch){
	if(defined($matchedPeptides{$peptide_id})){
	    $matchedSites{$site_id}=1;
	}
    }
    return(\%matchedSites);
}

#updates the peptide quantification tables
sub updatePeptideQuantifications{
    my $olddbh = $_[0];
    my $newdbh = $_[1];
    my $taxid = $_[2];
    my %matchedPeptides = %{$_[3]};

    my $peptide_quantification_query = "SELECT peptide_quantification.id, `condition`, spectral_count, log2, peptide_quantification.peptide FROM peptide_quantification  INNER JOIN peptide ON peptide.id = peptide_quantification.peptide INNER JOIN ensp_peptide ON peptide.id = ensp_peptide.peptide_id INNER JOIN ensp ON ensp.id = ensp_peptide.ensembl_id WHERE ensp.taxid = ?";
    my $peptide_quantification_insert = "INSERT INTO peptide_quantification (id, `condition`, spectral_count, log2, peptide) VALUES (?,?,?,?,?)";
    
    my $select = $olddbh->prepare($peptide_quantification_query);
    my $insert = $newdbh->prepare($peptide_quantification_insert);

    my $matched=0;
    my $total;
    $select->execute($taxid) or die "Cannot execute: " . $select->errstr();
    my ($id, $condition, $spectral_count,$log2, $peptide);
    $select->bind_columns(\$id, \$condition, \$spectral_count, \$log2, \$peptide);
    while(my $row = $select->fetch){
	if(defined($matchedPeptides{$peptide})){
	    $insert->execute($id, $condition, $spectral_count, $log2, $peptide);
	    $matched++;
	}
	$total++;
    }
    print "\t\t* ".$matched." out of ".$total." peptide quantifications remapped\n";

}



# # We could do what we want to do with the API, but this is simpler and
# # quicker, at the moment.  As always, when using plain SQL against our
# # databases, the user should not be surprised to see the code break when
# # we update the schema...
# my $statement = q(
# SELECT  old_version,
#         old_release,
#         new_stable_id, new_version,
#         new_release,
#         score
# FROM    stable_id_event
#   JOIN  mapping_session USING (mapping_session_id)
# WHERE   old_stable_id = ?
# ORDER BY old_version ASC, CAST(new_release AS UNSIGNED)
# );

# my $sth = $adaptor->dbc()->db_handle()->prepare($statement);

# # if comma or space used as a delimiter, split the string into multiple ids
#   foreach my $stable_id (@ids) {
#     print("Old stable ID, New stable ID, Release, Mapping score\n");
#     $sth->bind_param( 1, $stable_id, SQL_VARCHAR );
#     $sth->execute();
#     my ( $version, $release, $new_stable_id, $new_version, $new_release, $score );
#     $sth->bind_columns( \( $version, $release, $new_stable_id, $new_version, $new_release, $score ) );
#     while ( $sth->fetch() ) {
#       if ( defined($new_stable_id) ) {
#         printf( "%s.%s, %s.%s, %s, %s\n", $stable_id, $version, $new_stable_id, $new_version, $new_release, $score );
#       } elsif ( !defined($new_stable_id) ) {
#         printf( "%s.%s, <retired>, %s, %s\n", $stable_id, $version, $new_release, $score );
#       }
#     }
#     print("\n");
#   }

