
use Event qw(one_event loop unloop);
use Time::HiRes qw(time);
use GraphViz::Data::Grapher;
use Data::Dump qw(dump);
use Digest::MD5;

`touch -t 198101010101 t/master/mfs1/1/var/mosix-ha/clinitstat`;
`touch -t 198201010101 t/master/mfs1/2/var/mosix-ha/clinitstat`;
`rm -rf t/scratch; cp -rp t/master t/scratch`;
my %stomlist;

sub debug
{
  my $debug = $ENV{DEBUG} || 0;
  return unless $debug;
  my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
  my $subline = (caller(0))[2];
  my $msg = join(' ',@_);
  $msg.="\n" unless $msg =~ /\n$/;
  warn time()." $$ $subroutine,$subline: $msg" if $debug;
}

sub graph
{
  my $graph = GraphViz::Data::Grapher->new(@_);
  open(F,">t/graph.ps") || die $!;
  print F $graph->as_ps;
  close F;
  unless (fork())
  {
    system("gv t/graph.ps");
    exit;
  }
  warn dump @_;
}

sub run
{
  my $seconds=shift;
  Event->timer(at=>time() + $seconds,cb=>sub{unloop()});
  loop();
}

sub stomith
{
  my $node=shift;
  # warn "STOMITH $node";
  $stomlist{$node}=1;
}

sub stomck
{
  my $node=shift;
  # warn dump \%stomlist;
  return $stomlist{$node};
}

sub stomreset
{
  %stomlist=();
}

sub md5sum
{
  my $file=shift;
  open(F,"<$file") || die $!;
  my $ctx = Digest::MD5->new;
  $ctx->addfile(*F);
  my $sum = $ctx->hexdigest;
  return $sum;
}

sub waitdown
{
  while(1)
  {
    my $count = `ps -eaf 2>/dev/null | grep perl | grep $0 | grep -v defunct | grep -v runtests | grep -v grep | wc -l`;
    chomp($count);
    # warn "$count still running";
    last if $count==1;
    run(1);
  }
}

sub waitgstat
{
  my ($ha,$group,$level,$state,$timeout)=@_;
  $timeout||=10;
  my $start=time;
  my $mynode = $ha->{mynode};
  while(1)
  {
    my ($hastat) = $ha->hastat($ha->nodes());
    debug dump $hastat;
    my $cklevel=$hastat->{$group}{$mynode}{level} || next;
    my $ckstate=$hastat->{$group}{$mynode}{state} || next;
    last if $level eq $cklevel && $state eq $ckstate;
  }
  continue
  {
    my $line = (caller(0))[2];
    if ($start + $timeout < time)
    {
      warn "missed line $line $group $mynode $level $state\n";
      my ($hastat) = $ha->hastat($ha->nodes());
      warn dump $hastat;
      return 0;
    }
    run(1);
  }
  return 1;
}

sub waitstat
{
  my ($init,$group,$level,$state,$timeout)=@_;
  $timeout||=10;
  my $start=time;
  while(1)
  {
    my $out = $init->status();
    debug $out if $out;
    last if $out =~ /^$group\s+$level\s+$state$/ms;
    # warn "missed";
    return 0 if $start + $timeout < time;
    run(1);
  }
  return 1;
}

sub waitgstop
{
  my ($ha,$group,$timeout)=@_;
  $timeout||=10;
  my $start=time;
  my $mynode = $ha->{mynode};
  while(1)
  {
    my ($hastat) = $ha->hastat($ha->nodes());
    # warn dump $hastat;
    last unless $hastat->{$group}{$mynode};
  }
  continue
  {
    my $line = (caller(0))[2];
    if ($start + $timeout < time)
    {
      warn "missed line $line $group $mynode stop\n";
      my ($hastat) = $ha->hastat($ha->nodes());
      warn dump $hastat;
      return 0;
    }
    run(1);
  }
  return 1;
}

1;
