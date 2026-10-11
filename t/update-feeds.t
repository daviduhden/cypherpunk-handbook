#!/usr/bin/perl
# Regression tests for scripts/update-feeds.pl (cypherpunk-handbook).
# The script is interactive, so answers are fed through a pipe. Where
# the automatic rebuild would hide the raw insertion, rebuild-feeds.pl
# is removed from the fixture first.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite qw(fixture run_input slurp);
use File::Spec;

sub feed {
    my (%a) = @_;
    my $body = $a{body} // '';
    return <<"XML";
<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
  <channel>
    <title>Test - Articles</title>
    <link>/</link>
    <description>Channel description</description>
    <lastBuildDate>Thu, 01 Jan 2026 00:00:00 GMT</lastBuildDate>
    <atom:link href="/feeds/articles.xml" rel="self" type="application/rss+xml"/>
$body  </channel>
</rss>
XML
}

sub item {
    my (%a) = @_;
    return
        "    <item>\n"
      . "      <title>$a{title}</title>\n"
      . "      <link>$a{link}</link>\n"
      . "      <description>$a{desc}</description>\n"
      . "      <pubDate>$a{pub}</pubDate>\n"
      . "      <guid isPermaLink=\"false\">$a{link}</guid>\n"
      . "    </item>\n";
}

sub run_update {
    my ( $dir, $input, @args ) = @_;
    my $script = File::Spec->catfile( $dir, 'scripts', 'update-feeds.pl' );
    return run_input( $input, $^X, $script, @args );
}

sub strip_rebuild {
    my ($dir) = @_;
    unlink File::Spec->catfile( $dir, 'scripts', 'rebuild-feeds.pl' );
}

# --- inserts a new item with escaped metadata -----------------------
{
    my $dir = fixture( 'feeds/articles.xml' => feed() );
    strip_rebuild($dir);
    my $r = run_update( $dir, "newslug\nA & B\nD & D\n2026-03-04\n" );
    is( $r->{status}, 0, 'insert succeeds' ) or diag( $r->{stderr} );
    my $xml = slurp("$dir/feeds/articles.xml");
    like( $xml, qr{<link>/articles/newslug\.html</link>}, 'link inserted' );
    like(
        $xml,
        qr{<guid isPermaLink="false">/articles/newslug\.html</guid>},
        'guid uses stable relative identifier'
    );
    like( $xml, qr{<title>A &amp; B</title>},             'title escaped' );
    like( $xml, qr{<description>D &amp; D</description>}, 'desc escaped' );
    like(
        $xml,
        qr{<lastBuildDate>Wed, 04 Mar 2026 00:00:00 GMT</lastBuildDate>},
        'lastBuildDate refreshed'
    );
}

# --- existing link warns and does not duplicate ---------------------
{
    my $existing = item(
        title => 'Dup',
        link  => '/articles/dup.html',
        desc  => 'dup',
        pub   => 'Thu, 01 Jan 2026 00:00:00 GMT'
    );
    my $dir = fixture(
        'feeds/articles.xml' => feed( body => $existing ),
        'articles/dup.html'  => "<html lang=\"en\"><body><article>"
          . "<header id=\"article-header\"><h1>Dup</h1>"
          . "<time datetime=\"2026-01-01\">x</time></header>"
          . "</article></body></html>\n",
    );
    strip_rebuild($dir);
    my $before = slurp("$dir/feeds/articles.xml");
    my $r      = run_update( $dir, "dup\nT\nD\n" );
    is( $r->{status}, 0, 'kept without --replace' );
    like( $r->{stderr}, qr/Feed already has/, 'warns about existing link' );
    is( slurp("$dir/feeds/articles.xml"), $before, 'feed unchanged' );
}

# --- --replace removes the previous item and adds one ---------------
{
    my $existing = item(
        title => 'Old',
        link  => '/articles/gpl.html',
        desc  => 'old',
        pub   => 'Thu, 01 Jan 2026 00:00:00 GMT'
    );
    my $dir = fixture(
        'feeds/articles.xml' => feed( body => $existing ),
        'articles/gpl.html'  => "<html lang=\"en\"><body><article>"
          . "<header id=\"article-header\"><h1>GPL</h1>"
          . "<time datetime=\"2026-03-04\">x</time></header>"
          . "</article></body></html>\n",
    );
    strip_rebuild($dir);
    my $r = run_update( $dir, "gpl\nNew Title\nNew Desc\n", '--replace' );
    is( $r->{status}, 0, 'replace succeeds' ) or diag( $r->{stderr} );
    my $xml   = slurp("$dir/feeds/articles.xml");
    my $count = () = $xml =~ m{/articles/gpl\.html}g;
    is( $count, 2, 'exactly one item link and one guid' );
    like( $xml, qr{<title>New Title</title>}, 'new title present' );
    unlike( $xml, qr{<title>Old</title>}, 'old title removed' );
}

# --- invalid slug is rejected ---------------------------------------
{
    my $dir = fixture( 'feeds/articles.xml' => feed() );
    strip_rebuild($dir);
    my $before = slurp("$dir/feeds/articles.xml");
    my $r      = run_update( $dir, "../evil\n" );
    isnt( $r->{status}, 0, 'invalid slug rejected' );
    like(
        $r->{stderr},
        qr/may only contain lowercase letters/,
        'error explains the slug rule'
    );
    is( slurp("$dir/feeds/articles.xml"), $before, 'feed untouched' );
}

# --- full path with automatic rebuild -------------------------------
{
    my $dir = fixture(
        'feeds/articles.xml' => feed(),
        'articles/auto.html' => "<html lang=\"en\"><body><article>"
          . "<header id=\"article-header\"><h1>Auto</h1>"
          . "<time datetime=\"2026-03-04\">x</time></header>"
          . "</article></body></html>\n",
    );
    my $r = run_update( $dir, "auto\nAuto\nAuto desc\n" );
    is( $r->{status}, 0, 'run with rebuild succeeds' );
    my $xml = slurp("$dir/feeds/articles.xml");
    like( $xml, qr{<link>/articles/auto\.html</link>}, 'item after rebuild' );
    like( $xml, qr{<title>Auto</title>}, 'title from article after rebuild' );
    unlike( $xml, qr{<title>Auto desc</title>}, 'no stray fields' );
}

done_testing();
