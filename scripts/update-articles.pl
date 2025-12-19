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

# Small helper to update the Articles section in cypherpunk-handbook/index.html
# Usage: update-articles.pl
# Prompts for: category (desktop|mobile), title, slug (without .html), where to insert

use strict;
use warnings;
use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

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

sub prompt {
    my ( $msg, $default ) = @_;
    my $suf = defined $default && length $default ? " [$default]" : "";
    print "$msg$suf: ";
    my $in = <STDIN>;
    defined $in or die_tool "Could not read input.\n";
    chomp $in;
    return length $in ? $in : ( $default // '' );
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die_tool "Could not open $path: $!\n";
    local $/;
    my $c = <$fh>;
    close $fh;
    return $c;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>:raw', $path or die_tool "Could not write $path: $!\n";
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

my $content = read_file($index);

logi("This will insert a new article link into $index");

my $category = lc prompt( 'Category (desktop/mobile)', 'desktop' );
$category =~ /^(desktop|mobile)$/
  or die_tool "Category must be 'desktop' or 'mobile'.\n";

my $title = prompt( 'Link text/title', 'New Article' );
my $slug  = prompt( 'Slug (filename without .html, e.g. android-privacy)', '' );
length $slug or die_tool "Slug is required.\n";

my $href = "./articles/$slug.html";

# Prevent duplicates
    if ( index( $content, $href ) != -1 ) {
    logw("A link to $href already exists in $index. No change made.");
    exit 0;
}

my $link_html =
qq{<li>\n              <a href="$href" target="_blank" rel="noopener noreferrer">}
  . esc_html($title)
  . qq{</a>\n            </li>\n\n};

if ( $category eq 'desktop' ) {

# Find Desktop Systems column: <h3>Desktop Systems</h3> followed by <ul class="article-list"> ... </ul>
    if ( $content =~
/(\Q<h3>Desktop Systems<\/h3>\E.*?<ul[^>]*class="article-list"[^>]*>)(.*?)(<\/ul>)/s
      )
    {
        my ( $pre, $inner, $post ) = ( $1, $2, $3 );
        $inner .= "\n            " . $link_html;
        $content =~ s/\Q$pre$inner$post\E/$pre$inner$post/s;
        write_file( $index, $content );
        logi("Inserted link into Desktop Systems list.");
        exit 0;
    }
    else {
        die_tool "Could not locate Desktop Systems list in $index.\n";
    }
}
else {
    # mobile: either Overview (top-level) or topic list
    my $inserted = 0;

# If user wants Overview (title equals 'Overview' or asks), add top-level link if no such link exists
    if ( lc($title) eq 'overview' ) {

        # Find Mobile Systems article-list and insert the link as first <li>
        if ( $content =~
/(\Q<h3>Mobile Systems<\/h3>\E.*?<ul[^>]*class="article-list"[^>]*>)(.*?)(<\/ul>)/s
          )
        {
            my ( $pre, $inner, $post ) = ( $1, $2, $3 );
            $inner = "\n            " . $link_html . $inner;
            $content =~ s/\Q$pre$inner$post\E/$pre$inner$post/s;
            write_file( $index, $content );
            logi("Inserted Overview link into Mobile Systems.");
            exit 0;
        }
    }

    # Otherwise try to insert into topic-list
    if ( $content =~
/(\Q<h3>Mobile Systems<\/h3>\E.*?<ul[^>]*class="article-list"[^>]*>.*?<ul[^>]*class="topic-list"[^>]*>)(.*?)(<\/ul>)/s
      )
    {
        my ( $pre, $inner, $post ) = ( $1, $2, $3 );
        $inner .= "\n                " . $link_html;
        $content =~ s/\Q$pre$inner$post\E/$pre$inner$post/s;
        write_file( $index, $content );
        logi("Inserted link into Mobile Systems topics.");
        exit 0;
    }

    die_tool "Could not locate Mobile Systems topic list in $index.\n";
}
