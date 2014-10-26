
package OpenMosix::HA;
use strict;

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	$VERSION     = 0.01;
	@ISA         = qw (Exporter);
	@EXPORT      = qw ();
	@EXPORT_OK   = qw ();
	%EXPORT_TAGS = ();
}

=head1 NAME

OpenMosix::HA -- High Availability (HA) layer for an openMosix cluster

=head1 SYNOPSIS

  use OpenMosix::HA;

  my $ha = new OpenMosix::HA;

  # spawn all apps for resource group "foo", runlevel "run"
  $ha->tell("foo","run");

  # spawn all apps for resource group "foo", runlevel "runmore"
  # (this stops everything started by runlevel "run")
  $ha->tell("foo","runmore");

  # get status of all resource groups
  $ha->status();

=head1 DESCRIPTION

This module provides basic "init" functionality, giving you a single
inittab-like file to manage daemon startup and restart across a
cluster of openMosix machines.  

This gives you a high-availability cluster with low hardware overhead.
In contrast to traditional HA clusters, we use the openMosix cluster
membership facility to provide heartbeat and to detect network
partitions.

All you need to do is build a relatively conventional openMosix
cluster, install this module, and configure it to start and manage
your HA processes.  There is no need to use the heartbeat serial
cables, spare ethernet cards, or high-end server machines which
traditional HA requires.  There is no need for chained SCSI buses --
you can share disks among many nodes via any number of other current
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

In addition to the normal inittab format, the configuration file for
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

=head1 AVAILABILITY

This module is based on my IS::Init module, which is already in
production and available from CPAN.  My wife and I had hoped to have a
beta version of OpenMosix::HA available by the time of Moshe Bar's Feb
5 2003 openMosix talk at the Silicon Valley Linux Users Group.

Then I unexpectedly became involved in data collection for Columbia's
California transit -- SVLUG member Ian Kluft was one of the few
witnesses.  We decided it best to defer work on this module in favor
of improving our understanding of where the shuttle's breakup actually
began, relaying our results to Johnson Space Center and working with
media to encourage others to do the same.  These efforts by ourselves
and others have been successful beyond what any of us expected -- NASA
JSC emergency ops responded to us personally and as of this writing a
search in California is already underway.  But I don't have a Perl
module for you yet.

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


