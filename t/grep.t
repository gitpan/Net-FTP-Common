use strict;
use Test;

use Net::FTP::Common;
use Data::Dumper;

BEGIN { plan tests => 3 }

my %net_ftp_cfg = (Debug => 1, Timeout => 120);

my %common_cfg =
    (
     User => 'anonymous',           # overwrite anonymous USER default
     Host => 'lnc.usc.edu',       # overwrite ftp.microsoft.com HOST default
     Pass => 'tbone@cpan.org',     # overwrite list@rebol.com PASS default
     Dir  => '/pub/dlr',   # overwrite slash DIR default
     Type => 'A'                   # overwrite I (binary) TYPE default
     );

my $ez = Net::FTP::Common->new(\%common_cfg, %net_ftp_cfg);


#
# Test 1
#
my @retval = $ez->grep(File => 'tiff$');
ok("@retval","71_15.tiff");


#
# Test 2
#
my @retval = $ez->glob(File => 'tif');
warn "@retval";
ok("@retval","71_15.tiff 71_15_col_mod.tif glade_all.tif me.tif");

#
# Test 3
#
my $retval = $ez->exists(File => 'gen_seq.C');
ok($retval);

