package OpenMosix::HA;
use strict;
use Cluster::Init;
use Event qw(one_event loop unloop);
use Time::HiRes qw(time);
use Data::Dump qw(dump);

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	$VERSION     = 0.532;
	@ISA         = qw (Exporter);
	@EXPORT      = qw ();
	@EXPORT_OK   = qw ();
	%EXPORT_TAGS = ();
}

sub debug
{
  my $debug = $ENV{DEBUG} || 0;
  return unless $debug;
  my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
  my $subline = (caller(0))[2];
  my $msg = join(' ',@_);
  $msg.="\n" unless $msg =~ /\n$/;
  warn time()." $$ $subroutine,$subline: $msg" if $debug;
  if ($debug > 1)
  {
    warn _stacktrace();
  }
  if ($debug > 2)
  {
    Event::Stats::collect(1);
    warn sprintf("%d\n%-35s %3s %10s %4s %4s %4s %4s %7s\n", time,
    "DESC", "PRI", "CBTIME", "PEND", "CARS", "RAN", "DIED", "ELAPSED");
    for my $w (reverse all_watchers())
    {
      my @pending = $w->pending();
      my $pending = @pending;
      my $cars=sprintf("%01d%01d%01d%01d",
      $w->is_cancelled,$w->is_active,$w->is_running,$w->is_suspended);
      my ($ran,$died,$elapsed) = $w->stats(60);
      warn sprintf("%-35s %3d %10d %4d %4s %4d %4d %7.3f\n",
      $w->desc,
      $w->prio,
      $w->cbtime,
      $pending,
      $cars,
      $ran,
      $died,
      $elapsed);
    }
  }
}

sub _stacktrace
{
  my $out="";
  for (my $i=1;;$i++)
  {
    my @frame = caller($i);
    last unless @frame;
    $out .= "$frame[3] $frame[1] line $frame[2]\n";
  }
  return $out;
}

=head1 NAME

OpenMosix::HA -- High Availability (HA) layer for an openMosix cluster

=head1 SYNOPSIS

  use OpenMosix::HA;

  my $ha = new OpenMosix::HA;

  # start the monitor daemon 
  $ha->monitor;

=head1 DESCRIPTION

This module provides the basic functionality needed to manage resource 
startup and restart across a cluster of openMosix machines.  

This gives you a high-availability cluster with low hardware overhead.
In contrast to traditional HA clusters, we use the openMosix cluster
membership facility, rather than hardware serial cables or extra
ethernet ports, to provide heartbeat and to detect network partitions.

All you need to do is build a relatively conventional openMosix
cluster, install this module on each node, and configure it to start
and manage your HA processes.  You do not need the relatively
high-end server machines which traditional HA requires.  There is no
need for chained SCSI buses (though you can use them) -- you can
instead share disks among many nodes via any number of other current
technologies, including SAN, NAS, GFS, or Firewire (IEEE-1394).

=head1 BACKGROUND

Normally, a process-migration-based cluster computing technology (such
as openMosix) is orthogonal to the intent of high availability.  When
openMosix nodes die, any processes migrated to those nodes will also
die, regardless of where they were spawned.  The higher the node
count, the more frequently these failures are likely to occur.

But if processes are started via OpenMosix::HA, any processes and
resource groups which fail due to node failure can be configured to
automatically restart on other nodes.  OpenMosix::HA detects process
failure, selects a new node out of all currently available, and
deconflicts the selection so that two nodes don't restart the same
process or resource group.  

While similar to the normal inittab format, the configuration file for
OpenMosix::HA includes an extra "resource group" column -- this is
what enables you to group processes, disk mounts, virtual IP
addresses, and related resources into resource groups.  

