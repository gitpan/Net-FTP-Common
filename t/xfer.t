use strict;
use Test;

use Net::FTP::Common;
use Data::Dumper;

BEGIN { plan tests => 1 }

my %net_ftp_cfg = (Debug => 1, Timeout => 120);

my %common_cfg =
    (
     User => 'anonymous',           # overwrite anonymous USER default
     Host => 'lnc.usc.edu',       # overwrite ftp.microsoft.com HOST default
     Pass => 'tbone@cpan.org',     # overwrite list@rebol.com PASS default
     Dir  => '/pub/holt',   # overwrite slash DIR default
     Type => 'A'                   # overwrite I (binary) TYPE default
     );

my $ez = Net::FTP::Common->new(\%common_cfg, %net_ftp_cfg);


#
# Test 1
#
my $retval = $ez->get(File => 'h5pp.tar.gz', LocalFile => 'dl.C');
ok($retval);

