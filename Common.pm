package Net::FTP::Common;

use strict;


require Exporter;

use Data::Dumper;
use Net::FTP;


use vars qw(@ISA $VERSION);

@ISA     = qw(Net::FTP);

$VERSION =   '2.0';

# Preloaded methods go here.

sub new {
    my $pkg  = shift;
    my $common_cfg_in = shift;
    my %netftp_cfg_in = @_;

    my %common_cfg_default = (
			      User => 'anonymous',
			      Host => 'ftp.microsoft.com',
			      Pass => 'list@rebol.com',
			      Dir  => '/pub',
			      Type => 'I'
			      );

    my %netftp_cfg_default = ( Debug => 1, Timeout => 240 );

    # overwrite defaults with values supplied by sub input
    @common_cfg_default{keys %$common_cfg_in} = values %$common_cfg_in;
    @netftp_cfg_default{keys  %netftp_cfg_in} = values  %netftp_cfg_in;
    
    my $self = {};

    @{$self->{Common}}{keys %common_cfg_default} = values %common_cfg_default;
    @{$self->{NetFTP}}{keys %netftp_cfg_default} = values %netftp_cfg_default;

    my $new_self = { %{$self->{NetFTP}}, Common => $self->{Common} } ;

    bless $new_self, $pkg;
}

sub Host { $_[0]->{Common}->{Host} or die "Host must be defined when creating a __PACKAGE__ object" }

sub NetFTP { $_[0]->prep }

sub login {
  my $self = shift;

  my $ftp_session = Net::FTP->new($self->Host, %$self);

  $ftp_session or return 0;

  $ftp_session->login($self->{Common}->{User}, $self->{Common}->{Pass})  && return $ftp_session  || die "error logging in: $!";
}

sub dir {
  my ($self, %config) = @_;

  my $ftp = $self->prep($config{New});

  my $ls = $ftp->ls;
  if (!defined($ls)) {
    return ();
  } else {
    return @{$ls};
  }
}

sub mkdir {
    my ($self,%config) = @_;

    my $ftp = $self->prep($config{New});

    $ftp->mkdir($config{Dir}, $config{Recurse});
}

# The Perl -e operator for files on a remote site. Even though the
# REBOL exists? word works on local files as well as URL's, Perl's does 
# not. Shame isn't it? :-)

sub exists {
    my ($self,%cfg) = @_;

    my @listing = $self->dir(%cfg);

    scalar grep { $_ eq $cfg{File} } @listing;
}

sub glob {
#    warn Data::Dumper->Dump([\@_],['@_(glob)']);
    my ($self,%cfg) = @_;

#    warn sprintf "self: %s host: %s cfg: %s", $self, $host, Data::Dumper::Dumper(\%cfg);

    my @listing = $self->dir(%cfg);

    grep { $_ =~ /$cfg{File}/ } @listing;
}

sub grep { goto &glob }

# Really, the best abstraction would be:
# ftp_download_all_with_hook where the hook in this case would be a
# coderef that conditionally decrypts the downloaded file
# Laziness now will lead to more work later I guess.

sub prep {
  my $self = shift;
  my %cfg  = @_;

  @{$self->{Common}}{keys %cfg} = values %cfg;
  
  my $ftp = $self->login($self->Host);
  $ftp->cwd($self->{Common}->{Dir});
  $ftp->type($self->{Common}->{Type});

  $ftp;
}

sub binary {
    my $self = shift;

    $self->{Common}{Type} = 'I';
}

sub ascii {
    my $self = shift;

    $self->{Common}{Type} = 'A';
}

sub get {

  my ($self,%cfg) = @_;

  my $ftp = $self->prep($cfg{New});

  $ftp->get($cfg{File},$cfg{LocalFile}) || die "download of $cfg{File} failed";

}

sub send {
  my ($self,%cfg) = @_;

  my $ftp = $self->prep($cfg{New});

  $ftp->put($cfg{File}) || die "upload of $cfg{File} failed";
}


1;
__END__

=head1 NAME

Net::FTP::Common - Perl extension for simplifying common usages of Net::FTP.

