#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 0 }

exit;

use OpenMosix::HA;
use Data::Dump qw(dump);

my @child;
for my $node qw(1 2 3)
{
  my $child;
  unless ($child=fork())
  {
    my $ha= new OpenMosix::HA
      (
       hpcbase=>"t/scratch/proc/hpc",
       clinit_s=>"t/scratch/var/mosix-ha/clinit.$node.s",
       mfsbase=>"t/scratch/mfs1",
       mwhois=>'echo This is MOSIX \#'.$node
      );
    warn $ha->{mwhois};
    $ha->monitor();
    $ha->{init}->shutdown;
    waitdown();
    exit;
  }
  push @child, $child;
}

sleep 999999;
kill $_ for (@child);

__END__

my $node1 = new OpenMosix::HA
(
 hpcbase=>"t/scratch/proc/hpc",
 clinit_s=>"t/scratch/var/mosix-ha/clinit.s",
 mfsbase=>"t/scratch/mfs1",
 mwhois=>'echo This is MOSIX \#1'
);
ok($node1);

my $node2 = new OpenMosix::HA
(
 hpcbase=>"t/scratch/proc/hpc",
 clinit_s=>"t/scratch/var/mosix-ha/clinit.s",
 mfsbase=>"t/scratch/mfs1",
 mwhois=>'echo This is MOSIX \#2'
);
ok($node2);

my $node3 = new OpenMosix::HA
(
 hpcbase=>"t/scratch/proc/hpc",
 clinit_s=>"t/scratch/var/mosix-ha/clinit.s",
 mfsbase=>"t/scratch/mfs1",
 mwhois=>'echo This is MOSIX \#3'
);
ok($node3);

while(1)
{
  $node1->monitor(1);
  $node2->monitor(1);
  $node3->monitor(1);
  run(1);
}

$node1->{init}->shutdown;
$node2->{init}->shutdown;
$node3->{init}->shutdown;
waitdown();