Any given node only needs to be able to support a subset of all
resource groups.  OpenMosix::HA provides an extra "test" runmode
(beyond init's normal 'wait', 'once', and 'respawn'), enabling the
module to automatically test a given node for fitness before
considering starting a given resource group there.

There is no "head" or "supervisor" node in an OpenMosix::HA cluster --
there is no single point of failure.  Each node makes its own
observations and decisions about the start or restart of processes and
resource groups.  

IO Fencing (also STOMITH or STONITH, the art of making sure that a
partially-dead node doesn't continue to access shared resources) can
be handled as it is in conventional HA clusters, by a combination of
exclusive device logins when using Firewire, distributed locks when
using GFS or other SAN, and brute-force methods such as X10 or
network-controlled powerstrips.  OpenMosix::HA provides a callback
hook which can be used to trigger the latter.  

=head1 METHODS

=over 

=item new(%parms)

Loads Cluster::Init, but does not start any resource groups.

Accepts an optional parameter hash which you can use to override
module defaults.  Defaults are set for a typical openMosix cluster
installation.  Parameters you can override include:

=over 

=item mfsbase

MFS mount point.  Defaults to C</mfs>.

=item mynode

Mosix node number of local machine.  You should only override this for
testing purposes.

=item varpath

The local path under C</> where the module should look for the
C<hactl> and C<cltab> files, and where it should put clstat
  and clinit.s; this is also the subpath where it should look for
these things on other machines, under C</mfsbase/NODE>.  Defaults to
C<var/mosix-ha>.

=item timeout

The maximum age (in seconds) of any node's C<clstat> file, after which
the module considers that node to be stale, and calls for a STOMITH.
Defaults to 60 seconds.

=item XXX STOMITH callback.


=back

=cut

sub new
{
  my $class=shift;
  my $self={@_};
  bless $self, $class;
  $self->{mfsbase}   ||="/mfs";
  $self->{hpcbase}   ||="/proc/hpc";
  $self->{mwhois}    ||= "mosctl whois";
  $self->{mynode}    ||= $self->mosnode();
  $self->{varpath}   ||= "var/mosix-ha";
  $self->{clinit_s}  ||= "/".$self->{varpath}."/clinit.s";
  $self->{timeout}   ||= 60;
  $self->{cycletime} ||= 1;
  $self->{stomith}   ||= sub{$self->stomith(@_)};
  $self->{mybase}      = $self->nodebase($self->{mynode});
  $self->{hactl}       = $self->{mybase}."/hactl";
  $self->{cltab}       = $self->{mybase}."/cltab";
  $self->{clstat}      = $self->{mybase}."/clstat";
  $self->{hastat}      = $self->{mybase}."/hastat";
  unless (-d $self->{mybase})
  {
    mkdir $self->{mybase} || die $!;
  }
  return $self;
}

sub init
{
  my $self=shift;
  my %parms = (
    'clstat' => $self->{clstat},
    'cltab' => $self->{cltab},
    'socket' => $self->{clinit_s}
  );
  # start daemon
  unless (fork())
  {
    my $init = Cluster::Init->daemon(%parms);
    debug "daemon exiting";
    exit;
  }
  run(1);
  # initialize client
  $self->{init} = Cluster::Init->client(%parms);
  return $self->{init};
}

=item monitor()

Starts the monitor daemon.  The monitor ensures the resource groups in
C<cltab> are each running somewhere in the cluster, at the
runlevels specified in C<hactl>.  Any resource groups found not
running are candidates for a restart on the local node.

Before restarting a resource group, the local monitor announces its
intentions in the local C<clstat> file, and observes C<clstat> on
other nodes.  If the monitor on any other node also intends to start
the same resource group, then the local monitor will detect this and
cancel its own restart.  The checks and restarts are staggered by
random times on various nodes to prevent oscillation.

XXX document run levels: plan test run stop

=cut

sub monitor
{
  my $self=shift;
  my $runtime=shift || 999999999;
  $self->getcltab($self->nodes);
  $self->init() unless $self->{init};
  my $init=$self->{init};
  my $start=time();
  my $stop=$start + $runtime;
  while(time < $stop)
  {
    my @node = $self->nodes();
    unless($self->quorum(@node))
    {
      $self->haltall;
      run(30);
      next;
    }
    # build consolidated clstat 
    my ($hastat,$stomlist)=$self->hastat(@node);
    # STOMITH stale nodes
    $self->stomscan($stomlist) if time > $start + 120;
    # get and read latest hactl and cltab
    my $hactl=$self->gethactl(@node);
    my $cltab=$self->getcltab(@node);
    $self->scangroups($hastat,$hactl,@node);
    warn "node $self->{mynode} cycletime $self->{cycletime}\n";
    run($self->cycletime) if $self->cycletime + time < $stop;
  }
  return 1;
}

sub cycle_faster
{
  my $self=shift;
  $self->{cycletime}/=rand(.5)+.5;
  # $self->{cycletime}=15 if $self->{cycletime} < 15;
}

sub cycle_slower
{
  my $self=shift;
  $self->{cycletime}*=rand()+1;
}

sub backoff
{
  my $self=shift;
  $self->{cycletime}+=rand(10);
}

sub cycletime
{
  my $self=shift;
  my $time=shift;
  if ($time)
  {
    my $ct = $self->{cycletime};
    $ct = ($ct+$time)/2;
    $self->{cycletime}=$ct;
  }
  return $self->{cycletime};
}

sub compile_metrics
{
  my $self=shift;
  my $hastat=shift;
  my $hactl=shift;
  my $group=shift;
  my $mynode=$self->{mynode};
  my %metric;
  # is group active somewhere?
  if ($hastat->{$group})
  {
    $metric{isactive}=1;
    # is group active on my node?
    $metric{islocal}=1 if $hastat->{$group}{$mynode};
    for my $node (keys %{$hastat->{$group}})
    {
      # is group active in multiple places?
      $metric{instances}++;
    }
  }
  if ($metric{islocal})
  {
    # run levels which must be defined in cltab: plan test stop 
    # ("start" or equivalent is defined in hactl)
    my $level=$hastat->{$group}{$mynode}{level};
    my $state=$hastat->{$group}{$mynode}{state};
    debug "$group $level $state";
    # is our local instance of group contested?
    $metric{inconflict}=1 if $metric{instances} > 1;
    # has group been planned here?
    $metric{planned}=1 if $level eq "plan" && $state eq "DONE";
    # did group pass or fail a test here?
    $metric{passed}=1 if $level eq "test" && $state eq "PASSED";
    $metric{failed}=1 if $level eq "test" && $state eq "FAILED";
    # allow group to have no defined "test" runlevel -- default to pass
    $metric{passed}=1 if $level eq "test" && $state eq "DONE";
    # is group in transition?
    $metric{intransition}=1 unless $state =~ /^(DONE|PASSED|FAILED)$/;
    # is group in hactl?
    if ($hactl->{$group})
    {
      # does group runlevel match what's in hactl?
      $metric{chlevel}=1 if $level ne $hactl->{$group};
      # do we want to plan to test and start group on this node?
      unless ($hactl->{$group} eq "stop" || $metric{instances})
      {
	$metric{needplan}=1;
      }
    }
    else
    {
      $metric{deleted}=1;
    }
  }
  if ($hactl->{$group})
  {
    # do we want to plan to test and start group on this node?
    unless ($hactl->{$group} eq "stop" || $metric{instances})
    {
      $metric{needplan}=1;
    }
  }
  return %metric;
}

# get latest hactl file
sub gethactl
{
  my $self=shift;
  my @node=@_;
  $self->getlatest("hactl",@node);
  # return the contents
  my $hactl;
  open(CONTROL,"<".$self->{hactl}) || die $!;
  while(<CONTROL>)
  {
    next if /^\s*#/;
    next if /^\s*$/;
    chomp;
    my ($group,$level)=split;
    $hactl->{$group}=$level;
  }
  return $hactl;
}

# get latest cltab file
sub getcltab
{
  my $self=shift;
  my @node=@_;
  if ($self->getlatest("cltab",@node))
  {
    # reread cltab if it changed
    # if $self->{init}
    # XXX $self->tell("::ALL::","::REREAD::");
  }
  # return the contents
  my $cltab;
  open(CLTAB,"<".$self->{cltab}) || die $!;
  while(<CLTAB>)
  {
    next if /^\s*#/;
    next if /^\s*$/;
    chomp;
    my ($group,$tag,$level,$mode)=split(':');
    next unless $group;
    $cltab->{$group}=1;
  }
  return $cltab;
}

# get the latest version of a file
sub getlatest
{
  my $self=shift;
  my $file=shift;
  my @node=@_;
  my $newfile;
  # first we have to find it...
  my $myfile;
  for my $node (@node)
  {
    my $base=$self->nodebase($node);
    my $ckfile="$base/$file";
    $myfile=$ckfile if $node == $self->{mynode};
    next unless -f $ckfile;
    $newfile||=$ckfile;
    if (-M $newfile > -M $ckfile)
    {
      debug "$ckfile is newer than $newfile";
      $newfile=$ckfile;
    }
  }
  # ...then get it...
  if ($newfile && $myfile && $newfile ne $myfile)
  {
    if (-f $myfile && -M $myfile <= -M $newfile)
    {
      return 0;
    }
    sh("cp -p $newfile $myfile") || die $!; 
    return 1;
  }
  return 0;
}

# halt all local resource groups
sub haltall
{
  my $self=shift;
  my ($hastat)=$self->hastat($self->{mynode});
  debug dump $hastat;
  for my $group (keys %$hastat)
  {
    debug "halting $group";
    $self->tell($group,"stop");
  }
}

# build consolidated clstat and STOMITH stale nodes
sub hastat
{
  my $self=shift;
  my @node=@_;
  my $hastat;
  my @stomlist;
  for my $node (@node)
  {
    my $base=$self->nodebase($node);
    my $file="$base/clstat";
    next unless -f $file;
    my $age = -M $file;
    debug "$node age $age\n";
    # STOMITH stale nodes
    if ($age > $self->{timeout}/86400)
    {
      debug "$node is old\n";
      unless($node == $self->{mynode})
      {
	push @stomlist, $node;
      }
    }
    open(CLSTAT,"<$file") || next;
    while(<CLSTAT>)
    {
      chomp;
      my ($class,$group,$level,$state) = split;
      next unless $class eq "Cluster::Init::Group";
      # ignore inactive groups
      next if $state eq "CONFIGURED";
      next if $level eq "stop" && $state eq "DONE";
      $hastat->{$group}{$node}{level}=$level;
      $hastat->{$group}{$node}{state}=$state;
    }
  }
  open(HASTAT,">".$self->{hastat}."tmp") || die $!;
  print HASTAT (dump $hastat);
  close HASTAT;
  rename($self->{hastat}."tmp", $self->{hastat}) || die $!;
  return ($hastat,\@stomlist);
}

sub mosnode
{
  my $self=shift;
  my $whois=`$self->{mwhois}`; 
  # "This is MOSIX #32"
  $whois =~ /(\d+)/;
  my $node=$1;
  die "can't figure out my openMosix node number" unless $node;
  return $node;
}

sub nodebase
{
  my $self=shift;
  my $node=shift;
  my $base = join
  (
    "/",
    $self->{mfsbase},
    $node,
    $self->{varpath}
  );
  return $base;
}

# build list of nodes by looking in /proc/hpc/nodes
sub nodes
{
  my $self=shift;
  opendir(NODES,$self->{hpcbase}."/nodes") || die $!;
  my @node = grep /^\d/, readdir(NODES);
  closedir NODES;
  my @upnode;
  # check availability 
  for my $node (@node)
  {
    open(STATUS,$self->{hpcbase}."/nodes/$node/status") || next;
    chomp(my $status=<STATUS>);
    # XXX status bits mean what?
    next unless $status & 2;
    push @upnode, $node;
  }
  return @upnode;
}

# halt all resource groups if we've lost quorum
sub quorum
{
  my ($self,@node)=@_;
  $self->{quorum}||=0;
  if (@node < $self->{quorum} * .6)
  {
    return 0;
  }
  $self->{quorum}=@node;
  return 1;
}

sub run
{
  my $seconds=shift;
  Event->timer(at=>time() + $seconds,cb=>sub{unloop()});
  loop();
}

# scan through all known groups, stopping or starting them according 
# to directives in hactl and status of all nodes; the goal here is to
# make each group be at the runlevel shown in hactl
sub scangroups
{
  my $self=shift;
  my $hastat=shift;
  my $hactl=shift;
  my @node=@_;
  my $init=$self->{init};
  # for each group in hastat or hactl
  for my $group (uniq(keys %$hastat, keys %$hactl))
  {
    my %metric = $self->compile_metrics($hastat,$hactl,$group);
    debug "$group ", dump %metric;
    # stop groups which have been deleted from hactl
    if ($metric{deleted})
    {
      $self->tell($group,"stop");
      $self->cycletime(5);
      next;
    }
    # stop contested groups
    if ($metric{inconflict})
    {
      $self->tell($group,"stop");
      $self->backoff();
      next;
    }
    # start groups which previously passed tests
    if ($metric{passed})
    {
      $self->tell($group,$hactl->{$group});
      $self->cycletime(5);
      next;
    }
    # stop failed groups
    if ($metric{failed})
    {
      $self->tell($group,"stop");
      $self->cycletime(5);
      next;
    }
    # start tests for all uncontested groups we planned
    if ($metric{planned})
    {
      $self->tell($group,"test");
      $self->cycletime(5);
      next;
    }
    # notify world of groups we plan to test
    if ($metric{needplan})
    {
      $self->cycletime(10);
      # balance startup across all nodes
      next if rand(scalar @node) > 1.5;
      # start planning
      $self->tell($group,"plan");
      next;
    }
    # in transition -- don't do anything yet
    if ($metric{intransition})
    {
      $self->cycletime(5);
      next;
    }
    # whups -- level changed in hactl
    if ($metric{chlevel})
    {
      $self->tell($group,$hactl->{$group});
      $self->cycletime(5);
      next;
    }
    # normal cycletime is such that one node should wake up each
    # second
    $self->cycletime(scalar @node);
  }
}

sub sh
{
  my @cmd=@_;
  my $cmd=join(' ',@cmd);
  debug "> $cmd\n";
  my $res=`$cmd`;
  my $rc= $? >> 8;
  $!=$rc;
  return ($rc,$res) if wantarray;
  return undef if $rc;
  return 1;
}

sub stomith
{
  my ($self,$node)=@_;
  warn "STOMITH node $node\n";
}

sub stomscan
{
  my $self=shift;
  my $stomlist=shift;
  for my $node (@$stomlist)
  {
    # warn "STOMITH $node\n";
    &{$self->{stomith}}($node);
  }
}

sub tell
{
  my $self=shift;
  my $group=shift;
  my $level=shift;
  debug "tell $group $level";
  $self->{init}->tell($group,$level);
}

sub uniq
{
  my @in=@_;
  my @out;
  for my $in (@in)
  {
    push @out, $in unless grep /^$in$/, @out;
  }
  return @out;
}

sub DESTROY
{
  my $self=shift;
  unlink $self->{hastat};
  unlink $self->{clstat};
}

=back

=head1 INSTALLATION

=head1 FILES

XXX list files and their purposes; refer to Cluster::Init default filenames

=head1 AVAILABILITY

This module is based on my IS::Init module, which is already in
production and available from CPAN.  My wife and I had hoped to have a
beta version of OpenMosix::HA available by the time of Moshe Bar's Feb
5 2003 openMosix talk at the Silicon Valley Linux Users Group.

Then I unexpectedly became involved in data collection for Columbia's
California transit -- SVLUG member Ian Kluft was one of the few
witnesses.  We decided it best to defer work on this module in favor
of improving our understanding of where the orbiter's breakup actually
began, relaying our results to Johnson Space Center and working with
media to encourage others to do the same.  These efforts by ourselves
  and others have been successful beyond what any of us expected --
NASA JSC emergency ops responded to us personally and as of this
writing a search in California is already underway.  But I don't have
a Perl module for you yet.

For a production version of OpenMosix::HA, check CPAN.org,
TerraLuna.Org, or Infrastructures.Org in early March 2003, or contact
me.  Beta versions will become available as time permits before then. 

=head1 AUTHOR

	Steve Traugott
	CPAN ID: STEVEGT
	stevegt@TerraLuna.Org
	http://www.stevegt.com

=head1 COPYRIGHT

Copyright (c) 2003 Steve Traugott. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

IS::Init, openMosix.Org, qlusters.com

=cut

1; 


