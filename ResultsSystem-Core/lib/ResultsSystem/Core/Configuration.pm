
=head1 NAME

ResultsSystem::Core::Configuration

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

=cut

=head1 INHERITS FROM



=cut

=head1 EXTERNAL (PUBLIC) METHODS

=cut

package ResultsSystem::Core::Configuration;

use strict;
use warnings;
use Carp;

use XML::Simple;
use Sort::Maker;
use List::MoreUtils qw/ first_value any /;
use Regexp::Common qw /whitespace/;
use Data::Dumper;
use Params::Validate qw/:all/;

use ResultsSystem::Exception;

## For testing purposes only.
#sub _set_stylesheet {
#  my $self  = shift;
#  my $h_ref = shift;
#  $self->{TAGS}->{stylesheets}[0]{sheet}[0] = $h_ref->{name};
#  $self->{TAGS}->{stylesheets}[0]{copy}[0]  = $h_ref->{copy};
#  return 0;
#}

=head2 Configuration Setup

=cut

=head3 new

Constructor for the ResultsSystem::Core::Configuration object. Optionally accepts the full filename
of the configuration file as an argument. Does not read the file at this point.

If -full_filename is not provided, then it must be set explicitly before the file 
can be read.

  $c = ResultsSystem::Core::Configuration->new( -full_filename => "/custom/config.ini" );

or 

  $c = ResultsSystem::Core::Configuration->new();
  $c->set_full_filename("/custom/config.ini");

Requires -logger

=cut

#***************************************
sub new {

  #***************************************
  my ( $class, %args ) = @_;
  my $self = {};
  bless $self, $class;
  my $err = 0;

  $self->set_logger( $args{-logger} );

  # $self->set_full_filename("../custom/results_system.ini");
  if ( $args{-full_filename} ) {
    $err = $self->set_full_filename( $args{-full_filename} );
  }

  if ( $err == 0 ) {
    return $self;
  }
  else {
    $self->logger->error("Could not create object.");
    return;
  }
}

=head3 set_full_filename

Sets the full filename of the configuration file. Filters out
characters other than alphanumeric characters, "_", ".", or "/".

=cut

#***************************************
sub set_full_filename {

  #***************************************
  my $self = shift;
  my $err  = 0;
  $self->{FULL_FILENAME} = shift;
  $self->{FULL_FILENAME} =~ s/[^\w\.\/ -]//xg;
  if ( !-f $self->{FULL_FILENAME} ) {
    $self->logger->error( $self->{FULL_FILENAME} . " does not exist." );
    $err = 1;
  }
  return $err;
}

=head3 get_full_filename

Returns the full filename of the configuration file.

=cut

#***************************************
sub get_full_filename {

  #***************************************
  my $self = shift;
  return $self->{FULL_FILENAME} if $self->{FULL_FILENAME};
  my $system = $self->get_system;
  if ($system) {
    $self->set_full_filename("../custom/$system/$system.ini");
  }
  return $self->{FULL_FILENAME};
}

=head3 read_file

Read the configuration file. Returns an error if the file doesn't exist or the read fails.

$err = $c->read_file();

Uses the full filename given by $self->get_full_filename().

If the full filename ends in _local.ini then it will look for a similar file
without the _local and use that as a parent. eg nfcca.ini and nfcca_local.ini.

It will merge the tags from the local file into the parent and put the result into
the TAGS attribute.

The tags which can be merged are paths, descriptors, return_to, stylesheets, divisions, 
users, calculations

eg If nfcca.ini contains:

  <descriptors>
   <title>
     South East Hampshire Cricket Association
   </title>
   <season>
     2008
   </season>  
  </descriptors>

  <stylesheets>
    <sheet>
      sehca_styles.css
    </sheet>
   </stylesheets>

And nfcca_local.ini contains:

  <stylesheets>
    <sheet>
      different.css
    </sheet>
   </stylesheets>

