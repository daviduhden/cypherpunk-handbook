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
# REBUILD feed files by scanning the articles directory from scratch.
# Parses article headers/metadata, sorts entries by publication date and then
# regenerates feed content to keep output consistent and deterministic.
#
# Usage:
#   rebuild-feeds.pl
#
# Behavior:
#   - Detects supported feed files under ../feeds
#   - Reads metadata from ../articles/*.html
#   - Generates locale-aware pubDate values (EN/ES)
#   - Rewrites feed files in UTF-8 with escaped XML content

use strict;
use warnings;
use utf8;

use File::Find;
use File::Spec;
use POSIX       qw(strftime);
use Time::Local qw(timegm);

my $script_dir   = ( File::Spec->splitpath($0) )[1];
my $root_dir     = File::Spec->catdir( $script_dir, '..' );
my $feeds_dir    = File::Spec->catdir( $root_dir,   'feeds' );
my $articles_dir = File::Spec->catdir( $root_dir,   'articles' );

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

sub die_tool { die "❌ [ERROR] $_[0]\n"; }
sub logi     { print "✅ [INFO] $_[0]\n"; }

sub read_file {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path
      or die_tool("Could not read $path: $!");
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>:encoding(UTF-8)', $path
      or die_tool("Could not write $path: $!");
    print {$fh} $content;
    close $fh;
}

sub xml_escape {
    my ($text) = @_;
    return '' unless defined $text;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    return $text;
}

sub iso_to_epoch {
    my ($iso) = @_;
    return undef unless defined $iso;
    if ( $iso =~
/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(Z|([+-])(\d{2}):(\d{2}))?$/
      )
    {
        my ( $Y, $M, $D, $h, $m, $s, undef, $sign, $oh, $om ) =
          ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10 );
        my $epoch = timegm( $s, $m, $h, $D, $M - 1, $Y );
        if ( defined $sign && defined $oh ) {
            my $ofs = $oh * 3600 + $om * 60;
            $epoch -= ( $sign eq '+' ) ? $ofs : -$ofs;
        }
        return $epoch;
    }
    if ( $iso =~ /^(\d{4})-(\d{2})-(\d{2})$/ ) {
        return timegm( 0, 0, 0, $3, $2 - 1, $1 );
    }
    return undef;
}

sub format_pubdate {
    my ( $epoch, $lang ) = @_;
    my @wday_en = qw(Sun Mon Tue Wed Thu Fri Sat);
    my @mon_en  = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @wday_es = qw(dom lun mar mié jue vie sáb);
    my @mon_es  = qw(ene feb mar abr may jun jul ago sep oct nov dic);

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = gmtime($epoch);
    $year += 1900;
    if ( $lang eq 'es' ) {
        return sprintf(
            '%s, %02d %s %d %02d:%02d:%02d GMT',
            lc( $wday_es[$wday] ),
            $mday, lc( $mon_es[$mon] ),
            $year, $hour, $min, $sec
        );
    }
    return sprintf( '%s, %02d %s %d %02d:%02d:%02d GMT',
        $wday_en[$wday], $mday, $mon_en[$mon], $year, $hour, $min, $sec );
}

sub detect_feeds {
    my %out;
    my $blog_en = File::Spec->catfile( $feeds_dir, 'blog.xml' );
    my $blog_es = File::Spec->catfile( $feeds_dir, 'blog-es.xml' );
    my $art_en  = File::Spec->catfile( $feeds_dir, 'articles.xml' );
    my $art_es  = File::Spec->catfile( $feeds_dir, 'articles-es.xml' );

    if ( -f $blog_en ) {
        $out{en} = $blog_en;
        $out{es} = $blog_es if -f $blog_es;
        return \%out;
    }
    if ( -f $art_en ) {
        $out{en} = $art_en;
        $out{es} = $art_es if -f $art_es;
        return \%out;
    }
    die_tool("No supported feed files found in $feeds_dir");
}

