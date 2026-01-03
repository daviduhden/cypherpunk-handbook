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
# This script converts media files under the specified root directory
# to canonical formats:
#   - Images (non-SVG) -> PNG
#   - Audio            -> Vorbis in .ogg
#   - Video            -> Theora+Vorbis in .ogv
#
# Additionally (in --apply):
#   - Updates .html/.htm references from converted source filenames/paths to their
#     canonical output filenames/paths (so HTML doesn't reference deleted originals).
#
# -------------------------
# Usage: convert-media.pl [--root DIR] [--apply|--check] [--no-color] [--verbose]
# Modes:
#   --apply             Convert in place / create canonical outputs (default)
#   --check             Do not modify files; fail if any conversion is needed
# Options:
#   --root DIR          Root directory to scan (default: ../ relative to this script)
#   --no-color          Disable colored output
#   --verbose           Print commands and extra info
#-------------------------
#
# Note: This script requires ImageMagick (magick/convert), ffmpeg, and ffprobe.

use strict;
use warnings;

use FindBin;
use File::Spec;
use File::Find;
use File::Basename qw(dirname basename);
use File::Temp     qw(tempfile);
use File::Compare  qw(compare);
use Getopt::Long   qw(GetOptions);

# -------------------------
# Options
# -------------------------
my $default_root = File::Spec->catdir( $FindBin::RealBin, '..' );

my $root_dir   = $default_root;
my $mode_apply = 1;               # default: apply conversions
my $no_color   = 0;
my $verbose    = 0;

sub usage {
    print STDERR <<"USAGE";
Usage:
  $0 [--root DIR] [--apply|--check] [--no-color] [--verbose]

Modes:
  --apply             Convert in place / create canonical outputs (default)
  --check             Do not modify files; fail if any conversion is needed

Options:
  --root DIR          Root directory to scan (default: ../ relative to this script)
  --no-color          Disable colored output
  --verbose           Print commands and extra info

Outputs (canonical):
  Images (non-SVG) -> .png
  Audio            -> Vorbis in .ogg
  Video            -> Theora+Vorbis in .ogv

Exit codes:
  0  OK
  2  Conversion needed (in --check) and/or conversion errors
  1  Tooling/usage error
USAGE
    exit 1;
}

GetOptions(
    "root=s"    => \$root_dir,
    "apply!"    => sub { $mode_apply = 1 },
    "check!"    => sub { $mode_apply = 0 },
    "no-color!" => \$no_color,
    "verbose!"  => \$verbose,
) or usage();

-d $root_dir or die "ERROR: root is not a directory: $root_dir\n";

# -------------------------
# Logging
# -------------------------
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

