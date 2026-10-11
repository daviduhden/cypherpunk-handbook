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
# REBUILD sitemap.xml by scanning public HTML files and producing
# canonical URLs without fabricated modification dates.
#
# Usage:
#   rebuild-sitemap.pl

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Find;
use File::Spec;
use File::Temp qw(tempfile);

my $script_dir = ( File::Spec->splitpath($0) )[1];
my $root_dir   = abs_path( File::Spec->catdir( $script_dir, '..' ) );
my $site_url   = 'https://handbook.uhden.dev';

sub write_file_atomic {
    my ( $path, $content ) = @_;
    my $dir  = dirname($path);
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
        close $fh;
        unlink $tmp;
        die "Could not write $path: $err\n";
    }
    if ( !close $fh ) {
        my $err = $!;
        unlink $tmp;
        die "Could not close $path: $err\n";
    }
    if ( defined $mode && !chmod $mode, $tmp ) {
        my $err = $!;
        unlink $tmp;
        die "Could not set permissions on $path: $err\n";
    }
    if ( !rename $tmp, $path ) {
        my $err = $!;
        unlink $tmp;
        die "Could not replace $path: $err\n";
    }
    return 1;
}

sub xml_escape {
    my ($text) = @_;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    return $text;
}

sub sitemap_url {
    my ($path) = @_;
    my $relative = File::Spec->abs2rel( $path, $root_dir );
    $relative =~ s{\\}{/}g;

    return "$site_url/" if $relative eq 'index.html';
    if ( $relative =~ m{^(.*)/index\.html$} ) {
        return "$site_url/$1/";
    }
    return "$site_url/$relative";
}

my @pages;
find(
    {
        no_chdir => 1,
        wanted   => sub {
            return unless -f $_ && /\.html$/i;
            my $path = $File::Find::name;
            return if $path =~ m{/(?:archive|templates)/};
            push @pages, sitemap_url($path);
        },
    },
    $root_dir
);

@pages = sort @pages;
my $xml = qq(<?xml version="1.0" encoding="UTF-8"?>\n)
  . qq(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n);
for my $url (@pages) {
    $xml .= "  <url>\n";
    $xml .= '    <loc>' . xml_escape($url) . "</loc>\n";
    $xml .= "  </url>\n";
}
$xml .= "</urlset>\n";

my $output = File::Spec->catfile( $root_dir, 'sitemap.xml' );
write_file_atomic( $output, $xml );

print "Rebuilt sitemap: $output\n";
