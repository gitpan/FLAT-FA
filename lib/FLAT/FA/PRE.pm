# $Revision: 1.2 $ $Date: 2006/02/21 14:43:40 $ $Author: estrabd $

=head1 NAME

PRE - A regular expression base class

=head1 SYNOPSIS

    use PRE;

=head1 DESCRIPTION

This module implements a parallel regular expression
parser, and supports the conversion of a PRE to
a parallel finite automata.  A homegrown recursive
descent parser is used to build the parse tree, and the method
used to convert the parallel regular expression to a PFA is a
modified Thompson's construction that accounts for the additional
interleave operator (&).

Recursive Descent-safe Regex Grammar:

 R  -> P
 
 P  -> OP'
 
 P  -> '&' OP' | epsilon

 O  -> CO'

 O' -> '|' CO' | epsilon

 C  -> SC'

 C' -> .SC' | epsilon

 S  -> LS'

 S' -> *S' | epsilon

 L  -> a | b | c |..| 0 | 1 | 2 |..| (R) | epsilon

 Terminal symbols: a,b,c,..,z,0,1,2,..,9,|,*,(,)

 NOTE: Concatenation operator, '.', is not a terminal symbol
 and should not be included in the regex

 FAQ:
   Q: Does this support Perl regular expressions?
   A: No, just the regular expression using the terminal symbols
      listed above.

B<Valid terminal characters include:>

I<a b c d e f g h i j k l m n o p q r s t u v w x y z>

I<A B C D E F G H I J K L M N O P Q R S T U V W X Y Z>

I<0 1 2 3 4 5 6 7 8 9 + - = , ? [ ] { } . ~ ^ @ % $>

I<: ; < >>

B<Methods>

=cut

package FLAT::FA::PRE;

use base 'FLAT::FA';
use strict;
use Carp;

use FLAT::FA::PFA;
use Data::Dumper;

=over 1 

=item C<new>

Create a brand spaking new pRE object; does not accept regex here

=cut

sub new {
  my $class = shift;
  bless {
    _CAT_STATE => 0,
    _CURRENT_STR => [],
    _DONE => 0,
    _EPSILON => 'epsilon',
    _ERROR => 0,
    _FOLLOW_POS => {},
    _LOOKAHEAD => '',
    _OR_STATE => 0,
    _PARSE_TREE => undef,
    _POS_COUNT => 0,
    _PRE_END_SYMBOL => '#',
    _PRE => '',
    _SYMBOL_POS  => [],
    _TERMINALS => [qw(a b c d e f g h i j k l m n o p q r s t u v w x y z 
                      A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 
		      0 1 2 3 4 5 6 7 8 9 + - = , ? [ ] { } . ~ ^ @ % $ : 
		      ; < >)],
    _TRACE => 0,
    _SYMBOLS => [],
  }, $class;
}

=item C<set_epsilon>

Not really for public consumption, but could be in the future.  Defines
how epsilon (i.e., the null string) is represented in the parse tree.

=cut

sub set_epsilon {
  my $self = shift;
  my $e = shift;
  chomp($e);
  $self->{_EPSILON} = $e;
  return;
}

=item C<get_epsilon_symbol>

Returns the string representation of the null string

=cut

sub get_epsilon_symbol {
  my $self = shift;
  return $self->{_EPSILON};
}


=item C<set_pre>

Defines a regular expression for RE to parse through

=cut

