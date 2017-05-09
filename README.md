# gff3sort
A Perl Script to sort gff3 files and produce suitable results for tabix tools

## Usage
```
gff3sort.pl --input=[input GFF3 file] >output.sort.gff3
```

## Background
The tabix tool from [htslib](https://github.com/samtools/htslib) requires files sorted by their chromosomes and positions. For GFF3 files, they would be [sorted](http://gmod.org/wiki/JBrowse_FAQ#How_do_I_create_a_Tabix_indexed_GFF) by column 1 (chromosomes) and 4 (start positions) as:
```
sort -k1,1 -k4,4n myfile.gff > myfile.sorted.gff
(OR)
gt gff3 -sortlines -tidy myfile.gff > myfile.sorted.gff
```
Then, the sorted GFF3 file could be indexed by:
```
bgzip myfile.sorted.gff
tabix -p gff myfile.sorted.gff.gz
```

However, either the GNU sort or the gt tool has a bug: Lines with the same chromosomes and start positions would be placed randomly. Therefore, parent feature lines might sometimes be placed after their children lines. For example

