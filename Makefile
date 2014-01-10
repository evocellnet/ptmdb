# Makefile --- 

# Copyright (C) 2014 evolcellnet

# Author: Brandon Invergo <invergo@ebi.ac.uk>

# This program is free software, you can redistribute it and/or
# modify it under the terms of the new-style BSD license.

# You should have received a copy of the BSD license along with this
# program. If not, see <http://www.debian.org/misc/bsd.license>.


# Database
#schema
DATABASE_SCHEMA ?= src/databaseSchema/ptmdb_model.sql
#connection
DBHOST ?= localhost
DATABASE ?= ptmdb
DBUSER ?= webAdmin
DBPASS ?= webAdmin
DBPORT ?= 3306

# Programs
MYSQL ?= /usr/bin/mysql 
R ?= /usr/bin/R
PERL ?= /usr/bin/perl
TAR ?= /usr/bin/tar
WGET ?= /usr/bin/wget
AWK ?= /usr/bin/awk

MYSQL_CMD = $(MYSQL) -h$(DBHOST) -u$(DBUSER) -p$(DBPASS) -P$(DBPORT)
DB = $(DBHOST) $(DATABASE) $(DBUSER) $(DBPASS) $(DBPORT)

#Proteomes FTPS
INPARAFTP ?= http://inparanoid.sbc.su.se/download/8.0_current/sequences/processed
IPIFTP ?= ftp://ftp.ebi.ac.uk/pub/databases/IPI/last_release/current
UNIPROT ?= http://www.uniprot.org/uniprot/?query=taxonomy%3a$(1)&force=yes&format=txt
ENSEMBL_URL = $(1)/release-$(4)/fasta/$(shell echo $(2) | sed 's/\(.*\) \(.*\)/\L\1_\2/')/pep/$(shell echo $(2) | sed 's/ /_/').$(3).$(4).pep.all.fa.gz

# Biomart datasets
MARTS = $(CURDIR)/src/databaseXreferences
XML_PATH = $(MARTS)/xmlTemplates
BIOMARTLWP = $(CURDIR)/src/databaseXreferences

#Proteomes folder
PROTEOMES = $(CURDIR)/proteomes

# Organisms table
ORGANISMSFILE = $(CURDIR)/organism.csv

# Modification types
MODTYPESFILE = $(CURDIR)/modifications.csv

# ptmdbR library (for R)
PTMDBRSRC = $(CURDIR)/src/ptmdbR/src
PTMDBRLIBLOC = $(CURDIR)/src/ptmdbR/
RMIRROR ?= http://cran.uk.r-project.org

# generate some lists based on the species in ORGANISMSFILE
CSVCUT = $(shell grep $(1) $(ORGANISMSFILE) | cut -d"	" -f$(2))
SPECIES = $(shell sed "1d" $(ORGANISMSFILE) | cut -d"	" -f1)
SPECIESDIRS = $(foreach SP,$(SPECIES),$(SP)_dir)
UNIPROTS = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/uniprot.txt)
INPARAS = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/inpara.txt)
IPIS = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/ipi.fasta)
HISTORIES = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/ipi.history)
ENSEMBLS = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/ensembl)
ENSG_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_ensg.xml)
ENSP_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_ensg_ensp.xml)
UNIPROT_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_uniprot_ensp.xml)
INPARANOID_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_inparanoid_ensp.xml)
REFSEQ_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_refseq.xml)

UNIPROT_TARGETS = $(foreach SP,$(SPECIES),uniprot_$(SP))
INPARA_TARGETS = $(foreach SP,$(SPECIES),inpara_$(SP))
IPIFASTA_TARGETS = $(foreach SP,$(SPECIES),ipifasta_$(SP))
IPIHIST_TARGETS = $(foreach SP,$(SPECIES),ipihistory_$(SP))
ENSEMBL_TARGETS = $(foreach SP,$(SPECIES),ensembl_$(SP))
INSERT_TARGETS = $(foreach SP,$(SPECIES),insert_$(SP))
PARSE_TARGETS =  $(foreach SP,$(SPECIES),parse-history_$(SP))

