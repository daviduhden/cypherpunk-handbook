#!/usr/bin/perl

# Copyright (c) 2025-2026 David Uhden Collado
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# Small helper to update data/articles.json and feeds/articles.xml
# - Ensures articles.json is written with keys sorted alphabetically
# - Extracts first <p> from article files when available
# - Updates feeds/articles.xml with new item and updated pubDate/lastBuildDate
# -------------------------
# Usage: update-feeds.pl
# No arguments
# -------------------------
# Outputs to data/articles.json and feeds/articles.xml
# -------------------------
# Requires data/articles.json and articles/*.html to exist
# Requires Perl with JSON::PP
# Requires UTF-8 support
# Requires POSIX for strftime
# Requires Cwd and File::Basename for path handling
# Requires File::Spec for path handling
# Requires strict and warnings
# -------------------------
# Note: This is a simple script and does not handle all edge cases.

use strict;
use warnings;
use POSIX qw(strftime);
use File::Spec;
use JSON::PP;
use Time::Local qw(timegm);

# -------------------------
# Logging
# -------------------------
my $no_color  = 0;
my $is_tty    = ( -t STDOUT )             ? 1 : 0;
my $use_color = ( !$no_color && $is_tty ) ? 1 : 0;

my ( $GREEN, $YELLOW, $RED, $RESET ) = ( "", "", "", "" );
if ($use_color) {
    $GREEN  = "\e[32m";
    $YELLOW = "\e[33m";
    $RED    = "\e[31m";
    $RESET  = "\e[0m";
}

sub logi { print "${GREEN}✅ [INFO]${RESET} $_[0]\n"; }
sub logw { print STDERR "${YELLOW}⚠️ [WARN]${RESET} $_[0]\n"; }
sub loge { print STDERR "${RED}❌ [ERROR]${RESET} $_[0]\n"; }

sub die_tool {
    my ($msg) = @_;
    loge($msg);
    exit 1;
}

sub read_file {
    my ($p) = @_;
    open my $fh, '<:encoding(UTF-8)', $p or return undef;
    local $/;
    my $c = <$fh>;
    close $fh;
    $c;
}

sub write_file {
    my ( $p, $c ) = @_;
    open my $fh, '>:encoding(UTF-8)', $p or die_tool "Could not write $p: $!\n";
    print {$fh} $c;
    close $fh;
}

sub xml_escape {
    my ($t) = @_;
    return '' unless defined $t;
    $t =~ s/&/&amp;/g;
    $t =~ s/</&lt;/g;
    $t =~ s/>/&gt;/g;
    $t;
}

sub iso_to_epoch {
    my ($s) = @_;
    return undef unless defined $s;
    if ( $s =~ /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})Z$/ ) {
        my ( $Y, $M, $D, $h, $m, $sec ) = ( $1, $2, $3, $4, $5, $6 );
        return timegm( $sec, $m, $h, $D, $M - 1, $Y );
    }
    return undef;
}

my $root = File::Spec->catdir( ( File::Spec->splitpath($0) )[1] || '.', '..' );
my $data_file    = File::Spec->catfile( $root, 'data',  'articles.json' );
my $feed         = File::Spec->catfile( $root, 'feeds', 'articles.xml' );
my $articles_dir = File::Spec->catdir( $root, 'articles' );

sub prompt {
    my ( $m, $d ) = @_;
    print "$m" . ( defined $d ? " [$d]" : "" ) . ": ";
    my $in = <STDIN>;
    chomp $in;
    return length($in) ? $in : $d;
}

my $slug = prompt( 'Slug (without .html)', '' );
$slug =~ s/^\s+|\s+$//g;
die_tool "slug required" unless length $slug;
my $title = prompt( 'Title',       '' );
my $desc  = prompt( 'Description', '' );

# try to extract <time datetime> from article
my $article_path = File::Spec->catfile( $articles_dir, "$slug.html" );
my $found_iso    = undef;
if ( -e $article_path ) {
    my $html = read_file($article_path) // '';
    if ( $html =~ /\<time[^>]*datetime\s*=\s*"([^"]+)"/i ) { $found_iso = $1 }
}
my $pub_iso =
  $found_iso || prompt( 'Publication date ISO (YYYY-MM-DDTHH:MM:SSZ)', '' );
my $pub_epoch = iso_to_epoch($pub_iso) || time();
my $pub_rfc   = strftime( '%a, %d %b %Y %H:%M:%S GMT', gmtime($pub_epoch) );

# update feed immediate insert (not canonical)
my $link = "./../articles/$slug.html";
my $item =
    "    <item>\n"
  . "      <title>"
  . xml_escape($title)
  . "</title>\n"
  . "      <link>$link</link>\n"
  . "      <description>"
  . xml_escape($desc)
  . "</description>\n"
  . "      <pubDate>$pub_rfc</pubDate>\n"
  . "      <guid>$link</guid>\n"
  . "    </item>\n";
my $content = read_file($feed) // die_tool "Feed template missing: $feed\n";
$content =~ s{<pubDate>[^<]*</pubDate>}{<pubDate>$pub_rfc</pubDate>}m;
$content =~
s{<lastBuildDate>[^<]*</lastBuildDate>}{<lastBuildDate>$pub_rfc</lastBuildDate>}m;
$content =~ s{(</lastBuildDate>\s*\n)}{$1\n$item}m
  or $content =~ s{(</channel>)}{$item$1}m;
write_file( $feed, $content );

# update data/articles.json
my $articles = {};
if ( -e $data_file ) {
    my $j = read_file($data_file);
    eval { $articles = JSON::PP->new->utf8->decode($j); 1 } or $articles = {};
}
$articles->{$slug} =
  { en => "$slug.html", title_en => $title, pubdate => $pub_iso };
my $out = JSON::PP->new->utf8->canonical->pretty->encode($articles);
write_file( $data_file, $out );

# call rebuild if exists
my $rebuild = File::Spec->catfile( $root, 'scripts', 'rebuild-feeds.pl' );
if ( -x $rebuild ) { system( $^X, $rebuild ) == 0 or logw("rebuild failed") }

logi("Updated cypherpunk-handbook feed and data mapping.");

exit 0;
