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
# UPDATE the article listing in index.html. It asks for a
# subsection, title, and slug, builds a safe article link, and
# injects it into the matching section while preserving existing
# markup.
#
# Usage:
#   update-articles.pl
#
# Behavior:
#   - Uses ../index.html as the edit target
#   - Does not create the article file or update data/articles.json
#   - Validates the target subsection and prevents duplicate article links
#   - Writes updated HTML back to disk with explicit error
#     reporting

use strict;
use warnings;
use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempfile);

# -------------------------
# Logging
# -------------------------

sub logi { print "[INFO] $_[0]\n"; }

sub logw {
    print {*STDERR} "[WARN] $_[0]\n";
}

sub loge {
    print {*STDERR} "[ERROR] $_[0]\n";
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
      : q{};
    print "$msg$suf: ";
    my $in = <STDIN>;
    defined $in
      or die_tool "Could not read input.\n";
    chomp $in;
    return length $in
      ? $in
      : ( $default // q{} );
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path
      or die_tool "Could not open $path: $!\n";
    local $/ = undef;
    my $c = <$fh>;
    close $fh or die_tool("Could not close $path: $!\n");
    return $c;
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
    binmode $fh, ':raw';

    if ( !print {$fh} $content ) {
        my $err = $!;
        close $fh;    ## no critic (RequireCheckedClose, RequireCheckedSyscalls)
        unlink $tmp;
        die_tool("Could not write $path: $err\n");
    }
    if ( !close $fh ) {
        my $err = $!;
        unlink $tmp;
        die_tool("Could not close $path: $err\n");
    }
    if ( defined $mode && !chmod $mode, $tmp ) {
        my $err = $!;
        unlink $tmp;
        die_tool("Could not set permissions on $path: $err\n");
    }
    if ( !rename $tmp, $path ) {
        my $err = $!;
        unlink $tmp;
        die_tool("Could not replace $path: $err\n");
    }
    return 1;
}

sub esc_html {
    my ($s) = @_;
    return q{} unless defined $s;
    $s =~ s/&/&amp;/gsm;
    $s =~ s/</&lt;/gsm;
    $s =~ s/>/&gt;/gsm;
    return $s;
}

my $script_path = abs_path($0);
if ( !defined $script_path || !length $script_path ) {
    die_tool("Could not resolve script path\n");
}
my $root  = File::Spec->catdir( dirname($script_path), q{..} );
my $index = File::Spec->catfile( $root, 'index.html' );

sub run_update {
    my $content = read_file($index);

    logi( 'This will insert a new article link' . " into $index" );

    my $subsection =
      lc question( 'Subsection (for example operating-systems/openbsd)',
        'operating-systems/openbsd' );
    my ( $section_id, $subsection_id ) =
      $subsection =~ m{^([a-z0-9-]+)/([a-z0-9-]+)$}s
      or die_tool "Subsection must be a section/subsection identifier.\n";

    my $title = question( 'Link text/title', 'New Article' );
    my $slug =
      question( 'Slug (filename without .html,' . ' e.g. android-privacy)',
        q{} );
    $slug =~ /^[A-Za-z0-9][A-Za-z0-9-]*$/s
      or die_tool( 'Slug may only contain letters, digits, and'
          . " hyphens (and must not be empty).\n" );

    my $href = "./articles/$slug.html";

    if ( index( $content, $href ) != -1 ) {
        logw(
            "A link to $href already exists" . " in $index. No change made." );
        return 0;
    }

    # The slug validation above keeps the generated relative path within the
    # expected article naming convention; escape user-supplied link text below.
    # Build a list item that matches the formatting produced by
    # tidy(1) so the inserted markup stays formatting-clean.
    my $link_html =
        qq{<li>\n                <a href="$href">}
      . esc_html($title)
      . qq{</a>\n              </li>};

    if (
        $content =~ m{(<section\s+id="\Q$section_id\E"[^>]*>
          .*?<section\s+id="\Q$subsection_id\E"[^>]*>
          .*?<ul[^>]*class="article-list"[^>]*>)(.*?)(<\/ul>)}sx
      )
    {
        my ( $pre, $inner, $post ) = ( $1, $2, $3 );

        # Drop the trailing indentation so the new item can be
        # positioned immediately before the closing </ul>.
        my $body = $inner;
        $body =~ s/\n[ \t]*$//s;
        my $new_inner =
          $body . "\n\n              " . $link_html . "\n            ";

        my $old_block = $pre . $inner . $post;
        my $pos       = index( $content, $old_block );
        $pos >= 0
          or die_tool( 'Could not locate the article list in'
              . " $index for subsection $subsection.\n" );
        substr( $content, $pos, length($old_block), $pre . $new_inner . $post );

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