# An XML template used in building XML queries
XMLSTUB = <?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE Query>\n<Query virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "1" count = "" datasetConfigVersion = "0.6" >\n\t<Dataset name = "DATASET" interface = "default" >ATTRIBUTES\n\t</Dataset>\n</Query>


#### Phony targets

.PRECIOUS: $(UNIPROTS) $(INPARAS) $(IPIS) $(HISTORIES) $(ENSEMBLS)
.PHONY: all create-tables R-deps ptmdbR clean organisms modifications proteomes \
xml-queries parse-histories insert-species uniprots inparas ipifastas \
ipihistories ensembls 

all: create-tables organisms

create-tables:
	@printf "Connecting to the database...\n"
	if ! (echo "SELECT * from organism;" | $(MYSQL_CMD) $(DATABASE) >/dev/null 2>&1); then \
		$(MYSQL_CMD) $(DATABASE) <${DATABASE_SCHEMA}; \
	fi

R-deps:
	$(R) --slave -e "library('roxygen2')" >/dev/null 2>&1 || \
		$(R) -e "install.packages(c('roxygen2'), repos=c('$(RMIRROR)'))"
	$(R) --slave -e "library('RMySQL')" >/dev/null 2>&1 || \
		$(R) -e "install.packages(c('RMySQL'), repos=c('$(RMIRROR)'))"
	$(R) --slave -e "library('Biobase')" >/dev/null 2>&1 || \
		$(R) -e "source('http://bioconductor.org/biocLite.R'); biocLite(); biocLite(c('Biobase'))"

ptmdbR: R-deps
	$(R) -q -e "library(roxygen2); roxygenize('$(PTMDBRSRC)')"
	TAR=$(TAR) $(R) CMD INSTALL $(PTMDBRSRC) -l $(PTMDBRLIBLOC)

organisms: modifications xml-queries parse-histories insert-species

proteomes: uniprots inparas ipifastas ipihistories ensembls

uniprots: $(foreach SP,$(SPECIES),uniprot_$(SP))

inparas:  $(foreach SP,$(SPECIES),inpara_$(SP))

ipifastas:  $(foreach SP,$(SPECIES),ipifasta_$(SP))

ipihistories:  $(foreach SP,$(SPECIES),ipihistory_$(SP))

ensembls:  $(foreach SP,$(SPECIES),ensembl_$(SP))

xml-queries: $(ENSG_QUERIES) $(ENSP_QUERIES) $(UNIPROT_QUERIES) $(INPARANOID_QUERIES) $(REFSEQ_QUERIES)

parse-histories: $(foreach SP,$(SPECIES),parse-history_$(SP))

insert-species: create-tables $(foreach SP,$(SPECIES),insert_$(SP))

modifications: create-tables
	if [[ "`echo 'SELECT count(*) FROM modification;' | $(MYSQL_CMD) -N $(DATABASE)`" != \
			"`sed -n '$$=' $(MODTYPESFILE)`" ]]; then \
		printf "Inserting modifications...\n "; \
		$(PERL) $(MARTS)/insertModifications.pl $(DB) $(MODTYPESFILE) || true; \
	fi

clean:
	rm -rvf $(PROTEOMES)

%_dir:
	mkdir -p $(PROTEOMES)/$*

# Some pattern targets for convenience, with a bit of magic to make
# phony targets and pattern targets live together in peace and harmony.

$(UNIPROT_TARGETS): uniprot_%: $(PROTEOMES)/%/uniprot.txt

$(INPARA_TARGETS): inpara_%: $(PROTEOMES)/%/inpara.txt

$(IPIFASTA_TARGETS): ipifasta_%: $(PROTEOMES)/%/ipi.fasta

$(IPIHIST_TARGETS): ipihistory_%: $(PROTEOMES)/%/ipi.history

$(ENSEMBL_TARGETS): ensembl_%: $(PROTEOMES)/%/ensembl

$(PARSE_TARGETS): parse-history_%: $(PROTEOMES)/%/parsed.history