sub extract_metadata {
    my ($path) = @_;
    my $html = read_file($path);
    my ($article_header) = $html =~
      m{<header[^>]*\bid\s*=\s*["']article-header["'][^>]*>(.*?)</header>}is;
    my $content_scope = defined $article_header ? $article_header : $html;

    my ($lang) = $html =~ /<html[^>]*\blang\s*=\s*"([^"]+)"/i;
    $lang = defined $lang && $lang =~ /^es/i ? 'es' : 'en';

    my ($title) = $content_scope =~ /<h1[^>]*>\s*(.*?)\s*<\/h1>/is;
    $title //= 'Untitled';
    $title =~ s/<[^>]+>//g;
    $title =~ s/\s+/ /g;
    $title =~ s/^\s+|\s+$//g;

    my ($desc) =
      $html =~
      /<meta[^>]*\bname\s*=\s*["']description["'][^>]*\bcontent\s*=\s*["'](.*?)["'][^>]*>/is;
    $desc = '' unless defined $desc && length $desc;
    if ( !length $desc ) {
        ($desc) = $content_scope =~
          /<p[^>]*\bclass\s*=\s*["'][^"']*\blede\b[^"']*["'][^>]*>\s*(.*?)\s*<\/p>/is;
        $desc //= '';
    }
    if ( !length $desc ) {
        ($desc) = $content_scope =~ /<p[^>]*>\s*(.*?)\s*<\/p>/is;
        $desc //= '';
    }
    $desc =~ s/<[^>]+>//g;
    $desc =~ s/\s+/ /g;
    $desc =~ s/^\s+|\s+$//g;

    my ($iso) = $html =~ /<time[^>]*\sdatetime\s*=\s*"([^"]+)"/i;
    $iso //= ( $html =~ /<time[^>]*\sdatetime\s*=\s*'([^']+)'/i )[0];
    my $mtime = ( stat($path) )[9] || time;
    my $epoch = iso_to_epoch($iso);
    $epoch = $mtime unless defined $epoch;

    my ( undef, undef, $file ) = File::Spec->splitpath($path);
    $file =~ s/\.html$//i;

    return {
        slug  => $file,
        lang  => $lang,
        title => $title,
        desc  => $desc,
        epoch => $epoch,
    };
}

sub collect_articles {
    my ($has_es_feed) = @_;
    my @rows;
    find(
        sub {
            return unless -f $_;
            return unless /\.html$/i;
            return if $_ eq 'index.html';

            my $path = $File::Find::name;
            my $meta = extract_metadata($path);
            if ( !$has_es_feed ) {
                $meta->{lang} = 'en';
            }
            push @rows, $meta;
        },
        $articles_dir
    );

    @rows = sort { $b->{epoch} <=> $a->{epoch} } @rows;
    return \@rows;
}

sub rebuild_feed_file {
    my ( $feed_path, $lang, $rows ) = @_;
    my $xml = read_file($feed_path);

    my ($channel_title) = $xml =~ m{<title>(.*?)</title>}s;
    $channel_title //= 'RSS Feed';
    my ($channel_link) = $xml =~ m{<link>(.*?)</link>}s;
    $channel_link //= '../';
    my ($channel_desc) = $xml =~ m{<description>(.*?)</description>}s;
    $channel_desc //= '';

    my $items = '';
    for my $r (@$rows) {
        next if $r->{lang} ne $lang;
        my $pub = format_pubdate( $r->{epoch}, $lang );
        $items .= join '',
          "    <item>\n",
          "      <title>", xml_escape( $r->{title} ), "</title>\n",
          "      <link>./../articles/$r->{slug}.html</link>\n",
          "      <description>", xml_escape( $r->{desc} ), "</description>\n",
          "      <pubDate>$pub</pubDate>\n",
          "      <guid>./../articles/$r->{slug}.html</guid>\n",
          "    </item>\n\n";
    }

    my $last_epoch = time;
    for my $r (@$rows) {
        next if $r->{lang} ne $lang;
        $last_epoch = $r->{epoch};
        last;
    }
    my $last_build = format_pubdate( $last_epoch, $lang );

    my $new_xml = join '',
      qq(<?xml version="1.0" encoding="UTF-8"?>\n),
      qq(<rss version="2.0">\n),
      qq(  <channel>\n),
      qq(    <title>$channel_title</title>\n),
      qq(    <link>$channel_link</link>\n),
      qq(    <description>$channel_desc</description>\n),
      qq(    <lastBuildDate>$last_build</lastBuildDate>\n\n),
      $items,
      qq(  </channel>\n),
      qq(</rss>\n);

    write_file( $feed_path, $new_xml );
    logi("Rebuilt feed: $feed_path");
}

sub main {
    my $feeds       = detect_feeds();
    my $has_es_feed = exists $feeds->{es} ? 1 : 0;
    my $rows        = collect_articles($has_es_feed);

    rebuild_feed_file( $feeds->{en}, 'en', $rows );
    rebuild_feed_file( $feeds->{es}, 'es', $rows ) if $has_es_feed;
}

main();
