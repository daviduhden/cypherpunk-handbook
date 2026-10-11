#!/usr/bin/perl
# Regression tests for the internal link checker in
# scripts/validate-website.pl. Runs the real script against isolated
# fixtures with only HTML files, so no CSS/JS tooling is required.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite       qw(script run slurp spew);
use File::Temp     qw(tempdir);
use File::Path     qw(make_path);
use File::Basename qw(dirname);

my $validator = script('validate-website.pl');

my $have_tidy = ( run( 'tidy', '-v' )->{status} == 0 );
plan skip_all => 'tidy not available' if !$have_tidy;

sub page {
    my ($body) = @_;
    return
        "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
      . "<meta charset=\"utf-8\">\n<title>fixture</title>\n</head>\n"
      . "<body>\n$body\n</body>\n</html>\n";
}

# Write a file and normalise it with tidy so `--check` sees it as clean.
sub write_page {
    my ( $dir, $rel, $body ) = @_;
    my $p = "$dir/$rel";
    make_path( dirname($p) ) if dirname($p) ne $dir;
    spew( $p, page($body) );
    run(
        'tidy',             '-indent', '-quiet',              '-wrap',
        '80',               '-utf8',   '--indent-spaces',     '2',
        '--tidy-mark',      'no',      '--preserve-entities', 'yes',
        '--vertical-space', 'yes',     '-m',                  $p
    );
    return $p;
}

sub check_links {
    my ($dir) = @_;
    return run( $^X, $validator, '--root', $dir, '--check', '--check-links' );
}

sub report_of {
    my ($r)    = @_;
    my ($path) = $r->{stdout} =~ m{Temporary link report written to:\s*(\S+)};
    return defined $path ? slurp($path) : '';
}

# --- valid internal links pass --------------------------------------
{
    my $dir = tempdir( CLEANUP => 1 );
    write_page( $dir, 'index.html', '<p><a href="sub/other.html">x</a></p>' );
    write_page( $dir, 'sub/other.html', '<p>ok</p>' );
    my $r = check_links($dir);
    is( $r->{status}, 0, 'valid internal links pass' )
      or diag( $r->{stdout} . $r->{stderr} );
}

# --- broken internal link fails -------------------------------------
{
    my $dir = tempdir( CLEANUP => 1 );
    write_page( $dir, 'index.html', '<p><a href="missing.html">x</a></p>' );
    my $r = check_links($dir);
    is( $r->{status}, 2, 'broken internal link fails' );
    like( report_of($r), qr/missing\.html/, 'report names the link' );
    like( report_of($r), qr/^broken \|/m,   'report marks it broken' );
}

# --- JavaScript `new URL(...)` is not treated as a CSS url() --------
{
    my $dir = tempdir( CLEANUP => 1 );
    write_page( $dir, 'index.html',
            '<p><a href="a.html">x</a></p>' . "\n"
          . '<script>var u = new URL(window.location.href);</script>' );
    write_page( $dir, 'a.html', '<p>ok</p>' );
    my $r = check_links($dir);
    is( $r->{status}, 0, 'new URL(...) in a script is ignored' )
      or diag( $r->{stderr} );
    unlike( report_of($r), qr/window\.location/,
        'script text not treated as a link' );
}

done_testing();