=head1 SYNOPSIS

  use Net::FTP::Common;
  %net_ftp_config = (Debug => 1, Timeout => 120);

  %common_cfg = 
    (
      User => 'username',           # overwrite anonymous USER default
      Host => 'ftp.perl.com',       # overwrite ftp.microsoft.com HOST default
      Pass => 'tbone@soap-pan.org', # overwrite list@rebol.com PASS default
      Dir  => 'pub',                # overwrite slash DIR default
      Type => 'A'                   # overwrite I (binary) TYPE default
     );

  # NOTE WELL!!! one is passed by reference, the other by value.
  # This is inconsistent, but still it is A Very, Very Good Thing.
  # Believe me! I thought about this. And I have a good reason for it:
  # This is to allow the least modification of legacy Net::FTP source code.
  $ez = Net::FTP::Common->new(\%common_cfg, %net_ftp_config); 

  # can we login to the machine?
  # Note: it is NEVER necessary to first login before calling Net::FTP::Common API functions.                               
  # This function is just for checking to see if a machine is up. It is published as part of
  # The API because I have found it useful when writing FTP scripts which scan for the 
  # first available FTP site to use for upload.
  # The exact call-and-return semantics for this function are described and justified below.
  $ez->login || die "cant login: $@";

  # Get a listing of a remote directory (list the 'Dir' option supplied to the constructor)
  @listing =	$ez->dir; 

  # Let's list a different directory, over-riding and changing the
  # default directory
   @listing =	$ez->dir( New => { Dir => '/pub/rfcs' } ); 

  # Let's list the default dir on several hosts
  @host_listings = map { $ez->dir( New => { Host => $_ } ) } @host_list

  # Let's get the listings of several directories
  @dir_listings  = map { $ez->dir( New => { Dir  => $_ } ) } @dir_list;

  # Get a file from the remote machine
  $ez->get(File => 'codex.txt', LocalFile => '/tmp/crypto.txt');

  # Send a file to the remote machine
  $ez->send(File => 'codex.txt');

  # test for a file's existence on the remote machine (using =~)
  @file = $ez->grep(File => '[A-M]*[.]txt');

  # a synonym for grep is glob (no difference, just another name)
  @file = $ez->glob(File => 'n.*-file.t?t');

  # test for a file on the remote machine (using eq)
  $ez->exists(File => 'needed-file.txt');
  # note this is no more than you manually calling:
  # (scalar grep { $_ eq 'needed-file.txt' } $ez->dir) > 0;


=head1 DESCRIPTION

This module is intended to make the common uses of Net::FTP a one-line
affair. Also, it made the development of Net::FTP::Shell 
straightforward.

Besides the constructor, all functions allow the over-riding of the initially supplied Net::FTP::Common configuration hashref 
by supplying a hashref with an API call.

Usage of this module is intended to be straightforward and stereotyped. The general steps to be used are:

=over 4

=item * use Net::FTP::Common

=item * Define FTP configuration information 

This can be inlined within the script but oftentimes this will be stored in a module for usage in many other scripts.

=item * Use a Net::FTP::Common API function

Note well that you NEVER have to login first. All API functions automatically log you in and change to the configured or
specified directory. However, sometimes it is useful to see if you can actually login before
attempting to do something else on an FTP site. This is the only time you will need the login() API method.

Note well: though Net::FTP works in the stateful way that the FTP protocol 
does, Net::FTP::Common works in a stateless "one-hit" fashion. That is, for
each separate call to the API, a connection is established, the particular
Net::FTP::Common functionality is performed and the connection is dropped.
The disadvantage of this approach is the (usually irrelevant and 
insignificant) overhead of connection and disconnection. The
advantage is that there is much less chance of incurring failure due
to timeout.

=head1 METHODS

=head2 new ( $net_ftp_common_hashref, %net_ftp_hash ) 

This method takes initialization information for Net::FTP::Common as well as Net::FTP and returns a new Net::FTP::Common object.
Though the calling convention may seem a bit inconsistent, it is actually the best API to support re-use of legacy
Net::FTP constructor calls. For example if you had a Net::FTP script which looked like this:

           use Net::FTP;

           $ftp = Net::FTP->new("some.host.name", Debug => 0);
           $ftp->login("anonymous",'me@here.there');
           $ftp->cwd("/pub");
           $ftp->get("that.file");
           $ftp->quit;

Here is all you would have to do to convert it to the Net::FTP::Common API:

           use Net::FTP::Common;

           $net_ftp_common_cfg = { Host => 'some.host.name', 
				   User => 'anonymous',
				   Pass => 'me@here.there',
				   Dir  => '/pub'
				   }	

           $ftp = Net::FTP::Common->new($net_ftp_common_cfg, Debug => 0);
           $ftp->get("that.file");
           $ftp->quit;

The example shows all the arguments that may be supplied to the
Net::FTP::Common config hashref, except one, 'Type' which takes an
argument of 'A' for ascii transfers and 'I' for binary transfers.

=head2 dir 

When given no arguments, C<dir()> uses Common configuration
information to login to the ftp site, change directory and transfer
type and then return an array of directory contents. You may only call
this routine in array context and unlike Net::FTP, it returns a list
representing the contents of the remote directory and in the case of
no files, returns an empty array instead of (like Net::FTP) returning
a 1-element array containing the element undef.

You may give this function any number of configuration arguments to over-ride the predefined configuration options. For 
example:

 my %dir;
 my @dir =qw (/tmp /pub /gnu);
 map { @{$dir{$_}} = $ftp->dir(New => { Dir => $_ }) } @dir;

=head1 TRAPS FOR THE UNWARY

=item *

  @file = $ez->grep(File => '[A-M]*[.]txt');
  
is correct

  @file = $ez->grep('[A-M]*[.]txt');

looks correct but is not because you did not name the argument as you are 
supposed to.

=head2 EXPORT

None by default.

=head1 AUTHOR

T. M. Brannon <metaperl@yahoo.com>

=head1 SEE ALSO

REBOL (www.rebol.com) is a language which supports 1-line
internet processing for the schemes of mailto:, http:, daytime:, and ftp:. 

A Perl implementation of REBOL is in the works at www.metaperl.com.

=cut
