use strict;
use Test;

use Net::FTP::Common;
use Data::Dumper;

BEGIN { plan tests => 4 }

use TestConfig;

# fodder to eliminate
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
my @retval = sort $ez->ls;
ok("@retval", qr/README/);

#
# Test 2
#
my @listing =   $ez->ls(RemoteDir => '/');
warn "L: @listing";
ok("@listing", qr/for_mirrors_only/);

#
# Test 3
# Let's list the default dir on several hosts
#
$ez->Common(RemoteDir => '/pub');
my @host_list = qw(ftp.kernel.org ftp.dartmouth.edu);
my @a;
for (@host_list) {
    warn $_;
    push @a, ($ez->ls(Host => $_)) ;
}
warn "push_ver: ", Dumper(\@a);

my @host_listings = map { $ez->ls(Host => $_) } @host_list;

warn "map_ver: ", Dumper(\@host_listings);

ok("@host_listings", qr/majordomo-docs.+security/);


#
# Test 4
# Let's list several directories on the same host
#
$ez->Common(Host => 'ftp.dartmouth.edu');
my @dir_list = qw(/pub/software /pub/floods);
my @dir_listings = map { $ez->ls(RemoteDir => $_) } @dir_list;

warn "complete dir listing: @dir_listings", Dumper \@dir_listings;
ok("@dir_listings", qr/image/);


