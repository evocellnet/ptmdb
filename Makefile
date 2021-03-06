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
DBHOST ?= mysql-beltrao-ptmdb
DATABASE ?= ptmdb
DBUSER ?= webAdmin
DBPASS ?= webAdmin
DBPORT ?= 4434

# Programs
MYSQL ?= $(shell which mysql)
R ?= $(shell which R)
RSCRIPT ?= $(shell which Rscript)
PERL ?= $(shell which perl)
TAR ?= $(shell which tar)
WGET ?= $(shell which wget) -q
AWK ?= $(shell which awk)
SED := $(shell { command -v gsed || command -v sed; } 2>/dev/null)

MYSQL_CMD = $(MYSQL) -h$(DBHOST) -u$(DBUSER) -p$(DBPASS) -P$(DBPORT)
DB = $(DBHOST) $(DATABASE) $(DBUSER) $(DBPASS) $(DBPORT)

#Proteomes FTPS
# INPARAFTP ?= http://inparanoid.sbc.su.se/download/8.0_current/sequences/processed
IPIFTP ?= ftp://ftp.ebi.ac.uk/pub/databases/IPI/last_release/current
UNIPROTMAPPINGSFTP ?= ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/idmapping/idmapping.dat.gz
UNIPROT ?= http://www.uniprot.org/uniprot/?query=taxonomy%3a$(1)&force=yes&format=txt
ENSEMBL_URL = $(1)/release-$(4)/fasta/$(shell echo $(2) | $(SED) 's/ /_/g' | $(SED) -e 's/.*/\L&/g')/pep/$(shell echo $(2) | $(SED) 's/ /_/g' | $(SED) -e 's/.*/\L&/g' | $(SED) -e 's/.*/\u&/').$(shell echo $(3) | $(SED) 's/ /_/g').pep.all.fa.gz
ENSEMBL_ASC1_COL_URL = $(1)/release-$(4)/fasta/fungi_ascomycota1_collection/$(shell echo $(2) | $(SED) 's/ /_/g' | $(SED) -e 's/.*/\L&/g')/pep/$(shell echo $(2) | $(SED) 's/ /_/g' | $(SED) -e 's/.*/\L&/g' | $(SED) -e 's/.*/\u&/').$(3).pep.all.fa.gz
ENSEMBL_ASC2_COL_URL = $(1)/release-$(4)/fasta/fungi_ascomycota2_collection/$(shell echo $(2) | $(SED) 's/ /_/g' | $(SED) -e 's/.*/\L&/g')/pep/$(shell echo $(2) | $(SED) 's/ /_/g' | $(SED) -e 's/.*/\L&/g' | $(SED) -e 's/.*/\u&/').$(3).pep.all.fa.gz

# Biomart datasets
MARTS = $(CURDIR)/src/databaseXreferences
BIOMARTDATASETS = $(MARTS)/biomart_datasets.csv
XML_PATH = $(MARTS)/xmlTemplates
BIOMARTLWP = $(CURDIR)/src/databaseXreferences

#Proteomes folder
PROTEOMES = $(CURDIR)/proteomes

# Uniprot mappings
UNIPROTMAPPINGS = $(PROTEOMES)/idmapping.dat

# Organisms table
ORGANISMSFILE = $(CURDIR)/organism.csv

# Modification types
MODTYPESFILE = $(CURDIR)/modifications.csv

# ptmdbR library (for R)
PTMDBRSRC = $(CURDIR)/src/ptmdbR/src
PTMDBRLIBLOC = $(CURDIR)/src/ptmdbR/
RMIRROR ?= http://cran.uk.r-project.org