Then the merged xml will be:

  <descriptors>
   <title>
     South East Hampshire Cricket Association
   </title>
   <season>
     2008
   </season>  
  </descriptors>

  <stylesheets>
    <sheet>
      different.css
    </sheet>
   </stylesheets>

=cut

#***************************************
sub read_file {

  #***************************************
  my $self = shift;
  my $err  = 0;

  $err = $self->_read_file();
  return $err if $err;

  return $err;
}

=head3 set_logger

=cut

sub set_logger {
  my ( $self, $logger ) = @_;
  $self->{LOGGER} = $logger;
  return $self;
}

=head3 set_system

Sets the stem of the .ini file which must be the same as the subdirectory it is in.

eg nfcca is the stem of nfcca.ini and will be located in custom/nfcca.

=cut

sub set_system {
  my ( $self, $system ) = @_;
  $self->{system} = $system;
  return $self;
}

=head3 get_system

Returns the stem of the .ini file which must be the same as the subdirectory it is in.

eg nfcca is the stem of nfcca.ini and will be located in custom/nfcca.

=cut

sub get_system {
  my $self = shift;
  return $self->{system};
}

=head3 get_log_stem

Appends the current season to the string passed as an argument.

=cut

#***************************************
sub get_log_stem {

  #***************************************
  my $self   = shift;
  my $system = shift;
  my $stem   = "results_system";
  if ($system) {
    $stem = $system;
  }
  my $s = $self->get_season;
  if ($s) {
    $stem = $stem . $s;
  }

  return $stem;
}

=head2 Path Handling

=cut

=head3 get_path

This method accepts one mandatory named parameter and one optional named
parameter. Returns the appropriate path from the configuration file.

Valid paths are -csv_files, -log_dir, -pwd_dir, -table_dir, -results_dir,
-htdocs, -cgi_dir, -root, -season, -csv_files_with_season, -htdocs_full,
-results_dir_full, -table_dir_full, -cgi_dir_full, -divisions_file_dir. 

It logs a warning and continues if the key isn't in the list of valid keys.

$path = $c->get_path( -csv_files => "Y" );

The optional parameter stops it emitting a warning if the path does
not exist. For example, the Apache docroot. It can take any true
value.

$path = $c->get_path( -htdocs => "Y", -allow_not_exists => 1 );

=cut

#***************************************
sub get_path {

  #***************************************
  my ( $self, %args ) = @_;

  my $p;
  my $err = 0;

  my $allow_not_exists = $args{"-allow_not_exists"};
  delete $args{"-allow_not_exists"};

  $self->logger->debug( "get_path() called. " . Dumper(%args) ) if !$args{-log_dir};
  croak( ResultsSystem::Exception->new( 'NO_PATHS_DEFINED', 'No paths defined' ) )
    if !exists $self->_get_tags->{paths};

  my @keys        = keys %args;
  my $key         = shift @keys;
  my @valid_paths = (
    "-csv_files",             "-log_dir",
    "-pwd_dir",               "-table_dir",
    "-results_dir",           "-htdocs",
    "-cgi_dir",               "-root",
    '-htdocs_full',           '-results_dir_full',
    '-table_dir_full',        "-season",
    "-csv_files_with_season", "-cgi_dir_full",
    "-divisions_file_dir",
  );

  if ( !( any { $key eq $_ } @valid_paths ) ) {
    $self->logger->warn("$key is not in the list of valid paths.");
    $self->logger->warn( Dumper caller );
  }

  my $k = $key;
  $k =~ s/^-//x;
  $p = $self->_get_tags->{paths}[0]{$k}[0];
  croak( ResultsSystem::Exception->new( 'PATH_NOT_IN_TAGS', $k ) ) if !$p;

  $p = $self->_construct_path( -path => $p );
  $p = $self->_trim($p);

  if ( ( !$allow_not_exists ) && ( !-d $p ) ) {

    # Report this as a warning rather than a serious error.
    $self->logger->warn( "Path does not exist. " . join( ", ", keys(%args) ) . " " . $p );
    $self->logger->warn( Dumper caller );
  }
  $self->logger->debug( "get_path() returning: " . $p . " was called with " . Dumper(%args) )
    if !$args{-log_dir};
  return $p;

}

