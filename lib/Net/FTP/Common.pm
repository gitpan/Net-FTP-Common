package Net::FTP::Common;

use strict;

use Carp qw(cluck confess);
use Data::Dumper;
use Net::FTP;

use vars qw(@ISA $VERSION);

@ISA     = qw(Net::FTP);

$VERSION = sprintf '%s', q{$Revision: 2.10 $} =~ /\S+\s+(\S+)/ ;

# Preloaded methods go here.

sub new {
  my $pkg  = shift;
  my $common_cfg_in = shift;
  my %netftp_cfg_in = @_;

  my %common_cfg_default = 
    (
     Host => 'ftp.microsoft.com',
     RemoteDir  => '/pub',
     Type => 'I'
    );

  my %netftp_cfg_default = ( Debug => 1, Timeout => 240 );

  # overwrite defaults with values supplied by constructor input
  @common_cfg_default{keys %$common_cfg_in} = values %$common_cfg_in;
  @netftp_cfg_default{keys  %netftp_cfg_in} = values  %netftp_cfg_in;
    
  my $self = {};

  @{$self->{Common}}{keys %common_cfg_default} = values %common_cfg_default;
  @{$self          }{keys %netftp_cfg_default} = values %netftp_cfg_default;

  my $new_self = { %$self, Common => $self->{Common} } ;

  bless $new_self, $pkg;
}

sub Common {
    my $self = shift;
    my %tmp = @_;

    @{$self->{Common}}{keys %tmp} = values %tmp;
}

sub GetCommon {
    my ($self,$key) = @_;

    if ($key) {
	if (defined($self->{Common}{$key})) {
	    return ($self->{Common}{$key});
	} else {
	    return undef;
	}
    } else {
	$self->{Common};
    }
}

sub Host { $_[0]->{Common}->{Host} or die "Host must be defined when creating a __PACKAGE__ object" }

sub NetFTP { 

    my ($self, %config) = @_;

    @{$self}{keys %config} = values %config;

}

sub login {
  my ($self, %config) = @_;

#  my $ftp_session = Net::FTP->new($self->Host, %{$self->{NetFTP}});
  my $ftp_session = Net::FTP->new($self->Host, %$self);

  $ftp_session or return undef;

  my $session;
  my $account = $self->GetCommon('Account');
  if ($self->GetCommon('User') and $self->GetCommon('Pass')) {
      $session = 
	  $ftp_session->login($self->GetCommon('User') , 
			      $self->GetCommon('Pass'),
			      $account);
  } else {
      warn "either User or Pass was not defined. Attempting .netrc for login";
      $session = 
	  $ftp_session->login;
  }

  $session and return $ftp_session 
      or 
	  warn "error logging in: $!" and return undef;

}

sub ls {
  my ($self, @config) = @_;
  my %config=@config;


  my $ftp = $self->prep(%config);

  my $ls = $ftp->ls;
  if (!defined($ls)) {
    return ();
  } else {
    return @{$ls};
  }
}

