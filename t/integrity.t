#!/usr/bin/perl
# Content integrity checks for cypherpunk-handbook.
# These read the real repository (read-only) and fail if the article
# index, HTML metadata, feeds, or sitemap drift apart.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite       qw(repo_root slurp);
use File::Basename qw(basename);
use File::Spec;
use JSON::PP qw(decode_json);

my $root = repo_root();

sub file {
    my ($relative) = @_;
    return File::Spec->catfile( $root, split m{/}sm, $relative );
}

sub h1_of {
    my ($path) = @_;
    my $s      = slurp($path);
    my ($h)    = $s =~ m{<h1[^>]*>(.*?)</h1>}sm;
    return if !defined $h;
    $h =~ s/<[^>]+>//gsm;
    $h =~ s/\s+/ /gsm;
    $h =~ s/^\s+|\s+$//gs;
    return $h;
}

my $json = eval { decode_json( slurp( file('data/articles.json') ) ) };
ok( defined $json, 'data/articles.json parses as JSON' )
  or BAIL_OUT('cannot parse article index');

# --- index <-> files, both directions -------------------------------
my %covered;
my @dupes;
for my $key ( sort keys %{$json} ) {
    my $e = $json->{$key};
    for my $lang (qw(en es)) {
        next if !defined $e->{$lang};
        my $fn = $e->{$lang};
        push @dupes, $fn if $covered{$fn}++;
        my $p = file("articles/$fn");
        ok( -f $p, "index entry $key/$lang points to an existing file" );
        next if !-f $p;
        my $h1 = h1_of($p);
        is( $h1, $e->{"title_$lang"}, "title matches <h1> for $fn" );
    }
}
is_deeply( \@dupes, [], 'no article file is listed twice' );

opendir my $dh, file('articles') or die "opendir articles: $!";
my @html = sort grep { /\.html$/is } readdir $dh;
closedir $dh;
for my $fn (@html) {
    ok( $covered{$fn}, "articles/$fn is listed in data/articles.json" );
}

# --- feeds reference existing articles ------------------------------
for my $feed ( glob( file('feeds/*.xml') ) ) {
    my $xml   = slurp($feed);
    my @links = $xml =~ m{<link>/articles/([^<]+)</link>}gsm;
    ok( scalar(@links), basename($feed) . ' has items' );
    for my $fn (@links) {
        ok( -f file("articles/$fn"), "feed link targets articles/$fn" );
    }
    while ( $xml =~ m{<guid\s+isPermaLink="false">([^<]+)</guid>}gsm ) {
        my $g = $1;
        like( $g, qr{^/articles/}s,
            'guid is a stable root-relative identifier' );
    }
}

# --- sitemap targets exist ------------------------------------------
my $sm   = slurp( file('sitemap.xml') );
my @locs = $sm =~ m{<loc>(.*?)</loc>}gm;
ok( scalar(@locs), 'sitemap has entries' );
for my $loc (@locs) {
    ( my $path = $loc ) =~ s{^https?://[^/]+/?}{}s;
    $path =~ s{^/}{}s;
    if ( $path eq q{} || $path =~ m{/$}s ) {
        my $idx = file( $path . 'index.html' );
        ok( -f $idx, "sitemap $loc maps to $idx" );
    }
    else {
        ok( -f file($path), "sitemap $loc maps to $path" );
    }
}
for my $fn (@html) {
    like( $sm, qr{/articles/\Q$fn\E</loc>}s,
        "articles/$fn appears in sitemap" );
}

done_testing();
