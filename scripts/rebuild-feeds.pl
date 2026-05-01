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

use Cwd            qw(abs_path);
use File::Basename qw(basename);
use File::Find;
use File::Spec;
use Time::Local qw(timegm);

my $script_dir   = ( File::Spec->splitpath($0) )[1];
my $root_dir     = File::Spec->catdir( $script_dir, '..' );
my $feeds_dir    = File::Spec->catdir( $root_dir,   'feeds' );
my $articles_dir = File::Spec->catdir( $root_dir,   'articles' );
my $abs_root     = abs_path($root_dir);
$root_dir     = $abs_root if defined $abs_root && length $abs_root;
$feeds_dir    = File::Spec->catdir( $root_dir, 'feeds' );
$articles_dir = File::Spec->catdir( $root_dir, 'articles' );

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

sub as_root_relative_url {
    my ($url) = @_;
    return '' unless defined $url;
    $url =~ s/^\s+|\s+$//g;
    return '' unless length $url;
    return $url if $url =~ m{^/};

    if ( $url =~ m{^[a-z][a-z0-9+.-]*://[^/]+(/.*)?$}i ) {
        my $path = defined $1 && length $1 ? $1 : '/';
        return $path;
    }
    if ( $url =~ m{^//[^/]+(/.*)?$} ) {
        my $path = defined $1 && length $1 ? $1 : '/';
        return $path;
    }
    return $url;
}

sub strip_tags_and_trim {
    my ($text) = @_;
    $text //= '';
    $text =~ s/<[^>]+>//g;
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

sub normalize_summary {
    my ($text) = @_;
    $text = strip_tags_and_trim($text);
    return '' unless length $text;
    my $max = 420;
    return $text if length($text) <= $max;
    $text = substr( $text, 0, $max - 1 );
    $text =~ s/\s+\S*$//;
    return $text . '…';
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
    my ($epoch) = @_;
    my @wday_en = qw(Sun Mon Tue Wed Thu Fri Sat);
    my @mon_en  = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = gmtime($epoch);
    $year += 1900;
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
    my ($path)           = @_;
    my $html             = read_file($path);
    my ($article_header) = $html =~
      m{<header[^>]*\bid\s*=\s*["']article-header["'][^>]*>(.*?)</header>}is;
    my $content_scope = defined $article_header ? $article_header : $html;

    my ($lang) = $html =~ /<html[^>]*\blang\s*=\s*"([^"]+)"/i;
    $lang = defined $lang && $lang =~ /^es/i ? 'es' : 'en';

    my ($title) = $content_scope =~ /<h[12][^>]*>\s*(.*?)\s*<\/h[12]>/is;
    $title //= 'Untitled';
    $title = strip_tags_and_trim($title);

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
    $desc = strip_tags_and_trim($desc);
    $desc = normalize_summary($desc);

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
        {
            no_chdir => 1,
            wanted   => sub {
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
        },
        $articles_dir
    );

    @rows =
      sort { $b->{epoch} <=> $a->{epoch} || $a->{slug} cmp $b->{slug} } @rows;
    return \@rows;
}

sub rebuild_feed_file {
    my ( $feed_path, $lang, $rows ) = @_;
    my $xml = read_file($feed_path);

    my ($channel_title) = $xml =~ m{<title>(.*?)</title>}s;
    $channel_title //= 'RSS Feed';
    my ($channel_link) = $xml =~ m{<link>(.*?)</link>}s;
    $channel_link = as_root_relative_url($channel_link);
    $channel_link = '/' unless length $channel_link;
    my ($channel_desc) = $xml =~ m{<description>(.*?)</description>}s;
    $channel_desc //= '';
    my $feed_name = basename($feed_path);
    my $feed_url  = "/feeds/$feed_name";

    my $items = '';
    for my $r (@$rows) {
        next if $r->{lang} ne $lang;
        my $pub         = format_pubdate( $r->{epoch} );
        my $article_url = "/articles/$r->{slug}.html";
        $items .= join '',
          "    <item>\n",
          "      <title>", xml_escape( $r->{title} ), "</title>\n",
          "      <link>$article_url</link>\n",
          "      <description>", xml_escape( $r->{desc} ), "</description>\n",
          "      <pubDate>$pub</pubDate>\n",
          "      <guid isPermaLink=\"false\">$article_url</guid>\n",
          "    </item>\n\n";
    }

    my $last_epoch = time;
    for my $r (@$rows) {
        next if $r->{lang} ne $lang;
        $last_epoch = $r->{epoch};
        last;
    }
    my $last_build = format_pubdate($last_epoch);

    my $new_xml = join '',
      qq(<?xml version="1.0" encoding="UTF-8"?>\n),
      qq(<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">\n),
      qq(  <channel>\n),
      qq(    <title>) . xml_escape($channel_title) . qq(</title>\n),
      qq(    <link>$channel_link</link>\n),
      qq(    <description>) . xml_escape($channel_desc) . qq(</description>\n),
      qq(    <lastBuildDate>$last_build</lastBuildDate>\n),
qq(    <atom:link href="$feed_url" rel="self" type="application/rss+xml"/>\n),
      qq(\n),
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
