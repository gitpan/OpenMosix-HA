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
 mfsbase=>"t/scratch/mfs1",
 mwhois=>'echo This is MOSIX \#3'
);

ok($ha);
ok $ha->getclinittab(1,2,3);
my $init=$ha->init();
ok $init;
ok $ha->{init};
my $rc = eval
{
  my $clinittab = $ha->getclinittab(1,2,3);
  # XXX check for reread 
  ok $clinittab->{foo};
  ok $clinittab->{bar};
};
ok $rc;
warn $@ unless $rc;
$ha->{init}->shutdown;
waitdown();

# use GraphViz::Data::Grapher;
# my $graph = GraphViz::Data::Grapher->new(%$ha);
# open(F,">/tmp/2.ps") || die $!;
# print F $graph->as_ps;
