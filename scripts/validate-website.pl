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
# FORMAT + VALIDATE website files (HTML, XML, SVG, CSS, JS) using only:
#   - tidy       : HTML format + basic validation (as supported by tidy)
#   - xmllint    : XML/SVG format + well-formedness validation
#   - dprint     : CSS/JS format + parse/format check (as supported by dprint)
#
# Usage:
#   validate-website.pl [--root DIR] [--apply|--check] [--no-color] [--verbose]
#
# Modes:
#   --apply   Format in place; also validate as tools support
#   --check   Do not modify files; fail if formatting would change and/or validation fails
#
# Exit codes:
#   0  OK
#   2  Formatting needed (in --check) and/or validation errors
#   1  Tooling/usage error
#
# Notes on "validation":
#   - HTML: tidy is used as validator (errors/warnings -> non-zero). We treat non-zero as validation failure.
#   - XML/SVG: xmllint --noout validates well-formedness; formatting uses xmllint --format.
#   - CSS/JS: dprint "check" ensures formatted and parses; any error is validation failure.

use strict;
use warnings;

use File::Basename qw(dirname);
use File::Spec;
use File::Find;
use Cwd          qw(abs_path);
use Getopt::Long qw(GetOptions);
use File::Temp   qw(tempfile);
use IPC::Open3   qw(open3);
use Symbol       qw(gensym);

# -------------------------
# Options
# -------------------------
my $script_dir   = dirname( abs_path($0) );
my $default_root = File::Spec->catdir( $script_dir, '..' );

my $root_dir   = $default_root;
my $mode_apply = 1;               # default: apply formatting
my $no_color   = 0;
my $verbose    = 0;

sub usage {
    print STDERR <<"USAGE";
Usage:
  $0 [--root DIR] [--apply|--check] [--no-color] [--verbose]

Modes:
  --apply         Format in place and validate (default)
  --check         Do not modify files; fail if formatting would change and/or validation fails

Options:
  --root DIR      Root directory to scan (default: ../ relative to this script)
  --no-color      Disable colored output
  --verbose       Print extra info

Dependencies (compiled binaries):
  tidy            HTML formatting + validation (as supported by tidy)
  xmllint         XML/SVG formatting + well-formedness validation
  dprint          CSS/JS formatting + parse/check (as supported by dprint)

Exit codes:
  0  OK
  2  Formatting needed (in --check) and/or validation errors
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

# Normalize the root directory to a canonical absolute path where possible.
# This avoids leaving `..` segments (e.g. scripts/..) which can lead to
# tools like `dprint` failing canonicalization (see CI errors).
my $abs_root = abs_path($root_dir);
if ( defined $abs_root && length $abs_root ) {
    $root_dir = $abs_root;
}

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

my $os_name = `uname -s 2>/dev/null`;
chomp $os_name;
my $is_openbsd = ( $os_name eq "OpenBSD" ) ? 1 : 0;

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

sub require_cmd {
    my ( $cmd, $why ) = @_;
    have_cmd($cmd)
      or die_tool("Required tool '$cmd' not found in PATH ($why).");
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

    my $err = gensym;
    my $pid = open3( undef, my $out, $err, @cmd );

    local $/;
    my $stdout = <$out> // "";
    my $stderr = <$err> // "";

    waitpid( $pid, 0 );
    my $rc = ( $? >> 8 );

    return ( $rc, $stdout, $stderr );
}

sub read_all {
    my ($path) = @_;
    open my $fh, '<:raw', $path or return undef;
    local $/;
    my $c = <$fh>;
    close $fh;
    return $c;
}

sub write_all {
    my ( $path, $content ) = @_;
    open my $fh, '>:raw', $path or return 0;
    print {$fh} $content;
    close $fh;
    return 1;
}

sub chunked {
    my ( $aref, $n ) = @_;
    my @out;
    for ( my $i = 0 ; $i < @$aref ; $i += $n ) {
        my $end = $i + $n - 1;
        $end = $#$aref if $end > $#$aref;
        push @out, [ @$aref[ $i .. $end ] ];
    }
    return @out;
}

sub make_tmp_file_in_tmp {
    my ( $suffix, $content ) = @_;

    my ( $base, $ext ) = ( $suffix, "" );
    if ( $suffix =~ /^(.*)(\.[^.]*)$/ ) {
        $base = $1;
        $ext  = $2;
    }
    $base =~ s/^\./-/;

    # File::Temp requires the TEMPLATE to end with at least 4 'X' characters.
    # Place extension via SUFFIX to keep TEMPLATE ending in Xs.
    my $template = "validate-website${base}-XXXXXX";

    my ( $fh, $path ) =
      tempfile( $template, DIR => "/tmp", SUFFIX => $ext, UNLINK => 0 );
    print {$fh} $content;
    close $fh;
    return $path;
}

# -------------------------
# Collect files
# -------------------------
my ( @html, @xml, @svg, @css, @js, @json );

my %skip_dir = map { $_ => 1 } qw(.git node_modules dist build .cache);

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

            my $lc = lc($path);
            if ( $lc =~ /\.html?$/ )        { push @html, $path; return; }
            if ( $lc =~ /\.xml$/ )          { push @xml,  $path; return; }
            if ( $lc =~ /\.svg$/ )          { push @svg,  $path; return; }
            if ( $lc =~ /\.css$/ )          { push @css,  $path; return; }
            if ( $lc =~ /\.(js|mjs|cjs)$/ ) { push @js,   $path; return; }
            if ( $lc =~ /\.json$/ )         { push @json, $path; return; }
        },
    },
    $root_dir
);

