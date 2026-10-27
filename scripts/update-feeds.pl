#!/usr/bin/env perl

# Copyright (c) 2025-2026, David Uhden Collado
#
# Permission to use, copy, modify, and distribute this software
# for any purpose with or without fee is hereby granted, provided
# that the above copyright notice and this permission notice
# appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
# NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# UPDATE RSS/ATOM-like feed entries from article metadata and
# publication date. Scans article pages, extracts
# title/date/description/link and inserts a new <item> in the
# selected feed while preserving XML escaping and language
# format.
#
# Usage:
#   update-feeds.pl [--replace] [ARTICLE]
#
# Options:
#   --replace   If an item with the same link already exists,
#               replace it. Without this flag, existing links
#               are kept and reported.
#
# Arguments:
#   ARTICLE     Optional article HTML file. Its <time datetime>
#               value supplies the publication date.
#
# Behavior:
#   - Detects available feed targets under ../feeds
#   - questions for language/feed file and article slug
#   - Builds RFC2822 pubDate and normalized GUID/link values
#   - Writes the updated feed file in UTF-8

use strict;
use warnings;

use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempfile);
use Getopt::Long;
use Time::Local qw(timegm);

my $replace_existing = 0;
GetOptions( 'replace' => \$replace_existing )
  or die "Usage: $0 [--replace] [ARTICLE]\n";
my $article_argument = shift @ARGV;
die "Usage: $0 [--replace] [ARTICLE]\n" if @ARGV;
if ( defined $article_argument && !-f $article_argument ) {
    die "[ERROR] Article file not found: $article_argument\n";
}

sub resolve_script_path {
    my $direct = abs_path($0);
    return $direct if defined $direct;
    return         if $0 =~ m{/};
    for my $dir ( File::Spec->path ) {
        my $resolved = abs_path( File::Spec->catfile( $dir, $0 ) );
        return $resolved if defined $resolved;
    }
    return;
}

my $script_path = resolve_script_path();
if ( !defined $script_path || !length $script_path ) {
    die "[ERROR] Could not resolve script path\n";
}
my $root_dir     = File::Spec->catdir( dirname($script_path), q{..} );
my $feeds_dir    = File::Spec->catdir( $root_dir,             'feeds' );
my $articles_dir = File::Spec->catdir( $root_dir,             'articles' );
my $site_url     = 'https://handbook.uhden.dev';

sub logi { print "[INFO] $_[0]\n"; }

sub logw {
    print {*STDERR} "[WARN] $_[0]\n";
}
sub die_tool { die "[ERROR] $_[0]\n"; }

sub question {
    my ( $message, $default ) = @_;
    my $suffix =
      defined $default && length $default
      ? " [$default]"
      : q{};
    print "$message$suffix: ";
    my $input = <STDIN>;
    defined $input
      or die_tool('Could not read input.');
    chomp $input;
    return length $input ? $input : $default;
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path
      or die_tool("Could not read $path: $!");
    local $/ = undef;
    my $content = <$fh>;
    close $fh or die_tool("Could not close $path: $!");
    return $content;
}

sub write_file {
    my ( $path, $content ) = @_;
    my $dir = dirname($path);
    my $mode;
    if ( -e $path ) {
        $mode = ( stat($path) )[2] & 07777;
    }
    else {
        my $mask = umask;
        umask $mask;
        $mode = 0666 & ~$mask;
    }

    my ( $fh, $tmp ) = tempfile( '.tmp-XXXXXX', DIR => $dir, UNLINK => 0 );
    binmode $fh, ':encoding(UTF-8)';

    if ( !print {$fh} $content ) {
        my $err = $!;
        close $fh;    ## no critic (RequireCheckedClose, RequireCheckedSyscalls)
        unlink $tmp;
        die_tool("Could not write $path: $err");
    }
    if ( !close $fh ) {
        my $err = $!;
        unlink $tmp;
        die_tool("Could not close $path: $err");
    }
    if ( defined $mode && !chmod $mode, $tmp ) {
        my $err = $!;
        unlink $tmp;
        die_tool("Could not set permissions on $path: $err");
    }
    if ( !rename $tmp, $path ) {
        my $err = $!;
        unlink $tmp;
        die_tool("Could not replace $path: $err");
    }
    return 1;
}

sub xml_escape {
    my ($text) = @_;
    return q{} unless defined $text;
    $text =~ s/&/&amp;/gsm;
    $text =~ s/</&lt;/gsm;
    $text =~ s/>/&gt;/gsm;
    return $text;
}

sub normalize_slug {
    my ($s) = @_;
    $s //= q{};
    $s =~ s/^\s+|\s+$//gs;
    $s = lc $s;
    return $s;
}

sub iso_to_epoch {
    my ($s) = @_;
    return unless defined $s;
    if (
        $s =~ m{^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})
  (Z|([+-])(\d{2}):(\d{2}))?$}xs
      )
    {
        my ( $Y, $M, $D, $h, $m, $sec, undef, $sign, $oh, $om ) =
          ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10 );
        my $epoch = timegm( $sec, $m, $h, $D, $M - 1, $Y );
        if ( defined $sign && defined $oh ) {
            my $ofs = $oh * 3600 + $om * 60;
            $epoch -= ( $sign eq q{+} ) ? $ofs : -$ofs;
        }
        return $epoch;
    }
    if ( $s =~ /^(\d{4})-(\d{2})-(\d{2})$/s ) {
        return timegm( 0, 0, 0, $3, $2 - 1, $1 );
    }
    return;
}