# Insert a species into the database
$(INSERT_TARGETS): insert_%: uniprot_% inpara_% ipifasta_% ipihistory_% ensembl_% parse-history_% xml-queries
	printf "Inserting databases information...\n"
	COMMONNAME=$(call CSVCUT,$*,1); \
	SCINAME="$(call CSVCUT,$*,2)"; \
	TAXID=$(call CSVCUT,$*,3); \
	ENSEMBL_NAME=`echo "$${SCINAME}" | sed 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	if grep -q $${ENSEMBL_NAME} "$(MARTS)/biomart_datasets.txt"; then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	if ! $(PERL) $(MARTS)/checkOrganism.pl $(DB) $$TAXID; then \
		printf "\n\t* Inserting new Organism $$SCINAME\n"; \
		$(PERL) $(MARTS)/insertDatabaseInfo.pl $(DB) "$(PROTEOMES)/$*/ensembl" \
			$${TAXID} "$${SCINAME}" $${COMMONNAME} "$${ENSNAME}" \
			"$(PROTEOMES)/$*/inpara.txt" "$(PROTEOMES)/$*/uniprot.txt" \
			"$(PROTEOMES)/$*/ipi.fasta" "$(PROTEOMES)/$*/parsed.history" \
			$(BIOMARTLWP) $(XML_PATH); \
	else \
		printf "Organism $$SCINAME already exists in the database\n\n"; \
	fi

### File creation targets

# Get the Biomart datasets
$(MARTS)/biomart_datasets.txt:
	printf "Downloading datasets from Biomart...\n "
	$(WGET) -P $(MARTS) \
		'http://www.biomart.org/biomart/martservice?type=datasets&mart=ensembl' \
		-O $@

# Download the uniprot proteome for a species
$(PROTEOMES)/%/uniprot.txt: %_dir
	printf "Downloading $* from uniprot...\n"
	$(WGET) -P $(PROTEOMES)/$* "$(call UNIPROT,$(call CSVCUT,$*,3))" -O $@

# Download the inparanoid proteome for a species
$(PROTEOMES)/%/inpara.txt: %_dir
	printf "Downloading $* from inparanoid ...\n"
	$(WGET) -P $(PROTEOMES)/$* $(INPARAFTP)/$(call CSVCUT,$*,3).fasta -O $@

# Download the IPI proteome for a species
$(PROTEOMES)/%/ipi.fasta: %_dir
	printf "Downloading $* from IPI (fasta)...\n"
	if [[ "$(call CSVCUT,$*,4)" != "NA" ]]; then \
		$(WGET) -P $(PROTEOMES)/$* $(IPIFTP)/$(call CSVCUT,$*,4).fasta.gz -O $@.gz; \
		gunzip $@.gz; \
	fi

# Download the IPI history for a species
$(PROTEOMES)/%/ipi.history: %_dir
	printf "Downloading $* from IPI (history)...\n"
	if [[ "$(call CSVCUT,$*,4)" != "NA" ]]; then \
		$(WGET) -P $(PROTEOMES)/$* $(IPIFTP)/$(call CSVCUT,$*,4).history.gz -O $@.gz; \
		gunzip $@.gz; \
	fi

# Download the Ensembl proteome for a species
$(PROTEOMES)/%/ensembl: %_dir
	printf "Downloading $* from ensembl...\n"
	$(WGET) -P $(PROTEOMES)/$* \
		$(call ENSEMBL_URL,$(call CSVCUT,$*,5),$(call CSVCUT,$*,2),$(call CSVCUT,$*,6),$(call CSVCUT,$*,7)) -O $@.gz
	gunzip $@.gz

$(XML_PATH)/%_ensg.xml: $(MARTS)/biomart_datasets.txt
	printf "Generating Ensembl Gene XML queries...\n"
	mkdir -p $(XML_PATH)
	SCINAME="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f2`"; \
	TAXID="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f3`"; \
	ENSEMBL_NAME=`echo "$${SCINAME}" | sed 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	if grep -q $${ENSEMBL_NAME} "$(MARTS)/biomart_datasets.txt"; then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	ATTRIBUTES="\n\t\t<Filter name = \"biotype\" value = \"protein_coding\"/>\n\t\t<Attribute name = \"ensembl_gene_id\" />\n\t\t<Attribute name = \"external_gene_id\" />\n\t\t<Attribute name = \"description\" />"; \
	printf '$(XMLSTUB)' | m4 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@

