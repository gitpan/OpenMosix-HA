#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 2 }

use OpenMosix::HA;
# use Data::Dump qw(dump);

my $ha = new OpenMosix::HA
(
 mfsbase=>"t/scratch/mfs1",
 mynode=>1
);

ok($ha);
$ha->init();
$DB::single=1;
ok($ha->{init});
# my $can=$ha->{init}->can('shutdown');
$ha->{init}->shutdown;
waitdown();

# use GraphViz::Data::Grapher;
# my $graph = GraphViz::Data::Grapher->new(%$ha);
# open(F,">/tmp/2.ps") || die $!;
# print F $graph->as_ps;