# generate some lists based on the species in ORGANISMSFILE
CSVCUT = $(shell grep $(1) $(ORGANISMSFILE) | cut -d"," -f$(2))
SPECIES = $(shell $(SED) "1d" $(ORGANISMSFILE) | cut -d"," -f1)
SPECIESDIRS = $(foreach SP,$(SPECIES),$(SP)_dir)
UNIPROTS = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/uniprot.txt)
# INPARAS = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/inpara.txt)
IPIS = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/ipi.fasta)
HISTORIES = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/ipi.history)
ENSEMBLS = $(foreach SP,$(SPECIES),$(PROTEOMES)/$(SP)/ensembl)
ENSG_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_ensg.xml)
ENSP_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_ensg_ensp.xml)
UNIPROT_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_uniprot_ensp.xml)
# INPARANOID_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_inparanoid_ensp.xml)
# REFSEQ_QUERIES = $(foreach SP,$(SPECIES),$(XML_PATH)/$(SP)_refseq.xml)

UNIPROT_TARGETS = $(foreach SP,$(SPECIES),uniprot_$(SP))
# INPARA_TARGETS = $(foreach SP,$(SPECIES),inpara_$(SP))
IPIFASTA_TARGETS = $(foreach SP,$(SPECIES),ipifasta_$(SP))
IPIHIST_TARGETS = $(foreach SP,$(SPECIES),ipihistory_$(SP))
ENSEMBL_TARGETS = $(foreach SP,$(SPECIES),ensembl_$(SP))
INSERT_TARGETS = $(foreach SP,$(SPECIES),insert_$(SP))
PARSE_TARGETS =  $(foreach SP,$(SPECIES),parse-history_$(SP))

# An XML template used in building XML queries
XMLSTUB = <?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE Query>\n<Query virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "ROWS" count = "" datasetConfigVersion = "0.6" >\n\t<Dataset name = "DATASET" interface = "default" >ATTRIBUTES\n\t</Dataset>\n</Query>

TABLES = organism ensg \
ensg_ensp ipi_history ipi ensembl_ipi ensp uniprot_ipi	\
uniprot_isoform uniprot_acc uniprot_entry domain modification

#### Phony targets

.PRECIOUS: $(UNIPROTS) $(IPIS) $(HISTORIES) $(ENSEMBLS)
.PHONY: all tables R-deps ptmdbR clean organisms modifications proteomes \
xml-queries parse-histories insert-species uniprots ipifastas \
ipihistories ensembls 

test:
	echo $(SPECIES)

all: tables organisms

tables:
	@printf "Connecting to the database ${DATABASE}...\n"
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

proteomes: uniprots ipifastas ipihistories ensembls

uniprots: $(foreach SP,$(SPECIES),uniprot_$(SP))

# inparas:  $(foreach SP,$(SPECIES),inpara_$(SP))

ipifastas:  $(foreach SP,$(SPECIES),ipifasta_$(SP))

ipihistories:  $(foreach SP,$(SPECIES),ipihistory_$(SP))

ensembls:  $(foreach SP,$(SPECIES),ensembl_$(SP))

xml-queries: $(ENSG_QUERIES) $(ENSP_QUERIES) $(UNIPROT_QUERIES)

parse-histories: $(foreach SP,$(SPECIES),parse-history_$(SP))

insert-species: tables $(foreach SP,$(SPECIES),insert_$(SP))

modifications: tables
	if [[ "`echo 'SELECT count(*) FROM modification;' | $(MYSQL_CMD) -N $(DATABASE)`" != \
			"`$(SED) -n '$$=' $(MODTYPESFILE)`" ]]; then \
		printf "Inserting modifications...\n "; \
		$(PERL) $(MARTS)/insertModifications.pl $(DB) $(MODTYPESFILE) || true; \
	fi

ifdef NEWDB
OLDDATABASE:=${DATABASE}
DATABASE:=${NEWDB}
updateDB: $(BIOMARTDATASETS) tables organisms
	@printf "Updating database ptm content...\n"
	$(PERL) $(CURDIR)/src/updateDatabase/updater.pl \
		-organismsFile $(ORGANISMSFILE) \
		-martDirectory $(BIOMARTDATASETS) \
		-ptmdbhost $(DBHOST) \
		-ptmdbDB $(OLDDATABASE) \
		-newptmdbDB $(DATABASE) \
		-ptmdbuser $(DBUSER) \
		-ptmdbport $(DBPORT) \
		-ptmdbpass $(DBPASS)