sub rfc2822_from_ts_locale {
    my ($t)     = @_;
    my @wday_en = qw(Sun Mon Tue Wed Thu Fri Sat);
    my @mon_en  = qw(Jan Feb Mar Apr May Jun Jul
      Aug Sep Oct Nov Dec);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = gmtime($t);
    $year += 1900;
    return sprintf( '%s, %02d %s %d %02d:%02d:%02d GMT',
        $wday_en[$wday], $mday, $mon_en[$mon], $year, $hour, $min, $sec );
}

sub extract_datetime_from_article {
    my ($path) = @_;
    return unless -e $path;
    my $html = read_file($path);
    if ( $html =~ /<time[^>]*\sdatetime\s*=\s*"([^"]+)"/ism ) {
        return $1;
    }
    if ( $html =~ /<time[^>]*\sdatetime\s*=\s*'([^']+)'/ism ) {
        return $1;
    }
    return;
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
    die_tool( 'No supported feed file found' . " under $feeds_dir" );
}

sub update_feed {
    my (%args)        = @_;
    my $path          = $args{path};
    my $slug          = $args{slug};
    my $pub           = $args{pub_rfc};
    my $link          = "/articles/$slug.html";
    my @link_variants = ( $link, "$site_url$link" );
    my $link_re =
      join q{|},
      map { quotemeta } @link_variants;

    # Match both historical absolute links and the root-relative form emitted
    # by the rebuild script, while quoting the slug-derived strings literally.
    my $item = join q{},
      "    <item>\n",
      '      <title>',
      xml_escape( $args{title} ),
      "</title>\n",
      "      <link>$link</link>\n",
      '      <description>',
      xml_escape( $args{description} ),
      "</description>\n",
      "      <pubDate>$pub</pubDate>\n",
      '      <guid isPermaLink="false">' . "$link</guid>\n",
      "    </item>\n\n";

    my $content = read_file($path);

    if ( $content =~ m{<link>\s*(?:$link_re)\s*</link>}s ) {
        if ( !$replace_existing ) {
            logw(   "Feed already has $link in $path"
                  . ' (use --replace to replace)' );
            return;
        }

        # Keep the leading wildcard inside one item; otherwise a match
        # on a later item would consume every preceding item too.
        $content =~ s{<item>(?:(?!</item>).)*?<link>\s*
            (?:$link_re)\s*</link>
            .*?</item>\s*}{}gsx;
    }

    # Only lastBuildDate is refreshed here. The new <item> already
    # carries its own <pubDate>, so rewriting the first <pubDate>
    # could overwrite an unrelated item when insertion falls back to
    # appending before </channel>.
    $content =~ s{<lastBuildDate>[^<]*</lastBuildDate>}
       {<lastBuildDate>$pub</lastBuildDate>}ms;

    my $inserted = $content =~ s{(<lastBuildDate>[^<]*</lastBuildDate>
        \s*\n)}{$1\n$item}mxs;
    $inserted ||= $content =~ s{(<channel>\s*\n)}{$1$item}ms;
    $inserted ||= $content =~ s{(</channel>)}{$item$1}ms;
    $inserted
      or die_tool("Could not insert item into $path");

    write_file( $path, $content );
    logi("Updated feed: $path");
}

sub main {
    my $feeds  = detect_feeds();
    my $has_es = exists $feeds->{es} ? 1 : 0;

    my $slug_en =
      normalize_slug( question( 'English slug (without .html)', q{} ) );
    length $slug_en
      or die_tool('English slug is required.');
    $slug_en =~ /^[a-z0-9][a-z0-9-]*$/s
      or die_tool( 'English slug may only contain lowercase letters,'
          . ' digits, and hyphens.' );
    my $slug_es = undef;
    if ($has_es) {
        $slug_es = normalize_slug(
            question( 'Spanish slug (without .html)', "$slug_en-es" ) );
        length $slug_es
          or die_tool('Spanish slug is required.');
        $slug_es =~ /^[a-z0-9][a-z0-9-]*$/s
          or die_tool( 'Spanish slug may only contain lowercase letters,'
              . ' digits, and hyphens.' );
    }

    my $title_en = question( 'Title (English)',       q{} );
    my $desc_en  = question( 'Description (English)', q{} );
    my ( $title_es, $desc_es ) = ( undef, undef );
    if ($has_es) {
        $title_es = question( 'Title (Spanish)',       q{} );
        $desc_es  = question( 'Description (Spanish)', q{} );
    }

    my $article_en_path = File::Spec->catfile( $articles_dir, "$slug_en.html" );
    my $article_es_path =
      $has_es
      ? File::Spec->catfile( $articles_dir, "$slug_es.html" )
      : undef;

    my $found_iso = q{};
    $found_iso = extract_datetime_from_article($article_argument)
      if defined $article_argument;
    $found_iso ||= extract_datetime_from_article($article_en_path);
    $found_iso ||= extract_datetime_from_article($article_es_path)
      if $has_es;

    my $pub_input = $found_iso // question(
        'Publication date ISO' . ' (e.g., 2025-03-06T10:00:00Z)' . ' or blank',
        q{}
    );
    my $pub_epoch = iso_to_epoch($pub_input);
    if ( !defined $pub_epoch ) {
        $pub_epoch = time();
        logw( 'Invalid/empty ISO date,' . ' using current time.' );
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
        if ( $rc == -1 ) {
            logw("Could not run $rebuild_script: $!");
        }
        elsif ( $rc & 127 ) {
            logw( 'Rebuild script terminated by signal ' . ( $rc & 127 ) );
        }
        elsif ( $rc >> 8 ) {
            logw( 'Rebuild script exited with code ' . ( $rc >> 8 ) );
        }
    }
}

main();
