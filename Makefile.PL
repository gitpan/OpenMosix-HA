use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'OpenMosix::HA',
    VERSION_FROM => 'lib/OpenMosix/HA.pm', # finds $VERSION
    AUTHOR       => 'Steve Traugott (stevegt@TerraLuna.Org)',
    ABSTRACT     => 'High Availability (HA) layer for an openMosix cluster'
);
