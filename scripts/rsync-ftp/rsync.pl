use AppConfig qw(:argcount);
use Data::Dumper;
use File::Find;
use Net::FTP::Common;
use strict;


my $lockfile = '/tmp/net-ftp-rsync.lck';

-e $lockfile and die "$lockfile must be removed before running script";

#open L, ">$lockfile" or die "couldn't open $lockfile for writing: $!";
#open(STDERR, ">&L");


# 
# get connection info
#

my $config = AppConfig->new( {CASE => 1} ) ;
my $site   = 'urth_';
my $rl     = 'rsync_Location';

$config->define("$site$_", { ARGCOUNT => ARGCOUNT_ONE  } ) 
    for qw(User Pass Host RemoteDir Type);
$config->define($rl,       { ARGCOUNT => ARGCOUNT_LIST });
my $dir = $config->get($rl);

$config->file('/Users/metaperl/.appconfig');

my %urth = $config->varlist("^$site", 1);


#
# setup Net::FTP::Common object
#
our %netftp_cfg = (Debug => 1, Timeout => 120);
my $ez = Net::FTP::Common->new({ %urth, STDERR => $lockfile }, %netftp_cfg);

warn Data::Dumper->Dump([\%urth, $dir],[qw(urth dir)]);

find(\&wanted, @$dir);

#
# convert local absolute paths to remote absolute paths
#
sub remotedir {
    my $dir = shift;
    $dir =~ s{Users/metaperl}{home/metaperl/rsync};
    $dir

}


sub unwanted {
    my $file = shift;
    return 1 if $file =~ /.DS_Store/;
    return 1 if $file =~ /.FBC/;
    return 1 if $file =~ /\.mp3$/;
}

our %mkdir;
sub wanted {

    last unless -f;
    last if /[\r\n]/s;
    
    my $lf = $_;
    my $ld =  $File::Find::dir;
    my $rd = remotedir $ld;

    last if unwanted($File::Find::name);

    warn "ld: $ld lf: $lf rd: $rd";

    {
      last if $mkdir{$rd};
      $ez->mkdir(RemoteDir => $rd, Recurse => 1);
      $mkdir{$rd}++;
    }
    
    if ($ez->exists(RemoteFile => $lf, RemoteDir => $rd)) {
      warn "$lf already there in $rd... skipping";
      return;
    }

    warn "ez->send(LocalFile => $lf, LocalDir => $ld)";
    $ez->send(LocalFile => $lf, LocalDir => $ld);
}


close(Net::FTP::Common::DUP);

unlink $lockfile;
