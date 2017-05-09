#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;

my $usage = <<"END_USAGE";
Usage: $0 --input=[input GFF3 file] >output.sort.gff3
Required Parameters:
    --input    The GFF3 file to be sorted
END_USAGE

my $help;
my $input;
GetOptions(
    'help'          =>  \$help,
    'input=s'       =>  \$input,
);


if ($help or !$input) {
    print "$usage";
    exit(0);
}

############################
# %gff: sort by: chr, start pos, lines without "parent=" attributes and lines with "parent=" attributes
############################

my %gff;
open my $fh, "<", $input;
while (<$fh>) {
    chomp;
    next if (/^#/);
    my ($chr, $pos, $note) = (split /\t/, $_)[0,3,-1];
    if ($note =~ /parent=/i) {
        $gff{$chr}{$pos}{"2"}{$_} = 1;
    }
    else {
        $gff{$chr}{$pos}{"1"}{$_} = 1;
    }
}
close $fh;

for my $chr (sort keys %gff) {
    for my $pos (sort {$a<=>$b} keys %{$gff{$chr}}) {
        for my $rank (sort {$a<=>$b} keys %{$gff{$chr}{$pos}}) {
            print join("\n", keys %{$gff{$chr}{$pos}{$rank}});
            print "\n";
        }
    }
}

