use strict;
use Test;

use Net::FTP::Common;
use Data::Dumper;

BEGIN { plan tests => 1 }

my %net_ftp_cfg = (Debug => 1, Timeout => 120, Port => $ENV{ARUFTPD_PORT});

my %common_cfg =
    (
     User => 'tmbranno',           # overwrite anonymous USER default
     Host => 'localhost',       # overwrite ftp.microsoft.com HOST default
     Pass => 'tmbranno',     # overwrite list@rebol.com PASS default
     Dir  => '/341334',   # overwrite slash DIR default
     );

my $ez = Net::FTP::Common->new(\%common_cfg, %net_ftp_cfg);

my $retval = $ez->get(File => '3413341060t.Z');

ok($retval, undef);

