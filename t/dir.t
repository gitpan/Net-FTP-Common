use strict;
use Test;

use Net::FTP::Common;
use Data::Dumper;

BEGIN { plan tests => 4 }

my %net_ftp_cfg = (Debug => 1, Timeout => 120);

my %common_cfg =
    (
     User => 'anonymous',           # overwrite anonymous USER default
     Host => 'lnc.usc.edu',       # overwrite ftp.microsoft.com HOST default
     Pass => 'tbone@cpan.org',     # overwrite list@rebol.com PASS default
     Dir  => '/pub/image-database',   # overwrite slash DIR default
     Type => 'A'                   # overwrite I (binary) TYPE default
     );

my $ez = Net::FTP::Common->new(\%common_cfg, %net_ftp_cfg);


#
# Test 1
#
my @retval = $ez->dir;
ok("@retval", "Database-Small.ps.gz images.tar.gz README ObjectList");

#
# Test 2
#
my @listing =   $ez->dir( New => { Dir => '/pub/dlr' } );
ok("@listing", "images.tar.gz gen_seq.C 71_15.gif rf.ps.Z 71_15.tiff 71_15_col_mod.tif review.ps.Z coottha8.642.rs.im glade_all.tif me.tif");

#
# Test 3
# Let's list the default dir on several hosts
#
$ez->Config(New => { Dir => '/pub' });
my @host_list = qw(gatekeeper.dec.com lnc.usc.edu);
my @host_listings = map { $ez->dir( New => { Host => $_ } ) } @host_list;

#warn "@host_listings";
ok("@host_listings","net mozilla X11 database graphics plan data multimedia comm mail misc news text sf DEC GNU BSD VMS micro recipes doc standards published Mach NIST Digital athena editors games maps usenet usenix sysadm case forums conferences Alpha X11-contrib dcpi digital recipes.tar.Z linux SysManSwMgr compaq winston mel karchie fiser dlr holt images image-database room-images test SEEMORE-code SEEMORE-database SEEMORE-images incoming");


#
# Test 4
# Let's list several directories on the same host
#

my @dir_list = qw(/pub/holt /pub/fiser);
my @dir_listings = map { $ez->dir( New => { Dir => $_ } ) } @dir_list;

#warn "@dir_listings";
ok("@dir_listings","nrn-4.2.2.tar.gz iv-3.2a-hines11.tar.gz h5pp.tar.gz h5pp.zip qpixmap_bug.shar xroute.11.9.94.tar feature.C binding.eps features.eps graphs.eps");