# -------------------------
# Helpers
# -------------------------
sub have_cmd {
    my ($cmd) = @_;
    return 0 unless defined $cmd && length $cmd;
    for my $dir ( split /:/, ( $ENV{PATH} // "" ) ) {
        my $p = File::Spec->catfile( $dir, $cmd );
        return 1 if -x $p;
    }
    return 0;
}

sub run_cmd {
    my (@cmd) = @_;
    print "[cmd] @cmd\n" if $verbose;
    system(@cmd);
    return 0 if $? == -1;
    return 0 if $? & 127;
    return ( ( $? >> 8 ) == 0 ) ? 1 : 0;
}

sub run_capture {
    my (@cmd) = @_;
    print "[cmd] @cmd\n" if $verbose;

    my $tmp  = "/tmp/convert-media-$$.out";
    my $tmp2 = "/tmp/convert-media-$$.err";
    unlink $tmp;
    unlink $tmp2;

    my $ok = system( @cmd, ">", $tmp, "2>", $tmp2 );
    my $rc = ( $? >> 8 );

    my $out = "";
    my $err = "";
    if ( open my $fh, "<", $tmp )  { local $/; $out = <$fh> // ""; close $fh; }
    if ( open my $fh, "<", $tmp2 ) { local $/; $err = <$fh> // ""; close $fh; }

    unlink $tmp;
    unlink $tmp2;

    return ( $rc, $out, $err );
}

sub ext_lc {
    my ($p) = @_;
    return "" unless defined $p;
    return ( $p =~ /\.([^.\/]+)$/ ) ? lc($1) : "";
}

sub base_no_ext {
    my ($p) = @_;
    return $p =~ s/\.[^.\/]+$//r;
}

sub slashes_for_html {
    my ($p) = @_;
    return "" unless defined $p;
    $p =~ s{\\}{/}g;
    return $p;
}

sub write_atomic {
    my ( $tmp_path, $target_path ) = @_;

    if ( -e $target_path ) {

        # If identical, do nothing
        if ( compare( $tmp_path, $target_path ) == 0 ) {
            unlink $tmp_path;
            return ( 1, 0 );    # ok, not changed
        }
    }

# Prefer atomic rename; if it fails due to existing target (common on Windows),
# explicitly unlink the target and retry (this also ensures "originals" are gone
# for in-place conversions where dst == src).
    if ( !rename( $tmp_path, $target_path ) ) {
        if ( -e $target_path ) {
            unlink $target_path;    # remove old/original content
            if ( !rename( $tmp_path, $target_path ) ) {
                unlink $tmp_path;
                return ( 0, 0 );
            }
            return ( 1, 1 );
        }
        unlink $tmp_path;
        return ( 0, 0 );
    }

    return ( 1, 1 );    # ok, changed
}

# -------------------------
# File collection
# -------------------------
my %skip_dir = map { $_ => 1 } qw(.git node_modules dist build .cache);

my %img_ext = map { $_ => 1 } qw(
  png jpg jpeg jpe gif bmp tiff tif webp heic heif avif
);

# Media containers/extensions we consider for ffprobe classification
my %media_ext = map { $_ => 1 } qw(
  ogg oga ogv
  mp3 wav flac aac m4a
  mp4 m4v mov mkv webm avi mpg mpeg
);

my ( @images, @media_candidates, @html_files );

File::Find::find(
    {
        no_chdir => 1,
        wanted   => sub {
            my $path = $File::Find::name;

            if ( -d $path ) {
                my $base = $_;
                if ( $skip_dir{$base} ) {
                    $File::Find::prune = 1;
                }
                return;
            }
            return unless -f $path;

            my $e = ext_lc($path);
            return if $e eq "";

            if ( $e eq "html" || $e eq "htm" ) {
                push @html_files, $path;
                return;
            }

            # SVG is excluded from image conversion by requirement
            if ( $e eq "svg" ) {
                return;
            }

            if ( $img_ext{$e} ) {
                push @images, $path;
                return;
            }

            if ( $media_ext{$e} ) {
                push @media_candidates, $path;
                return;
            }
        },
    },
    $root_dir
);

logi(   "Found images="
      . scalar(@images)
      . ", media="
      . scalar(@media_candidates)
      . ", html="
      . scalar(@html_files)
      . " under: $root_dir" );

# -------------------------
# Tool selection (best available)
# -------------------------
my $magick =
  have_cmd("magick") ? "magick" : ( have_cmd("convert") ? "convert" : "" );
my $ffmpeg  = have_cmd("ffmpeg")  ? "ffmpeg"  : "";
my $ffprobe = have_cmd("ffprobe") ? "ffprobe" : "";

if (@images) {
    $magick
      or die_tool_tool(
"Required tool not found: 'magick' (ImageMagick 7) or 'convert' (ImageMagick 6) for image conversion."
      );
}
if (@media_candidates) {
    $ffmpeg
      or die_tool_tool(
        "Required tool not found: 'ffmpeg' for audio/video conversion.");
    $ffprobe
      or die_tool_tool(
        "Required tool not found: 'ffprobe' for audio/video classification.");
}

# -------------------------
# Planning + tracking
# -------------------------
my %need_convert;         # source => 1
my %errors;               # file => 1
my %changed_outputs;      # output => 1
my %converted_map;        # source => dest (only when dest path differs)
my %inplace_converted;    # source => 1 (dst == src but re-encoded)

sub mark_need  { $need_convert{ $_[0] } = 1 if defined $_[0] && length $_[0]; }
sub mark_error { $errors{ $_[0] }       = 1 if defined $_[0] && length $_[0]; }

# -------------------------
# Image conversion (non-SVG -> PNG) via ImageMagick only
# -------------------------
sub plan_image_target {
    my ($src) = @_;
    my $e = ext_lc($src);
    return ( 0, "" ) if $e eq "png";            # already canonical
    return ( 1, base_no_ext($src) . ".png" );
}

sub convert_image_to_png {
    my ( $src, $dst ) = @_;

    my $dir = dirname($dst);
    my ( $fh, $tmp ) = tempfile(
        TEMPLATE => "img-XXXXXX",
        SUFFIX   => ".png",
        DIR      => $dir,
        UNLINK   => 0
    );
    close $fh;

    # Note: Animated GIF -> first frame only (ImageMagick default).
    my @cmd = ( $magick, $src, $tmp );
    my $ok  = run_cmd(@cmd);
    if ( !$ok ) {
        unlink $tmp;
        loge("Image conversion failed: $src");
        mark_error($src);
        return 0;
    }

    my ( $wok, $did_change ) = write_atomic( $tmp, $dst );
    if ( !$wok ) {
        loge("Failed to write target image: $dst");
        mark_error($src);
        return 0;
    }
    $changed_outputs{$dst} = 1 if $did_change;

    # Always remove original if output path differs.
    if ( lc($src) ne lc($dst) ) {
        $converted_map{$src} = $dst;
        unlink $src or logw("Could not remove original (continuing): $src");
    }
    else {
        # Not expected for images (we don't convert .png), but keep semantics.
        $inplace_converted{$src} = 1;
    }

    return 1;
}

# -------------------------
# ffprobe helpers (classify + codecs)
# -------------------------
sub ffprobe_has_video {
    my ($path) = @_;
    my ( $rc, $out, $err ) = run_capture(
        $ffprobe,            "-v",
        "error",             "-select_streams",
        "v:0",               "-show_entries",
        "stream=codec_name", "-of",
        "default=nk=1:nw=1", $path
    );
    return 0 if $rc != 0;
    $out =~ s/\s+//g;
    return length($out) ? 1 : 0;
}

sub ffprobe_has_audio {
    my ($path) = @_;
    my ( $rc, $out, $err ) = run_capture(
        $ffprobe,            "-v",
        "error",             "-select_streams",
        "a:0",               "-show_entries",
        "stream=codec_name", "-of",
        "default=nk=1:nw=1", $path
    );
    return 0 if $rc != 0;
    $out =~ s/\s+//g;
    return length($out) ? 1 : 0;
}

sub ffprobe_video_codec {
    my ($path) = @_;
    my ( $rc, $out, $err ) = run_capture(
        $ffprobe,            "-v",
        "error",             "-select_streams",
        "v:0",               "-show_entries",
        "stream=codec_name", "-of",
        "default=nk=1:nw=1", $path
    );
    return "" if $rc != 0;
    $out =~ s/^\s+|\s+$//g;
    return $out;
}

sub ffprobe_audio_codec {
    my ($path) = @_;
    my ( $rc, $out, $err ) = run_capture(
        $ffprobe,            "-v",
        "error",             "-select_streams",
        "a:0",               "-show_entries",
        "stream=codec_name", "-of",
        "default=nk=1:nw=1", $path
    );
    return "" if $rc != 0;
    $out =~ s/^\s+|\s+$//g;
    return $out;
}

# -------------------------
# Audio conversion (Vorbis in .ogg)
# -------------------------
sub plan_audio_target {
    my ($src) = @_;
    my $dst = $src;

    # Canonical audio extension: .ogg
    $dst = base_no_ext($src) . ".ogg" if ext_lc($src) ne "ogg";

    # If it's already .ogg but not Vorbis, we re-encode in place (dst == src)
    return $dst;
}

sub audio_is_canonical {
    my ($src) = @_;
    return 0 unless ext_lc($src) eq "ogg";
    return 0 if ffprobe_has_video($src);    # .ogg might be video
    my $ac = ffprobe_audio_codec($src);
    return ( $ac eq "vorbis" ) ? 1 : 0;
}

sub convert_audio_to_vorbis_ogg {
    my ( $src, $dst ) = @_;

    my $dir = dirname($dst);
    my ( $fh, $tmp ) = tempfile(
        TEMPLATE => "aud-XXXXXX",
        SUFFIX   => ".ogg",
        DIR      => $dir,
        UNLINK   => 0
    );
    close $fh;

    my @cmd = (
        $ffmpeg,     "-y",   "-i", $src, "-vn", "-c:a",
        "libvorbis", "-q:a", "5",  $tmp
    );

    my $ok = run_cmd(@cmd);
    if ( !$ok ) {
        unlink $tmp;
        loge("Audio conversion failed: $src");
        mark_error($src);
        return 0;
    }

    my ( $wok, $did_change ) = write_atomic( $tmp, $dst );
    if ( !$wok ) {
        loge("Failed to write target audio: $dst");
        mark_error($src);
        return 0;
    }
    $changed_outputs{$dst} = 1 if $did_change;

    if ( lc($src) ne lc($dst) ) {
        $converted_map{$src} = $dst;
        unlink $src or logw("Could not remove original (continuing): $src");
    }
    else {
      # In-place conversion: the previous/original bytes are gone (overwritten).
        $inplace_converted{$src} = 1;
    }

    return 1;
}

# -------------------------
# Video conversion (Theora+Vorbis in .ogv)
# -------------------------
sub plan_video_target {
    my ($src) = @_;
    my $dst = $src;

    # Canonical video extension: .ogv
    $dst = base_no_ext($src) . ".ogv" if ext_lc($src) ne "ogv";

    # If it's already .ogv but not Theora, we re-encode in place (dst == src)
    return $dst;
}

sub video_is_canonical {
    my ($src) = @_;
    return 0 unless ext_lc($src) eq "ogv";
    return 0 unless ffprobe_has_video($src);
    my $vc = ffprobe_video_codec($src);
    return 0 unless $vc eq "theora";
    if ( ffprobe_has_audio($src) ) {
        my $ac = ffprobe_audio_codec($src);
        return 0 unless $ac eq "vorbis";
    }
    return 1;
}

sub convert_video_to_theora_ogv {
    my ( $src, $dst ) = @_;

    my $dir = dirname($dst);
    my ( $fh, $tmp ) = tempfile(
        TEMPLATE => "vid-XXXXXX",
        SUFFIX   => ".ogv",
        DIR      => $dir,
        UNLINK   => 0
    );
    close $fh;

    my @cmd = ( $ffmpeg, "-y", "-i", $src, "-c:v", "libtheora", "-q:v", "7", );

    if ( ffprobe_has_audio($src) ) {
        push @cmd, ( "-c:a", "libvorbis", "-q:a", "5" );
    }
    else {
        push @cmd, ("-an");
    }

    push @cmd, $tmp;

    my $ok = run_cmd(@cmd);
    if ( !$ok ) {
        unlink $tmp;
        loge("Video conversion failed: $src");
        mark_error($src);
        return 0;
    }

    my ( $wok, $did_change ) = write_atomic( $tmp, $dst );
    if ( !$wok ) {
        loge("Failed to write target video: $dst");
        mark_error($src);
        return 0;
    }
    $changed_outputs{$dst} = 1 if $did_change;

    if ( lc($src) ne lc($dst) ) {
        $converted_map{$src} = $dst;
        unlink $src or logw("Could not remove original (continuing): $src");
    }
    else {
        $inplace_converted{$src} = 1;
    }

    return 1;
}

# -------------------------
# Build conversion plan (detect what needs converting)
# -------------------------
my %target_to_sources;

# Images
for my $src (@images) {
    my ( $needs, $dst ) = plan_image_target($src);
    next unless $needs;
    mark_need($src);
    $target_to_sources{$dst} ||= [];
    push @{ $target_to_sources{$dst} }, $src;
}

# Media (audio vs video by ffprobe)
my ( @audio_sources, @video_sources );

for my $src (@media_candidates) {
    my $has_v = ffprobe_has_video($src);
    my $has_a = ffprobe_has_audio($src);

    if ($has_v) {
        push @video_sources, $src;
        next;
    }
    if ($has_a) {
        push @audio_sources, $src;
        next;
    }

    loge("Cannot classify media (no audio/video stream detected): $src");
    mark_error($src);
}

# Audio plan
for my $src (@audio_sources) {
    next if audio_is_canonical($src);
    mark_need($src);
    my $dst = plan_audio_target($src);
    $target_to_sources{$dst} ||= [];
    push @{ $target_to_sources{$dst} }, $src;
}

# Video plan
for my $src (@video_sources) {
    next if video_is_canonical($src);
    mark_need($src);
    my $dst = plan_video_target($src);
    $target_to_sources{$dst} ||= [];
    push @{ $target_to_sources{$dst} }, $src;
}

# Detect collisions (two different sources mapping to same target)
my $collision = 0;
for my $dst ( sort keys %target_to_sources ) {
    my @srcs = @{ $target_to_sources{$dst} };
    my %uniq = map { $_ => 1 } @srcs;
    @srcs = sort keys %uniq;
    if ( @srcs > 1 ) {
        $collision = 1;
        loge(
"Target collision: multiple sources want to write the same output: $dst"
        );
        for my $s (@srcs) {
            print STDERR "  - $s\n";
            mark_error($s);
        }
    }
}
if ($collision) {
    exit 2 if !$mode_apply;
    die_tool_tool(
"Refusing to convert due to output name collisions. Rename files to avoid collisions."
    );
}

# -------------------------
# Check mode summary
# -------------------------
if ( !$mode_apply ) {
    my @need = sort keys %need_convert;
    if (@need) {
        loge(   "Conversion is required (--check): "
              . scalar(@need)
              . " file(s) need conversion." );
        for my $i ( 0 .. $#need ) {
            last if $i > 199;
            print STDERR "  - $need[$i]\n";
        }
    }
    my @bad = sort keys %errors;
    if (@bad) {
        loge(   "Errors detected while classifying media: "
              . scalar(@bad)
              . " file(s)." );
        for my $i ( 0 .. $#bad ) {
            last if $i > 199;
            print STDERR "  - $bad[$i]\n";
        }
    }
    exit( ( @need || @bad ) ? 2 : 0 );
}

# -------------------------
# HTML reference updates (apply-mode)
# -------------------------
sub update_html_references {
    my (@htmls) = @_;
    return 1 unless @htmls;

    my @pairs;
    for my $src ( sort keys %converted_map ) {
        my $dst = $converted_map{$src};
        next unless defined $dst && length $dst;
        next if lc($src) eq lc($dst);
        push @pairs, [ $src, $dst ];
    }
    return 1 unless @pairs;

    my $changed = 0;

    for my $html (@htmls) {
        next unless -f $html;

        my $dir = dirname($html);

        my $content = "";
        my $fh;
        if ( !open $fh, "<", $html ) {
            logw("Could not read HTML (skipping): $html");
            next;
        }
        { local $/; $content = <$fh> // ""; }
        close $fh;

        my $orig = $content;

        # Replace both relative paths (from HTML dir) and plain basenames.
        for my $p (@pairs) {
            my ( $src, $dst ) = @$p;

            my $rel_src = File::Spec->abs2rel( $src, $dir );
            my $rel_dst = File::Spec->abs2rel( $dst, $dir );

            $rel_src = slashes_for_html($rel_src);
            $rel_dst = slashes_for_html($rel_dst);

            my $b_src = basename($src);
            my $b_dst = basename($dst);

            # Replace path form first (more specific)
            if ( length $rel_src ) {
                my $q = quotemeta($rel_src);
                $content =~ s/$q/$rel_dst/g;
            }

# Also replace plain basename occurrences (handles cases like src referenced without path)
            if ( length $b_src ) {
                my $q = quotemeta($b_src);
                $content =~ s/$q/$b_dst/g;
            }
        }

        next if $content eq $orig;

        my ( $fhw, $tmp ) = tempfile(
            TEMPLATE => "html-XXXXXX",
            SUFFIX   => ".tmp",
            DIR      => $dir,
            UNLINK   => 0
        );
        if ( !$fhw ) {
            logw("Could not create temp file for HTML (skipping): $html");
            next;
        }
        print $fhw $content;
        close $fhw;

        my ( $ok, $did_change ) = write_atomic( $tmp, $html );
        if ( !$ok ) {
            logw("Failed to write updated HTML (skipping): $html");
            next;
        }

        if ($did_change) {
            $changed++;
            logi("Updated HTML references: $html");
        }
    }

    logi("HTML updated: $changed file(s).") if $changed;
    return 1;
}

# -------------------------
# Apply conversions
# -------------------------
logi("Applying conversions...");

# Images
for my $src (@images) {
    my ( $needs, $dst ) = plan_image_target($src);
    next unless $needs;

    logi("Image -> PNG: $src -> $dst");
    convert_image_to_png( $src, $dst );
}

# Audio
for my $src (@audio_sources) {
    next if audio_is_canonical($src);
    my $dst = plan_audio_target($src);

    logi("Audio -> Vorbis/Ogg: $src -> $dst");
    convert_audio_to_vorbis_ogg( $src, $dst );
}

# Video
for my $src (@video_sources) {
    next if video_is_canonical($src);
    my $dst = plan_video_target($src);

    logi("Video -> Theora+Vorbis/Ogg: $src -> $dst");
    convert_video_to_theora_ogv( $src, $dst );
}

# Update HTML references AFTER conversions (so mapping reflects what actually happened)
update_html_references(@html_files);

# -------------------------
# Final summary
# -------------------------
my @bad = sort keys %errors;
if (@bad) {
    loge( "Completed with errors: " . scalar(@bad) . " file(s)." );
    for my $i ( 0 .. $#bad ) {
        last if $i > 199;
        print STDERR "  - $bad[$i]\n";
    }
    exit 2;
}

my $changed = scalar( keys %changed_outputs );
logi("Done. Outputs changed/created: $changed file(s).");
exit 0;