=head3 set_csv_file

Name of csv file for current request. eg U9.csv

=cut

sub set_csv_file {
  my ( $self, $csv_file ) = validate_pos( @_, 1, { regex => qr/^[0-9a-z]*\.csv$/xi } );
  $self->{csv_file} = $csv_file;
  return $self;
}

=head3 get_csv_file

=cut

sub get_csv_file {
  my $self = shift;
  return $self->{csv_file};
}

=head3 get_csv_full_filename

Return the full path and filename of the csv file for the
current request.

Returns undef if either the csv file or the path is not set.

=cut

sub get_csv_full_filename {
  my ($self) = validate_pos( @_, 1 );
  my $f = $self->get_csv_file;
  my $p = $self->get_path( -csv_files_with_season => 1 );
  return if !( $f && $p );
  return $p . '/' . $f;
}

=head3 get_divisions_full_filename

Return the full path and filename of the divisions file.

Returns undef if either the full filename is not set.

=cut

sub get_divisions_full_filename {
  my ($self) = validate_pos( @_, 1 );
  my $p = join( '/', $self->get_path( -divisions_file_dir => 1 ), 'divisions.xml' );
  return $p;
}

=head3 set_matchdate

eg 8-May

=cut

sub set_matchdate {
  my ( $self, $matchdate ) = validate_pos( @_, 1, { regex => qr/^\d{1,2}-[A-Z][a-z]{2}$/xi } );
  $self->{matchdate} = $matchdate;
  return $self;
}

=head3 get_results_full_filename

Return the full path and filename of the results file for the
current request.

Returns undef if either the csv file or the path or the matchdate
is not set.

eg /results_system/forks/nfcca/results_system/fixtures/nfcca/2016/U9N_11-May.dat

=cut

sub get_results_full_filename {
  my ($self) = validate_pos( @_, 1 );

  my $f = $self->get_csv_file || '';
  $f =~ s/\.csv$//x;

  my $m = $self->_get_matchdate;

  my $p = $self->get_path( -csv_files_with_season => 1 );

  return if !( $f && $p && $m );

  return $p . '/' . $f . '_' . $m . '.dat';
}

=head3 get_table_html_full_filename

Reurn the full path and filename of the HTML file which holds
the table for the division.

Returns undef if the csv file is not set.

=cut

sub get_table_html_full_filename {
  my ($self) = @_;

  my $f = $self->get_csv_file;    # The csv file
  return if !$f;

  my $dir = $self->get_path( -table_dir_full => "Y" );
  croak(
    ResultsSystem::Exception->new( 'DIR_DOES_NOT_EXIST', "Table directory $dir does not exist." )
  ) if !-d $dir;

  $f =~ s/\..*$/\.htm/x;          # Change the extension to .htm
  $f = "$dir/$f";                 # Add the path

  return $f;
}

=head3 get_results_html_full_filename

Reurn the full path and filename of the HTML file which holds
the results for the division and week.

Returns undef if either the csv file or the matchdate are not set.

=cut

sub get_results_html_full_filename {
  my ($self) = @_;

  my $f = $self->get_csv_file;      # The csv file
  my $w = $self->_get_matchdate;    # The match date
  return if !( $f && $w );

  my $dir = $self->get_path( -results_dir_full => "Y" );
  croak(
    ResultsSystem::Exception->new(
      'DIR_DOES_NOT_EXIST', "Result directory $dir does not exist."
    )
  ) if !-d $dir;

  $f =~ s/\..*$//x;                 # Remove extension
  $f = "$dir/${f}_$w.htm";          # Add the path

  return $f;
}

=head2 Password Handling

=cut

=head3 get_code

This method return the password for the user passed as an argument. Returns
undefined if the user does not exist.


$pwd = $c->get_code( "fred" );

=cut

