#! /usr/bin/perl 
use strict;
use warnings;


my $dataset = $ARGV[0];
my $xml_path = $ARGV[1];
my $taxid = $ARGV[2];


open(OUTFILE, ">$xml_path/ensg.xml")  or die $!;
	
		print OUTFILE '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "1" count = "" datasetConfigVersion = "0.6" >
			
	<Dataset name = "';
	print OUTFILE "$dataset";
	
	print OUTFILE '" interface = "default" >
		<Filter name = "biotype" value = "protein_coding"/>
		<Attribute name = "ensembl_gene_id" />
		<Attribute name = "external_gene_id" />
		<Attribute name = "description" />
	</Dataset>
</Query>';
	
close(OUTFILE);

open(OUTFILE, ">$xml_path/ensg_ensp.xml")  or die $!;
	
		print OUTFILE '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "1" count = "" datasetConfigVersion = "0.6" >
			
	<Dataset name = "';
	print OUTFILE "$dataset";
	print OUTFILE '" interface = "default" >
		<Filter name = "biotype" value = "protein_coding"/>
		<Attribute name = "ensembl_gene_id" />
		<Attribute name = "ensembl_peptide_id" />
	</Dataset>
</Query>';

close(OUTFILE);

open(OUTFILE, ">$xml_path/uniprot_ensp.xml")  or die $!;

print OUTFILE '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "1" count = "" datasetConfigVersion = "0.6" >
			
	<Dataset name = "';
	print OUTFILE "$dataset";
	print OUTFILE '" interface = "default" >
		<Attribute name = "ensembl_peptide_id" />
		<Attribute name = "uniprot_swissprot_accession" />
		<Attribute name = "uniprot_sptrembl" />
	</Dataset>
</Query>';

close(OUTFILE);

if ($taxid == 6239)
{
open(OUTFILE, ">$xml_path/inparanoid_ensp.xml")  or die $!;

print OUTFILE '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "0" count = "" datasetConfigVersion = "0.6" >
			
	<Dataset name = "celegans_gene_ensembl" interface = "default" >
		<Attribute name = "ensembl_peptide_id" />
		<Attribute name = "wormpep_id" />
	</Dataset>
</Query>';

close(OUTFILE);

}
