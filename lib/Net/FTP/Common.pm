package Net::FTP::Common;

use strict;

use Carp qw(cluck confess);
use Data::Dumper;
use Net::FTP;


use vars qw(@ISA $VERSION);

@ISA     = qw(Net::FTP);

$VERSION = '5.31';

# Preloaded methods go here.

sub new {
  my $pkg  = shift;
  my $common_cfg_in = shift;
  my %netftp_cfg_in = @_;

  my %common_cfg_default = 
    (
     Host => 'ftp.microsoft.com',
     RemoteDir  => '/pub',
#     LocalDir  => '.',   # setup something for $ez->get
     Type => 'I'
    );

  my %netftp_cfg_default = ( Debug => 1, Timeout => 240, Passive => 1 );

  # overwrite defaults with values supplied by constructor input
  @common_cfg_default{keys %$common_cfg_in} = values %$common_cfg_in;
  @netftp_cfg_default{keys  %netftp_cfg_in} = values  %netftp_cfg_in;
    
  my $self = {};

  @{$self->{Common}}{keys %common_cfg_default} = values %common_cfg_default;
  @{$self          }{keys %netftp_cfg_default} = values %netftp_cfg_default;

  my $new_self = { %$self, Common => $self->{Common} } ;

  if (my $file = $self->{Common}{STDERR}) {
      open DUP, ">$file" or die "cannot dup STDERR to $file: $!";
      lstat DUP; # kill used only once error
      open STDERR, ">&DUP";
  }

  warn "Net::FTP::Common::VERSION = ", $Net::FTP::Common::VERSION  
      if $self->{Debug} ;


  bless $new_self, $pkg;
}

sub config_dump {
  my $self = shift;
  
  sprintf '
Here are the configuration parameters:
-------------------------------------
%s
', Dumper($self);

}


sub Common {
    my $self = shift;

    not (@_ % 2) or die 
"
Odd number of elements in assignment hash in call to Common().
Common() is a 'setter' subroutine. You cannot call it with an
odd number of arguments (e.g. $self->Common('Type') ) and 
expect it to get a value. use GetCommon() for that.

Here is what you passed in.
", Dumper(\@_);

    my %tmp = @_;

#    warn "HA: ", Dumper(\%tmp,\@_);

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

sub Host { 
    $_[0]->{Common}->{Host}

      or die "Host must be defined when creating a __PACKAGE__ object"
}

sub NetFTP { 

    my ($self, %config) = @_;

    @{$self}{keys %config} = values %config;

}

sub login {
  my ($self, %config) = @_;

  shift;

  if (@_ % 2) {
    die sprintf "Do not confuse Net::FTP::Common's login() with Net::FTP's login()
Net::FTP::Common's login() expects to be supplied a hash. 
E.g. \$ez->login(Host => \$Host)

It was called incorrectly (%s). Program terminating
%s
", (join ':', @_), $self->config_dump;
  }

#  my $ftp_session = Net::FTP->new($self->Host, %{$self->{NetFTP}});
  my $ftp_session = Net::FTP->new($self->Host, %$self);

#  $ftp_session or return undef;
  $ftp_session or 
      die sprintf 'FATAL: attempt to create Net::FTP session on host %s failed.
If you cannot figure out why, supply the configuration parameters when
emailing the support email list.
  %s', $self->Host, $self->config_dump;


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

  $session and ($self->Common('FTPSession', $ftp_session)) 
    and return $ftp_session 
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

    # Comments were made on this code in this thread:
    # http://perlmonks.org/index.pl?node_id=287552

    foreach (@{$dir})
        {
	    # $_ =~ m#([a-z-]*)\s*([0-9]*)\s*([0-9a-zA-Z]*)\s*([0-9a-zA-Z]*)\s*([0-9]*)\s*([A-Za-z]*)\s*([0-9]*)\s*([0-9A-Za-z:]*)\s*([A-Za-z0-9.-]*)#;
	  #$_ = m#([a-z-]*)\s*([0-9]*)\s*([0-9a-zA-Z]*)\s*([0-9a-zA-Z]*)\s*([0-9]*)\s*([A-Za-z]*)\s*([0-9]*)\s*([0-9A-Za-z:]*)\s*([\w*\W*\s*\S*]*)#;

=for comment

drwxr-xr-x    8 0        0            4096 Sep 27  2003 .
drwxr-xr-x    8 0        0            4096 Sep 27  2003 ..
drwxr-xr-x    3 0        0            4096 Sep 11  2003 .afs
-rw-r--r--    1 0        0             809 Sep 26  2003 .banner
----r-xr-x    1 0        0               0 Mar  4  2002 .notar
-rw-r--r--    1 0        0             796 Sep 27  2003 README

=cut

	  warn "input-line: $_" if $self->{Debug} ;

	  $_ =~ m!^
	    ([\-FlrwxsStTdD]{10})  # directory and permissions
	    \s+
	    (\d+)                  # inode
	    \s+
	    (\w+)                  # 2nd number
	    \s+
	    (\w+)                  # 3rd number
	    \s+
	    (\d+)                  # file/dir size
	    \s+
	    (\w{3,4})         # month
	    \s+
	    (\d{1,2})         # day
	    \s+
	    (\d{1,2}:\d{2}|\d{4})           # year
	    \s+
		(.+) # filename
		  $!x;


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

	  warn "
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
" if $self->{Debug} ;

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

	  warn "regexp-matches for ($name): ", Dumper(\$HoH{$name}) if $self->{Debug} ;

        }
  return(%HoH);
  }
}



