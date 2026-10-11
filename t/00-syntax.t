#!/usr/bin/perl
# Syntax checks for the maintenance scripts. Uses the same interpreter
# that runs the tests ($^X) and only core tools.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite qw(repo_root run);
use File::Spec;

my $sdir = File::Spec->catdir( repo_root(), 'scripts' );

opendir my $dh, $sdir or die "opendir $sdir: $!";
my @pl = sort grep { /\.pl$/ }  readdir $dh;
rewinddir $dh;
my @sh = sort grep { /\.sh$/ }  readdir $dh;
closedir $dh;

ok( scalar(@pl), "found Perl scripts" ) or BAIL_OUT("no scripts found");
ok( scalar(@sh), "found shell scripts" );

for my $f (@pl) {
    my $path = File::Spec->catfile( $sdir, $f );
    my $r    = run( $^X, '-c', $path );
    is( $r->{status}, 0, "perl -c $f" )
      or diag( "stdout: $r->{stdout}\nstderr: $r->{stderr}" );
}

my $have_sh = 0;
for my $candidate ( '/bin/sh', '/usr/bin/sh', 'sh' ) {
    my $r = run( $candidate, '-c', 'exit 0' );
    if ( $r->{status} == 0 && !$r->{signal} ) { $have_sh = 1; last; }
}
SKIP: {
    skip 'no /bin/sh available', scalar(@sh) if !$have_sh;
    for my $f (@sh) {
        my $path = File::Spec->catfile( $sdir, $f );
        my $r    = run( 'sh', '-n', $path );
        is( $r->{status}, 0, "sh -n $f" )
          or diag("stderr: $r->{stderr}");
    }
}

done_testing();
