use AppConfig::Std;
use Net::FTP::Common;
use strict;

my $config = AppConfig::Std->new( { CASE=>1 } );

my $site = 'urth_';
$config->define("$site$_") for qw(User Pass Host RemoteDir Type);
$config->file('/Users/metaperl/.appconfig');

my %urth = $config->varlist("^$site", 1);

use Data::Dumper;


our %netftp_cfg =
    (Debug => 1, Timeout => 120);

my $ez = Net::FTP::Common->new(\%urth, %netftp_cfg);



use File::Find;

find(\&wanted, "/Users/metaperl/Documents");

sub remotedir {
    
    my $dir = shift;
    $dir =~ s{Users/metaperl}{home/metaperl/rsync};
    $dir

}

sub unwanted {
    shift =~ /(.FBCIndex)/;
}

our %mkdir;
sub wanted {

    last unless -f;
    last if /[\r\n]/s;
    
    my $lf = $_;
    my $ld =  $File::Find::dir;
    my $rd = remotedir $ld;

    last if unwanted($lf);

    warn "ld: $ld lf: $lf rd: $rd";

    {
      last if $mkdir{$rd};
      $ez->mkdir(RemoteDir => $rd, Recurse => 1);
      $mkdir{$rd}++;
    }
    
    warn "ez->send(LocalFile => $lf, LocalDir => $ld)";

    if ($ez->exists(RemoteFile => $lf, RemoteDir => $rd)) {
      warn "$lf already there.. skipping";
      return;
    }

    $ez->send(LocalFile => $lf, LocalDir => $ld);
}