sub mkdir {
    my ($self,%config) = @_;

    my $ftp = $self->prep(%config);
    my $rd =  $self->GetCommon('RemoteDir');
    my $r  =  $self->GetCommon('Recurse');
    $ftp->mkdir($rd, $r);
}


sub exists {
    my ($self,%cfg) = @_;

    my @listing = $self->ls(%cfg);

    my $rf = $self->GetCommon('RemoteFile');

   warn sprintf "[checking @listing for [%s]]", $rf if $self->{Debug} ;

    scalar grep { $_ eq $self->GetCommon('RemoteFile') } @listing;
}

sub delete {
    my ($self,%cfg) = @_;

    my $ftp = $self->prep(%cfg);
    my $rf  = $self->GetCommon('RemoteFile');

    
    warn Dumper \%cfg;

    $ftp->delete($rf);

}

sub grep {

    my ($self,%cfg) = @_;

#    warn sprintf "self: %s host: %s cfg: %s", $self, $host, Data::Dumper::Dumper(\%cfg);

    my @listing = $self->ls(%cfg);

    grep { $_ =~ /$cfg{Grep}/ } @listing;
}

sub connected {
    my $self = shift;

#    warn "CONNECTED SELF ", Dumper($self);

    my $session = $self->GetCommon('FTPSession') or return 0;

    local $@;
    my $pwd;
    my $connected = $session->pwd ? 1 : 0;
#    warn "connected: $connected RESP: $connected";
    $connected;
}

sub quit {
    my $self = shift; 

    $self->connected and $self->GetCommon('FTPSession')->quit;

}


sub prepped {
    my $self = shift; 
    my $prepped = $self->GetCommon('FTPSession') and $self->connected;
    #    warn "prepped: $prepped";
    $prepped;
}