# contributed by kevin evans
# this returns a hash of hashes keyed by filename with attributes for each
sub dir {       
  my ($self, @config) = @_;
  my %config=@config;


  my $ftp = $self->prep(%config);

  my $dir = $ftp->dir;
  if (!defined($dir)) {
    return ();
  } else
  {
    my %HoH;
    foreach (@{$dir})
        {
        $_ =~ m#([a-z-]*)\s*([0-9]*)\s*([0-9a-zA-Z]*)\s*([0-9a-zA-Z]*)\s*([0-9]*)\s*([A-Za-z]*)\s*([0-9]*)\s*([0-9A-Za-z:]*)\s*([A-Za-z0-9.-]*)#;

        my $perm = $1;
        my $inode = $2;
        my $owner = $3;
        my $group = $4;
        my $size = $5;
        my $month = $6;
        my $day = $7;
        my $yearOrTime = $8;
        my $name = $9;
        my $linkTarget;

        if ( $' =~ m#\s*->\s*([A-Za-z0-9.-/]*)# )       # it's a symlink
                { $linkTarget = $1; }

        $HoH{$name}{perm} = $perm;
        $HoH{$name}{inode} = $inode;
        $HoH{$name}{owner} = $owner;
        $HoH{$name}{group} = $group;
        $HoH{$name}{size} = $size;
        $HoH{$name}{month} = $month;
        $HoH{$name}{day} = $day;
        $HoH{$name}{yearOrTime} =  $yearOrTime;
        $HoH{$name}{linkTarget} = $linkTarget;

        }
  return(%HoH);
  }
}



sub mkdir {
    my ($self,%config) = @_;

    my $ftp = $self->prep(%config);

    $ftp->mkdir($self->GetCommon('RemoteDir'), $self->GetCommon('Recurse'));
}

# The Perl -e operator for files on a remote site. Even though the
# REBOL exists? word works on local files as well as URL's, Perl's does 
# not. Shame isn't it? :-)

sub exists {
    my ($self,%cfg) = @_;

    my @listing = $self->ls(%cfg);

    my $rf = $self->GetCommon('RemoteFile');

    warn sprintf "checking @listing for %s", $rf;

    scalar grep { $_ eq $self->GetCommon('RemoteFile') } @listing;
}

sub grep {

    my ($self,%cfg) = @_;

#    warn sprintf "self: %s host: %s cfg: %s", $self, $host, Data::Dumper::Dumper(\%cfg);

    my @listing = $self->ls(%cfg);

    grep { $_ =~ /$cfg{Grep}/ } @listing;
}


# Really, the best abstraction would be:
# ftp_download_all_with_hook where the hook in this case would be a
# coderef that conditionally decrypts the downloaded file
# Laziness now will lead to more work later I guess.

sub prep {
  my $self = shift;
  my %cfg  = @_;

  $self->Common(%cfg);
  
  my $ftp = $self->login;
  if ($self->{Common}->{RemoteDir}) {
      $ftp->cwd($self->GetCommon('RemoteDir'))
  } else {
      warn "RemoteDir not configured. ftp->cwd will not work. certain Net::FTP usages will failed.";
  }
  $ftp->type($self->GetCommon('Type'));

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

  my $ftp = $self->prep(%cfg);

  my $r;

  $ftp->hash;

  my $file;
  if ($self->GetCommon('LocalFile')) {
      $file= $self->GetCommon('LocalFile');
  } else {
      $file=$self->GetCommon('RemoteFile');
  }
	
  my $local_file = join '/', ($self->GetCommon('LocalDir'), $file);
		

  if ($r = $ftp->get($self->GetCommon('RemoteFile'), $local_file)) {
      return $r;
  } else { 
    warn sprintf "download of %s to %s failed",
	  $self->GetCommon('RemoteFile'), $self->GetCommon('LocalFile');
    return undef;
}
  

}

sub file_attr {
    my $self = shift;
    my %hash;
    my @key = qw(LocalFile LocalDir RemoteFile RemoteDir);
    @hash{@key} = @{$self->{Common}}{@key};
    %hash;
}

sub bad_filename {
    shift =~ /[\r\n]/s;
}

sub send {
  my ($self,%cfg) = @_;

  my $ftp = $self->prep(%cfg);

  my %fa = $self->file_attr;

  if (bad_filename($fa{LocalFile})) {
      warn "filenames may not have CRLF in them. skipping $fa{LocalFile}";
      return;
  }


  use Data::Dumper;

  my $lf = sprintf "%s/%s", $fa{LocalDir}, $fa{LocalFile};
  my $RF = $fa{RemoteFile} ? $fa{RemoteFile} : $fa{LocalFile};
  my $rf = sprintf "%s/%s", $fa{RemoteDir}, $RF;

  $ftp->put($lf, $rf) or 
      die sprintf "upload of %s to %s failed", $lf, $rf;
}

sub put { goto &send }


1;
__END__

=head1 NAME

Net::FTP::Common - Perl extension for simplifying common usages of Net::FTP.

=head1 SYNOPSIS

 our %netftp_cfg = 
    (Debug => 1, Timeout => 120);

 our %common_cfg =    
    (
     # 
     # The first 2 options, if not present, 
     # lead to relying on .netrc for login
     #
     User => 'anonymous',           
     Pass => 'tbone@cpan.org',      

     #
     # Other options
     #

     LocalDir  => '/tmp/downloads'   # setup something for $ez->get
     LocalFile => 'delete.zip'       # setup something for $ez->get
     Host => 'ftp.fcc.gov',          # overwrite ftp.microsoft.com default
     RemoteDir  => '/',                    # automatic CD on remote machine to RemoteDir
     Type => 'A'                     # overwrite I (binary) TYPE default
     );

  # NOTE WELL!!! one constructor arg is  passed by reference, the 
  # other by value. This is inconsistent, but still it is A Good Thing.
  # Believe me! I thought about this. And I have a good reason for it:
  # This is to allow the least modification of legacy Net::FTP source code.

  $ez = Net::FTP::Common->new(\%common_cfg, %netftp_config); 

  # can we login to the machine?
  # Note: it is NEVER necessary to first login before calling
  # Net::FTP::Common API functions.                                
  # This function is just for checking to see if a machine is up. 
  # It is published as part of the API because I have found it 
  # useful when writing FTP scripts which scan for the 
  # first available FTP site to use for upload. The exact 
  # call-and-return semantics for this function are described
  # and justified below.

  $ez->login or die "cant login: $@";

  # Get a listing of a remote directory 
 
  @listing =	$ez->ls; 

  # Let's list a different directory, over-riding and changing the
  # default directory
 
  @listing =	$ez->ls(RemoteDir => '/pub/rfcs'); 

  # Let's list the default dir on several hosts
 
 @host_listings = map { $ez->ls(Host => $_) } @host_list

  # Let's get the listings of several directories

  @dir_listings  = map { $ez->ls(RemoteDir  => $_) } @dir_list;

  # Let's get a detailed directory listing... (thanks Kevin!)
 
  %listing =	$ez->dir; # Note this is a hash, not an array return value.

  ### representative output

            'test' => {
                      'owner' => 'root',
                      'month' => 'Jan',
                      'linkTarget' => undef,
                      'inode' => '1',
                      'size' => '6',
                      'group' => 'root',
                      'yearOrTime' => '1999',
                      'day' => '27',
                      'perm' => '-rw-r--r--'
                    },
          'ranc' => {
                      'owner' => 'root',
                      'month' => 'Oct',
                      'linkTarget' => undef,
                      'inode' => '2',
                      'size' => '4096',
                      'group' => 'root',
                      'yearOrTime' => '00:42',
                      'day' => '31',
                      'perm' => 'drwxr-xr-x'
                    }

  # Get a file from the remote machine

  $ez->get(RemoteFile => 'codex.txt', LocalFile => '/tmp/crypto.txt');

  # Get a file from the remote machine, specifying dir:
  $ez->get(RemoteFile => 'codex.txt', LocalDir => '/tmp');

  # NOTE WELL:  because the prior call set LocalFile, it is still a
  # part of the object store. In other words this example will try
  # to store the downloaded file in /tmp/tmp/crypto.txt.
  # Better to say:

  $ez->get(RemoteFile => 'codex.txt', LocalDir => '/tmp', LocalFile => '');


  # Send a file to the remote machine (*dont* use put!)

  $ez->send(RemoteFile => 'codex.txt');

  # test for a file's existence on the remote machine (using =~)

  @file = $ez->grep(Grep => qr/[A-M]*[.]txt/);


  # test for a file on the remote machine (using eq)

  $ez->exists(RemoteFile => 'needed-file.txt');

  # note this is no more than you manually calling:
  # (scalar grep { $_ eq 'needed-file.txt' } $ez->ls) > 0;

The test suite contains plenty of common examples.

=head1 IMPORTANT API CHANGES

=over 4

=item File is now RemoteFile

=back

=head1 DESCRIPTION

This module is intended to make the common uses of Net::FTP a
one-line, no-argument affair. In other words, you have 100% programming with
Net::FTP. With Net::FTP::Common you will have 95% configuration and 5%
programming.  

The way that it makes it a one-line affair is that the common
pre-phase of login, cd, file type (binary/ascii) is handled for
you. The way that it makes usage a no-argument affair is by pulling
things from the hash that configured it at construction time. Should
arguments be supplied to any API function, then these changes are applied to
the hash of the object's state and used by any future-called API function
which might need them.

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

=head2 C<$ez = Net::FTP::Common->new($net_ftp_common_hashref, %net_ftp_hash)>

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

           $common_cfg = { Host => 'some.host.name', 
			   User => 'anonymous',
			   Pass => 'me@here.there',
			   RemoteDir  => '/pub'
			   }	

           $ftp = Net::FTP::Common->new($common_cfg, Debug => 0);
           $ftp->get("that.file");
           $ftp->quit;


=head2 $ez->Common(%config)

This is hardly ever necessary to use in isolation as all public API methods
will call this as their first step in processing your request. However, it is
available should you wish to extend this module.

=head2 $ez->GetCommon($config_key)

Again, this is hardly ever necessary to use in isolation. However, it is
available should you wish to extend this module.

=head2 $ez->NetFTP(%netftp_config_overrides)

This creates and returns a Net::FTP object. In this case, any overrides are 
shuttled onward to the Net::FTP object as opposed to the configuration of the 
Net::FTP::Common object.

Also note that any overrides are preserved and used for all future calls.

=head2 $ez->login(%override)

This logs into an FTP server. C<%override> is optional. It relies on 2
Common configuration options, C<User> and C<Pass>, which, if not present
load to logging in via a .netrc file.

Normal login with C<User> and C<Pass> are tested. .netrc logins are not.


=head2 $ez->ls (%override)

When given no arguments, C<ls()> uses Common configuration
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
 map { @{$dir{$_}} = $ftp->ls(RemoteDir => $_ ) } @dir;

=head2 $ez->dir (%override)

When given no arguments, C<dir()> uses Common configuration
information to login to the ftp site, change directory and transfer
type and then return a hash of with detailed description of directory 
contents. You may only call
this routine and expect a hash back.

You may give this function any number of configuration arguments to over-ride the predefined configuration options. 

Here is the results of the example from the the test suite (t/dir.t):

 my %retval = $ez->dir;
 use Data::Dumper;
 warn "NEW_DIR ...", Dumper(\%retval);

          'incoming' => {
                          'owner' => 'root',
                          'month' => 'Jul',
                          'linkTarget' => undef,
                          'inode' => '2',
                          'size' => '4096',
                          'group' => 'root',
                          'yearOrTime' => '2001',
                          'day' => '10',
                          'perm' => 'drwxrwxrwx'
                        },

          'test' => {
                      'owner' => 'root',
                      'month' => 'Jan',
                      'linkTarget' => undef,
                      'inode' => '1',
                      'size' => '6',
                      'group' => 'root',
                      'yearOrTime' => '1999',
                      'day' => '27',
                      'perm' => '-rw-r--r--'
                    },
          'SEEMORE-database' => {
                                  'owner' => 'mel',
                                  'month' => 'Aug',
                                  'linkTarget' => 'image',
                                  'inode' => '1',
                                  'size' => '14',
                                  'group' => 'lnc',
                                  'yearOrTime' => '20:35',
                                  'day' => '15',
                                  'perm' => 'lrwxrwxrwx'
                                },
          'holt' => {
                      'owner' => 'holt',
                      'month' => 'Jun',
                      'linkTarget' => undef,
                      'inode' => '2',
                      'size' => '4096',
                      'group' => 'daemon',
                      'yearOrTime' => '2000',
                      'day' => '12',
                      'perm' => 'drwxr-xr-x'
                    },
          'SEEMORE-images' => {
                                'owner' => 'mel',
                                'month' => 'Aug',
                                'linkTarget' => 'images',
                                'inode' => '1',
                                'size' => '6',
                                'group' => 'lnc',
                                'yearOrTime' => '20:35',
                                'day' => '15',
                                'perm' => 'lrwxrwxrwx'
                              },
          'dlr' => {
                     'owner' => 'root',
                     'month' => 'Sep',
                     'linkTarget' => undef,
                     'inode' => '2',
                     'size' => '4096',
                     'group' => 'root',
                     'yearOrTime' => '1998',
                     'day' => '11',
                     'perm' => 'drwxr-xr-x'
                   },
          'fiser' => {
                       'owner' => '506',
                       'month' => 'May',
                       'linkTarget' => undef,
                       'inode' => '2',
                       'size' => '4096',
                       'group' => 'daemon',
                       'yearOrTime' => '1996',
                       'day' => '25',
                       'perm' => 'drwxr-xr-x'
                     },


=head2 $ez->mkdir (%override)

Makes directories on remote FTP server. Will recurse if Recurse => 1 is
in object's internal state of overridden at method call time. 

This function has no test case but a working example of its use is in 
C<scripts/rsync.pl>. I use it to back up my stuff.

=head2 $ez->exists (%override)

uses the C<RemoteFile> option of object internal state (or override) to check for a
file in a directory listing. This means a C<eq>, not regex match.

=head2 $ez->grep(%override)


uses the C<Grep> option of object internal state (or override) to check for a
file in a directory listing. This means a regex, not C<eq> match.


=head2 $ez->get(%override)


uses the C<RemoteFile>, C<LocalFile>, and C<LocalDir> options of object internal 
state 
(or override) to download a file. No slashes need be appended to the end of
C<LocalDir>. If C<LocalFile> and C<LocalDir> arent defined, then the file
is written to the current directory. C<LocalDir> must exist: 
C<Net::FTP::Common> will not create it for you.

All of the following have test cases and work:

  LocalDir    LocalFile  Action
  --------    ---------  ------
  null        null       download to local dir using current dir
  null        file       download to local dir using current dir but spec'ed file
  dir         null       download to spec'ed dir using remote file name
  dir         file       download to spec'ed dir using spec'ed file name

null is any Perl non-true value... 0, '', undef.

=head2 $ez->send(%override)

=head1 TRAPS FOR THE UNWARY

=item *

  @file = $ez->grep(Grep => '[A-M]*[.]txt');
  
is correct

  @file = $ez->grep('[A-M]*[.]txt');

looks correct but is not because you did not name the argument as you are 
supposed to.

=head1 NOTES

=over 4

=item * A slide talk on Net::FTP::Common in HTML format is available at

  http://www.metaperl.com

=item * big change from version after 2.30:

C<Dir> has been changed to C<RemoteDir> to avoid confusion.

=item * on object destruction:

When a Net::FTP::Common object is goes out of scope, the following
warning is thrown by Net::FTP:

 (in cleanup) Not a GLOB reference at Net/FTP.pm line 147.

This is a harmless error that I should fix some day.

=item * parsing FTP list output

This output is not standard. We did a fair job for most common Unixen, but
if we aspire to the heights of an ange-ftp or other high-quality FTP
client, we need something like they have in python:

     http://freshmeat.net/redir/ftpparsemodule/20709/url_homepage/

=back

=head1 AUTHOR

T. M. Brannon <tbone@cpan.org>

dir() method contributed by Kevin Evans (kevin _! a t (* i n s i g ht dot-com

=cut
