#!/usr/bin/perl -w
# vim:set syntax=perl:
use strict;
use Test;
require "t/utils.pl";

# BEGIN { plan tests => 14, todo => [3,4] }
BEGIN { plan tests => 53 }

use OpenMosix::HA;
use Data::Dump qw(dump);
# use Devel::Trace qw(trace);

my $ha;
my $hastat;
my $hactl;
my %metric;

$ha = new OpenMosix::HA
(
 hpcbase=>"t/scratch/proc/hpc",
 clinit_s=>"t/scratch/var/mosix-ha/clinit.s",
 mfsbase=>"t/scratch/mfs1",
 mwhois=>'echo This is MOSIX \#1'
);
ok($ha);
# system("cat t/scratch/mfs1/1/var/mosix-ha/cltab");
ok $ha->getcltab(1,2,3);
ok $ha->init();
ok $ha->{init};
`cp -rp t/master/* t/scratch`;
$hactl=$ha->gethactl(1,2,3);
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
# run(1);
# $hactl=$ha->gethactl(1,2,3);
# ($hastat)=$ha->hastat(1,2,3);
# $ha->scangroups($hastat,$hactl);
# warn $ha->{init}->status();
ok waitgstop($ha,"bar");
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstat($ha,"foo","plan","DONE");
ok waitgstat($ha,"new","plan","DONE");
ok waitgstat($ha,"bad","plan","DONE");
ok waitgstop($ha,"bar");
ok waitgstop($ha,"del");
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstat($ha,"foo","test","DONE");
ok waitgstat($ha,"new","test","DONE");
ok waitgstat($ha,"bad","test","FAILED");
ok waitgstop($ha,"bar");
ok waitgstop($ha,"del");
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstat($ha,"foo","start","DONE");
ok waitgstat($ha,"new","start","DONE");
ok waitgstop($ha,"bad");
ok waitgstop($ha,"bar");
ok waitgstop($ha,"del");
# `rm -rf t/scratch2; find t/scratch -type f | cpio -pudm t/scratch2`;
`tar -cf t/scratch.tar t/scratch/mfs1/*/var/mosix-ha/clstat`;
$ha->{init}->shutdown;
waitdown();

$ha = new OpenMosix::HA
(
 hpcbase=>"t/scratch/proc/hpc",
 clinit_s=>"t/scratch/var/mosix-ha/clinit.s",
 mfsbase=>"t/scratch/mfs1",
 mwhois=>'echo This is MOSIX \#2'
);
ok($ha);
ok $ha->getcltab(1,2,3);
ok $ha->init();
ok $ha->{init};
# `cp -rp t/scratch2/* t/scratch`;
`tar -xf t/scratch.tar`;
# system("cat t/scratch/mfs1/1/var/mosix-ha/clstat");
# system("cat t/scratch/mfs1/2/var/mosix-ha/clstat");
# system("cat t/scratch/mfs1/3/var/mosix-ha/clstat");
$hactl=$ha->gethactl(1,2,3);
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstop($ha,"bar");
ok waitgstop($ha,"foo");
ok waitgstat($ha,"baz","start","DONE");
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstop($ha,"foo");
ok waitgstat($ha,"bar","plan","DONE");
ok waitgstop($ha,"del");
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstop($ha,"foo");
ok waitgstat($ha,"bar","test","DONE");
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstop($ha,"foo");
ok waitgstat($ha,"bar","2","DONE");
$ha->{init}->shutdown;
waitdown();

$ha = new OpenMosix::HA
(
 hpcbase=>"t/scratch/proc/hpc",
 clinit_s=>"t/scratch/var/mosix-ha/clinit.s",
 mfsbase=>"t/scratch/mfs1",
 mwhois=>'echo This is MOSIX \#3'
);
ok($ha);
ok $ha->getcltab(1,2,3);
ok $ha->init();
ok $ha->{init};
$hactl=$ha->gethactl(1,2,3);
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstop($ha,"foo");
ok waitgstop($ha,"new");
ok waitgstat($ha,"bar","plan","DONE");
ok waitgstat($ha,"baz","plan","DONE");
ok waitgstat($ha,"bad","plan","DONE");
$hactl=$ha->gethactl(1,2,3);
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstop($ha,"foo");
ok waitgstop($ha,"new");
ok waitgstat($ha,"bar","test","DONE");
ok waitgstat($ha,"baz","test","PASSED");
ok waitgstat($ha,"bad","test","FAILED");
$hactl=$ha->gethactl(1,2,3);
($hastat)=$ha->hastat(1,2,3);
$ha->scangroups($hastat,$hactl);
ok waitgstop($ha,"foo");
ok waitgstop($ha,"new");
ok waitgstat($ha,"bar","2","DONE");
ok waitgstat($ha,"baz","start","DONE");
ok waitgstop($ha,"bad");
$ha->{init}->shutdown;
waitdown();

