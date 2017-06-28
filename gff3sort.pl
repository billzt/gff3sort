#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;

my $usage = <<"END_USAGE";
Usage: $0 [input GFF3 file] >output.sort.gff3
Optional Parameters:
    --precise       Run in precise mode, about 2X~3X slower than the default mode. 
                    Only needed to be used if your original GFF3 files have parent
                    features appearing behind their children features.
END_USAGE

############ Usage ############
my $help;
my $precise;
GetOptions(
    'help'          =>  \$help,
    'precise'       =>  \$precise,
);
if ($help or @ARGV!=1) {
    print "$usage";
    exit(0);
}

############ Topological Sort function, ####################################
############ Code from https://metacpan.org/pod/Sort::Topological  #########
sub toposort {
    my ($deps, $in) = @_;
    # Assign the depth of traversal.
    my %depth;
    {
        # Assign a base depth of traversal for the input.
        my @stack = reverse map([ $_, 1 ], @$in);

        # While there are still items to traverse,
        while ( @stack ) {
            # Pop the top item and the current traversal depth.
            my $q = pop @stack;
            my $x = $q->[0];
            my $d = $q->[1];

            # Remember current depth.
            if ( (! defined $depth{$x}) || $depth{$x} < $d ) {
                $depth{$x} = $d;
                # warn "$x depth = $d\n";
            }
            # Push the next items along the graph, remembering the depth they were found at.
            if ( 1 ) {
                my @depa = $deps->($x); 
                unshift(@stack, reverse map([ $_, $d + 1 ], @depa));
            }
        }
    }

    # print STDERR 'depth = ', join(', ', %depth), "\n";

    # Create a depth tie-breaker map based on order of appearance of list.
    my %order;
    {
        my $i = 0;
        %order = map(($_, ++ $i), @$in);
    }

    # Sort by depth and input order.
    my @out = sort { 
        $depth{$a} <=> $depth{$b} ||
        $order{$a} <=> $order{$b}
    } @$in;

    # Return array or array ref.
    wantarray ? @out : \@out;
}
############ Topological Sort function End ###############################

############################
# %gff: sort by: chr, start pos, lines in their original order (default mode, very fast)
# OR in Topological order of parent-children relationships (precise mode, a little slower)
############################

my %gff;
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

}

for my $chr (sort keys %gff) {
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
                my ($id) = $note=~/ID=([^;]+)/;         # Using the semicolon as the separator can deal with any IDs even with blanks.
                                                        # Thanks to reviewers' comments
                my ($parent) = $note=~/Parent=([^;]+)/; # Attribute names are case sensitive. "Parent" is not the same as "parent". 
                                                        # See https://github.com/The-Sequence-Ontology/Specifications/blob/master/gff3.md
                                                        # Thanks to reviewers' comments
                ##### Begin to fill the hash %id2line
                if (defined($id)) {
                    $id2line{$id} = $line;
                }
                else {      # These lines has no ID attributes (but possibly have Parent attributes, 
                            # i.e they are the least-level features with no children
                    $id2line{$line} = $line;
                }
                
                ##### Begin to fill the hash %parent2children
                if (defined($parent)) {
                    if (defined($id)) {
                        push @{ $parent2children{$parent} }, $id;
                    }
                    else {  #  These lines has no Parent attributes (but possibly have ID attributes, 
                            #  i.e they are the top-level features with no parents
                        push @{ $parent2children{$parent} }, $line;
                    }
                }
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

