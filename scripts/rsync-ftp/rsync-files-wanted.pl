package Net::FTP::Backup;

our $Location;

use AppConfig qw(:argcount);
use Data::Dumper;
use File::Find;
use Net::FTP::Common;
use strict;

my $lockfile = '/tmp/net-ftp-common-rsync-files.lck';

sub cleanup {
    warn "closing dup handle";
    close(Net::FTP::Common::DUP);
    unlink $lockfile;
    1;
}

-e $lockfile and 
    cleanup and die "$lockfile must be removed before running script";

my $config = AppConfig->new( {CASE => 1} ) ;
my $rl     = 'Location';

$config->define($rl, { ARGCOUNT => ARGCOUNT_LIST });
$config->file($ENV{NET_FTP_BACKUP});

my $dir = $config->get($rl);

warn Dumper($dir);

foreach (@$dir) {
  $Location = $_;
  find(\&wanted, $_);
}

sub unwanted {
    my $file = shift;

    return 1 if $file =~ /.DS_Store/;
    return 1 if $file =~ /.FBC/;
    return 1 if $file =~ /\.mp3$/;
}

sub wanted {

  last unless -f; 

  if ($Location = '/Users/metaperl') {
    # do not enter subdirs for home dir
    last unless $File::Find::dir eq $Location;
  }

    last if /[\r\n]/s;
    
    my $lf = $_;

    last if unwanted($File::Find::name);

    print $File::Find::name, $/;

}