sub prep {
  my $self = shift;
  my %cfg  = @_;

  $self->Common(%cfg);

# This will not work if the Host changes and you are still connected 
# to the prior host. It might be wise to simply drop connection 
# if the Host key changes, but I don't think I will go there right now.
#  my $ftp = $self->connected 
#                  ? $self->GetCommon('FTPSession') 
#                  : $self->login ;
# So instead:
  my $ftp = $self->login ;

  
  $self->Common(LocalDir => '.') unless
      $self->GetCommon('LocalDir') ;

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

  my $file;

  if ($self->GetCommon('LocalFile')) {
    $file= $self->GetCommon('LocalFile');
  } else {
    $file=$self->GetCommon('RemoteFile');
  }
	
  my $local_file = join '/', ($self->GetCommon('LocalDir'), $file);
		
  #  warn "LF: $local_file ", "D: ", Dumper($self);


  if ($r = $ftp->get($self->GetCommon('RemoteFile'), $local_file)) {
    return $r;
  } else { 
    warn sprintf 'download of %s to %s failed',
	$self->GetCommon('RemoteFile'), $self->GetCommon('LocalFile');
    warn 
	'here are the settings in your Net::FTP::Common object: %s',
	    Dumper($self);
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

  #  warn "send_self", Dumper($self);

  my %fa = $self->file_attr;

  if (bad_filename($fa{LocalFile})) {
      warn "filenames may not have CRLF in them. skipping $fa{LocalFile}";
      return;
  }

  warn "send_fa: ", Dumper(\%fa) if $self->{Debug} ;


  my $lf = sprintf "%s/%s", $fa{LocalDir}, $fa{LocalFile};
  my $RF = $fa{RemoteFile} ? $fa{RemoteFile} : $fa{LocalFile};
  my $rf = sprintf "%s/%s", $fa{RemoteDir}, $RF;

  warn "[upload $lf as $rf]" if $self->{Debug} ;

  $ftp->put($lf, $RF) or 
      confess sprintf "upload of %s to %s failed", $lf, $rf;
}

sub put { goto &send }

sub DESTROY {


}


1;
__END__

=head1 NAME

Net::FTP::Common - simplify common usages of Net::FTP

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


     LocalFile => 'delete.zip'   # setup something for $ez->get
     Host => 'ftp.fcc.gov',      # overwrite ftp.microsoft.com default
     LocalDir   => '/tmp',
     RemoteDir  => '/',          # automatic CD on remote machine to RemoteDir
     Type => 'A'                 # overwrite I (binary) TYPE default
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

  # Let's get all output written to STDERR to goto a logfile

  my $ez = Net::FTP::Common->new( { %CFG, STDERR => $logfile }, %netftp_cfg);

The test suite contains plenty of common examples.

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


=head2 %retval = $ez->dir (%override)

B<this function returns a hash NOT an array>

When given no arguments, C<dir()> uses Common configuration
information to login to the ftp site, change directory and transfer
type and then return a hash of with detailed description of directory 
contents. You may only call
this routine and expect a hash back.

You may give this function any number of configuration arguments to over-ride the predefined configuration options. 

Here is the results of the example from the the test suite (t/dir.t):

 my %retval = $ez->dir;

# warn "NEW_DIR ...", Dumper(\%retval);

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

=head2 $ez->delete (%override)

This function logins into the remote machine, changes to C<RemoteDir> and then 
issues C<$ftp->delete> on C<RemoteFile>

In the C<samples/delete-file> directory of the distribution 
exists files called 
C<upload.pl> and C<download.pl> which together with C<Login.pm> will log into 
a system and upload or delete the C<upfile>

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

IMPORTANT: C<LocalDir> must be set when you create a Net::FTP::Common object 
(i.e, when you call Net::FTP::Common->new) or your Net::FTP::Common will
default C<LocalDir> to "." and warn you about it.



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

=item * 

also note that the Net::FTP::Common login() function expects to be passed a
hash, while the Net::FTP login() function expets to be passed a scalar.

=head1 NOTES

=over 4

=item * A good example of Net::FTP::Common usage comes with your download:

C<scripts/rsync.pl>

Although this script
requires AppConfig, Net::FTP::Common in general does not... but go get
AppConfig anyway, it rocks the house.

=item * A slide talk on Net::FTP::Common in HTML format is available at

  http://www.metaperl.com

=item * subscribe to the mailing list via

net-ftp-common-subscribe@yahoogroups.com

=head1 * A harmless warning

When a Net::FTP::Common object is goes out of scope, the following warning 
is thrown by Net::FTP: 

  Not a GLOB reference at Net/FTP.pm line 147.

This is a harmless warning that I should fix some day. 

=back

=head1 TODO

=head2 Definite


=over 4

=item * replace parsing in dir() with lwp's File::Listing::line()

=item * adding a warning about any keys passed that are not recognised 

=item * support resumeable downloads

=back

=head2 Musings

=over 4

=item * Cache directory listings?

=item * parsing FTP list output

This output is not standard. We did a fair job for most common Unixen, but
if we aspire to the heights of an ange-ftp or other high-quality FTP
client, we need something like they have in python:

     http://freshmeat.net/redir/ftpparsemodule/20709/url_homepage/


=back

=head1 Net::FTP FAQ

Because I end up fielding so many Net::FTP questions, I feel it best to start a
small FAQ.

=head2 Trapping fatal exceptions

http://perlmonks.org/index.pl?node_id=317408

=head1 SEE ALSO

=over 4

=item 

=item * http://lftp.yar.ru

=item * L<Net::FTP::Recursive|Net::FTP::Recursive>

=item * L<Net::FTP::blat>

=item * L<Tie::FTP>

=back


=head1 AUTHOR

T. M. Brannon <tbone@cpan.org>

=head2 Acknowledgements

=over 4

=item * Kevin Evans

dir() method contributed by Kevin Evans (kevin  a t  i n s i g h t dot-com)

=item * Matthew Browning (matthewb on perlmonks)

pointed out a problem with the dir() regexp which then led to me 
plagiarizing a healthy section of File::Listing::line() from the LWP
distro.

=back

=cut