endif

# updateDB: create-tables insert-organisms

# proteomes
# 	@read -p "Enter New Database Name:" NEWDATABASE; \
# 	@printf "Connecting to the database...\n"
# 	if ! (echo "SELECT * from organism;" | $(MYSQL_CMD) $(NEWDATABASE) >/dev/null 2>&1); then \
# 		$(MYSQL_CMD) $(NEWDATABASE) <${DATABASE_SCHEMA}; \
# 	fi

# < 	NEWDB = $(DBHOST) $(NEWDATABASE) $(DBUSER) $(DBPASS) $(DBPORT)

clean: clean-proteomes clean-xml

clean-proteomes:
	rm -rvf $(PROTEOMES)

clean-xml:
	rm $(XML_PATH)/*.xml

clean-tables:
	for table in $(TABLES); do \
		echo "DELETE FROM $$table;" | $(MYSQL_CMD) $(DATABASE); \
	done

%_dir:
	mkdir -p $(PROTEOMES)/$*

# Some pattern targets for convenience, with a bit of magic to make
# phony targets and pattern targets live together in peace and harmony.

$(UNIPROT_TARGETS): uniprot_%: $(PROTEOMES)/%/uniprot.txt

# $(INPARA_TARGETS): inpara_%: $(PROTEOMES)/%/inpara.txt

$(IPIFASTA_TARGETS): ipifasta_%: $(PROTEOMES)/%/ipi.fasta

$(IPIHIST_TARGETS): ipihistory_%: $(PROTEOMES)/%/ipi.history

$(ENSEMBL_TARGETS): ensembl_%: $(PROTEOMES)/%/ensembl

$(PARSE_TARGETS): parse-history_%: $(PROTEOMES)/%/parsed.history

proteome_%: uniprot_%  ipifasta_% ipihistory_% ensembl_% parse-history_%

# Insert a species into the database
$(INSERT_TARGETS): insert_%: uniprot_% ipifasta_% ipihistory_% ensembl_% parse-history_% xml-queries tables
	printf "Inserting databases information for $*...\n"
	COMMONNAME=$(call CSVCUT,$*,1); \
	SCINAME="$(call CSVCUT,$*,2)"; \
	TAXID=$(call CSVCUT,$*,3); \
	ENSEMBL_NAME=`echo "$${SCINAME}" | $(SED) 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	BIOMART_HOST=$(call CSVCUT,$*,9); \
	if grep -q $${ENSEMBL_NAME} $(BIOMARTDATASETS); then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	if ! $(PERL) $(MARTS)/checkOrganism.pl $(DB) $$TAXID; then \
		printf "\n\t* Inserting new Organism $$SCINAME\n"; \
		$(PERL) $(MARTS)/insertDatabaseInfo.pl $(DB) "$(PROTEOMES)/$*/ensembl" \
			$${TAXID} "$${SCINAME}" $${COMMONNAME} "$${ENSNAME}" \
			"$(PROTEOMES)/$*/uniprot.txt" \
			"$(PROTEOMES)/$*/ipi.fasta" "$(PROTEOMES)/$*/parsed.history" \
			$(BIOMARTLWP) $(XML_PATH) "$${BIOMART_HOST}"; \
	else \
		printf "Organism $$SCINAME already exists in the database\n\n"; \
	fi

### File creation targets

# Get the Biomart datasets
$(BIOMARTDATASETS):
	printf "Downloading Biomart datasets...\n";\
	$(RSCRIPT) $(MARTS)/biomartDatasets.R "ensembl_compara_"$(call CSVCUT,"human",7) $@

# Download the uniprot proteome for a species
$(PROTEOMES)/%/uniprot.txt: %_dir
	printf "Downloading $* from uniprot...\n";\
	$(WGET) -P $(PROTEOMES)/$* "$(call UNIPROT,$(call CSVCUT,$*,3))" -O $@

