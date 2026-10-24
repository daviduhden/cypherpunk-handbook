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
use File::Basename qw(basename dirname);

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
    my ($path) = $r->{stdout} =~ m{Temporary link report written to:\s*(\S+)}sm;
    return defined $path ? slurp($path) : q{};
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
    like( report_of($r), qr/missing\.html/sm, 'report names the link' );
    like( report_of($r), qr/^broken \|/ms,    'report marks it broken' );
}

# --- a prefix-sharing sibling directory is outside the root --------
{
    my $dir     = tempdir( CLEANUP => 1 );
    my $outside = "$dir-outside";
    make_path($outside);
    spew( "$outside/secret.html", page('<p>secret</p>') );

    my $rel = '../' . basename($dir) . '-outside/secret.html';
    write_page( $dir, 'index.html', qq{<p><a href="$rel">x</a></p>} );
    my $r = check_links($dir);
    is( $r->{status}, 2, 'link outside the root is rejected' );
    like( report_of($r), qr/^broken [|]/m, 'report marks it broken' );

    unlink "$outside/secret.html";
    rmdir $outside;
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
    unlike( report_of($r), qr/window\.location/sm,
        'script text not treated as a link' );
}

# --- a proposed fix does not make a broken link pass in --check ---
{
    my $dir = tempdir( CLEANUP => 1 );
    write_page( $dir, 'index.html', '<p><a href="target">x</a></p>' );
    write_page( $dir, 'target.html', '<p>ok</p>' );
    my $r = check_links($dir);
    is( $r->{status}, 2, 'broken link with a candidate still fails' );
    like( report_of($r), qr/^broken [|]/m, 'report marks it broken' );
    like( report_of($r), qr/target\.html/sm,
        'report records the proposed candidate' );
}

# --- ignored build directories are pruned ---------------------------
{
    my $dir = tempdir( CLEANUP => 1 );
    write_page( $dir, 'index.html', '<p>ok</p>' );
    make_path("$dir/node_modules");
    spew( "$dir/node_modules/broken.html",
        page('<p><a href="missing.html">x</a></p>') );
    my $r = check_links($dir);
    is( $r->{status}, 0, 'node_modules is not validated' )
      or diag( $r->{stdout} . $r->{stderr} );
    unlike( $r->{stdout} . $r->{stderr}, qr/node_modules/sm,
        'node_modules does not appear in the run' );
}

# --- --noapply does not rewrite tracked target files ----------------
{
    my $dir = tempdir( CLEANUP => 1 );
    my $p   = write_page( $dir, 'index.html',
        '<p><a href="target">x</a></p>' );
    write_page( $dir, 'target.html', '<p>ok</p>' );
    my $before = slurp($p);
    my $r      = run( $^X, $validator, '--root', $dir, '--noapply',
        '--check-links' );
    is( $r->{status}, 2, '--noapply leaves check mode active' );
    is( slurp($p), $before, '--noapply leaves the link unfixed' );
}

# --- --check-links-external implies internal link checking ----------
{
    my $dir = tempdir( CLEANUP => 1 );
    write_page( $dir, 'index.html', '<p><a href="missing.html">x</a></p>' );
    my $have_curl = ( run( 'curl', '--version' )->{status} == 0 );
  SKIP: {
        skip 'curl not available', 1 if !$have_curl;
        my $r = run( $^X, $validator, '--root', $dir, '--check',
            '--check-links-external' );
        is( $r->{status}, 2,
            '--check-links-external performs internal link checks' );
    }
}

# --- a missing root is a tooling error, not success -----------------
{
    my $dir = tempdir( CLEANUP => 1 );
    my $r   = run( $^X, $validator, '--root', "$dir/missing", '--check' );
    is( $r->{status}, 1, 'missing root exits 1' );
}

done_testing();