#***************************************
sub get_code {

  #***************************************
  my $self = shift;
  my $user = shift;
  my $tags;
  $tags = $self->_get_tags->{users} if $self->_get_tags;
  my $code;

  if ( !$user ) {
    return;
  }

  foreach my $u (@$tags) {

    if ( $u->{user}[0] eq $user ) {
      $code = $u->{code}[0];
      last;
    }
  }
  return $self->_trim($code);
}

=head2 View Handling

=cut

=head3 get_stylesheet

Returns a hash ref containing the name of the first stylesheet
and whether it is to be copied.

The elements of the hash ref are name and copy. The latter can
have values of "yes" and "no".

=cut

#***************************************
sub get_stylesheet {

  #***************************************
  my $self = shift;
  my $name = $self->_get_tags->{stylesheets}[0]{sheet}[0];
  my $copy = $self->_get_tags->{stylesheets}[0]{copy}[0];
  $name = $self->_trim($name);
  $copy = "no" if !$copy;
  $copy = ( $copy =~ m/yes/i ) ? "yes" : "no";
  if ( !$name ) {
    $self->logger->debug("get_stylesheet() No sheet element found.");
    if ( $self->_get_tags->{stylesheets}[0] =~ m/\w+/x ) {
      $name = $self->_get_tags->{stylesheets}[0];
      $self->logger->debug("get_stylesheet() Return $name instead.");
    }
  }
  return { name => $name, copy => $copy };
}

=head3 get_stylesheets

Returns a list of stylesheets

=cut

#***************************************
# Return a list of stylesheets
#***************************************
sub get_stylesheets {

  #***************************************
  my $self = shift;
  my @s    = @{ $self->_get_tags->{stylesheets}[0]{sheet} };

  foreach my $sheet (@s) {
    $sheet = $self->_trim($sheet);
  }

  return @s;
}

=head3 get_return_page

The return link on the page will point here. Returns HTML
within a <p> tag.

  my ( $results_index_url, $title ) 
    = $self->get_return_page( -results_index => 1 );

  my ( $menu_url, $title ) = $self->get_return_page;

=cut

#***************************************
# The return link on the page will point
# here.
#***************************************
sub get_return_page {

  #***************************************
  my $self = shift;
  my %args = (@_);

  my $l = $self->_get_tags->{return_to}[0]{menu}[0]{href}[0];
  my $t = $self->_get_tags->{return_to}[0]{menu}[0]{title}[0];

  if ( $args{-results_index} ) {
    $l = $self->_get_tags->{return_to}[0]{results_index}[0]{href}[0];
    $t = $self->_get_tags->{return_to}[0]{results_index}[0]{title}[0];
  }

  return ( $self->_trim($l), $self->_trim($t) );
}

=head3 get_descriptors

Returns a string. $c->get_descriptors( title => "Y" ) or
$c->get_descriptors( season => "Y" );

=cut

#***************************************
sub get_descriptors {

  #***************************************
  my $self = shift;
  my %args = (@_);
  my $d;

  if ( $args{-title} ) {
    $d = $self->_get_tags->{descriptors}[0]{title}[0];
  }
  if ( $args{-season} ) {
    $d = $self->_get_tags->{descriptors}[0]{season}[0];
  }

  return $self->_trim($d);
}

=head3 get_title

Returns the title.

=cut

#***************************************
sub get_title {

  #***************************************
  my $self = shift;
  my $s    = $self->_get_tags->{descriptors}[0]{title}[0];
  return $self->_trim($s);
}

=head3 get_season

Returns the current season. eg 2018.

Used in views and in path building. The former is legitimate, but path
building should be centralised. Putting it under "View Handling".

=cut

#***************************************
sub get_season {

  #***************************************
  my $self = shift;
  my $s    = $self->_get_tags->{descriptors}[0]{season}[0];
  return $self->_trim($s);
}

=head2 Behaviour Handling

=cut

=head3 get_calculation

points or average eg $c->get_calculation( -order_by => "Y" );

Controls whether the league tables should be ordered by total points
or average points.

=cut

