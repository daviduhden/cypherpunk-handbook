#!/usr/bin/perl

# Copyright (c) 2025-2026 David Uhden Collado
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
# UPDATE article listings/pages from local templates and
# structured metadata. It asks for a subsection, title, and slug,
# builds a safe article link, and injects it into the matching
# section of index.html while preserving existing markup.
#
# Usage:
#   update-articles.pl
#
# Behavior:
#   - Uses ../index.html as the edit target
#   - Validates the target subsection and prevents duplicate article links
#   - Writes updated HTML back to disk with explicit error
#     reporting

use strict;
use warnings;
use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

# -------------------------
# Logging
# -------------------------

sub logi { print "[INFO] $_[0]\n"; }

sub logw {
    print STDERR "[WARN] $_[0]\n";
}

sub loge {
    print STDERR "[ERROR] $_[0]\n";
}

sub die_tool {
    my ($msg) = @_;
    loge($msg);
    exit 1;
}

sub question {
    my ( $msg, $default ) = @_;
    my $suf =
      defined $default && length $default
      ? " [$default]"
      : "";
    print "$msg$suf: ";
    my $in = <STDIN>;
    defined $in
      or die_tool "Could not read input.\n";
    chomp $in;
    return length $in
      ? $in
      : ( $default // '' );
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path
      or die_tool "Could not open $path: $!\n";
    local $/;
    my $c = <$fh>;
    close $fh;
    return $c;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>:raw', $path
      or die_tool "Could not write $path: $!\n";
    print {$fh} $content;
    close $fh;
}

sub esc_html {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    return $s;
}

my $script_path = abs_path($0);
my $root        = File::Spec->catdir( dirname($script_path), '..' );
my $index       = File::Spec->catfile( $root, 'index.html' );

sub run_update {
    my $content = read_file($index);

    logi( "This will insert a new article link" . " into $index" );

    my $subsection = lc question(
        'Subsection (for example operating-systems/openbsd)',
        'operating-systems/openbsd'
    );
    $subsection =~ m{^([a-z0-9-]+)/([a-z0-9-]+)$}
      or die_tool "Subsection must be a section/subsection identifier.\n";
    my ( $section_id, $subsection_id ) = ( $1, $2 );

    my $title = question( 'Link text/title', 'New Article' );
    my $slug =
      question( 'Slug (filename without .html,' . ' e.g. android-privacy)',
        '' );
    length $slug
      or die_tool "Slug is required.\n";

    my $href = "./articles/$slug.html";

    if ( index( $content, $href ) != -1 ) {
        logw(
            "A link to $href already exists" . " in $index. No change made." );
        return 0;
    }

    my $link_html =
        qq{<li>\n              <a href="$href">}
      . esc_html($title)
      . qq{</a>\n            </li>\n\n};

    if (
        $content =~ /(<section\s+id="\Q$section_id\E"[^>]*>
          .*?<section\s+id="\Q$subsection_id\E"[^>]*>
          .*?<ul[^>]*class="article-list"[^>]*>)(.*?)(<\/ul>)/sx
      )
    {
        my ( $pre, $inner, $post ) = ( $1, $2, $3 );
        $inner .= "\n              " . $link_html;
        $content =~ s/\Q$pre$inner$post\E/
            $pre$inner$post/s;
        write_file( $index, $content );
        logi("Inserted link into $subsection.");
        return 0;
    }

    die_tool "Could not locate subsection $subsection in $index.\n";
}

sub main {
    run_update();
}

main();
