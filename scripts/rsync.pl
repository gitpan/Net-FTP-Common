use AppConfig::Std;
use Data::Dumper;
use File::Find;
use Net::FTP::Common;
use strict;


# 
# get connection info
#

my $config = AppConfig::Std->new( { CASE=>1 } );
my $sit  e = 'urth_';
$config->define("$site$_") for qw(User Pass Host RemoteDir Type);
$config->file('/Users/metaperl/.appconfig');
my %urth = $config->varlist("^$site", 1);

#
# setup Net::FTP::Common object
#
our %netftp_cfg =
    (Debug => 1, Timeout => 120);

my $ez = Net::FTP::Common->new(\%urth, %netftp_cfg);

#
# traverse directory tree, uploading files which *dont* exist
# this script is now a mdtm checker. that's for later
#
find(\&wanted, "/Users/metaperl/Documents");

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


