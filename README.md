# GFF3sort
A Perl Script to sort gff3 files and produce suitable results for tabix tools

## Usage
```
gff3sort.pl [input GFF3 file] >output.sort.gff3
Optional Parameters:
--precise           Run in precise mode, about 2X~3X slower than the default mode. 
                    Only needed to be used if your original GFF3 files have parent
                    features appearing behind their children features.
                    
--chr_order         Select how the chromosome IDs should be sorted. 
                    Acceptable values are: alphabet, natural, original
                    [Default: alphabet]
                    
--extract_FASTA     If the input GFF3 file contains FASTA sequence at the end, use this
                    option to extract the FASTA sequence and place in a separate file 
                    with the extention '.fasta'. By default, the FASTA sequences would be
                    discarded.
```

## Publication
```
Zhu T, Liang C, Meng Z, Guo S, Zhang R: GFF3sort: A novel tool to sort GFF3 files for tabix indexing. BMC Bioinformatics 2017, 18:482, https://doi.org/10.1186/s12859-017-1930-3
```


## Background
The tabix tool from [htslib](https://github.com/samtools/htslib) requires files sorted by their chromosomes and positions. For GFF3 files, they would be [sorted](http://gmod.org/wiki/JBrowse_FAQ#How_do_I_create_a_Tabix_indexed_GFF) by column 1 (chromosomes) and 4 (start positions) as:
```
sort -k1,1 -k4,4n myfile.gff > myfile.sorted.gff
(OR)
gt gff3 -sortlines -tidy -retainids myfile.gff > myfile.sorted.gff
```
Then, the sorted GFF3 file could be indexed by:
```
bgzip myfile.sorted.gff
tabix -p gff myfile.sorted.gff.gz
```

However, either the GNU sort or the gt tool has a bug: Lines with the same chromosomes and start positions would be placed randomly. Therefore, parent feature lines might sometimes be placed after their children lines. For example, the following features: 
```
##gff-version 3
###
A01	Cufflinks	mRNA	473	6154	.	-	.	ID=XLOC_001154.41;description=Novel: Intergenic transcript
A01	Cufflinks	exon	473	814	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	1626	2574	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	2695	2721	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	3637	3726	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	5329	5408	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	5994	6154	.	-	.	Parent=XLOC_001154.41
###
A01	Cufflinks	mRNA	473	6386	.	-	.	ID=XLOC_001154.42;description=Novel: Intergenic transcript
A01	Cufflinks	exon	473	2024	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	2615	2721	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	3637	3726	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	5329	6386	.	-	.	Parent=XLOC_001154.42
```

would be sorted as:
```
##gff-version 3
##sequence-region   A01 473 6386
A01	Cufflinks	exon	473	814	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	473	2024	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	mRNA	473	6154	.	-	.	ID=XLOC_001154.41;description=Novel: Intergenic transcript
A01	Cufflinks	mRNA	473	6386	.	-	.	ID=XLOC_001154.42;description=Novel: Intergenic transcript
A01	Cufflinks	exon	1626	2574	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	2615	2721	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	2695	2721	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	3637	3726	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	3637	3726	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	5329	5408	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	5329	6386	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	5994	6154	.	-	.	Parent=XLOC_001154.41
###
```

That is, the two `mRNA` lines start with pos `473` would be "randomly" placed after the two `exon` lines which also start with pos `473`. These would encount bugs such as https://github.com/GMOD/jbrowse/issues/780

This script would adjust lines with the same start positions. It would move lines with `"Parent="` attributes (case insensitive) behind lines without `"Parent="` attributes. The result would be:

```
A01	Cufflinks	mRNA	473	6386	.	-	.	ID=XLOC_001154.42;description=Novel: Intergenic transcript
A01	Cufflinks	mRNA	473	6154	.	-	.	ID=XLOC_001154.41;description=Novel: Intergenic transcript
A01	Cufflinks	exon	473	814	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	473	2024	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	1626	2574	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	2615	2721	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	2695	2721	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	3637	3726	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	3637	3726	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	5329	5408	.	-	.	Parent=XLOC_001154.41
A01	Cufflinks	exon	5329	6386	.	-	.	Parent=XLOC_001154.42
A01	Cufflinks	exon	5994	6154	.	-	.	Parent=XLOC_001154.41
```


