package Net::FTP::Backup;

our $Location;

use AppConfig qw(:argcount);
use Data::Dumper;
use Getopt::Long;
use File::Find;
use Net::FTP::Common;
use strict;

our $last_done;
my ($since_last_run, $blind, $days_old);

GetOptions('since-last-run' => \$since_last_run, 'blind'  => \$blind, 'days_old' => \$days_old) or die;

my $sum = $since_last_run + $blind + $days_old;
my @option_name = qw(since-last-run blind days-old);
$sum == 1 or die "exactly one of @option_name must be specified";


my $lockfile = '/tmp/net-ftp-common-rsync-files.lck';

sub cleanup {
    warn "closing dup handle";
    close(Net::FTP::Common::DUP);
    unlink $lockfile;
    1;
}

-e $lockfile and 
    cleanup and die "$lockfile must be removed before running script";

my $config      = AppConfig->new( {CASE => 1} ) ;
my $location    = 'location';
my $install_dir = 'install_dir';



$config->define($location, { ARGCOUNT => ARGCOUNT_LIST });
$config->define($install_dir, { ARGCOUNT => ARGCOUNT_ONE });
$config->file($ENV{NET_FTP_BACKUP});

my $location = $config->get($location);
$install_dir = $config->get($install_dir);

my $done_file = "$install_dir/files-wanted.done";

warn Dumper($location, $install_dir);

if ($since_last_run) {
  warn "calculating last_done on $done_file";
  $last_done = (stat($done_file))[9];
}




foreach (@$location) {
  $Location = $_;
  find(\&wanted, $_);
}

sub unwanted {
    my $file = shift;

    return 1 if $file =~ /.DS_Store/;
    return 1 if $file =~ /.FBC/;
    return 1 if $file =~ /\.mp3$/;
    my $mtime = (stat($file))[9];
    if ($since_last_run) {
      my $diff = $last_done - $mtime;
      warn "$file\tlast_done - mtime: $diff";
      return 1 unless $diff < 0;
    }
    return 0
}

sub wanted {

  last unless -f; 

  if ($Location = '/Users/metaperl') {
    # do not enter subdirs for home dir
    last unless $File::Find::dir eq $Location;
  }

  last if /[\r\n]/s;
    
  my $lf = $_;

  last if unwanted($File::Find::name);

  print $File::Find::name, $/;

}


open RUNLOG, ">$install_dir/files-wanted.done" or 
  die "could not open $install_dir/files-wanted.done: $!";
print RUNLOG "complete.\n";
close(RUNLOG);

