#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;

my $usage = <<"END_USAGE";
Usage: $0 [input GFF3 file] >output.sort.gff3
END_USAGE

my $help;
GetOptions(
    'help'          =>  \$help,
);


if ($help or @ARGV!=1) {
    print "$usage";
    exit(0);
}

############################
# %gff: sort by: chr, start pos, lines without "parent=" attributes (according to their appearance),
# and lines with "parent=" attributes (according to their appearance)
############################

my %gff;
while (<>) {
    chomp;
    next if (/^#/);
    my ($chr, $pos, $note) = (split /\t/, $_)[0,3,-1];
    if ($note =~ /parent=/i) {
        push @{$gff{$chr}{$pos}{"2"}}, $_;
    }
    else {
        push @{$gff{$chr}{$pos}{"1"}}, $_;
    }
}

for my $chr (sort keys %gff) {
    for my $pos (sort {$a<=>$b} keys %{$gff{$chr}}) {
        for my $rank (sort {$a<=>$b} keys %{$gff{$chr}{$pos}}) {
            print join("\n", @{$gff{$chr}{$pos}{$rank}});
            print "\n";
        }
    }
}

