use strict;
use Test;

use Net::FTP::Common;
use Data::Dumper;

BEGIN { plan tests => 2 }

use TestConfig;

# fodder to eliminiate 
# Name "TestConfig::netftp_cfg" used only once: possible typo 
# red herring errors
keys %TestConfig::common_cfg;
keys %TestConfig::netftp_cfg;

warn Data::Dumper->Dump([\%TestConfig::common_cfg, \%TestConfig::netftp_cfg], [qw(common netftp)]);

my $ez = Net::FTP::Common->new
  (\%TestConfig::common_cfg, %TestConfig::netftp_cfg);

#
# Test 1
#
my @retval = $ez->grep(Grep => qr/^wel/);
warn "GREP RETVAL: @retval";
ok("@retval","welcome.msg");


#
# Test 2
#
my $retval = $ez->exists(File => 'welcome.msg');
ok($retval);

