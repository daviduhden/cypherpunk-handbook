#!/usr/bin/perl
# Functional tests for the shell maintenance scripts using controlled
# stubs, so no real audio/image conversion is performed.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite qw(script run run_input slurp spew);
use File::Temp qw(tempdir);

my $sh = -x '/bin/sh' ? '/bin/sh' : 'sh';

sub mkstubs {
    my (%files) = @_;
    my $bin = tempdir( CLEANUP => 1 );
    for my $name ( keys %files ) {
        spew( "$bin/$name", $files{$name} );
        chmod 0755, "$bin/$name";
    }
    return $bin;
}

my $pandoc_ok = "#!/bin/sh\necho 'some text'\n";
my $espeak_ok =
  "#!/bin/sh\ncat >/dev/null\n"
  . "while [ \$# -gt 0 ]; do case \"\$1\" in -w) shift; : >\"\$1\";; esac; shift; done\n";
my $ffmpeg_ok = "#!/bin/sh\nlast=\nfor a in \"\$@\"; do last=\$a; done\n: >\"\$last\"\n";
my $rsvg_ok =
  "#!/bin/sh\nout=\nfor a in \"\$@\"; do case \"\$a\" in --output=*) out=\${a#--output=};; esac; done\n: >\"\$out\"\n";

# ------------------------------------------------------------------
# html2ogg.sh
# ------------------------------------------------------------------
{
    my $bin = mkstubs(
        pandoc     => $pandoc_ok,
        'espeak-ng' => $espeak_ok,
        ffmpeg     => $ffmpeg_ok,
    );
    my $dir  = tempdir( CLEANUP => 1 );
    my $tmpd = tempdir( CLEANUP => 1 );
    spew( "$dir/a.html", "<html><body><p>hi</p></body></html>\n" );

    local $ENV{PATH}   = "$bin:" . ( $ENV{PATH} // '' );
    local $ENV{TMPDIR} = $tmpd;

    my $r = run_input( "1\n", $sh, script('html2ogg.sh'), "$dir/a.html" );
    is( $r->{status}, 0, 'html2ogg succeeds' )
      or diag( $r->{stdout} . $r->{stderr} );
    ok( -f "$dir/a.ogg", 'output .ogg created' );
    like( $r->{stdout}, qr/\[OK\]/, 'reports success' );

    opendir my $dh, $tmpd or die $!;
    my @left = grep { !/^\.\.?$/ } readdir $dh;
    closedir $dh;
    is_deeply( \@left, [], 'temporary file cleaned up' );
}

# html2ogg: pandoc failure aborts without producing output
{
    my $bin = mkstubs(
        pandoc      => "#!/bin/sh\necho boom >&2\nexit 2\n",
        'espeak-ng' => $espeak_ok,
        ffmpeg      => $ffmpeg_ok,
    );
    my $dir  = tempdir( CLEANUP => 1 );
    my $tmpd = tempdir( CLEANUP => 1 );
    spew( "$dir/b.html", "<html><body>x</body></html>\n" );
    local $ENV{PATH}   = "$bin:" . ( $ENV{PATH} // '' );
    local $ENV{TMPDIR} = $tmpd;

    my $r = run_input( "1\n", $sh, script('html2ogg.sh'), "$dir/b.html" );
    isnt( $r->{status}, 0, 'pandoc failure aborts' );
    ok( !-e "$dir/b.ogg", 'no output produced on failure' );
}

# html2ogg: invalid language option is rejected
{
    my $bin = mkstubs(
        pandoc      => $pandoc_ok,
        'espeak-ng' => $espeak_ok,
        ffmpeg      => $ffmpeg_ok,
    );
    my $dir = tempdir( CLEANUP => 1 );
    spew( "$dir/c.html", "<html><body>x</body></html>\n" );
    local $ENV{PATH} = "$bin:" . ( $ENV{PATH} // '' );
    my $r = run_input( "9\n", $sh, script('html2ogg.sh'), "$dir/c.html" );
    isnt( $r->{status}, 0, 'invalid option rejected' );
    like( $r->{stderr}, qr/Invalid option/, 'message' );
}

# html2ogg: missing dependency is reported (empty PATH)
{
    my $empty = tempdir( CLEANUP => 1 );
    my $dir   = tempdir( CLEANUP => 1 );
    spew( "$dir/d.html", "<html><body>x</body></html>\n" );
    local $ENV{PATH} = $empty;
    my $r = run_input( "1\n", $sh, script('html2ogg.sh'), "$dir/d.html" );
    isnt( $r->{status}, 0, 'missing dependency fails' );
    like( $r->{stderr}, qr/is not installed/, 'message' );
}

# ------------------------------------------------------------------
# svg2png.sh
# ------------------------------------------------------------------
{
    my $bin = mkstubs( 'rsvg-convert' => $rsvg_ok );
    my $dir = tempdir( CLEANUP => 1 );
    spew( "$dir/a.svg", "<svg xmlns='http://www.w3.org/2000/svg'/>\n" );
    local $ENV{PATH} = "$bin:" . ( $ENV{PATH} // '' );

    my $r = run( $sh, script('svg2png.sh'), $dir );
    is( $r->{status}, 0, 'svg2png succeeds' ) or diag( $r->{stderr} );
    ok( -f "$dir/a.png", 'png created' );

    my $r2 = run( $sh, script('svg2png.sh'), $dir );
    is( $r2->{status}, 0, 'second run succeeds' );
    like( $r2->{stdout}, qr/Skipping \(already exists\)/, 'existing skipped' );
}

# svg2png: names with spaces are handled
{
    my $bin = mkstubs( 'rsvg-convert' => $rsvg_ok );
    my $dir = tempdir( CLEANUP => 1 );
    spew( "$dir/my icon.svg", "<svg xmlns='http://www.w3.org/2000/svg'/>\n" );
    local $ENV{PATH} = "$bin:" . ( $ENV{PATH} // '' );
    my $r = run( $sh, script('svg2png.sh'), $dir );
    is( $r->{status}, 0, 'spaces handled' );
    ok( -f "$dir/my icon.png", 'png created for spaced name' );
}

# svg2png: missing directory fails
{
    my $bin = mkstubs( 'rsvg-convert' => $rsvg_ok );
    local $ENV{PATH} = "$bin:" . ( $ENV{PATH} // '' );
    my $r = run( $sh, script('svg2png.sh'), '/no/such/dir/exists' );
    isnt( $r->{status}, 0, 'missing directory fails' );
}

# svg2png: missing dependency (empty PATH)
{
    my $empty = tempdir( CLEANUP => 1 );
    my $dir   = tempdir( CLEANUP => 1 );
    spew( "$dir/a.svg", "<svg xmlns='http://www.w3.org/2000/svg'/>\n" );
    local $ENV{PATH} = $empty;
    my $r = run( $sh, script('svg2png.sh'), $dir );
    isnt( $r->{status}, 0, 'missing rsvg-convert fails' );
    like( $r->{stderr}, qr/is not installed/, 'message' );
}

done_testing();
