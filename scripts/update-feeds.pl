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
# UPDATE RSS/ATOM-like feed entries from article metadata and publication date.
# Scans article pages, extracts title/date/description/link and inserts a new
# <item> in the selected feed while preserving XML escaping and language format.
#
# Usage:
#   update-feeds.pl [--replace]
#
# Options:
#   --replace   If an item with the same link already exists, replace it.
#               Without this flag, existing links are kept and reported.
#
# Behavior:
#   - Detects available feed targets under ../feeds
#   - Prompts for language/feed file and article slug
#   - Builds RFC2822 pubDate and normalized GUID/link values
#   - Writes the updated feed file in UTF-8

use strict;
use warnings;

use File::Spec;
use Getopt::Long;
use Time::Local qw(timegm);

my $replace_existing = 0;
GetOptions( 'replace' => \$replace_existing );

my $root_dir =
  File::Spec->catdir( ( File::Spec->splitpath($0) )[1] || '.', '..' );
my $feeds_dir    = File::Spec->catdir( $root_dir, 'feeds' );
my $articles_dir = File::Spec->catdir( $root_dir, 'articles' );
my $site_url     = 'https://handbook.uhden.dev';

sub logi     { print "✅ [INFO] $_[0]\n"; }
sub logw     { print STDERR "⚠️ [WARN] $_[0]\n"; }
sub die_tool { die "❌ [ERROR] $_[0]\n"; }

sub prompt {
    my ( $message, $default ) = @_;
    my $suffix = defined $default && length $default ? " [$default]" : '';
    print "$message$suffix: ";
    my $input = <STDIN>;
    defined $input or die_tool("Could not read input.");
    chomp $input;
    return length $input ? $input : $default;
}

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

sub normalize_slug {
    my ($s) = @_;
    $s //= '';
    $s =~ s/^\s+|\s+$//g;
    $s = lc $s;
    return $s;
}

sub iso_to_epoch {
    my ($s) = @_;
    return undef unless defined $s;
    if ( $s =~
/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(Z|([+-])(\d{2}):(\d{2}))?$/
      )
    {
        my ( $Y, $M, $D, $h, $m, $sec, undef, $sign, $oh, $om ) =
          ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10 );
        my $epoch = timegm( $sec, $m, $h, $D, $M - 1, $Y );
        if ( defined $sign && defined $oh ) {
            my $ofs = $oh * 3600 + $om * 60;
            $epoch -= ( $sign eq '+' ) ? $ofs : -$ofs;
        }
        return $epoch;
    }
    if ( $s =~ /^(\d{4})-(\d{2})-(\d{2})$/ ) {
        return timegm( 0, 0, 0, $3, $2 - 1, $1 );
    }
    return undef;
}

sub rfc2822_from_ts_locale {
    my ($t)     = @_;
    my @wday_en = qw(Sun Mon Tue Wed Thu Fri Sat);
    my @mon_en  = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = gmtime($t);
    $year += 1900;
    return sprintf( '%s, %02d %s %d %02d:%02d:%02d GMT',
        $wday_en[$wday], $mday, $mon_en[$mon], $year, $hour, $min, $sec );
}

sub extract_datetime_from_article {
    my ($path) = @_;
    return undef unless -e $path;
    my $html = read_file($path);
    return $1 if $html =~ /<time[^>]*\sdatetime\s*=\s*"([^"]+)"/i;
    return $1 if $html =~ /<time[^>]*\sdatetime\s*=\s*'([^']+)'/i;
    return undef;
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
    die_tool("No supported feed file found under $feeds_dir");
}

