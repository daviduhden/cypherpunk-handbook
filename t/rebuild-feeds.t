#!/usr/bin/perl
# Regression tests for scripts/rebuild-feeds.pl (cypherpunk-handbook).
# These tests operate entirely inside isolated temporary fixtures; they
# never read or write the real repository files.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite qw(fixture slurp);
use File::Spec;

my $U = "\x{263A}";    # ☺ - checked in a UTF-8 handling test

sub article {
    my (%a)   = @_;
    my $lang  = $a{lang}  // 'en';
    my $time  = $a{time}  // '2026-01-02';
    my $title = $a{title} // 'Title';
    my $desc  = $a{desc}  // 'Description';
    return
        "<!DOCTYPE html>\n<html lang=\"$lang\">\n<head>\n"
      . "<meta charset=\"utf-8\">\n"
      . "<meta name=\"description\" content=\"$desc\">\n"
      . "</head>\n<body>\n<article>\n"
      . "<header id=\"article-header\">\n<h1>$title</h1>\n"
      . "<p class=\"meta\"><time datetime=\"$time\">x</time></p>\n"
      . "</header>\n</article>\n</body>\n</html>\n";
}

sub feed {
    my (%a)   = @_;
    my $title = $a{title} // 'Test - Articles';
    my $desc  = $a{desc}  // 'Channel description';
    return <<"XML";
<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
  <channel>
    <title>$title</title>
    <link>/</link>
    <description>$desc</description>
    <lastBuildDate>Thu, 01 Jan 2026 00:00:00 GMT</lastBuildDate>
    <atom:link href="/feeds/articles.xml" rel="self" type="application/rss+xml"/>
  </channel>
</rss>
XML
}

sub run_rebuild {
    my ( $dir, @args ) = @_;
    my $script = File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' );
    my $r      = TestSite::run( $^X, $script, @args );
    return ( $r, File::Spec->catfile( $dir, 'feeds', 'articles.xml' ) );
}

sub item_slugs {
    my ($xml) = @_;
    my @s = $xml =~ m{<link>/articles/([^<]+)\.html</link>}g;
    return @s;
}

