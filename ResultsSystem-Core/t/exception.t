use strict;
use warnings;

use Test::More;
use Test::Exception;

use_ok('ResultsSystem::Core::Exception');

my $e;
ok( $e = ResultsSystem::Core::Exception->new( 'TEST', 'Something bad happened' ),
  "Created an exception" );
isa_ok( $e, 'ResultsSystem::Core::Exception' );

dies_ok( sub { die $e; }, "Died" );
my $err = $@;

isa_ok( $err, 'ResultsSystem::Core::Exception', 'Exception object thrown by die' )
  || diag( ref($err) );

like( $err, qr/TEST,Something bad happened/, 'Stringified object is correct' );

like(
  $err,
  qr/^ResultsSystem::Core::Exception,TEST,Something bad happened,main,t\/exception.t,10$/,
  'Stringified object has additional data appended'
);

like( $err, qr/ResultsSystem::Core::Exception/, 'Stringified error does contain object type' );

subtest 'Recursion' => sub {

  dies_ok(
    sub {
      eval { die ResultsSystem::Core::Exception->new( 'A', 'Message A' ); }
        || do { my $err = $@; die ResultsSystem::Core::Exception->new( 'B', 'Message B', $err ); }
    },
    "Exception thrown"
  );
  my $error = $@;

  isa_ok( $error, 'ResultsSystem::Core::Exception' );

  like($error, qr/^ResultsSystem::Core::Exception,B,Message B,main,t\/exception\.t,35,ResultsSystem::Core::Exception,A,Message A,main,t\/exception\.t,34\n$/, 'Recursion is correct');
};
done_testing;
