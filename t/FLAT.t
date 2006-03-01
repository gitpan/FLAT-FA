# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl FLAT-FA.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 16;
use lib qw(../lib);
BEGIN { use_ok('FLAT::FA') };
BEGIN { use_ok('FLAT::FA::DFA') };
BEGIN { use_ok('FLAT::FA::NFA') };
BEGIN { use_ok('FLAT::FA::PFA') };
BEGIN { use_ok('FLAT::FA::RE') };
BEGIN { use_ok('FLAT::FA::PRE') };

isa_ok(FLAT::FA::DFA->new(),'FLAT::FA::DFA');
isa_ok(FLAT::FA::NFA->new(),'FLAT::FA::NFA');
isa_ok(FLAT::FA::PFA->new(),'FLAT::FA::PFA');
isa_ok(FLAT::FA::RE->new(),'FLAT::FA::RE');
isa_ok(FLAT::FA::PRE->new(),'FLAT::FA::PRE');

my $pre = FLAT::FA::PRE->new();
$pre->set_pre("010|10&01");
my $pfa = $pre->to_pfa();
isa_ok($pfa,'FLAT::FA::PFA');
my $nfa = $pfa->to_nfa();
isa_ok($nfa,'FLAT::FA::NFA');
my $dfa = $nfa->to_dfa();
isa_ok($dfa,'FLAT::FA::DFA');
my @removed = $dfa->minimize();
isa_ok($dfa,'FLAT::FA::DFA');
ok(($#removed+1) >= 0,'FLAT::FA::DFA->minimize() returns int >= 0');
