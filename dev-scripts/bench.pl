#!/usr/bin/env perl

#
# Brett D. Estrade <estrabd@mailcan.com>
#
# NFA to DFA driver
#
# $Revision: 1.9 $ $Date: 2005/04/13 18:20:00 $ $Author: estrabd $

$^W++;
$|++;

use strict;
use lib '../lib';
use Time::HiRes qw(gettimeofday);
use FLAT::FA::RE;
use FLAT::FA::NFA;
use FLAT::FA::DFA;
use Data::Dumper;

# skirt around deep recursion warning annoyance
local $SIG{__WARN__} = sub { $_[0] =~ /^Deep recursion/ or warn $_[0] };

my $SEED = 'a';
my $re;
my $close = '';

sub init {
  # Seed the random number generator.
  srand $$;
} # end init sub

sub getRandomChar {
  my $ch = '';
  # Get a random character between 0 and 127.
  do {
    $ch = chr(int(rand 255)+1);
  } while ($ch !~ /[a-zA-Z0-9\*|\(]/);  
  if ($ch eq '(') {
    $ch = "|(";
    $close .= ')';
  }
  return $ch;
}

# Call sub init
&init();
  
for (1..64) {
#  print "$SEED\n";
  $re = FLAT::FA::RE->new();
  $re->set_re("$SEED$close");
  my ($s1,$usec1) = gettimeofday();
  my $dfa = $re->to_dfa_BROKEN();
  my $nfa = $re->to_nfa();
#  print $dfa->info(); 
  my ($s2,$usec2) = gettimeofday();
  my $t = $usec2 - $usec1;
  print "$_: $t\n";
  print "$SEED$close\n";
  $SEED .= getRandomChar();  
  print "$SEED$close\n";
}