#***************************************
sub get_calculation {

  #***************************************
  my $self = shift;
  my %args = (@_);
  my $v;
  if ( $args{-order_by} ) {
    $v = $self->_get_tags->{calculations}[0]{order_by}[0];
  }
  return $self->_trim($v);
}

=head1 INTERNAL (PRIVATE) METHODS

=cut

=head2 logger

=cut

sub logger {
  my $self = shift;
  return $self->{LOGGER};
}

=head2 _trim

Remove the leading and trailing whitespace from a string passed as as argument.

$s = $c->_trim( $s );

=cut

#***************************************
sub _trim {

  #***************************************
  my $self = shift;
  my $s    = shift;
  return $s if !defined $s;
  $s =~ s/$RE{ws}{crop}//xg;

  #$s =~ s/^\s*([^\s])/$1/;
  #$s =~ s/([^\s])\s*$/$1/;
  return $s;
}

=head2 _get_tags

Internal method which gets the full data structure as read
from the configuration file.

=cut

#***************************************
sub _get_tags {

  #***************************************
  my $self = shift;
  croak( ResultsSystem::Exception->new( 'NO_TAGS_DEFINED', 'No tags defined' ) )
    if !$self->{TAGS};
  return $self->{TAGS};
}

=head2 _read_file

Does the hard work for read_file().

=cut

#***************************************
sub _read_file {

  #***************************************
  my $self = shift;
  my $err  = 0;
  my ( $main_filename, $local_filename, $main_xml, $local_xml );

  ( $main_filename, $local_filename ) = $self->_get_local_and_main_filenames();

  ( $err, $main_xml ) = $self->_load_file($main_filename);
  return $err if $err;

  $self->{TAGS} = $main_xml;
  return $err if !$local_filename;

  ( $err, $local_xml ) = $self->_load_file($local_filename);
  return $err if $err;

  $self->{TAGS} = $self->_merge_files( $local_xml, $main_xml );

  $self->logfile_name( $self->get_path( -log_dir => 'Y' ) );

  return $err;
}

=head2 _get_local_and_main_filenames

Analyze the full_filename to see if it is a local configuration.

If it is, return both the main filename and the local filename. Otherwise return the main filename and undef.

=cut

sub _get_local_and_main_filenames {
  my $self = shift;

  my $full_filename = $self->get_full_filename();
  my $main          = $full_filename;
  $main =~ s/_local(\.ini)$/$1/x;

  return ( $main eq $full_filename ) ? ( $main, undef ) : ( $main, $full_filename );
}

=head2 _merge_files

=cut

sub _merge_files {
  my ( $self, $local_xml, $main_xml ) = @_;
  foreach my $k (qw/paths descriptors return_to stylesheets divisions users calculations/) {
    next if !$local_xml->{$k};
    $main_xml->{$k} = $local_xml->{$k};
  }
  return $main_xml;
}

=head2 _load_file

Read the configuration file. Returns an error if the file doesn't exist or the read fails.

($err, $xml) = $c->_load_file($full_filename);

=cut

#***************************************
sub _load_file {

  #***************************************
  my ( $self, $full_filename ) = @_;
  my $err = 0;
  my ($tags);

  my $xml = XML::Simple->new();
  return 1 if !$xml;

  if ( !-f $full_filename ) {
    $self->logger->error( "_load_file(): File does not exist. " . $full_filename );
    return 1;
  }

  eval {
    $tags = $xml->XMLin(
      $full_filename,
      NoAttr        => 1,
      ForceArray    => 1,
      SuppressEmpty => ""
    );
    1;
  }
    || do { $self->logger->error($@); return 1; };

  $self->logger(1)->debug("File read");

  return ( 0, $tags );
}

=head2 _construct_path

Accepts one argument, which must be a path element. The element can
be in one of two forms:

It can be a simple string e.g. /a/b/c

or it can be a hash reference:

{ prefix => ( "path" ),
  value  => ( "/a/b/c" ),
  suffix => ( "path" ) }
  
