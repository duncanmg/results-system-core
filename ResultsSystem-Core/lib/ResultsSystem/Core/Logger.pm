
=head1 NAME

ResultsSystem::Core::Logger

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

=cut

=head1 INHERITS FROM

None

=cut

=head1 EXTERNAL (PUBLIC) METHODS

=cut

package ResultsSystem::Core::Logger;

use strict;
use warnings;
use Carp;

use Log::Log4perl;
use Log::Log4perl::Level;
use Data::Dumper;
use Params::Validate qw/ :all /;
use DateTime::Tiny;
use File::Spec;

use ResultsSystem::Core::Exception;

my ( $volume, $directories, $file ) = File::Spec->splitpath(__FILE__);
our $CONF_FILE = $directories . "/logger.conf";

=head2 new

Create the object and gives it an error object. Binds in the current values of
the class variables LOGDIR, OLDFILE.

=cut

#*****************************************************************************
sub new

  #*****************************************************************************
{
  my $class = shift;
  my $self  = {};
  bless $self, $class;
  my %args = (@_);

  $self->set_log_dir( $args{-log_dir} )            if $args{-log_dir};
  $self->set_log_file_stem( $args{-logfile_stem} ) if $args{-logfile_stem};

  return $self;

}    # End constructor

=head2 logger

$self->logger->debug( "Use the existing logger if there is one." );

$self->logger(undef, 1)->debug( "Always use a new logger. Write to STDERR" );

$self->logger($dir, 1)->debug( "Always use a new logger. Write to file in $dir" );

=cut

sub logger {
  my ( $self, $category ) = validate_pos( @_, 1, { type => SCALAR } );

  croak(
    ResultsSystem::Core::Exception->new(
      "LOGDIR_DOES_NOT_EXIST", "Log dir does not exist " . $self->get_log_dir
    )
  ) if !-d $self->get_log_dir;

  my $file = $self->logfile_name;
  croak(
    ResultsSystem::Core::Exception->new(
      "LOGFILENAME_NOT_SET", "The log file is not set " . $file
    )
  ) if !$file;

  local $ENV{LOGFILENAME} = $file;
  Log::Log4perl::init( $self->get_conf );

  return Log::Log4perl::get_logger($category);

}

=head2 screen_logger

Log to screen (STDERR) using the default configuration.

$logger = $self->screen_logger();

=cut

sub screen_logger {
  my ( $self, $category ) = validate_pos( @_, 1, { type => SCALAR } );

  my $conf = $self->default_conf();

  Log::Log4perl::init($conf);

  my $logger = Log::Log4perl::get_logger($category);

  return $logger;

}

=head2 logfile_name

Return the existing logfile_name or undef:

$self->logfile_name();

Set the logfile_name and use the given directory:

If called on 28 Apr 2013

my $logfile_name = $self->logfile_name( "/tmp" );

will set $logfile_name to "/tmp/rs28.log"

=cut

sub logfile_name {
  my ($self) = validate_pos( @_, 1 );
  my $now = DateTime::Tiny->now();
  $self->{logfile_name} =
    sprintf( "%s/%s%02d.log", ( $self->get_log_dir || "" ), $self->get_log_file_stem, $now->day );
  return $self->{logfile_name};
}

=head2 set_log_dir

Set the log directory.

=cut

#*****************************************************************************
sub set_log_dir

  #*****************************************************************************
{
  my $self = shift;
  $self->{LOGDIR} = shift;
  if ( !-d $self->get_log_dir ) {
    print STDERR "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX " . $self->get_log_dir . "\n";
    $self->{logger}->error( "Log directory does not exist. " . $self->get_log_dir );
  }
  return $self;
}

=head2 set_log_file_stem

=cut

sub set_log_file_stem {
  my ( $self, $v ) = @_;
  $self->{LOG_FILE_STEM} = $v;
  return $self;
}

=head2 open_log_file

Not needed any more. Will be removed at some point.

=cut

#*****************************************************************************
sub open_log_file

  #*****************************************************************************
{
  my ( $self, $logfile ) = @_;
  my $err   = 0;
  my $count = 0;
  my $LOGFILE;

  $self->{logger}->debug("open_log_file called()");

  return ( $err, $LOGFILE );
}    # End open_log_file()

=head2 close_log_file

Don't need this any more.

=cut

#*****************************************************************************
sub close_log_file

  #*****************************************************************************
{
  my $self = shift;
  my $err  = 0;

  return $err;
}    # End close_log_file()

=head1 INTERNAL (PRIVATE) METHODS

=cut

=head2 default_conf

Default configuration

=cut