sub update_feed {
    my (%args)        = @_;
    my $path          = $args{path};
    my $slug          = $args{slug};
    my $pub           = $args{pub_rfc};
    my $link          = "/articles/$slug.html";
    my @link_variants = ( $link, "$site_url$link" );
    my $link_re       = join '|', map { quotemeta($_) } @link_variants;
    my $item          = join '',
      "    <item>\n",
      "      <title>", xml_escape( $args{title} ), "</title>\n",
      "      <link>$link</link>\n",
      "      <description>", xml_escape( $args{description} ),
      "</description>\n",
      "      <pubDate>$pub</pubDate>\n",
      "      <guid isPermaLink=\"false\">$link</guid>\n",
      "    </item>\n\n";

    my $content = read_file($path);

    if ( $content =~ m{<link>\s*(?:$link_re)\s*</link>}s ) {
        if ( !$replace_existing ) {
            logw("Feed already has $link in $path (use --replace to replace)");
            return;
        }
        $content =~
          s{<item>.*?<link>\s*(?:$link_re)\s*</link>.*?</item>\s*}{}gs;
    }

    $content =~ s{<pubDate>[^<]*</pubDate>}{<pubDate>$pub</pubDate>}m;
    $content =~
s{<lastBuildDate>[^<]*</lastBuildDate>}{<lastBuildDate>$pub</lastBuildDate>}m;

    my $inserted =
      $content =~ s{(<lastBuildDate>[^<]*</lastBuildDate>\s*\n)}{$1\n$item}m;
    $inserted ||= $content =~ s{(<channel>\s*\n)}{$1$item}m;
    $inserted ||= $content =~ s{(</channel>)}{$item$1}m;
    $inserted or die_tool("Could not insert item into $path");

    write_file( $path, $content );
    logi("Updated feed: $path");
}

sub main {
    my $feeds  = detect_feeds();
    my $has_es = exists $feeds->{es} ? 1 : 0;

    my $slug_en =
      normalize_slug( prompt( 'English slug (without .html)', '' ) );
    length $slug_en or die_tool('English slug is required.');
    my $slug_es =
      $has_es
      ? normalize_slug(
        prompt( 'Spanish slug (without .html)', "$slug_en-es" ) )
      : undef;

    my $title_en = prompt( 'Title (English)',       '' );
    my $desc_en  = prompt( 'Description (English)', '' );
    my ( $title_es, $desc_es ) = ( undef, undef );
    if ($has_es) {
        $title_es = prompt( 'Title (Spanish)',       '' );
        $desc_es  = prompt( 'Description (Spanish)', '' );
    }

    my $article_en_path = File::Spec->catfile( $articles_dir, "$slug_en.html" );
    my $article_es_path =
      $has_es ? File::Spec->catfile( $articles_dir, "$slug_es.html" ) : undef;

    my $found_iso = extract_datetime_from_article($article_en_path);
    $found_iso ||= extract_datetime_from_article($article_es_path) if $has_es;

    my $pub_input = $found_iso
      // prompt( 'Publication date ISO (e.g., 2025-03-06T10:00:00Z) or blank',
        '' );
    my $pub_epoch = iso_to_epoch($pub_input);
    if ( !defined $pub_epoch ) {
        $pub_epoch = time();
        logw("Invalid/empty ISO date, using current time.");
    }

    my $pub_rfc_en = rfc2822_from_ts_locale($pub_epoch);
    update_feed(
        path        => $feeds->{en},
        slug        => $slug_en,
        title       => $title_en,
        description => $desc_en,
        pub_rfc     => $pub_rfc_en,
    );

    if ($has_es) {
        my $pub_rfc_es = rfc2822_from_ts_locale($pub_epoch);
        update_feed(
            path        => $feeds->{es},
            slug        => $slug_es,
            title       => $title_es,
            description => $desc_es,
            pub_rfc     => $pub_rfc_es,
        );
    }

    my $rebuild_script =
      File::Spec->catfile( $root_dir, 'scripts', 'rebuild-feeds.pl' );
    if ( -x $rebuild_script ) {
        my $rc = system( $^X, $rebuild_script );
        logw("Rebuild script exited with code $rc") if $rc != 0;
    }
}

main();
