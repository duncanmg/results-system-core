package ResultsSystem::Core::Model;

use strict;
use warnings;
use Params::Validate qw/:all/;

our $VERSION = 0.01;

=head1 NAME

ResultsSystem::Core::Model

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

Base class the the models.

=cut

=head1 INHERITS FROM

None

=cut

=head1 EXTERNAL (PUBLIC) METHODS

=cut

=head2 new

=cut

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
  return $self;
}

=head2 logger

=cut

sub logger {
  my $self = shift;
  return $self->{logger};
}

=head2 set_logger

=cut

sub set_logger {
  my $self = shift;
  $self->{logger} = shift;
  return $self;
}

=head2 get_configuration

=cut

sub get_configuration {
  my $self = shift;
  return $self->{configuration};
}

=head2 set_configuration

=cut

sub set_configuration {
  my $self = shift;
  $self->{configuration} = shift;
  return $self;
}

=head2 set_arguments

Helper method to set the constructor arguments of the child classes.

$self->set_arguments( $map, $args );

In the above example it will look for -logger in the $args hash ref and call set_logger
with the vaule of $args->{-logger}. eg $self->set_logger( $args->{-logger} )

It will do the same all elements in the map array ref.

eg

$self->set_arguments( [ qw/ logger configuration week_data fixtures / ], $args );

=cut

sub set_arguments {
  my ( $self, $map, $args ) = validate_pos( @_, 1, { type => ARRAYREF }, { type => HASHREF } );

  foreach my $m (@$map) {
    my $method = 'set_' . $m;
    my $key    = '-' . $m;
    $self->$method( $args->{$key} ) if exists $args->{$key};
  }
  return 1;
}

=head1 INTERNAL (PRIVATE) METHODS

=cut

1;