$(XML_PATH)/%_ensg_ensp.xml: $(MARTS)/biomart_datasets.txt
	printf "Generating Ensembl peptide XML queries...\n"
	mkdir -p $(XML_PATH)
	SCINAME="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f2`"; \
	TAXID="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f3`"; \
	ENSEMBL_NAME=`echo "$${SCINAME}" | sed 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	if grep -q $${ENSEMBL_NAME} "$(MARTS)/biomart_datasets.txt"; then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	ATTRIBUTES="\n\t\t<Filter name = \"biotype\" value = \"protein_coding\"/>\n\t\t<Attribute name = \"ensembl_gene_id\" />\n\t\t<Attribute name = \"ensembl_peptide_id\" />"; \
	printf '$(XMLSTUB)' | m4 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@

$(XML_PATH)/%_uniprot_ensp.xml: $(MARTS)/biomart_datasets.txt
	printf "Generating Uniprot XML queries...\n"
	mkdir -p $(XML_PATH)
	SCINAME="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f2`"; \
	TAXID="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f3`"; \
	ENSEMBL_NAME=`echo "$${SCINAME}" | sed 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	if grep -q $${ENSEMBL_NAME} "$(MARTS)/biomart_datasets.txt"; then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	ATTRIBUTES="\n\t\t<Attribute name = \"ensembl_peptide_id\"/>\n\t\t<Attribute name = \"uniprot_swissprot_accession\" />\n\t\t<Attribute name = \"uniprot_sptrembl\" />"; \
	printf '$(XMLSTUB)' | m4 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@

$(XML_PATH)/%_inparanoid_ensp.xml: $(MARTS)/biomart_datasets.txt
	printf "Generating Inparanoid XML queries...\n"
	mkdir -p $(XML_PATH)
	SCINAME="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f2`"; \
	TAXID="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f3`"; \
	ENSEMBL_NAME=`echo "$${SCINAME}" | sed 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	if grep -q $${ENSEMBL_NAME} "$(MARTS)/biomart_datasets.txt"; then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	if [[ "$$TAXID" == "6239" ]]; then \
		ATTRIBUTES="\n\t\t<Attribute name = \"ensembl_peptide_id\"/>\n\t\t<Attribute name = \"wormpep_id\" />"; \
		printf '$(XMLSTUB)' | m4 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@; \
	fi

$(XML_PATH)/%_refseq.xml: $(MARTS)/biomart_datasets.txt
	printf "Generating refseq XML queries...\n"
	mkdir -p $(XML_PATH)
	SCINAME="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f2`"; \
	TAXID="`grep $* $(ORGANISMSFILE) | cut -d\"	\" -f3`"; \
	ENSEMBL_NAME=`echo "$${SCINAME}" | sed 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	if grep -q $${ENSEMBL_NAME} "$(MARTS)/biomart_datasets.txt"; then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	ATTRIBUTES="\n\t\t<Attribute name = \"ensembl_peptide_id\"/>\n\t\t<Attribute name = \"refseq_peptide\" />\n\t\t<Attribute name = \"refseq_peptide_predicted\" />"; \
	printf '$(XMLSTUB)' | m4 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@

# Parse the IPI history for a species
$(PROTEOMES)/%/parsed.history: $(PROTEOMES)/%/ipi.history
	printf "Preformatting databases... "
	if [[ "$(call CSVCUT,$*,6)" != "NA" ]]; then \
		$(PERL) $(MARTS)/preformat_IPIhistory.pl $(PROTEOMES)/$*/ipi.fasta \
			$(PROTEOMES)/$*/ipi.history >$@; \
		printf "\n"; \
	else \
		printf "skipped\n"; \
	fi
