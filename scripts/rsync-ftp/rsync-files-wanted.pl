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
my $rl     = 'rsync_Location';

$config->define($rl, { ARGCOUNT => ARGCOUNT_LIST });
$config->file($ENV{FTP_RSYNC});

my $dir = $config->get($rl);
my  $W  = 'rsync-files-wanted.dat';
open W, ">$W" or die "cannot open $W: $!";

warn Dumper($dir);

find(\&wanted, @$dir);

sub unwanted {
    my $file = shift;
    return 1 if $file =~ /.DS_Store/;
    return 1 if $file =~ /.FBC/;
    return 1 if $file =~ /\.mp3$/;
}

sub wanted {

    last unless -f;
    last if /[\r\n]/s;
    
    my $lf = $_;

    last if unwanted($File::Find::name);

    print W "$File::Find::name\n";

}


