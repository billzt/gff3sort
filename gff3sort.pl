#!/usr/bin/env perl

use 5.010_001;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;
use FindBin qw($Bin);
use lib "$Bin";
use Sort::Naturally qw/nsort/;    ###### https://metacpan.org/pod/Sort::Naturally
use Sort::Topological qw/toposort/;   ###### https://metacpan.org/pod/Sort::Topological
use Pod::Usage;
no if ($] >= 5.018), 'warnings' => 'experimental';

############ Usage ############
my $help;
my $precise;
my $chr_order = 'alphabet';
my $extract_FASTA;
GetOptions(
    'help'          =>  \$help,
    'precise'       =>  \$precise,
    'chr_order=s'   =>  \$chr_order,
    'extract_FASTA' =>  \$extract_FASTA,
);
if ($help or @ARGV!=1) {
    pod2usage(-verbose => 2);
}
if ($chr_order !~ /(alphabet)|(natural)|(original)/i) {
    die "Unknown option:  --chr_order=$chr_order. Only [alphabet] [natural] [original] are allowed\n";
    exit(0);
}
$chr_order = lc($chr_order);

############################
# %gff: sort by: chr, start pos, lines in their original order (default mode, very fast)
# OR in Topological order of parent-children relationships (precise mode, a little slower)
############################

