package Net::FTP::Common;

use strict;


require Exporter;

use Data::Dumper;
use Net::FTP;


use vars qw(@ISA $VERSION);

@ISA = qw(Net::FTP);

$VERSION = '1.3';


# Preloaded methods go here.

sub new {
    my $pkg  = shift;
    my $netftp_cfg = shift;
    my $common_cfg = shift;

    my %common_cfg = (
		      User => 'anonymous',
		      Pass => 'list@rebol.com',
		      Dir  => '/pub',
		      Type => 'I'
		     );

    my %netftp_cfg = ( Debug => 1, Timeout => 240 );

    @common_cfg{keys %$common_cfg} = values %$common_cfg;
    @netftp_cfg{keys %$netftp_cfg} = values %$netftp_cfg;
    
    my $self = {};

    @{$self->{Common}}{keys %common_cfg} = values %common_cfg;
    @{$self->{NetFTP}}{keys %netftp_cfg} = values %netftp_cfg;
    bless $self, $pkg;
}



sub login {
  my ($self,$host) = @_;

  my $ftp_session = 
    Net::FTP->new($host, %{$self->{NetFTP}});

  if (!$ftp_session) {
    warn "error connecting to $host: $!";
    return 0;
  }

  $ftp_session->login($self->{Common}->{User},$self->{Common}->{Pass}) 
    && return $ftp_session 
    || die "error logging in: $!";

  return 0;
}

sub dir {
    my ($self,$host) = @_;

    my $ftp = $self->login($host);

    use Data::Dumper; print Data::Dumper->Dump([$ftp],['ftp']);

    $ftp->cwd($self->{Common}->{Dir});

    my $ls = $ftp->ls;
    if (!defined($ls)) {
	return ();
    } else {
	return @{$ls};
    }
}

sub mkdir {
    my ($self,$host,%cfg) = @_;

    my $ftp = $self->login($host);

    print Data::Dumper->Dump(['cfg',\%cfg]);

    $ftp->mkdir($cfg{Dir}, $cfg{Recurse});
}


sub check {
    my ($self,$host,%cfg) = @_;

    my @listing = $self->dir($host);

    scalar grep { $_ eq $cfg{File} } @listing;
}

sub glob {
    my ($self,$host,%cfg) = @_;

    my @listing = $self->dir($host);

    scalar grep { $_ =~ $cfg{File} } @listing;
}

sub grep { goto &glob }

# The Perl -e operator for files on a remote site. Even though the
# REBOL exists? word works on local files as well as URL's, Perl's does 
# not. Shame isn't it? :-)

sub file_exists {
  my ($server, $user, $pass, $dir, $file) = @_;

  my $ftp_session = ftp_login($server,$user,$pass);

  $ftp_session->cwd($dir);

  my @ls = ftp_session_ls($ftp_session);

  warn "* Grepping for $file in Listing @ls";

  my @grep = (grep { $file eq $_ } @ls);
  
  warn "* Grep @grep";

  return (@grep > 0) ;
}

# Checking for a file on a remote FTP server by use of regular 
# expressions as opposed to explicit filenames

sub ftp_file_exists_re {
  my ($server, $user, $pass, $dir, $file) = @_;

  my $ftp_session = ftp_login($server,$user,$pass);

  $ftp_session->cwd($dir);

  my @ls = ftp_session_ls($ftp_session);

  warn "* re_Grepping for $file in Listing @ls";

  my @grep = (grep { $_ =~ /$file/ } @ls);
  
  warn "* Grep @grep";

  return (@grep > 0) ;
}

# Login and upload a file to a directory.
# In rebol this would be:
# write/binary ftp://some.site/remote-file read/binary %local-file
# But in Perl it's a many-line chore. Sigh.

sub ftp_upload {

  my ($server, $user, $pass, $dir, $file) = @_;

  my $ftp_session = ftp_login($server,$user,$pass);

  $ftp_session->cwd($dir);
  if (!-e $file) {
      die "$file does not exist on local disk. Cannot be uploaded";
  } else {
      warn "$file exists on local disk.. uploading";
      $ftp_session->put($file);
  }

}


# Really, the best abstraction would be:
# ftp_download_all_with_hook where the hook in this case would be a
# coderef that conditionally decrypts the downloaded file
# Laziness now will lead to more work later I guess.

sub prep {
  my ($self,$host) = @_;
  
  my $ftp = $self->login($host);
  $ftp->cwd($self->{Common}->{Dir});
  $ftp->type($self->{Common}->{Type});

  $ftp;
}


sub get {

  my ($self,$host,%cfg) = @_;

  my $ftp = $self->prep($host);

  $ftp->get($cfg{File}) || die "download of $cfg{File} failed";

}

sub send {

  my ($self,$host,%cfg) = @_;

  warn Data::Dumper->Dump([$self,$host,\%cfg],['self','host','cfg']);

  my $ftp = $self->prep($host);

  $ftp->put($cfg{File}) || die "upload of $cfg{File} failed";

}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Net::FTP::Common - Perl extension for simplifying common usages of
Net::FTP.

=head1 SYNOPSIS

  use Net::FTP::Common;
  %net_ftp_config = ( Debug   => 1, Timeout => 120 );

  %common_cfg     = 
    (
      User => 'username',          # overwrite anonymous user default
      Pass => 'password',          # overwrite list@rebol.com pass default
      Dir  => 'pub'                # overwrite slash default
     );


  $ez = Net::FTP::Common->new(\%net_ftp_config, \%common_cfg);

  $host = 'ftp.rebol.com';

  # Get a listing of a remote directory:
  @listing =	$ez->dir($host);

  # Make a directory on the remote machine
  $ez->mkdir($host, Dir => '/pub/newdir/1/2/3', Recurse => 1);

  # Get a file from the remote machine
  $ez->get($host, File => 'codex.txt');

  # Send a file to the remote machine
  $ez->send($host, File => 'codex.txt');

  # test for a file's existence on the remote machine (using =~)
  $ez->grep($host, File => '[A-M]*[.]txt');
  # a synonym for grep is glob (no difference, just another name)
  $ez->glob($host, File => 'n.*-file.t?t');
  # note this is no more than you manually calling:
  # (scalar grep { $_ =~ 'n.*-file.t?t' } $ez->dir($host)) > 0;



  # test for a file on the remote machine (using eq)
  $ez->check($host, File => 'needed-file.txt');
  # note this is no more than you manually calling:
  # (scalar grep { $_ = 'needed-file.txt' } $ez->dir($host)) > 0;
  # or manually calling
  # (scalar $ez->grep($host)) > 0



  # can we login to the machine?
  $ez->login($host) || die "cant login";


=head1 DESCRIPTION

This module is intended to make the common uses of Net::FTP a one-line
affair. Also, it made the development of Net::FTP::Shell 
straightfoward.

Note well: though Net::FTP works in the stateful way that the FTP protocol 
does, Net::FTP::Common works in a stateless "one-hit" fashion. That is, for
each separate call to the API, a connection is established, the particular
Net::FTP::Common functionality is performed and the connection is dropped.
The disadvantage of this approach is the (usually irrelevant and 
insignificant) over head of connection and disconnection. The
advantage is that there is much less chance of incurring failure due
to timeout.

=head2 EXPORT

None by default.

=head1 AUTHOR

T. M. Brannon <tbone@cpan.org>

=head1 SEE ALSO

REBOL (www.metaperl.com) is a language which supports 1-line
internet processing for the schemes of mailto:, http:, daytime:, and ftp:. 

A Perl implementation of REBOL is in the works at www.metaperl.com.

=cut
