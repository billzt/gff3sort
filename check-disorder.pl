#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Fatal qw/open close chdir/;
use Getopt::Long;

my $usage = <<"END_USAGE";
usage: $0 [input GFF3 file]
Optional Parameters:
    --list       list all IDs that have children features appearing in front of themselves
END_USAGE

############ Usage ############
my $help;
my $list;
GetOptions(
    'help'       =>  \$help,
    'list'       =>  \$list,
);
if ($help or @ARGV!=1) {
    print "$usage";
    exit(0);
}

my %line_rank;
my %is_error_parent;
my %all_parent;
while (<>) {
    chomp;
    next if (/^#/);
    my $line_rank = $.;
    my ($chr, $pos, $note) = (split /\t/, $_)[0,3,-1];
    my ($id) = $note=~/ID=([^;]+);/;
    my ($parent) = $note=~/Parent=([^;]+);/;
    if ($id && !$line_rank{$id}) {
        $line_rank{$id} = $line_rank;
    }
    if ($parent) {
        $all_parent{$parent} = 1;
    }
    if ($parent && !$line_rank{$parent}) {
        $is_error_parent{$parent} = 1;
    }
}

if ($list) {
    for my $id (keys %is_error_parent) {
        print "$id\n";
    }
}

my $all_num = keys %all_parent;
my $error_num = keys %is_error_parent;

print "Number of all parent features: $all_num\nNumber of disordered parent features: $error_num\n";
