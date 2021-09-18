#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'ResultsSystem::Core' ) || print "Bail out!\n";
}

diag( "Testing ResultsSystem::Core $ResultsSystem::Core::VERSION, Perl $], $^X" );