my $total = @html + @xml + @svg + @css + @js + @json;
if ( $total == 0 ) {
    logi("No HTML/XML/SVG/CSS/JS/JSON files found under: $root_dir");
    exit 0;
}

logi(   "Found $total files (HTML="
      . scalar(@html)
      . ", XML="
      . scalar(@xml)
      . ", SVG="
      . scalar(@svg)
      . ", CSS="
      . scalar(@css) . ", JS="
      . scalar(@js)
      . ", JSON="
      . scalar(@json)
      . ")" );

# -------------------------
# Tools (compiled binaries)
# -------------------------
my $tidy    = "tidy";
my $xmllint = "xmllint";
my $dprint  = "dprint";

require_cmd( $tidy,    "HTML formatting/validation" )    if @html;
require_cmd( $xmllint, "XML/SVG formatting/validation" ) if ( @xml || @svg );
require_cmd( $dprint,  "CSS/JS/JSON formatting/validation" )
  if ( ( @css || @js || @json ) && !$is_openbsd );
require_cmd( 'jq', "JSON formatting/validation (jq)" ) if @json;

$ENV{XMLLINT_INDENT} = "  ";

# -------------------------
# Temp dprint config
# -------------------------
my @tmp_paths;
my $dprint_cfg = "";

if ( @css || @js || @json ) {
    if ($is_openbsd) {
        logw("OpenBSD: skipping dprint for CSS/JS/JSON (not ported)")
          if $verbose;
    }
    else {
        $dprint_cfg = make_tmp_file_in_tmp( ".dprint.json",
                "{\n"
              . "  \"lineWidth\": 80,\n"
              . "  \"newLineKind\": \"lf\",\n"
              . "  \"plugins\": [\n"
              . "    \"https://plugins.dprint.dev/typescript-0.95.15.wasm\",\n"
              . "    \"https://plugins.dprint.dev/g-plane/malva-v0.15.2.wasm\",\n"
              . "    \"https://plugins.dprint.dev/json-0.21.1.wasm\"\n"
              . "  ]\n"
              . "}\n" );
        push @tmp_paths, $dprint_cfg;
        logi("Created temporary dprint config in /tmp: $dprint_cfg")
          if $verbose;
    }
}

END { unlink $_ for @tmp_paths; }

# -------------------------
# Tracking
# -------------------------
my %format_needed;      # file => 1 (only meaningful in --check)
my %validate_failed;    # file => 1

sub mark_format_needed {
    $format_needed{ $_[0] } = 1 if defined $_[0] && length $_[0];
}

sub mark_validate_failed {
    $validate_failed{ $_[0] } = 1 if defined $_[0] && length $_[0];
}

