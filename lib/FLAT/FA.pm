# $Revision: 1.2 $ $Date: 2006/02/21 14:43:40 $ $Author: estrabd $

=head1 NAME

FA - A finite automata base class

=head1 SYNOPSIS

    use FA;

=head1 DESCRIPTION

This module is a base finite automata 
used by NFA and DFA to encompass 
common functions.  It is probably of no use
other than to organize the DFA and NFA modules.

B<Methods>

=cut

package FLAT::FA;

use base 'FLAT';
use strict;
use Carp;

use Data::Dumper;

=over 18

=item C<set_start>

Sets start state, calls FA->add_state

=cut

sub set_start {
  my $self = shift;
  my $state = shift;
  chomp($state);
  $self->{_START_STATE} = $state;
  # add to state list if not already there
  $self->add_state($state);
  return;
}

=item C<get_start>

Returns start state name as string

=cut

sub get_start {
  my $self = shift;
  return $self->{_START_STATE};
}

=item C<is_start>

Tests is string is the start state

=cut

sub is_start {
  my $self = shift;
  my $test = shift;
  chomp($test);
  my $ok = 0;
  if ($self->{_START_STATE} eq $test) {$ok++};
  return $ok;
}

=item C<add_state>

Adds a state label to the state array if it does not already exist (handles dups)

=cut

sub add_state {
  my $self = shift;
  foreach my $state (@_) {
    if (!$self->is_state($state)) {
      push(@{$self->{_STATES}},$state);    
    }
  }
  return;
}

=item C<get_states>

Returns the array of all states

=cut

# Returns array of states
sub get_states {
  my $self = shift;
  return @{$self->{_STATES}};  
}

=item C<ensure_unique_states>

Compares the names of the states in $self and the 
provided FA, and only renames a state (in $self)
if a name collision is detected; if the disambiguation
string causes a new collision, a random string is created
using crypt() until there is no collision detected

Usage:
$self->ensure_unique_states($NFA1,'string_to_disambiguate');

=cut

sub ensure_unique_states {
  my $self = shift;
  my $NFA1 = shift;
  my $disambigator = shift;
  chomp($disambigator);
  foreach ($self->get_states()) {
    my $state1 = $_;
    while ($NFA1->is_state($state1) && !$self->is_state($disambigator)) {
      $self->rename_state($state1,$disambigator);
      # re-assign $state1 with new name
      $state1 = $disambigator;
      # get new disambiguator just incase this is not unique
      $disambigator = crypt(rand 8,join('',[rand 8, rand 8]));
    }
  }
  return;
}

=item C<number_states>

Numbers states 0-# of states;  first appends state name with a
random string to avoid conflicts

=cut

sub number_states {
  my $self = shift;
  my $number = 0;
  # generate 5 character string of random numbers
  my $prefix = crypt(rand 8,join('',[rand 8, rand 8]));
  # add random prefix to state names
  foreach ($self->get_states()) {
    $self->rename_state($_,$prefix."_$number");
    $number++;
  }
  # rename states as actual numbers    
  my $number = 0;
  foreach ($self->get_states()) {
    $self->rename_state($_,$number);
    $number++;
  }
  return;  
}

=item C<append_state_names>

Appends state names with the specified suffix

=cut

sub append_state_names {
  my $self = shift;
  my $suffix = shift;
  if (defined($suffix)) {
    chomp($suffix);
  } else {
    $suffix = '';
  }
  foreach ($self->get_states()) {
    $self->rename_state($_,"$_".$suffix);
  }
  return;  
}


=item C<prepend_state_names>

Prepends state names with the specified prefix

=cut

sub prepend_state_names {
  my $self = shift;
  my $prefix = shift;
  if (defined($prefix)) {
    chomp($prefix);
  } else {
    $prefix = '';
  }
  foreach ($self->get_states()) {
    $self->rename_state($_,$prefix."$_");
  }
  return;  
}

=item C<is_state>

Tests if given string is the name of a state

=cut

# Will test if the string passed to it is the same as a label of any state
sub is_state {
  my $self = shift;
  return $self->is_member(shift,$self->get_states());
}

=item C<add_final>