# Download the inparanoid proteome for a species
# $(PROTEOMES)/%/inpara.txt: %_dir
# 	printf "Downloading $* from inparanoid ...\n" ;\
# 	$(WGET) -P $(PROTEOMES)/$* $(INPARAFTP)/$(call CSVCUT,$*,3).fasta -O $@ || \
# 		printf "Inparanoid proteome not available for $*\n"

# Download the IPI proteome for a species
$(PROTEOMES)/%/ipi.fasta: %_dir
	if [[ "$(call CSVCUT,$*,4)" != "NA" ]]; then \
		printf "Downloading $* from IPI (fasta)...\n";\
		$(WGET) -P $(PROTEOMES)/$* $(IPIFTP)/$(call CSVCUT,$*,4).fasta.gz -O $@.gz; \
		gunzip $@.gz; \
	fi

# Download the IPI history for a species
$(PROTEOMES)/%/ipi.history: %_dir
	if [[ "$(call CSVCUT,$*,4)" != "NA" ]]; then \
		printf "Downloading $* from IPI (history)...\n";\
		$(WGET) -P $(PROTEOMES)/$* $(IPIFTP)/$(call CSVCUT,$*,4).history.gz -O $@.gz; \
		gunzip $@.gz; \
	fi

# Download the Ensembl proteome for a species
$(PROTEOMES)/%/ensembl: %_dir
	printf "Downloading $* from ensembl...\n"; \
  case  "$(call CSVCUT,$*,3)" in \
    4956|547828985|226230|237561|284590|284593|294746|322104|559295|559307|1064592) \
      $(WGET) -P $(PROTEOMES)/$* \
        $(call ENSEMBL_ASC1_COL_URL,$(call CSVCUT,$*,5),$(call CSVCUT,$*,2),$(call CSVCUT,$*,6),$(call CSVCUT,$*,7)) -O $@.gz; \
        gunzip $@.gz;; \
    227321) \
      $(WGET) -P $(PROTEOMES)/$* \
        $(call ENSEMBL_ASC2_COL_URL,$(call CSVCUT,$*,5),$(call CSVCUT,$*,2),$(call CSVCUT,$*,6),$(call CSVCUT,$*,7)) -O $@.gz; \
        gunzip $@.gz;; \
    *) \
    $(WGET) -P $(PROTEOMES)/$* \
        $(call ENSEMBL_URL,$(call CSVCUT,$*,5),$(call CSVCUT,$*,2),$(call CSVCUT,$*,6),$(call CSVCUT,$*,7)) -O $@.gz; \
        gunzip $@.gz;; \
  esac

# Parse the IPI history for a species
$(PROTEOMES)/%/parsed.history: $(PROTEOMES)/%/ipi.history
	if [[ "$(call CSVCUT,$*,4)" != "NA" ]]; then \
		printf "Preformatting $* history... "; \
		$(PERL) $(MARTS)/preformat_IPIhistory.pl $(PROTEOMES)/$*/ipi.fasta \
			$(PROTEOMES)/$*/ipi.history >$@; \
		printf "\n"; \
	else \
		printf "skipped\n"; \
	fi

# Generate various XML queries for Biomart.  For now at least, the
# various attributes (<Attribute>, <Filter>, etc) need to be defined
# in a single-line string containing all the necessary newlines and
# tab characters (not strictly necessary, but they make the final
# product look nicer).  Then, the uniqueRows, dataset name and
# attributes are merged into the XMLSTUB via M4.
$(XML_PATH)/%_ensg.xml: $(BIOMARTDATASETS)
	printf "Generating Ensembl Gene XML queries for $*...\n"
	mkdir -p $(XML_PATH)
	SCINAME="$(call CSVCUT,$*,2)"; \
	TAXID=$(call CSVCUT,$*,3); \
	ENSEMBL_NAME=`echo "$${SCINAME}" | $(SED) 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	if grep -q $${ENSEMBL_NAME} $(BIOMARTDATASETS); then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	ATTRIBUTES="\n\t\t<Filter name = \"biotype\" value = \"protein_coding\"/>\n\t\t<Attribute name = \"ensembl_gene_id\" />\n\t\t<Attribute name = \"external_gene_name\" />\n\t\t<Attribute name = \"description\" />"; \
	printf '$(XMLSTUB)' | m4 -DROWS=1 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@

$(XML_PATH)/%_ensg_ensp.xml: $(BIOMARTDATASETS)
	printf "Generating Ensembl peptide XML queries for $*...\n"
	mkdir -p $(XML_PATH)
	SCINAME="$(call CSVCUT,$*,2)"; \
	TAXID=$(call CSVCUT,$*,3); \
	ENSEMBL_NAME=`echo "$${SCINAME}" | $(SED) 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	if grep -q $${ENSEMBL_NAME} $(BIOMARTDATASETS); then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	ATTRIBUTES="\n\t\t<Filter name = \"biotype\" value = \"protein_coding\"/>\n\t\t<Attribute name = \"ensembl_gene_id\" />\n\t\t<Attribute name = \"ensembl_peptide_id\" />"; \
	printf '$(XMLSTUB)' | m4 -DROWS=1 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@

