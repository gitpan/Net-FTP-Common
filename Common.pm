package Net::FTP::Common;

require 5.005_62;
use strict;
use warnings;

require Exporter;

use Data::Dumper;
use Net::FTP;


our @ISA = qw(Net::FTP);

our $VERSION = '0.01';


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
    warn "error connecting: $!";
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

sub check {
    my ($self,$host,%cfg) = @_;

    my @listing = $self->dir($host);

    scalar grep { $_ =~ $cfg{File} } @listing;
}

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


  $ez = Net::FTP::Common->new('ftp.rebol.com', \%net_ftp_config, \%common_cfg);

  $host = 'ftp.rebol.com';

  # Get a listing of a remote directory:
  @listing =	$ez->dir($host);

  # Make a directory on the remote machine
  $ez->mkdir($host, Dir => '/pub/newdir/1/2/3', Recurse => 1);

  # Get a file from the remote machine
  $ez->get($host, File => 'codex.txt');

  # "grep" for a file on the remote machine (slash defaultusing eq)
  $ez->grep($host, File => 'needed-file.txt');


  # "grep" for a file on the remote machine (slash defaultusing eq)
  $ez->check($host, File => 'needed-file.txt');
  # note this is no more than you manually calling:
  # (scalar grep { $_ = 'needed-file.txt' } $ez->dir($host)) > 0;


  # "grep" for a file on the remote machine (using regexp)
      		$ez->grep($host, File => 'n.*-file.t?t');
  # note this is no more than you manually calling:
  # (scalar grep { $_ =~ 'n.*-file.t?t' } $ez->dir($host)) > 0;

  # can we login to the machine?
  $ez->login($host) || die "cant login";


=head1 DESCRIPTION

This module is intended to make the common uses of Net::FTP a one-line
affair. It was developed to make the development of Net::FTP::Shell 
straightfoward.

=head2 EXPORT

None by default.

=head1 AUTHOR

T. M. Brannon <tbone@cpan.org>

=head1 SEE ALSO

www.metaperl.com, www.rebol.com, Net::FTP (part of the libnet distribution)

=cut
