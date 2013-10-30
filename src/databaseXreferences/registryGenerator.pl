#! /usr/bin/perl 
use strict;
use warnings;

#system("wget -N -P ./biomart-perl 'http://www.biomart.org/biomart/martservice?type=registry'");
my $biomart_database=$ARGV[0];
my $dataset=$ARGV[1];
my $registry = $ARGV[2];


open(INFILE, $registry)    or die $!;
open(OUTFILE, ">./biomart-perl/conf/registry.xml")  or die $!;
while(<INFILE>){
	
	if($_=~/.*displayName\=\"$biomart_database.*/)	
	{
		print OUTFILE '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE MartRegistry><MartRegistry>';
		s/includeDatasets\=\"\"/includeDatasets\=\"$dataset\"/g;
		print OUTFILE "\n$_";
		print OUTFILE '</MartRegistry>';
		last;
	}	
	
}	

close(INFILE);
close(OUTFILE);