Adds a list of state lables to the final states array; handles dups
and ensures state is in set of states $self->{{STATES}

=cut

# Adds state to final (accepting) state stack
sub add_final {
  my $self = shift;
  foreach my $state (@_) {
    if (!$self->is_final($state)) {
      # ensure state is in set of states - uniqueness enforced!
      $self->add_state($state);
      if (!$self->is_final($state)) {
	push(@{$self->{_FINAL_STATES}},$state);    
      }
    }
  }
  return;
}

=item C<remove_final>

Removes the given state from $self->{_FINAL_STATES}

=cut

sub remove_final {
  my $self = shift;
  my $remove = shift;
  my $i = 0;
  foreach ($self->get_final()) {
    if ($remove eq $_) {
      splice(@{$self->{_FINAL_STATES}},$i);
    }
    $i++;
  }
  return;
}

=item C<get_final>

Returns the array of all final states

=cut

# Returns array of final states
sub get_final {
  my $self = shift;
  return @{$self->{_FINAL_STATES}}
}


=item C<is_final>

Checks to see if given state is in the final state array

=cut

# Will test if the string passed to it is the same as a label of any state
sub is_final {
  my $self = shift;
  return $self->is_member(shift,$self->get_final());
}

=item C<add_symbol>

Adds symbol to the symbol array; handles dups

=cut

# Adds symbol
sub add_symbol {
  my $self = shift;
  foreach my $symbol (@_) {
    if (!$self->is_symbol($symbol)) {
      push(@{$self->{_SYMBOLS}},$symbol);
    }
  }
  return;
}

=item C<is_symbol>

Checks to see if given symbol is in the symbol array

=cut

# Will test if the string passed to it is the same as a label of any symbol
sub is_symbol {
  my $self = shift;
  return $self->is_member(shift,@{$self->{_SYMBOLS}});
}

=item C<get_symbols>

Returns array of all symbols

=cut

# Returns array of all symbols
sub get_symbols {
  my $self = shift;
  return @{$self->{_SYMBOLS}}; 
}

=item C<get_transition>

Returns hash of all transitions (symbols and next states) for given state

=cut

# Returns a hash of all transitions (symbols and next states) for specified state
sub get_transition {
  my $self = shift;
  my $state = shift;
  print Dumper(caller);
  return %{$self->{_TRANSITIONS}{$state}};  
}

=item C<get_all_transitions>

Returns hash of all transitions for all states and symbols

=cut

sub get_all_transitions {
  my $self = shift;
  return %{$self->{_TRANSITIONS}};
}


=item C<has_transition_on>

Tests if given state has a transition on given symbol

=cut

sub has_transition_on {
  my $self = shift;
  my $state = shift;
  my $symbol = shift;
  my $ok = 0;
  if (defined($self->{_TRANSITIONS}{$state}{$symbol})) {
    $ok++;
  }
  return $ok;
}

=item C<has_transitions>

Tests if given state has a transition on given symbol

=cut

sub has_transitions {
  my $self = shift;
  my $state = shift;
  my $ok = 0;
  if (defined($self->{_TRANSITIONS}{$state})) {
    $ok++;
  }
  return $ok;
}


=item C<delete_transition>

Deletes transition given the state and the symbol

=cut

sub delete_transition {
  my $self = shift;
  my $state = shift;
  my $symbol = shift;
  if ($self->is_state($state) && $self->is_symbol($symbol)) {  
    delete($self->{_TRANSITIONS}{$state}{$symbol});
  }
  return;  
}

=item C<to_file>

Dumps FA to file in the proper input file format

=cut

sub to_file {
  my $self = shift;
  my $file = shift;
  chomp($file);
  open(FH,">$file");
  print FH $self->to_string();
  close(FH);
}

=over 18

=item C<compliment>

Returns compliment of 2 arrays - i.e., the items that they
do not have in common; requires arrays be passed by reference;
example:
  my @compliment = $self->compliment(\@set1,\@set2);

=cut

sub  compliment {
  my $self = shift;
  my $set1 = shift;
  my $set2 = shift;
  my @ret = ();
  # convert set1 to a hash
  my %set1hash = map {$_ => 1} @{$set1};
  # iterate of set2 and test if $set1
  foreach (@{$set2}) {
    if (!defined $set1hash{$_}) {
      push(@ret,$_);
    }
  }
  ## Now do the same using $set2
  # convert set2 to a hash
  my %set2hash = map {$_ => 1} @{$set2};
  # iterate of set1 and test if $set1
  foreach (@{$set1}) {
    if (!defined $set2hash{$_}) {
      push(@ret,$_);
    }
  }
  # now @ret contains all items in $set1 not in $set 2 and all
  # items in $set2 not in $set1
  return @ret;  
}

=item C<is_member>

Tests if string is in given array

=cut

# General subroutine used to test if an element is already in an array
sub is_member {
  my $self = shift;
  my $test = shift;
  my $ret = 0;
  if (defined($test)) {
    # This way to test if something is a member is significantly faster..thanks, PM!
    if (grep {$_ eq $test} @_) {
      $ret++;
    }
#    foreach (@_) {
#      if (defined($_)) {
#	if ($test eq $_) {
#	  $ret++;
#	  last;
#	}
#      }
#    }
  }
  return $ret;
}

=item C<DESTROY>

Called automatically when object is no longer needed

=cut

sub DESTROY {
  return;
}

1;

=back

=head1 AUTHOR

Brett D. Estrade - <estrabd AT mailcan DOT com>

=head1 CAVEATS

Currently, all states are stored as labels.  There is also
no integrity checking for consistency among the start, final,
and set of all states.

=head1 BUGS

Not saying it is bug free, just saying I haven't hit any yet :)

=head1 AVAILABILITY

Anonymous CVS Checkout at L<http://www.brettsbsd.net/cgi-bin/viewcvs.cgi/>

=head1 ACKNOWLEDGEMENTS

This suite of modules started off as a homework assignment for a compiler
class I took for my MS in computer science at the University of Southern
Mississippi.  

=head1 COPYRIGHT

This code is released under the same terms as Perl.

=cut