# -------------------------
# tidy options
# -------------------------
my @tidy_common = (
    "-indent", "-quiet",              "-wrap", "80",
    "-utf8",   "--indent-spaces",     "2",     "--tidy-mark",
    "no",      "--preserve-entities", "yes",   "--vertical-space",
    "yes",
);

sub tidy_validate_one {
    my ($file) = @_;

    # Non-zero means warnings/errors. Treat as validation failure.
    my ( $rc, $out, $err ) =
      run_capture( $tidy, @tidy_common, "-errors", $file );
    if ( $rc != 0 ) {
        loge("tidy validation failed (exit $rc): $file");
        mark_validate_failed($file);
    }
}

sub tidy_format_or_check_one {
    my ($file) = @_;

    if ($mode_apply) {

        # Format in place
        my @cmd = ( $tidy, @tidy_common, "-m", $file );
        print "[cmd] @cmd\n" if $verbose;
        system(@cmd);
        my $rc = ( $? >> 8 );
        if ( $rc != 0 ) {

            # Even in apply, a non-zero indicates issues (warnings/errors)
            loge("tidy formatting reported issues (exit $rc): $file");
            mark_validate_failed($file);
        }
        return;
    }

    # --check: compare formatted output with file contents
    my ( $rc, $out, $err ) = run_capture( $tidy, @tidy_common, $file );

    if ( $rc != 0 ) {
        loge("tidy formatting/parse reported issues (exit $rc): $file");
        mark_validate_failed($file);

        # Still attempt to mark formatting difference if we got output
        # (but don't trust empty output).
    }

    my $before = read_all($file);
    if ( defined($before) && defined($out) && $out ne "" && $out ne $before ) {
        mark_format_needed($file);
    }
}

sub xmllint_validate_one {
    my ( $file, $label ) = @_;
    my $ok = run_cmd( $xmllint, "--noout", "--nonet", $file );
    if ( !$ok ) {
        loge("$label validation failed (xmllint): $file");
        mark_validate_failed($file);
    }
}

sub xmllint_format_or_check_one {
    my ( $file, $label ) = @_;

    my $before = read_all($file);
    if ( !defined $before ) {
        loge("Could not read $label file: $file");
        mark_validate_failed($file);
        return;
    }

    my ( $rc, $out, $err ) =
      run_capture( $xmllint, "--nonet", "--format", $file );
    if ( $rc != 0 || !defined($out) || $out eq "" ) {
        loge("$label formatting failed (xmllint): $file");
        mark_validate_failed($file);
        return;
    }

    if ($mode_apply) {
        if ( $out ne $before ) {
            write_all( $file, $out ) or do {
                loge("Failed to write formatted $label file: $file");
                mark_validate_failed($file);
            };
        }
    }
    else {
        if ( $out ne $before ) {
            mark_format_needed($file);
        }
    }
}