$(XML_PATH)/%_uniprot_ensp.xml: $(BIOMARTDATASETS)
	printf "Generating Uniprot XML queries for $*...\n"
	mkdir -p $(XML_PATH)
	SCINAME="$(call CSVCUT,$*,2)"; \
	TAXID=$(call CSVCUT,$*,3); \
	ENSEMBL_NAME=`echo "$${SCINAME}" | $(SED) 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
	if grep -q $${ENSEMBL_NAME} $(BIOMARTDATASETS); then \
		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
	else \
		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
	fi; \
	ATTRIBUTES="\n\t\t<Attribute name = \"ensembl_peptide_id\"/>\n\t\t<Attribute name = \"uniprot_swissprot\" />\n\t\t<Attribute name = \"uniprot_sptrembl\" />"; \
	printf '$(XMLSTUB)' | m4 -DROWS=1 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@

# $(XML_PATH)/%_inparanoid_ensp.xml: $(BIOMARTDATASETS)
# 	mkdir -p $(XML_PATH)
# 	SCINAME="$(call CSVCUT,$*,2)"; \
# 	TAXID=$(call CSVCUT,$*,3); \
# 	ENSEMBL_NAME=`echo "$${SCINAME}" | $(SED) 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
# 	if grep -q $${ENSEMBL_NAME} $(BIOMARTDATASETS); then \
# 		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
# 	else \
# 		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
# 	fi; \
# 	if [[ "$$TAXID" == "6239" ]]; then \
# 		printf "Generating Inparanoid XML queries for $*...\n"; \
# 		ATTRIBUTES="\n\t\t<Attribute name = \"ensembl_peptide_id\"/>\n\t\t<Attribute name = \"wormpep_id\" />"; \
# 		printf '$(XMLSTUB)' | m4 -DROWS=0 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@; \
# 	fi

# $(XML_PATH)/%_refseq.xml: $(BIOMARTDATASETS)
# 	printf "Generating refseq XML queries for $*...\n"
# 	mkdir -p $(XML_PATH)
# 	SCINAME="$(call CSVCUT,$*,2)"; \
# 	TAXID=$(call CSVCUT,$*,3); \
# 	ENSEMBL_NAME=`echo "$${SCINAME}" | $(SED) 's/\([A-Z]\)[a-z]* \(.*\)/\L\1\2/'`; \
# 	if grep -q $${ENSEMBL_NAME} $(BIOMARTDATASETS); then \
# 		ENSNAME=$${ENSEMBL_NAME}_gene_ensembl; \
# 	else \
# 		ENSNAME=$${ENSEMBL_NAME}_eg_gene; \
# 	fi; \
# 	ATTRIBUTES="\n\t\t<Attribute name = \"ensembl_peptide_id\"/>\n\t\t<Attribute name = \"refseq_peptide\" />\n\t\t<Attribute name = \"refseq_peptide_predicted\" />"; \
# 	printf '$(XMLSTUB)' | m4 -DROWS=1 -DDATASET=$$ENSNAME -DATTRIBUTES="`printf \"$$ATTRIBUTES\"`" - >$@