The prefix must be the name of a path which can be accessed using get_path.
This method retrieves the path and prefixes it to the contents of value.

So if "path" is /x/y/z then this method will return /x/y/z/a/b/c.

=cut

#***************************************
sub _construct_path {

  #***************************************
  my $self = shift;
  my (%args) = validate( @_, { -path => { type => SCALAR | HASHREF } } );

  return $args{-path} if !ref( $args{-path} );
  my $p = $args{-path};

  my ( $prefix, $value, $suffix, $path );

  croak(
    ResultsSystem::Exception( 'MISSING_KEYS', 'Path must contsin the keys prefix and value' ) )
    if !( $p->{prefix} && $p->{value} );

  $prefix = $p->{prefix}[0] if $p->{prefix}[0];
  $value  = $p->{value}[0]  if $p->{value}[0];
  $suffix = $p->{suffix}[0] if $p->{suffix}[0];

  $self->logger->debug( "Compound path. About to call get_path for prefix " . $prefix );

  my @bits = ();

  push( @bits, $self->get_path( '-' . $prefix => 'Y', -allow_not_exists => 'Y' ) ) if $prefix;
  push( @bits, $value ) if $value;
  push( @bits, $self->get_path( '-' . $suffix => 'Y', -allow_not_exists => 'Y' ) ) if $suffix;

  $path = join( '/', @bits );
  $path =~ s://:/:xg;    # Change // to /.

  return $path;
}

=head2 _get_matchdate

=cut

sub _get_matchdate {
  my ($self) = validate_pos( @_, 1 );
  return $self->{matchdate};
}

1;

__END__

=head1 Example Configuration File

The configuration file is an XML file.

 <xml>

=head2 paths

 <!-- Accessed via get_path -->
 <paths>
 
 <root>
  <!-- The document root -->
  /usr/home/sehca/public_html
 </root>
 <cgi_dir>
  <!-- The location of the cgi-bin directory relative to the document root. -->
  /cgi-bin/results_system/dev
 </cgi_dir>
 <!-- The location of the csv files on the file system. Not the URL. --> 
 <csv_files>
    ../fixtures/sehca/2008
  </csv_files>
  <!-- Location of the log directory on the file system. -->
  <log_dir>
    ../../../../sehca_logs
  </log_dir>
  <!-- Directory on the file system which holds the files containing information about
  failed password entries. -->
  <pwd_dir>
    ../../../../sehca_logs
  </pwd_dir>
  <!-- Directory on the file system which contains the HTML tables. Not URL. -->
  <table_dir>
    ../../../../results_system/dev/custom/sehca/2008/tables
  </table_dir>
  <!-- location of the htdocs directory relative to the document root. -->
  <htdocs>
    /results_system/dev
  </htdocs>
  
 </paths>

=head2 descriptors

 <!-- Accessed via get_descriptors -->
 <descriptors>
  <title>
    South East Hampshire Cricket Association
  </title>
  <season>
    2008
  </season>  
 </descriptors>

=head2 return_to

  <!-- Return links --> 
  <return_to>
  <!-- The page which is to have the link. -->
  <menu>
  <!-- The URL of the link (href). -->
  <href>
    /results_system/dev/common/many_systems.htm
  </href>
  <!-- The description of the link. -->
  <title>
  Return Many Systems Page
  </title>
  </menu>
  <results_index>
  <href>
    /results_system/dev/common/many_systems.htm
  </href>
  <title>
  Return Many Systems Page
  </title>
  </results_index>
</return_to>


=head2 stylesheets

 <!-- Accessed via get_stylesheets -->
 <stylesheets>
  <sheet>
    sehca_styles.css
  </sheet>
 </stylesheets>

=head2 users

 <users>
  <!-- Accessed via get_code() -->
  <user>DMG</user>
  <name>Duncan Garland</name>
  <!-- Not encrypted! -->
  <code>baffins</code>
 </users>

=head2 calculations

 <calculations>
 <order_by>
 average
 </order_by>
 </calculations>
 
 </xml>

=cut