sub dprint_validate_and_check_or_apply {
    my ($files_ref) = @_;
    return unless @$files_ref;

    if ($mode_apply) {
        logi("Formatting CSS/JS with dprint...");
        for my $chunk ( chunked( $files_ref, 120 ) ) {

        # Use run_cmd so dprint writes files in-place and inherits stdout/stderr
            my @cmd = ( $dprint, "fmt", "--config", $dprint_cfg, @$chunk );
            print "[cmd] @cmd\n" if $verbose;
            my $ok = run_cmd(@cmd);

            # run_cmd returns true on success; false on failure
            if ( !$ok ) {
                loge("dprint formatting/parse failed for some files in chunk.");
                mark_validate_failed($_) for @$chunk;
            }
        }
        return;
    }

    logi("Checking CSS/JS formatting and validity with dprint (check)...");
    for my $chunk ( chunked( $files_ref, 120 ) ) {

        my ( $rc, $out, $err ) = run_capture( $dprint, "check", "--config",
            $dprint_cfg, "--list-different", @$chunk );

        # If plugin download/resolution fails, skip dprint checks for this run.
        if ( defined($err) && $err =~ /Error (downloading|resolving) plugin/i )
        {
            logw(
"dprint plugin download/resolution failed; skipping dprint check in this run."
            );
            print STDERR $err if $verbose;
            return;
        }

        if ( $rc == 0 ) {
            next;    # formatted + parsed OK
        }

        # When not formatted, dprint often lists file paths (stdout).
        my $any_listed = 0;
        for my $line ( split /\n/, ( $out // "" ) ) {
            $line =~ s/\r$//;
            next unless length $line;
            $any_listed = 1;
            mark_format_needed($line);
        }

# If no list, conservatively mark the chunk as either "format needed" or "validation failed".
        if ( !$any_listed ) {
            mark_format_needed($_) for @$chunk;
        }

# If stderr has content, treat as validation failure (parse/plugin/config errors).
        if ( defined($err) && $err =~ /\S/ ) {
            loge(
"dprint reported errors while checking (see stderr with --verbose)."
            );
            mark_validate_failed($_) for @$chunk;
            print STDERR $err if $verbose;
        }
    }
}

# -------------------------
# Run
# -------------------------
# HTML
if (@html) {
    logi( ( $mode_apply ? "Formatting" : "Checking formatting of" )
        . " HTML with tidy..." );
    tidy_format_or_check_one($_) for @html;

    logi("Validating HTML with tidy (as supported)...");
    tidy_validate_one($_) for @html;
}

# XML
if (@xml) {
    logi( ( $mode_apply ? "Formatting" : "Checking formatting of" )
        . " XML with xmllint..." );
    xmllint_format_or_check_one( $_, "XML" ) for @xml;

    logi("Validating XML well-formedness with xmllint...");
    xmllint_validate_one( $_, "XML" ) for @xml;
}

# SVG
if (@svg) {
    logi( ( $mode_apply ? "Formatting" : "Checking formatting of" )
        . " SVG with xmllint..." );
    xmllint_format_or_check_one( $_, "SVG" ) for @svg;

    logi("Validating SVG well-formedness with xmllint...");
    xmllint_validate_one( $_, "SVG" ) for @svg;
}

# CSS/JS/JSON (via dprint)
if ( @css || @js || @json ) {
    if ($is_openbsd) {
        logw("OpenBSD: skipping dprint for CSS/JS/JSON (not ported)");
    }
    else {
        my @pfiles = ( @css, @js, @json );
        dprint_validate_and_check_or_apply( \@pfiles );
    }
}

# JSON validation with jq (ensure well-formedness and optional formatting)
if (@json) {
    logi( ( $mode_apply ? "Formatting" : "Checking formatting of" )
        . " JSON with jq..." );
    for my $f (@json) {
        my $before = read_all($f);
        if ( !defined $before ) {
            loge("Could not read JSON file: $f");
            mark_validate_failed($f);
            next;
        }

        my ( $rc, $out, $err ) = run_capture( 'jq', '.', $f );
        if ( $rc != 0 ) {
            loge("jq validation/parse failed (exit $rc): $f");
            mark_validate_failed($f);
            print STDERR $err if $verbose;
            next;
        }

        if ($mode_apply) {
            if ( $out ne $before ) {
                write_all( $f, $out ) or do {
                    loge("Failed to write formatted JSON file: $f");
                    mark_validate_failed($f);
                };
            }
        }
        else {
            if ( $out ne $before ) {
                mark_format_needed($f);
            }
        }
    }
}

# -------------------------
# Summary / exit
# -------------------------
my @fmt = sort keys %format_needed;
my @bad = sort keys %validate_failed;

if ( !$mode_apply && @fmt ) {
    loge(   "Formatting is not clean (--check): "
          . scalar(@fmt)
          . " file(s) would change." );
    for my $i ( 0 .. $#fmt ) {
        last if $i > 199;
        print STDERR "  - $fmt[$i]\n";
    }
}

if (@bad) {
    loge( "Validation failed: " . scalar(@bad) . " file(s)." );
    for my $i ( 0 .. $#bad ) {
        last if $i > 199;
        print STDERR "  - $bad[$i]\n";
    }
}

if ( ( !$mode_apply && @fmt ) || @bad ) {
    exit 2;
}

logi(
    $mode_apply
    ? "Done. Formatting applied and validation passed."
    : "Done. Formatting clean and validation passed."
);

exit 0;