# --- deterministic ordering (ties broken by slug) -------------------
{
    my $dir = fixture(
        'feeds/articles.xml' => feed(),
        'articles/b.html'    => article( time => '2026-01-01', title => 'B' ),
        'articles/a.html'    => article( time => '2026-01-01', title => 'A' ),
        'articles/c.html'    => article( time => '2026-02-01', title => 'C' ),
    );
    my ( $r, $feed ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds' )
      or diag( $r->{stdout} . $r->{stderr} );
    my @slugs = item_slugs( slurp($feed) );
    is_deeply( \@slugs, [ 'c', 'a', 'b' ], 'sorted by date desc, slug asc' );
}

# --- reproducibility: repeated run, TZ, locale, working dir ---------
{
    my $dir = fixture(
        'feeds/articles.xml' => feed(),
        'articles/a.html'    => article( time => '2026-01-01' ),
        'articles/b.html'    => article( time => '2026-01-01' ),
    );
    my $script = File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' );
    my $feed   = File::Spec->catfile( $dir, 'feeds',   'articles.xml' );

    TestSite::run( $^X, $script );
    my $first = slurp($feed);

    TestSite::run( $^X, $script );
    is( slurp($feed), $first, 'repeated run is byte-identical' );

    local $ENV{TZ}     = 'America/New_York';
    local $ENV{LC_ALL} = 'C';
    TestSite::run( $^X, $script );
    is( slurp($feed), $first, 'TZ/locale do not change output' );

    TestSite::run( $^X, $script );
    is( slurp($feed), $first, 'still identical after locale change' );
}

# --- XML escaping and entity handling of item metadata ---------------
{
    my $dir = fixture(
        'feeds/articles.xml' => feed(),
        'articles/x.html'    => article(
            title => 'A & B',
            desc  => 'd &amp; d &lt;e&gt;'
        ),
        'articles/y.html' => article(
            title => 'A <b>bold</b> B',
            desc  => 'plain'
        ),
    );
    my ( $r, $feed ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds' );
    my $xml = slurp($feed);
    like( $xml, qr{<title>A &amp; B</title>}, 'ampersand escaped once' );
    unlike( $xml, qr{&amp;amp;}, 'no double encoding in title' );
    like(
        $xml,
        qr{<description>d &amp; d &lt;e&gt;</description>},
        'entities decoded then re-escaped once'
    );
    unlike( $xml, qr{<description>d &amp;amp; d}, 'no double encoding' );
    like( $xml, qr{<title>A bold B</title>},
        'inline tags stripped from title' );
    unlike( $xml, qr{<b>}, 'no raw markup in feed' );
}

# --- existing channel entities are preserved (no double encoding) ---
{
    my $dir = fixture(
        'feeds/articles.xml' => feed( title => 'A &amp; B' ),
        'articles/a.html'    => article(),
    );
    my ( $r, $feed ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds' );
    my $xml = slurp($feed);
    like( $xml, qr{<title>A &amp; B</title>}, 'channel entity preserved' );
    unlike( $xml, qr{&amp;amp;}, 'no double encoding' );
}

# --- UTF-8 content is written as valid UTF-8 ------------------------
{
    my $dir = fixture(
        'feeds/articles.xml' => feed(),
        'articles/u.html'    => article( title => "Caf\x{e9} $U" ),
    );
    my ( $r, $feed ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds with UTF-8' );
    my $raw = slurp($feed);
    like( $raw, qr/Caf\xc3\xa9/,  'UTF-8 bytes preserved (é)' );
    like( $raw, qr/\xe2\x98\xba/, 'UTF-8 bytes preserved (☺)' );
}

# --- atomic write preserves permissions and leaves no temp files ----
{
    my $dir = fixture(
        'feeds/articles.xml' => feed(),
        'articles/a.html'    => article(),
    );
    my $feed = File::Spec->catfile( $dir, 'feeds', 'articles.xml' );
    chmod 0640, $feed;
    my ( $r, $f ) = run_rebuild($dir);
    is( $r->{status},           0,    'rebuild succeeds' );
    is( ( stat $f )[2] & 07777, 0640, 'file mode preserved' );

    opendir my $dh, File::Spec->catdir( $dir, 'feeds' ) or die $!;
    my @tmp = grep { /^\.tmp-/ } readdir $dh;
    closedir $dh;
    is_deeply( \@tmp, [], 'no temporary files left behind' );
}

# --- index.html is ignored ------------------------------------------
{
    my $dir = fixture(
        'feeds/articles.xml'  => feed(),
        'articles/index.html' => article( title => 'Index' ),
        'articles/a.html'     => article( title => 'A' ),
    );
    my ( $r, $feed ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds' );
    my @slugs = item_slugs( slurp($feed) );
    is_deeply( \@slugs, ['a'], 'index.html not listed' );
}

# --- empty articles directory yields an empty but valid feed --------
{
    my $dir = fixture( 'feeds/articles.xml' => feed() );
    my ( $r, $feed ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds with no articles' );
    my $xml = slurp($feed);
    unlike( $xml, qr/<item>/, 'no items' );
    like( $xml, qr{</channel>}, 'channel closed' );
}

# --- article without <time> still works (mtime fallback) ------------
{
    my $no_time =
        "<html lang=\"en\"><body><article>"
      . "<header id=\"article-header\"><h1>No Time</h1></header>"
      . "</article></body></html>\n";
    my $dir = fixture(
        'feeds/articles.xml' => feed(),
        'articles/nt.html'   => $no_time,
    );
    my ( $r, $feed ) = run_rebuild($dir);
    is( $r->{status}, 0, 'rebuild succeeds without <time>' );
    like( slurp($feed), qr{<link>/articles/nt\.html</link>}, 'item present' );
}

# --- missing feed is a hard error -----------------------------------
{
    my $dir    = fixture( 'articles/a.html' => article() );
    my $script = File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' );
    my $r      = TestSite::run( $^X, $script );
    isnt( $r->{status}, 0, 'missing feed target fails' );
    like(
        $r->{stderr},
        qr/No supported feed files found/,
        'clear error message'
    );
}

# --- optional absolute base URL; GUIDs stay stable ------------------
{
    my $dir = fixture(
        'feeds/articles.xml' => feed(),
        'articles/a.html'    => article(),
    );
    my ( $r, $feed ) = run_rebuild( $dir, '--base-url', 'https://example.org' );
    is( $r->{status}, 0, 'base-url run succeeds' );
    my $xml = slurp($feed);
    like(
        $xml,
        qr{<link>https://example\.org/articles/a\.html</link>},
        'item link made absolute'
    );
    like(
        $xml,
        qr{<link>https://example\.org/</link>},
        'channel link made absolute'
    );
    like(
        $xml,
        qr{<atom:link href="https://example\.org/feeds/articles\.xml"},
        'atom self link made absolute'
    );
    like(
        $xml,
        qr{<guid isPermaLink="false">/articles/a\.html</guid>},
        'guid stays root-relative and stable'
    );
}

done_testing();
