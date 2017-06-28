package Sort::Topological;

#########################################################################

=head1 NAME

Sort::Topological - Topological Sort

=head1 SYNOPSIS

  use Sort::Topological qw(toposort);
  my @result = toposort($item_direct_sub, @items);

=head1 DESCRIPTION

Sort::Topological does a topological sort of an acyclical directed graph.

=head1 EXAMPLE

  my %children = (
		  'a' => [ 'b', 'c' ],
		  'c' => [ 'x' ],
		  'b' => [ 'x' ],
		  'x' => [ 'y' ],
		  'y' => [ 'z' ],
		  'z' => [ ],
		  );
  sub children { @{$children{$_[0]} || []}; } 
  my @unsorted = ( 'z', 'a', 'x', 'c', 'b', 'y' );
  my @sorted = toposort(\&children, \@unsorted);


In the above example C<%children> is the graph, C<&children($x)> returns a list of targets of the directed graph from C<$x>.  

C<@sorted> is sorted such that:

=over 4

for any C<$x> in C<@sorted>:

=over 4
C<$x> is not reachable through the directed graph of anything after C<$x> in C<@sorted>.

=back 

i.e.: 'y' is not reachable by 'z', 'x' is not reachable by 'y' or 'z', and so on.

=back
 
=head1 CAVEATS

=over 4

=item *

Does not handle cyclical graphs.

=back

=head1 STATUS

If you find this to be useful please contact the author.  This is alpha software; all APIs, semantics and behavors are subject to change.

=head1 INTERFACE

This section describes the external interface of this module.


=cut


#########################################################################


use strict;
use warnings;

our $VERSION = '0.02';
our $REVISION = do { my @r = (q$Revision: 1.2 $ =~ /\d+/g); sprintf "%d." . "%02d" x $#r, @r };

our $PACKAGE = __PACKAGE__;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw();
our @EXPORT_OK = qw(toposort);
our %EXPORT_TAGS = ( 
		     'all'  => \@EXPORT_OK,
		     );


sub toposort
{
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
	# warn "$x depth = $d";
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


sub deep_deps
{
  my ($deps, @x) = @_;
  
  my @out;
  
  @x = map($deps->($_), @x);
  
  while ( @x ) {
    my $x = shift @x;
    push(@out, $x);
    push(@x, $deps->($x));
  }
  
  @out;
}


sub validate_sorted
{
  my ($dep, @sorted) = @_;
  my $ok = 1;

  my @after = @sorted;
  my @before;
  while ( @after ) {
    my $x = shift @after;
    my @deep_deps = deep_deps($dep, @after);
    # warn " @deep_deps";
    # each $x is not a dep of anything after it.
    if ( grep($_ eq $x, @deep_deps) ) {
      warn "found $x in @deep_deps";
      $ok = 0;
    }
    push(@before, $x);
  }

  $ok
}


sub UNIT_TEST
{
  print STDERR "VERSION = $VERSION, PACKAGE = $PACKAGE\n";
  my %children = (
		  'a' => [ 'b', 'c' ],
		  'b' => [ 'd' ],
		  'c' => [ 'e', 'y' ],
		  'd' => [ 'x' ],
		  'e' => [ 'y', 'z' ],
		  'f' => [ 'z' ],
		  'x' => [ 'y' ],
		  'y' => [ 'z' ],
		  'z' => [ ],
		  );

  my $passes = 20;
  my $verbose = 0;

  for my $pass ( 1 .. $passes ) {
    my @unsorted = ( 'a', 'b', 'c', 'd', 'e', 'f', 'x', 'y', 'z' );
    for my $i ( 0 .. $#unsorted ) {
      my $j = rand($#unsorted);
      ($unsorted[$i], $unsorted[$j]) = ($unsorted[$j], $unsorted[$i]);
    }
    my $children = sub { @{$children{$_[0]} || []} };
    
    $DB::single = 1;
    my @sorted = toposort($children, \@unsorted);
    
    print 'unsorted = ', join(', ', @unsorted), "\n" if $verbose;
    print '  sorted = ', join(', ', @sorted), "\n" if $verbose;
    validate_sorted($children, @sorted);
  }
}


# UNIT_TEST(@ARGV);

#########################################################################

=head1 VERSION

Version 0.01, $Revision: 1.2 $.

=head1 AUTHOR

Kurt A. Stephens <ks.perl@kurtstephens.com>

=head1 COPYRIGHT

Copyright (c) 2001, 2002, Kurt A. Stephens and ION, INC.

=head1 SEE ALSO

>.

=cut

##################################################

1;

### Keep these comments at end of file: kurtstephens@acm.org 2001/12/28 ###
### Local Variables: ###
### mode:perl ###
### perl-indent-level:2 ###
### perl-continued-statement-offset:0 ###
### perl-brace-offset:0 ###
### perl-label-offset:0 ###
### End: ###

