#!/usr/bin/perl

# Copyright (c) 2025 David Uhden Collado
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
# This script rebuilds feeds/articles.xml from data/articles.json
# - Reads data/articles.json
# - Ensures articles.json is written with keys sorted alphabetically
# - Extracts first <p> from article files when available
# - Writes feeds with UTF-8 encoding and RFC2822 pubDates
# -------------------------
# Usage: rebuild-feeds.pl
# No arguments
# -------------------------
# Outputs to feeds/articles.xml
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
use JSON::PP;
use File::Spec;
use POSIX          qw(strftime);
use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use Time::Local    qw(timegm);

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

sub read_utf8 {
    my ($p) = @_;
    open my $fh, '<:encoding(UTF-8)', $p or return undef;
    local $/;
    my $c = <$fh>;
    close $fh;
    $c;
}

sub write_utf8 {
    my ( $p, $c ) = @_;
    open my $fh, '>:encoding(UTF-8)', $p or die_tool "Could not write $p: $!\n";
    print {$fh} $c;
    close $fh;
}

sub xml_escape {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s;
}

sub rfc2822_from_ts_locale {
    my ( $t, $lang ) = @_;
    $lang ||= 'en';
    my @wday_en = qw(Sun Mon Tue Wed Thu Fri Sat);
    my @mon_en  = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @wday_es = qw(dom lun mar mié jue vie sáb);
    my @mon_es  = qw(ene feb mar abr may jun jul ago sep oct nov dic);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = gmtime($t);
    $year += 1900;

    if ( $lang eq 'es' ) {
        my $wd = $wday_es[$wday] || 'dom';
        my $mn = $mon_es[$mon]   || 'ene';
        return sprintf( '%s, %02d %s %d %02d:%02d:%02d GMT',
            lc($wd), $mday, lc($mn), $year, $hour, $min, $sec );
    }
    else {
        my $wd = $wday_en[$wday] || 'Sun';
        my $mn = $mon_en[$mon]   || 'Jan';
        return sprintf( '%s, %02d %s %d %02d:%02d:%02d GMT',
            $wd, $mday, $mn, $year, $hour, $min, $sec );
    }
}

sub iso_to_epoch {
    my ($s) = @_;
    return undef unless defined $s;
    if ( $s =~
/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(Z|([+-])(\d{2}):(\d{2}))?$/
      )
    {
        my ( $Y, $M, $D, $h, $m, $sec, $z, $sign, $oh, $om ) =
          ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10 );
        $Y   -= 0;
        $M   -= 1;
        $D   -= 0;
        $h   -= 0;
        $m   -= 0;
        $sec -= 0;
        my $epoch = timegm( $sec, $m, $h, $D, $M, $Y );

        if ( defined $sign && defined $oh ) {
            my $ofs = $oh * 3600 + $om * 60;
            $epoch -= ( $sign eq '+' ) ? $ofs : -$ofs;
        }
        return $epoch;
    }
    if ( $s =~ /^(\d{4})-(\d{2})-(\d{2})$/ ) {
        my ( $Y, $M, $D ) = ( $1, $2, $3 );
        return timegm( 0, 0, 0, $D, $M - 1, $Y );
    }
    return undef;
}

sub first_paragraph {
    my ($path) = @_;
    return '' unless -e $path;
    my $html = read_utf8($path) // '';
    if ( $html =~ /<p>(.*?)<\/p>/s ) {
        my $p = $1;
        $p =~ s/<[^>]+>//g;
        $p =~ s/\s+/ /g;
        $p =~ s/^\s+|\s+$//g;
        return $p;
    }
    return '';
}

my $script_path  = abs_path($0);
my $root         = File::Spec->catdir( dirname($script_path), '..' );
my $data_file    = File::Spec->catfile( $root, 'data',  'articles.json' );
my $feed         = File::Spec->catfile( $root, 'feeds', 'articles.xml' );
my $articles_dir = File::Spec->catdir( $root, 'articles' );

my $json_text = read_utf8($data_file) // '{}';
my $articles  = eval { JSON::PP->new->utf8->decode($json_text) } || {};

# canonicalize
my $sorted = {};
for my $k ( sort keys %$articles ) { $sorted->{$k} = $articles->{$k} }
my $json_out = JSON::PP->new->utf8->canonical->pretty->encode($sorted);
write_utf8( $data_file, $json_out );

sub build_items {
    my @arr;
    for my $k ( sort keys %$sorted ) {
        my $e = $sorted->{$k};
        next unless $e && ref $e eq 'HASH';
        my $slug = $e->{en} // next;
        $slug =~ s/\.html$//;
        my $title   = $e->{title_en} // $slug;
        my $article = File::Spec->catfile( $articles_dir, "$slug.html" );
        my $desc    = first_paragraph($article) || '';
        my $mtime   = undef;
        if ( exists $e->{pubdate} ) { $mtime = iso_to_epoch( $e->{pubdate} ); }
        $mtime ||= ( -e $article ) ? ( ( stat($article) )[9] ) : time();
        my $pub = rfc2822_from_ts_locale( $mtime, 'en' );
        $title = xml_escape($title);
        $desc  = xml_escape($desc);
        my $link = "./../articles/$slug.html";
        my $guid = $link;
        my $xml  = "    <item>\n";
        $xml .= "      <title>$title</title>\n";
        $xml .= "      <link>$link</link>\n";
        $xml .= "      <description>$desc</description>\n";
        $xml .= "      <pubDate>$pub</pubDate>\n";
        $xml .= "      <guid>$guid</guid>\n";
        $xml .= "    </item>\n";
        push @arr, { mtime => $mtime, xml => $xml };
    }
    @arr = sort { $b->{mtime} <=> $a->{mtime} } @arr;
    return join( "\n", map { $_->{xml} } @arr );
}

my $content = read_utf8($feed) // die_tool "Feed template not found: $feed\n";
if ( $content !~ /<channel>/ ) { die_tool "Invalid feed template: $feed\n" }
my $prefix = $content;
my $idx    = index( $content, '</channel>' );
if ( $idx != -1 ) {
    $prefix = substr( $content, 0, $idx );
    my $tail = substr( $content, $idx );
    my $now  = rfc2822_from_ts_locale( time(), 'en' );
    $prefix =~ s{<pubDate>[^<]*</pubDate>}{<pubDate>$now</pubDate>}m;
    $prefix =~
s{<lastBuildDate>[^<]*</lastBuildDate>}{<lastBuildDate>$now</lastBuildDate>}m;

# remove any existing <item> blocks from the prefix/template to avoid duplicates
    $prefix =~ s{<item>.*?</item>\s*}{}gs;
    $prefix =~ s/\s+$//s;
    $prefix .= "\n\n";
    my $items = build_items();
    my $new   = $prefix . $items . "\n" . $tail;
    $new =~ s/\n{3,}/\n\n/g;
    write_utf8( $feed, $new );
    logi("Wrote $feed");
}
else { die_tool "Could not find </channel> in template\n" }

exit 0;
