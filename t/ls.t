use strict;
use Test;

use Net::FTP::Common;
use Data::Dumper;

BEGIN { plan tests => 4 }

use TestConfig;

# fodder to eliminiate 
# Name "TestConfig::netftp_cfg" used only once: possible typo 
# red herring errors
keys %TestConfig::common_cfg;
keys %TestConfig::netftp_cfg;

#warn Data::Dumper->Dump([\%TestConfig::common_cfg, \%TestConfig::netftp_cfg], [qw(common netftp)]);

my $ez = Net::FTP::Common->new
  (\%TestConfig::common_cfg, %TestConfig::netftp_cfg);



#
# Test 1
#
my @retval = $ez->ls;
ok("@retval", qr/welcome.msg/);

#
# Test 2
#
my @listing =   $ez->ls(RemoteDir => '/pub');
ok("@listing", qr/index.html/);

#
# Test 3
# Let's list the default dir on several hosts
#
$ez->Common(RemoteDir => '/pub');
my @host_list = qw(ftp.fcc.gov ftp.fedworld.gov);
my @host_listings = map { $ez->ls(Host => $_) } @host_list;

ok("@host_listings", qr/reference_tools/);


#
# Test 4
# Let's list several directories on the same host
#
$ez->Common(Host => 'ftp.fedworld.gov');
my @dir_list = qw(/pub/irs-99 /pub/irs-98);
my @dir_listings = map { $ez->ls(RemoteDir => $_) } @dir_list;

ok("@dir_listings", qr/f5500.pdf/);


