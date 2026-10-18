#!/usr/bin/perl
# Regression tests for scripts/rebuild-sitemap.pl.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite qw(fixture slurp);
use File::Spec;

sub locs {
    my ($xml) = @_;
    my @l = $xml =~ m{<loc>(.*?)</loc>}gm;
    return @l;
}

sub strip_origin {
    my ($url) = @_;
    $url =~ s{^https?://[^/]+}{}s;
    return $url;
}

sub run_sitemap {
    my ($dir)  = @_;
    my $script = File::Spec->catfile( $dir, 'scripts', 'rebuild-sitemap.pl' );
    my $r      = TestSite::run( $^X, $script );
    return ( $r, "$dir/sitemap.xml" );
}

my $page = '<!DOCTYPE html><html lang="en"><head>'
  . "<title>x</title></head><body><p>x</p></body></html>\n";

{
    my $dir = fixture(
        'index.html'       => $page,
        'a.html'           => $page,
        'sub/index.html'   => $page,
        'sub/b.html'       => $page,
        'archive/old.html' => $page,
        'templates/t.html' => $page,
    );
    my ( $r, $sm ) = run_sitemap($dir);
    is( $r->{status}, 0, 'sitemap rebuild succeeds' )
      or diag( $r->{stdout} . $r->{stderr} );

    my @locs  = locs( slurp($sm) );
    my @paths = map { strip_origin($_) } @locs;

    is_deeply(
        [ sort @paths ],
        [ sort qw( / /a.html /sub/ /sub/b.html ) ],
        'index pages map to directories; archive/templates excluded'
    );
    is_deeply( \@paths, [ sort @paths ], 'entries are sorted' );

    my $first = slurp($sm);
    TestSite::run( $^X,
        File::Spec->catfile( $dir, 'scripts', 'rebuild-sitemap.pl' ) );
    is( slurp($sm), $first, 'regeneration is deterministic' );

    chmod 0640, $sm;
    TestSite::run( $^X,
        File::Spec->catfile( $dir, 'scripts', 'rebuild-sitemap.pl' ) );
    is( ( stat $sm )[2] & 07777, 0640, 'file mode preserved' );

    opendir my $dh, $dir or die $!;
    my @tmp = grep { /^\.tmp-/s } readdir $dh;
    closedir $dh;
    is_deeply( \@tmp, [], 'no temp files left behind' );

    like(
        slurp($sm),
        qr{^<\?xml version="1\.0" encoding="UTF-8"\?>}s,
        'XML declaration present'
    );
}

done_testing();