sub default_conf {
  my $self = shift;
  return {
    "log4perl.rootLogger"             => "INFO , Screen",
    "log4perl.appender.Screen"        => "Log::Log4perl::Appender::Screen",
    "log4perl.appender.Screen.stderr" => 1,
    "log4perl.appender.Screen.layout" => "Log::Log4perl::Layout::PatternLayout",
    "log4perl.appender.Screen.layout.ConversionPattern" =>
      "[%d{dd/MMM/yyyy:HH:mm:ss}] %c %p %F{1} %M %L - %m%n"
  };
}

=head2 conf_with_logfile

Used when a valid log file has been provided, but there is no configuration
file.

=cut

sub conf_with_logfile {
  my $self = shift;
  my $file = shift;
  return {
    "log4perl.rootLogger"                    => "INFO , LOGFILE",
    "log4perl.category.ResultsConfiguration" => "INFO , LOGFILE",
    "log4perl.category.Fixtures"             => "INFO , LOGFILE",
    "log4perl.category.WeekFixtures"         => "INFO , LOGFILE",
    "log4perl.category.WeekResults"          => "INFO , LOGFILE",
    "log4perl.appender.LOGFILE"              => "Log::Log4perl::Appender::File",
    "log4perl.appender.LOGFILE.filename"     => $file,
    "log4perl.appender.LOGFILE.mode"         => "append",
    "log4perl.appender.LOGFILE.layout"       => "Log::Log4perl::Layout::PatternLayout",
    "log4perl.appender.LOGFILE.layout.ConversionPattern" =>
      "[%d{dd/MMM/yyyy:HH:mm:ss}] %c %p %F{1} %M %L - %m%n",
  };
}

=head2 get_logger

$logger = get_logger($category, $file);

category: Log4perl category

file: Full file messages will be logged to.

If $file is undefined or the directory does not exist then undefined is returned.

If the configuration file does not exists, undefined is returned.

=cut

sub get_logger {
  my ( $self, $category, $file ) = validate_pos( @_, 1, 1, 0 );

  $category = 'Default' if !$category;
  my $conf = $self->get_conf($file);
  return if !$conf;

  Log::Log4perl::init($conf);

  my $logger = Log::Log4perl::get_logger($category);

  return $logger;

}

=head2 get_conf

Return the log configuration file if it exists.

=cut

sub get_conf {
  my $self = shift;

  croak(
    ResultsSystem::Core::Exception->new(
      "LOG_CONF_DOES_NOT_EXIST", "Log configuration file does not exist " . $CONF_FILE
    )
  ) if !-f $CONF_FILE;

  return $CONF_FILE;
}

=head2 get_log_dir

=cut

#*****************************************************************************
sub get_log_dir

  #*****************************************************************************
{
  my $self = shift;
  return $self->{LOGDIR};
}

#=head2 _create_suffix
#
#=cut
#
##*****************************************************************************
## Use a function to calculate the suffix.
#sub _create_suffix {
#
#  #*****************************************************************************
#  my $self = shift;
#  my $lt   = localtime();
#
#  my $tmp = $lt->yday;
#  while ( length $tmp < 3 ) { $tmp = '0' . $tmp; }
#  my $suffix = $tmp;
#
#  if ( $self->get_append_logfile() eq 'N' ) {
#
#    $tmp = $lt->hour;
#    while ( length $tmp < 2 ) { $tmp = '0' . $tmp; }
#    $suffix = $suffix . $tmp;
#
#    $tmp = $lt->min;
#    while ( length $tmp < 2 ) { $tmp = '0' . $tmp; }
#    $suffix = $suffix . $tmp;
#
#    $tmp = $lt->sec;
#    while ( length $tmp < 2 ) { $tmp = '0' . $tmp; }
#    $suffix = $suffix . $tmp;
#
#    $tmp = int( rand(100) );
#    while ( length $tmp < 2 ) { $tmp = '0' . $tmp; }
#
#    $suffix = $suffix . $tmp;
#
#  }
#
#  return $suffix;
#
#}

#=head2 get_log_file_name
#
#Return the name of the open log file. If a parameter is provided then the path is
#returned as well.
#
#=cut
#
#  #*****************************************************************************
#  sub get_log_file_name
#
#    #*****************************************************************************
#  {
#    my $self = shift;
#    my $full = shift;
#    my $name = $self->{LOGFILENAME};
#    if ( $full eq undef ) {
#      $name =~ s/^.*?([^\/\\]{1,})$/$1/;
#    }
#    return $name;
#  }

=head2 get_log_file_stem

=cut

sub get_log_file_stem {
  my $self = shift;
  return $self->{LOG_FILE_STEM} || 'rs';
}

1;
