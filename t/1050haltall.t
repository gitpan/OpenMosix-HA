#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 7 }

use OpenMosix::HA;
# use Data::Dump qw(dump);

my $ha = new OpenMosix::HA
(
 hpcbase=>"t/scratch/proc/hpc",
 clinit_s=>"t/scratch/var/mosix-ha/clinit.s",
 mfsbase=>"t/scratch/mfs1",
 mwhois=>'echo This is MOSIX \#1'
);

ok($ha);
$ha->init();
ok $ha->{init};
my $init=$ha->{init};
my $rc = eval
{
  $ha->{init}->tell("foo","start");
  $ha->{init}->tell("bar","1");
  ok waitstat($init,"foo","start","DONE");
  ok waitstat($init,"bar",1,"DONE",2);
  $ha->haltall();
  ok waitstat($init,"foo","stop","DONE");
  ok waitstat($init,"bar","stop","DONE");
};
ok $rc;
warn $@ unless $rc;
$ha->{init}->shutdown;
waitdown();

# use GraphViz::Data::Grapher;
# my $graph = GraphViz::Data::Grapher->new(%$ha);
# open(F,">/tmp/2.ps") || die $!;
# print F $graph->as_ps;
