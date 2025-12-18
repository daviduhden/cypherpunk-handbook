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

# Small helper to update the Articles section in cyberpunk-handbook/index.html
# Usage: update-guides.pl
# questions for: category (desktop|mobile), title, slug (without .html), where to insert

use strict;
use warnings;
use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

sub question {
    my ( $msg, $default ) = @_;
    my $suf = defined $default && length $default ? " [$default]" : "";
    print "$msg$suf: ";
    my $in = <STDIN>;
    defined $in or die "Could not read input.\n";
    chomp $in;
    return length $in ? $in : ( $default // '' );
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Could not open $path: $!\n";
    local $/;
    my $c = <$fh>;
    close $fh;
    return $c;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>:raw', $path or die "Could not write $path: $!\n";
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

print "This will insert a new article link into $index\n";

my $category = lc question( 'Category (desktop/mobile)', 'desktop' );
$category =~ /^(desktop|mobile)$/
  or die "Category must be 'desktop' or 'mobile'.\n";

my $title = question( 'Link text/title', 'New Article' );
my $slug  = question( 'Slug (filename without .html, e.g. android-privacy)', '' );
length $slug or die "Slug is required.\n";

my $href = "./articles/$slug.html";

# Prevent duplicates
if ( index( $content, $href ) != -1 ) {
    print "A link to $href already exists in $index. No change made.\n";
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
        print "Inserted link into Desktop Systems list.\n";
        exit 0;
    }
    else {
        die "Could not locate Desktop Systems list in $index.\n";
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
            print "Inserted Overview link into Mobile Systems.\n";
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
        print "Inserted link into Mobile Systems topics.\n";
        exit 0;
    }

    die "Could not locate Mobile Systems topic list in $index.\n";
}

__END__
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

# Small helper to update the Articles section in cyberpunk-handbook/index.html
# Usage: update-guides.pl
# questions for: category (desktop|mobile), title, slug (without .html), where to insert

use strict;
use warnings;
use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

sub question {
    my ( $msg, $default ) = @_;
    my $suf = defined $default && length $default ? " [$default]" : "";
    print "$msg$suf: ";
    my $in = <STDIN>;
    defined $in or die "Could not read input.\n";
    chomp $in;
    return length $in ? $in : ( $default // '' );
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Could not open $path: $!\n";
    local $/;
    my $c = <$fh>;
    close $fh;
    return $c;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>:raw', $path or die "Could not write $path: $!\n";
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

print "This will insert a new article link into $index\n";

my $category = lc question( 'Category (desktop/mobile)', 'desktop' );
$category =~ /^(desktop|mobile)$/
  or die "Category must be 'desktop' or 'mobile'.\n";

my $title = question( 'Link text/title', 'New Article' );
my $slug  = question( 'Slug (filename without .html, e.g. android-privacy)', '' );
length $slug or die "Slug is required.\n";

my $href = "./articles/$slug.html";

# Prevent duplicates
if ( index( $content, $href ) != -1 ) {
    print "A link to $href already exists in $index. No change made.\n";
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
        print "Inserted link into Desktop Systems list.\n";
        exit 0;
    }
    else {
        die "Could not locate Desktop Systems list in $index.\n";
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
            print "Inserted Overview link into Mobile Systems.\n";
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
        print "Inserted link into Mobile Systems topics.\n";
        exit 0;
    }

    die "Could not locate Mobile Systems topic list in $index.\n";
}

__END__


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

# Small helper to update the Articles section in cyberpunk-handbook/index.html
# Usage: update-guides.pl
# questions for: category (desktop|mobile), title, slug (without .html), where to insert

use strict;
use warnings;
use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

sub question {
    my ( $msg, $default ) = @_;
    my $suf = defined $default && length $default ? " [$default]" : "";
    print "$msg$suf: ";
    my $in = <STDIN>;
    defined $in or die "Could not read input.\n";
    chomp $in;
    return length $in ? $in : ( $default // '' );
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Could not open $path: $!\n";
    local $/;
    my $c = <$fh>;
    close $fh;
    return $c;
}

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>:raw', $path or die "Could not write $path: $!\n";
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

print "This will insert a new article link into $index\n";

my $category = lc question( 'Category (desktop/mobile)', 'desktop' );
$category =~ /^(desktop|mobile)$/
  or die "Category must be 'desktop' or 'mobile'.\n";

my $title = question( 'Link text/title', 'New Article' );
my $slug  = question( 'Slug (filename without .html, e.g. android-privacy)', '' );
length $slug or die "Slug is required.\n";

my $href = "./articles/$slug.html";

# Prevent duplicates
if ( index( $content, $href ) != -1 ) {
    print "A link to $href already exists in $index. No change made.\n";
    exit 0;
}

my $link_html =
qq{<li>\n              <a href="$href" target="_blank" rel="noopener noreferrer">}
  . esc_html($title)
  . qq{</a>\n            </li>\n\n};

if ( $category eq 'desktop' ) {

# Find Desktop Systems column: <h3>Desktop Systems</h3> followed by <ul class="guide-list"> ... </ul>
    if ( $content =~
                /(\Q<h3>Desktop Systems<\/h3>\E.*?<ul[^>]*class="article-list"[^>]*>)(.*?)(<\/ul>)/s
      )
    { 
        my ( $pre, $inner, $post ) = ( $1, $2, $3 );
        $inner .= "\n            " . $link_html;
        $content =~ s/\Q$pre$inner$post\E/$pre$inner$post/s;
        write_file( $index, $content );
        print "Inserted link into Desktop Systems list.\n";
        exit 0;
    }
    else {
        die "Could not locate Desktop Systems list in $index.\n";
    }
}
else {
    # mobile: either Overview (top-level) or topic list
    my $inserted = 0;

# If user wants Overview (title equals 'Overview' or asks), add top-level link if no such link exists
    if ( lc($title) eq 'overview' ) {

        # Find Mobile Systems guide-list and insert the link as first <li>
        if ( $content =~
                /(\Q<h3>Mobile Systems<\/h3>\E.*?<ul[^>]*class="article-list"[^>]*>)(.*?)(<\/ul>)/s
          )
        {
                        my ( $pre, $inner, $post ) = ( $1, $2, $3 ); 
            $inner = "\n            " . $link_html . $inner;
            $content =~ s/\Q$pre$inner$post\E/$pre$inner$post/s;
            write_file( $index, $content );
            print "Inserted Overview link into Mobile Systems.\n";
            exit 0;
        }
    }

    # Otherwise try to insert into topic-list
    if ( $content =~
/(\Q<h3>Mobile Systems<\/h3>\E.*?<ul[^>]*class="guide-list"[^>]*>.*?<ul[^>]*class="topic-list"[^>]*>)(.*?)(<\/ul>)/s
      )
    {
           my ( $pre, $inner, $post ) = ( $1, $2, $3 ); 
        $inner .= "\n                " . $link_html;
        $content =~ s/\Q$pre$inner$post\E/$pre$inner$post/s;
        write_file( $index, $content );
        print "Inserted link into Mobile Systems topics.\n";
        exit 0;
    }

    die "Could not locate Mobile Systems topic list in $index.\n";
}

__END__