my %gff; 
my @chromosomes;    # Store the order of chromosomes
my $encounter_FASTA = 0;
my $FASTA_str;
my $input = shift;
open my $in_fh, "<", $input;
while (<$in_fh>) {
    chomp;
    
    # deal with ##FASTA pragma, as tabix does not allow such blocks
    if ($_ eq '##FASTA') {
        $encounter_FASTA = 1;
    }
    
    # If we have not encountered the ##FASTA pragma, collect annotation lines to our hash %gff
    if (!$encounter_FASTA) {
        if ($_ =~ /^#/) {
            if ($_ !~ /[^#]/) { # lines with pure # chars are separators. As GFF3sort 
                                # generates results for tabix indexing instead of human reading, these separators
                                # are not so necessary
                next;
            }
            else {  # lines start with # and contains other non # chars are pragma lines, keep them
                print "$_\n";
                next;
            }
        }
        my ($chr, $pos) = (split /\t/, $_)[0,3];
        push @{$gff{$chr}{$pos}}, $_;
        push @chromosomes, $chr unless ($chr~~@chromosomes);    
    }
    # If we have encountered the ##FASTA pragma, we should stop collect lines 
    # If users have chosen to extract_FASTA,
    # Then extract FASTA here (excluding the ##FASTA pragma it self)
    else {
        if ($extract_FASTA && $_ ne '##FASTA') {
            $FASTA_str .= "$_\n";
        }
    }
}
close $in_fh;

# If the users have chosen to extract_FASTA, and there exisis FASTA sequences in the GFF file, print them
if ($extract_FASTA && $FASTA_str) {
    open my $out_fh, ">", "$input.fasta";
    print {$out_fh} $FASTA_str;
    close $out_fh;
    warn "The inline FASTA sequences were extracted to file $input.fasta\n";
}


###### Define the order of chromosomes based on users' option
if ($chr_order eq 'alphabet') {
    @chromosomes = sort @chromosomes;
}
elsif ($chr_order eq 'natural') {
    @chromosomes = nsort(@chromosomes);
}
else {
    1;  # the original chromosome order is kept
}

###### Begin Sorting

for my $chr (@chromosomes) {
    for my $pos (sort {$a<=>$b} keys %{$gff{$chr}}) {
        my @lines = @{$gff{$chr}{$pos}};
        ###### Only one feature line under this chromosome and position: Do not need to sort
        if (@lines==1) {
            print "$lines[0]\n";
        }
        ###### Precise mode: do Topological Sort
        elsif ($precise) {
            my %parent2children = ();   # This hash is used to do Topological Sort in precise mode
            my %id2line = ();           # This hash maps a ID to its full feature line
            for my $line (@lines) {
                my ($note) = (split /\t/, $line)[-1];
                my ($id) = $note=~/ID=([^;]+)/;             # Using the semicolon as the separator can deal with any IDs even with blanks.
                my ($parents) = $note=~/Parent=([^;]+)/;    # Attribute names are case sensitive. "Parent" is not the same as "parent". 
                
                ##### Begin to fill the hash %id2line
                if (defined($id)) {
                    $id2line{$id} = $line;
                }
                else {      # These lines has no ID attributes (but possibly have Parent attributes, 
                            # i.e they are the least-level features with no children
                    $id2line{$line} = $line;
                }
                ##### Finished filling the hash %id2line
                
                ##### Begin to fill the hash %parent2children
                if (defined($parents)) {
                    my @parents = split /,/,  $parents;     # Parent can have multiple values separated by comma
                    for my $parent (@parents) {
                        if (defined($id)) {
                            push @{ $parent2children{$parent} }, $id;
                        }
                        else {  #  These lines has no ID attributes (but possibly have Parent attributes, 
                                #  i.e they are the least-level features with no children
                            push @{ $parent2children{$parent} }, $line;
                        }
                    }
                }
                ##### Finished filling the hash %parent2children
            }
            my @unsorted_ids = keys %id2line;
            my @sorted_ids = toposort(\&{sub {my $i = shift @_; return @{$parent2children{$i} || []}}}, \@unsorted_ids);
            for my $id (@sorted_ids) {
                print "$id2line{$id}\n";
            }            
        }
        ###### Default mode: keep lines in their original order
        else {  
            print join("\n", @lines), "\n";
        }
    }
}

__END__ 

=head1 NAME

gff3sort.pl - Sort GFF3 file for tabix indexing

=head1 SYNOPSIS

gff3sort.pl [OPTIONS] input.file.gff3 >output.sort.gff3

=head1 COMMAND-LINE OPTIONS

These optional options could be placed either before or after the I/O files in the
commandline

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

=head1 DESCRIPTION

The tabix tool requires GFF3 files to be sorted by chromosomes and positions, which could be 
performed in the GNU sort program or the GenomeTools package. However, when dealing with feature 
lines in the same chromosome and position, both of the tools would sort them in an ambiguous 
way that usually results in parent features being placed behind their children. This would cause erroneous 
in some genome browsers such as JBrowse. GFF3sort can properly deal with the order of features 
that have the same chromosome and start position, therefore generating suitable results for JBrowse display.

=head2 Precise mode

In most situations, the original GFF3 annotations produced by genome annotation projects have already placed 
parent features before their children. Therefore, GFF3sort would remember their original order and placed them accordingly
within the same chromosome and start position block, which is the default behavior.

Sometimes the order in the input file has already been disturbed (for example, by GNU sort or GenomeTools).
In this situation, GFF3sort would sort them according to the parent-child topology using the sorting algorithm of 
directed acyclic graph (https://metacpan.org/pod/Sort::Topological), which is the most precise behavior but 2X~3X 
slower than the default mode.

=head2 The chromosome order

In default, chromosomes are sorted alphabetly. Users can choose to sort naturally (see https://metacpan.org/pod/Sort::Naturally)
or keep their original orders.

Therefore, chromosomes "Chr7 Chr1 Chr10 Chr2 Chr1" would be sorted as:

By alphabet (default):  Chr1 Chr10 Chr2 Chr7

By natural:             Chr1 Chr2 Chr7 Chr10

Kepp original:          Chr7 Chr1 Chr10 Chr2 (Note: tabix requires continuous chromosome blocks. Therefore the same chromosomes 
                                              such as Chr1 must be grouped together)

=head1 AUTHOR

Tao Zhu E<lt>zhutao@caas.cnE<gt>

Copyright (c) 2017

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