sub set_pre {
  my $self = shift;
  my $pre = shift;
  chomp($pre);
  # reset stuff
  $self->{_CAT_STATE} = 0;
  $self->{_CURRENT_STR} = [];
  $self->{_DONE} = 0;
  $self->{_ERROR} = 0;
  $self->{_FOLLOW_POS} = {};
  $self->{_LOOKAHEAD} = '';
  $self->{_OR_STATE} = 0;
  $self->{_PARSE_TREE} = undef;
  $self->{_POS_COUNT} = 0;
  $self->{_SYMBOL_POS}  = [];
  $self->{_TRACE} = 0;
  $self->{_SYMBOLS} = [];
  $self->{_PRE} = $pre;
  # load up current string stack
  $self->set_current($pre);
  my @re = split(//,$pre);
  # load up symbol position stack, and store unique terminal symbols encountered
  foreach (@re) {
    if ($self->is_terminal($_)) {
      push(@{$self->{_SYMBOL_POS}},$_);
      if (!$self->is_member($_,@{$self->{_SYMBOLS}})) {
        push(@{$self->{_SYMBOLS}},$_);
      }
    }
  }
  push(@{$self->{_SYMBOL_POS}},$self->{_PRE_END_SYMBOL});
  return;
}


=item C<get_pre>

Returns the regular expression set by C<set_pre> as a string

=cut

sub get_pre {
  my $self = shift;
  return $self->{_PRE};
}

=item C<set_current>

Meant for private consumption.  Initializes the stack used to store
what part of the regex has yet to be parsed

=cut

sub set_current {
  my $self = shift;
  my $pre = shift;
  chomp($pre);
  @{$self->{_CURRENT_STR}} = split(//,$pre);
  return;
}

=item C<reset_current>

Meant for private consumption.  Initializes the stack used to store
what part of the regex has yet to be parsed

=cut

sub reset_current {
  my $self = shift;
  @{$self->{_CURRENT_STR}} = split(//,$self->get_pre());
  return;
}

=item C<get_current>

Returns what is in the _CURRENT_STR stack

=cut

sub get_current {
  my $self = shift;
  return $self->{_CURRENT_STR};
}

=item C<to_pfa>

Not implemented, but will create an PFA using Thompson's Method; from there
one could do a PFA->to_dfa, and compare the resulting dfa to the one from 
RE->to_dfa.

=cut

sub to_pfa {
  my $self = shift;
  # parse re if _PARSE_TREE is not defined
  if (!defined($self->{_PARSE_TREE})) {
    $self->parse();
  } 
  # sync PFA's epsilon symbol with RE's
  my $PFA = $self->thompson($self->get_parse_tree());
  # find and store tied nodes
  $PFA->find_tied();
  return $PFA;
}

=item C<thompson>

Guts of RE->to_pfa; uses depth first parse tree traversal

=cut

sub thompson {
  my $self = shift;
  my $tree = shift;
  my $PFA_l = undef;
  my $PFA_r = undef;
  if ($tree->{symbol} ne $self->{_PRE_END_SYMBOL}) {
    # dive into tree recursively_RE_END_SYMBOL
    # go left
    if (defined($tree->{left}) ) {
      $PFA_l = $self->thompson($tree->{left});
    }
    # go right
    if (defined($tree->{right})) {
      $PFA_r = $self->thompson($tree->{right});
    }
    # kleene - terminal always returned from left
    if (defined($PFA_l) && $tree->{symbol} eq '*') {
      $PFA_l->kleene();
    }
    # Checks to see if current node is a leaf or not
    if (defined($tree->{pos})) {
      # create a minimal PFA with 1 symbol, 
      $PFA_l = FLAT::FA::PFA->jump_start($tree->{symbol});
    } elsif(defined($PFA_l) && defined($PFA_r)) {
      # ORs, Interleaves (ANDs) and CATs
      if ($tree->{symbol} eq '|') {      # or
	$PFA_l->or_pfa($PFA_r);
      } elsif ($tree->{symbol} eq '&') { # interleave (and)
	$PFA_l->interleave_pfa($PFA_r);
      } elsif ($tree->{symbol} eq '.') { # cat
	$PFA_l->append_pfa($PFA_r);
      }
    }
  }
  return $PFA_l;
}

################################################################
# Recursive Descent routines - parse tree is constructed here  # 
################################################################

=item C<parse>

Parses regular expressin set by RE->set_pre, and stores the parse tree in _PARSE_TREE

=cut

sub parse {
  my $self = shift;
  # load up first lookahead char
  $self->nexttoken();
  # PARSE
  $self->set_parse_tree($self->R());
  $self->cat_endmarker();
  $self->reset_current();
  return;
}

=item C<cat_endmarker>

Adds '#', or the end of regex marker to the parse tree; not for public consumption

=cut

sub cat_endmarker {
  my $self = shift;
  $self->{_PARSE_TREE} = {symbol=>'.',left=>$self->{_PARSE_TREE},right=>{symbol=>$self->{_PRE_END_SYMBOL},pos=>$self->get_next_pos()}};
  return; 
}

=item C<match>

Matches current terminal symbol with terminal character,
and loads up the next lookahead character

=cut

sub match {
  my $self = shift;
  my $match = shift;
  chomp($match);
  if ($self->{_TRACE}) {print "match!: '$match'\n"};
  if ($self->lookahead() eq $match) {
    $self->nexttoken();
  } else {
    $self->set_error();
    $self->set_done();
  }
  # returns the symbol passed to it.
  return $match;
}

=item C<lookahead>

Returns value of current lookahead

=cut

sub lookahead {
  my $self = shift;
  return $self->{_LOOKAHEAD};
}

=item C<nexttoken>

Sets next token as lookahead

=cut

sub nexttoken {
  my $self = shift;
  $self->{_LOOKAHEAD} = '';
  if (@{$self->{_CURRENT_STR}}) {
    $self->{_LOOKAHEAD} = shift(@{$self->{_CURRENT_STR}});
  }
  return;
}

=item C<R>

R  -> O

=cut

sub R {
  my $self = shift;
  my $tree = undef;
  if ($self->{_TRACE}) {print ">R "};
  if (!$self->done()) {
    $tree = $self->P();
  }
  if ($self->{_TRACE}) {print "R> "};
  return $tree;
}

=item C<P>

P  -> OP'

=cut

sub P {
  my $self = shift;
  my $tree = shift;
  if ($self->{_TRACE}) {print ">P "};  
  if (!$self->done()) {
    $tree = $self->O();
    $tree = $self->P_prime($tree);
  }
  if ($self->{_TRACE}) {print "P> "};  
  return $tree;
}

=item C<P_prime>

P' -> '&'O | epsilon

=cut

sub P_prime {
  my $self = shift;
  my $tree = shift;
  if ($self->{_TRACE}) {print ">P' "};  
  # first rule that contains a terminal symbol
  my $look = $self->lookahead();
  if (!$self->done()) {
    if ($look eq '&') {
      $self->match('&');
      # handles epsilon "and"
      if (!defined($tree)) {
        $tree = {symbol=>$self->get_epsilon_symbol(),pos=>-1};
      }
      my $O = $self->O();
      if (defined($O)) {
        $tree = {symbol=>'&',left=>$tree,right=>$O};
      } else {
	$tree = {symbol=>'&',left=>$tree,right=>{symbol=>$self->get_epsilon_symbol(),pos=>-1}};
      }
      $tree = $self->P_prime($tree);
    }
  }
  if ($self->{_TRACE}) {print "P'> "};
  return $tree;
}

=item C<O>

O  -> CO'

=cut

sub O {
  my $self = shift;
  my $tree = shift;
  if ($self->{_TRACE}) {print ">O "};  
  if (!$self->done()) {
    $tree = $self->C();
    $tree = $self->O_prime($tree);
  }
  if ($self->{_TRACE}) {print "O> "};  
  return $tree;
}

=item C<O_prime>

O' -> '|'CO' | epsilon

=cut

sub O_prime {
  my $self = shift;
  my $tree = shift;
  if ($self->{_TRACE}) {print ">O' "};  
  # first rule that contains a terminal symbol
  my $look = $self->lookahead();
  if (!$self->done()) {
    if ($look eq '|') {
      $self->match('|');
      # handles epsilon "or"
      if (!defined($tree)) {
        $tree = {symbol=>$self->get_epsilon_symbol(),pos=>-1};
      }
      my $C = $self->C();
      if (defined($C)) {
        $tree = {symbol=>'|',left=>$tree,right=>$C};
      } else {
	$tree = {symbol=>'|',left=>$tree,right=>{symbol=>$self->get_epsilon_symbol(),pos=>-1}};
      }
      $tree = $self->O_prime($tree);
    }
  }
  if ($self->{_TRACE}) {print "O'> "};
  return $tree;
}

=item C<C>

C  -> SC'

=cut

sub C {
  my $self = shift;
  my $tree = shift;
  if ($self->{_TRACE}) {print ">C "};
  if (!$self->done()) {   
    $tree = $self->S();
    $tree = $self->C_prime($tree);
  }
  if ($self->{_TRACE}) {print "C> "};
  return $tree;
}

=item C<C_prime>

C' -> .SC' | epsilon

=cut

sub C_prime {
  my $self = shift;
  my $tree = shift;
  if ($self->{_TRACE}) {print ">C' "};
  my $look = $self->lookahead();
  if (!$self->done()) {
    if ($self->get_cat_state() == 1) {
      $self->toggle_cat_state();
      my $S = $self->S();
      if (defined($tree)) {
	if (defined($S)) {
          $tree = {symbol=>'.',left=>$tree,right=>$S};
	}
      } else {
	if (defined($S)) {
          $tree = $S;
	}
      }
      $tree = $self->C_prime($tree);      
    }
  }
  if ($self->{_TRACE}) {print "C'> "};
  return $tree;
}

=item C<S>

S  -> LS'

=cut

sub S {
  my $self = shift;
  my $tree = shift;
  if ($self->{_TRACE}) {print ">S "};  
  if (!$self->done()) {
    $tree = $self->L($tree);
    $tree = $self->S_prime($tree);
  }
  if ($self->{_TRACE}) {print "S> "};  
  return $tree;
}

=item C<S_prime>

S' -> *S' | epsilon

=cut

sub S_prime {
  my $self = shift;
  my $tree = shift;
  if ($self->{_TRACE}) {print ">S' "};  
  my $look = $self->lookahead();
  if (!$self->done()) {
    if ($look eq '*') {
      $self->match('*');
      $tree = {symbol=>'*',left=>$self->S_prime($tree),right=>undef};
    }
  }
  if ($self->{_TRACE}) {print "S'> "};  
  return $tree;
}

=item C<L>

L  -> a | b | c |..| 0 | 1 | 2 |..| (R)

=cut

sub L {
  my $self = shift;
  my $tree = shift;
  if ($self->{_TRACE}) {print ">L "};  
  my $term = $self->lookahead();
  if (!$self->done()) {
    if ($term eq '(') {
      $self->match('(');      
      $tree = $self->R();
      $self->match(')');
      if (!defined($tree)) {
        $tree = {symbol=>$self->get_epsilon_symbol(),pos=>-1};
      }
      $self->toggle_cat_state();      
    } else {
      foreach my $terminal ($self->get_terminals()) {
        if ($term eq $terminal) {
          $self->match($term);
	  #set position automatically
	  $tree = {symbol=>$term,pos=>$self->get_next_pos()};
          $self->toggle_cat_state();
	  last;
        }
      }
    }
  }
  if ($self->{_TRACE}) {print "L> "};  
  return $tree;
}

=item C<get_next_pos>

Returns the next position, used in creating leaf nodes for terminal symbols (minus null string)

=cut

sub get_next_pos {
  my $self = shift;
  return ++$self->{_POS_COUNT};
}

=item C<get_curr_pos>

Returns the current count of terminal symbols (minus null string)

=cut

sub get_curr_pos {
  my $self = shift;
  return $self->{_POS_COUNT};
}

=item C<set_parse_tree>

Set parse tree

=cut

sub set_parse_tree {
  my $self = shift;
  $self->{_PARSE_TREE} = shift;
  return;
}

=item C<get_parse_tree>

Return parse tree

=cut

sub get_parse_tree {
  my $self = shift;
  return $self->{_PARSE_TREE};
}

=item C<get_terminals>

Returns array of terminal symbols

=cut

sub get_terminals {
  my $self = shift;
  return @{$self->{_TERMINALS}};
}

=item C<is_terminal>

Checks to see if given character is a terminal symbol

=cut

sub is_terminal {
  my $self = shift;
  return $self->is_member(shift,$self->get_terminals());
}

=item C<is_member>

General subroutine used to test if an element is already in an array

=cut

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

=item C<get_symbols>

Returns array of all symbols used in current regex

=cut

sub get_symbols {
  my $self = shift;
  return @{$self->{_SYMBOLS}}; 
}

=item C<trace_on>

Turns on tracing - allows to trace the recursive descent parsing

=cut

sub trace_on {
  my $self = shift;
  $self->{_TRACE} = 1;
  return;
}

=item C<trace_off>

Turns tracing off 

=cut

sub trace_off {
  my $self = shift;
  $self->{_TRACE} = 0;
  return;
}

=item C<trace>

Returns value of _TRACE

=cut

sub trace {
  my $self = shift;
  return $self->{_TRACE};
}

=item C<toggle_cat_state>

Toggles cat state instead of cat'ing a '.' to everything

=cut

sub toggle_cat_state {
  my $self = shift;
  if ($self->get_cat_state == 0) {$self->{_CAT_STATE}++} else {$self->{_CAT_STATE} = 0}; 
  return;
}

=item C<get_cat_state>

Returns $self->{_CAT_STATE} (1|0)

=cut

sub get_cat_state {
  my $self = shift;
  return $self->{_CAT_STATE}; 
}

=item C<set_error>

Increments error count for regex parsing

=cut

sub set_error {
  my $self = shift;
  $self->{_ERROR}++;
}

=item C<get_error>

Returns error count

=cut

sub get_error {
  my $self = shift;
  return $self->{_ERROR};
}

=item C<set_done>

Sets done flag

=cut

sub set_done {
  my $self = shift;
  $self->{_DONE}++;
} 

=item C<done>

Returns if done or not

=cut

sub done {
  my $self = shift;
  return $self->{_DONE};
}

=item C<DESTROY>

Called automatically when object is destroyed either explicitly
or automatically when references go to 0 or when the main program
is finished

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
