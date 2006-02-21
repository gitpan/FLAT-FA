# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl FLAT-FA.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use lib qw(../lib);
use Test::More tests => 6;
BEGIN { use_ok('FLAT::FA') };
BEGIN { use_ok('FLAT::FA::DFA') };
BEGIN { use_ok('FLAT::FA::NFA') };
BEGIN { use_ok('FLAT::FA::PFA') };
BEGIN { use_ok('FLAT::FA::RE') };
BEGIN { use_ok('FLAT::FA::PRE') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

