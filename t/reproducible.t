#!/usr/bin/perl
# Verifies that the committed feeds and sitemap are exactly what the
# generators produce from the committed sources. This catches stale
# generated artifacts as well as non-deterministic output.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite qw(clone_repo repo_root run slurp);
use File::Spec;
use File::Basename qw(basename);

my $root = repo_root();
my $dir  = clone_repo();

my $feeds = run( $^X, File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' ) );
is( $feeds->{status}, 0, 'rebuild-feeds.pl runs on a clean clone' )
  or diag( $feeds->{stdout} . $feeds->{stderr} );

my $sitemap =
  run( $^X, File::Spec->catfile( $dir, 'scripts', 'rebuild-sitemap.pl' ) );
is( $sitemap->{status}, 0, 'rebuild-sitemap.pl runs on a clean clone' )
  or diag( $sitemap->{stdout} . $sitemap->{stderr} );

for my $f ( glob File::Spec->catfile( $root, 'feeds', '*.xml' ) ) {
    my $name = basename($f);
    my $gen  = File::Spec->catfile( $dir, 'feeds', $name );
    is( slurp($gen), slurp($f), "feeds/$name matches the generator output" );
}

is(
    slurp( File::Spec->catfile( $dir,   'sitemap.xml' ) ),
    slurp( File::Spec->catfile( $root,  'sitemap.xml' ) ),
    'sitemap.xml matches the generator output'
);

# A second run must not change anything (determinism).
run( $^X, File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' ) );
for my $f ( glob File::Spec->catfile( $root, 'feeds', '*.xml' ) ) {
    my $name = basename($f);
    my $gen  = File::Spec->catfile( $dir, 'feeds', $name );
    is( slurp($gen), slurp($f), "feeds/$name stable on a second run" );
}

done_testing();
