#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;
use FindBin qw($Bin);
use lib "$Bin";
use Sort::Naturally qw/nsort/;    ###### https://metacpan.org/pod/Sort::Naturally
use Sort::Topological qw/toposort/;   ###### https://metacpan.org/pod/Sort::Topological

my $usage = <<"END_USAGE";
Usage: $0 [input GFF3 file] >output.sort.gff3
Optional Parameters:
    --precise       Run in precise mode, about 2X~3X slower than the default mode. 
                    Only needed to be used if your original GFF3 files have parent
                    features appearing behind their children features.
    --chr_order [alphabet|natural|original]
END_USAGE

############ Usage ############
my $help;
my $precise;
my $chr_order = 'alphabet';
GetOptions(
    'help'          =>  \$help,
    'precise'       =>  \$precise,
    'chr_order=s'   =>  \$chr_order
);
if ($help or @ARGV!=1) {
    print "$usage";
    exit(0);
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
while (<>) {
    chomp;
    if ($_ =~ /^#/) {
        if ($_ !~ /[^#]/) {
            next;
        }
        else {
            print "$_\n";
            next;
        }
    }
    my ($chr, $pos) = (split /\t/, $_)[0,3];
    push @{$gff{$chr}{$pos}}, $_;
    push @chromosomes, $chr unless ($chr~~@chromosomes);
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

