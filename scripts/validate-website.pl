#!/usr/bin/env perl

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
# FORMAT + VALIDATE website files (HTML, XML, SVG, CSS, JS)
# using only:
#   - tidy       : HTML format + basic validation
#   - xmllint    : XML/SVG format + well-formedness check
#   - dprint     : CSS/JS format + parse/format check
#
# Usage:
#   validate-website.pl [--root DIR] [--apply|--check]
#                       [--check-links] [--check-spelling]
#                       [--verbose]
#
# Modes:
#   --apply   Format in place; also validate
#   --check   Do not modify files; fail if formatting
#             would change and/or validation fails
#
# Exit codes:
#   0  OK
#   2  Formatting needed (in --check) and/or validation
#      errors
#   1  Tooling/usage error
#
# Notes on "validation":
#   - HTML: tidy is used as validator
#     (errors/warnings -> non-zero). We treat non-zero
#     as validation failure.
#   - XML/SVG: xmllint --noout validates well-formedness;
#     formatting uses xmllint --format.
#   - CSS/JS: dprint "check" ensures formatted and
#     parses; any error is validation failure.

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

my $root_dir    = $default_root;
my $mode_apply  = 1;               # default: apply formatting
my $check_links = 0;               # optional: check/fix links
my $check_spelling = 0;            # optional: check visible HTML text
my $verbose     = 0;

my %spelling_dictionary = ( en => 'en_US' );
my $spelling_dictionary_list =
  join( ', ', sort values %spelling_dictionary );
my $spelling_personal_list =
  join( ' or ', map { ".hunspell/$_" } sort values %spelling_dictionary );

sub usage {
    print STDERR <<"USAGE";
Usage:
  $0 [--root DIR] [--apply|--check] [--check-links] \\
     [--check-spelling] [--verbose]

Modes:
  --apply         Format in place and validate (default)
  --check         Do not modify files; fail if formatting
                  would change and/or validation fails

Options:
  --root DIR      Root directory to scan
                  (default: ../ relative to this script)
  --check-links   Check internal/external links, write a
                  temporary report and (in --apply) try to
                  auto-fix links. External fixes prefer
                  final official URL after redirects; if
                  unavailable, Wayback.
  --check-spelling
                  Check visible HTML text with the dictionary
                  selected from the document's lang attribute.
                  Configured dictionaries: $spelling_dictionary_list. This
                  check is read-only in both modes. Project-specific
                  words can be listed in $spelling_personal_list,
                  one word per line.
  --verbose       Print extra info

Dependencies (compiled binaries):
  tidy            HTML formatting + validation
  xmllint         XML/SVG formatting + validation
  dprint          CSS/JS formatting + parse/check
  curl            External link checking/fixing when
                  --check-links is used
  hunspell        Spell checking when --check-spelling is used;
                  each configured dictionary is required

Exit codes:
  0  OK
  2  Formatting needed (in --check) and/or validation
     errors
  1  Tooling/usage error
USAGE
    exit 1;
}

GetOptions(
    "root=s"       => \$root_dir,
    "apply!"       => sub { $mode_apply = 1 },
    "check!"       => sub { $mode_apply = 0 },
    "check-links!" => \$check_links,
    "check-spelling!" => \$check_spelling,
    "verbose!"     => \$verbose,
) or usage();

# Normalize the root directory to a canonical absolute
# path where possible. This avoids leaving `..` segments
# (e.g. scripts/..) which can lead to tools like `dprint`
# failing canonicalization (see CI errors).
my $abs_root = abs_path($root_dir);
if ( defined $abs_root && length $abs_root ) {
    $root_dir = $abs_root;
}

-d $root_dir
  or die "ERROR: root is not a directory: $root_dir\n";

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

    # File::Temp requires the TEMPLATE to end with at
    # least 4 'X' characters. Place extension via SUFFIX
    # to keep TEMPLATE ending in Xs.
    my $template = "validate-website${base}-XXXXXX";

    my $tmp_dir = File::Spec->tmpdir();
    $tmp_dir = $root_dir if !-d $tmp_dir || !-w $tmp_dir;

    my ( $fh, $path ) = tempfile(
        $template,
        DIR    => $tmp_dir,
        SUFFIX => $ext,
        UNLINK => 0
    );
    print {$fh} $content;
    close $fh;
    return $path;
}

sub trim {
    my ($v) = @_;
    $v = "" unless defined $v;
    $v =~ s/^\s+//;
    $v =~ s/\s+$//;
    return $v;
}

sub should_skip_link {
    my ($link) = @_;
    return 1 if !defined $link || $link eq "";
    return 1 if $link =~ /^\s*#/;                # in-page anchors
    return 1
      if $link =~ /^\s*(?:mailto|tel|javascript|data):/i;
    return 1
      if $link =~ /^\s*[A-Za-z][A-Za-z0-9+.-]*:/
      && $link !~ /^\s*(?:https?|file):/i;
    return 1 if $link =~ m{^\s*https?://[^/]+\.(?:onion|i2p)(?::\d+)?(?:/|$)}i;
    return 0;
}

sub is_external_link {
    my ($link) = @_;
    return 1 if $link =~ m{^\s*https?://}i;
    return 1 if $link =~ m{^\s*//[^/]};          # proto-rel
    return 0;
}

sub strip_query_fragment {
    my ($link) = @_;
    $link =~ s/[?#].*$// if defined $link;
    return $link;
}

sub url_percent_encode {
    my ($v) = @_;
    $v //= "";
    $v =~ s/([^A-Za-z0-9\-\._~])/sprintf("%%%02X", ord($1))/ge;
    return $v;
}

sub extract_links_from_content {
    my ($content) = @_;
    my @found;
    my %seen;

    while ( $content =~ /\b(?:href|src)\s*=\s*(['"])(.*?)\1/ig ) {
        my $link = trim($2);
        next if should_skip_link($link);
        next if $seen{$link}++;
        push @found, $link;
    }

    while ( $content =~ /\burl\(\s*(['"]?)([^'")]+)\1\s*\)/ig ) {
        my $link = trim($2);
        next if should_skip_link($link);
        next if $seen{$link}++;
        push @found, $link;
    }

    return @found;
}

sub internal_candidates {
    my ($link) = @_;
    my @candidates = ($link);

    my $base = $link;
    my $frag = "";
    if ( $base =~ s/(#[^#]*)$// ) {
        $frag = $1;
    }
    my $query = "";
    if ( $base =~ s/(\?[^?]*)$// ) {
        $query = $1;
    }

    my @path_variants = ($base);
    if ( $base !~ m{/$} ) {
        push @path_variants, "${base}.html"
          if $base !~ /\.html?$/i;
        push @path_variants, "${base}/index.html"
          if $base ne "";
    }
    else {
        push @path_variants, "${base}index.html";
    }

    my %seen;
    for my $p (@path_variants) {
        my $cand = "${p}${query}${frag}";
        next if $seen{$cand}++;
        push @candidates, $cand;
    }

    my @uniq;
    %seen = ();
    for my $c (@candidates) {
        next if !defined($c) || $c eq "";
        next if $seen{$c}++;
        push @uniq, $c;
    }
    return @uniq;
}

sub resolve_internal_link {
    my ( $source_file, $raw_link ) = @_;
    my $target = strip_query_fragment($raw_link);
    $target = trim($target);
    if ( $target eq "" ) {
        return ( 1, $source_file, "empty/anchor" );
    }

    $target =~ s{^file://}{};
    my $absolute;
    if ( $target =~ m{^/} ) {
        my $rel = $target;
        $rel =~ s{^/+}{};
        $absolute = File::Spec->catfile( $root_dir, split m{/+}, $rel );
    }
    else {
        my $src_dir = dirname($source_file);
        $absolute = File::Spec->catfile( $src_dir, split m{/+}, $target );
    }

    my $canon = abs_path($absolute);
    if (   defined($canon)
        && index( $canon, $root_dir ) == 0
        && -f $canon )
    {
        return ( 1, $canon, "ok" );
    }

    # Support links to directories by checking index.html
    my $with_index  = File::Spec->catfile( $absolute, "index.html" );
    my $canon_index = abs_path($with_index);
    if (   defined($canon_index)
        && index( $canon_index, $root_dir ) == 0
        && -f $canon_index )
    {
        return ( 1, $canon_index, "ok-index" );
    }

    return ( 0, $absolute, "missing" );
}

my %external_status_cache;

sub check_external_link {
    my ($url) = @_;
    if ( exists $external_status_cache{$url} ) {
        return $external_status_cache{$url};
    }

    my ( $rc, $out, $err ) = run_capture(
        'curl',                              '-L',
        '-sS',                               '--connect-timeout',
        '8',                                 '--max-time',
        '20',                                '-A',
        'validate-website-link-checker/1.0', '-o',
        '/dev/null',                         '-w',
        '%{http_code}\t%{url_effective}',    $url
    );

    my ( $code, $effective ) = ( "000", $url );
    if ( defined $out && $out =~ /^(\d{3})\t(.*)$/s ) {
        $code      = $1;
        $effective = trim($2);
    }
    my $ok =
      ( $rc == 0 && $code =~ /^(?:[23]\d\d|401|403|405|418|429)$/ ) ? 1 : 0;
    my $status = {
        ok        => $ok,
        code      => $code,
        effective => $effective,
        err       => ( $err // "" ),
    };
    $external_status_cache{$url} = $status;
    return $status;
}

sub find_wayback_url {
    my ($url) = @_;
    my $api =
      "https://archive.org/wayback/available?url=" . url_percent_encode($url);
    my ( $rc, $out, $err ) =
      run_capture( 'curl', '-L', '-sS', '--connect-timeout', '8',
        '--max-time', '20', $api );
    return undef
      if $rc != 0 || !defined($out) || $out eq "";

    if ( $out =~ /"available"\s*:\s*true.*?"url"\s*:\s*"([^"]+)"/s ) {
        my $wb = $1;
        $wb               =~ s{\\\/}{/}g;
        $wb               =~ s/\\"/"/g;
        return $wb if $wb =~ m{^https?://};
    }

    return undef;
}

sub propose_external_fix {
    my ($url) = @_;
    my $status = check_external_link($url);
    if (   $status->{ok}
        && $status->{effective} eq $url )
    {
        return ( undef, "ok" );
    }

    if ( $status->{ok} && $status->{effective} ne $url ) {
        return ( $status->{effective}, "redirect-final" );
    }

    my @candidates;
    if ( $url =~ m{^http://}i ) {
        ( my $https = $url ) =~ s{^http://}{https://}i;
        push @candidates, $https;
    }
    if ( $url =~ m{^https://}i ) {
        ( my $http = $url ) =~ s{^https://}{http://}i;
        push @candidates, $http;
    }
    if ( $url =~ m{^https?://www\.}i ) {
        ( my $no_www = $url ) =~ s{^(https?://)www\.}{$1}i;
        push @candidates, $no_www;
    }
    elsif ( $url =~ m{^https?://[^/]+}i ) {
        ( my $with_www = $url ) =~ s{^(https?://)}{$1www.}i;
        push @candidates, $with_www;
    }

    my %seen;
    for my $cand (@candidates) {
        next if $seen{$cand}++;
        my $cand_status = check_external_link($cand);
        if ( $cand_status->{ok} ) {
            return ( $cand_status->{effective}, "official-candidate" );
        }
    }

    my $wayback = find_wayback_url($url);
    return ( $wayback, "wayback" ) if defined $wayback;

    return ( undef, "unresolved" );
}

# -------------------------
# Collect files
# -------------------------
my ( @html, @xml, @svg, @css, @js, @json );

my %skip_dir =
  map { $_ => 1 } qw(.git node_modules dist build .cache);

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
            if ( $lc =~ /\.html?$/ ) {
                push @html, $path;
                return;
            }
            if ( $lc =~ /\.xml$/ ) {
                push @xml, $path;
                return;
            }
            if ( $lc =~ /\.svg$/ ) {
                push @svg, $path;
                return;
            }
            if ( $lc =~ /\.css$/ ) {
                push @css, $path;
                return;
            }
            if ( $lc =~ /\.(js|mjs|cjs)$/ ) {
                push @js, $path;
                return;
            }
            if ( $lc =~ /\.json$/ ) {
                push @json, $path;
                return;
            }
        },
    },
    $root_dir
);

my $total = @html + @xml + @svg + @css + @js + @json;
if ( $total == 0 ) {
    logi( "No HTML/XML/SVG/CSS/JS/JSON files found" . " under: $root_dir" );
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
require_cmd( 'jq',   "JSON formatting/validation (jq)" )      if @json;
require_cmd( 'curl', "link checking/fixing (--check-links)" ) if $check_links;
require_cmd( 'hunspell', "spell checking (--check-spelling)" )
  if $check_spelling;

$ENV{XMLLINT_INDENT} = "  ";

# -------------------------
# Temp dprint config
# -------------------------
my @tmp_paths;
my $dprint_cfg = "";

sub dprint_config_update {
    my ($cfg) = @_;
    return unless defined $cfg && length $cfg;

    my ( $rc, $out, $err ) =
      run_capture( $dprint, "config", "update", "--config", $cfg );
    if ( $rc != 0 ) {
        logw(   "dprint config update failed;"
              . " continuing with existing config." );
        print STDERR $err if $verbose;
    }
}

if ( @css || @js || @json ) {
    if ($is_openbsd) {
        logw( "OpenBSD: skipping dprint for" . " CSS/JS/JSON (not ported)" )
          if $verbose;
    }
    else {
        $dprint_cfg = make_tmp_file_in_tmp( ".dprint.json",
                "{\n"
              . "  \"lineWidth\": 80,\n"
              . "  \"newLineKind\": \"lf\",\n"
              . "  \"plugins\": [\n"
              . "    \"npm:\@dprint/typescript\@0.96.1\",\n"
              . "    \"npm:dprint-plugin-malva\@0.16.0\",\n"
              . "    \"npm:\@dprint/json\@0.23.0\"\n" . "  ]\n"
              . "}\n" );
        push @tmp_paths, $dprint_cfg;
        dprint_config_update($dprint_cfg);
        logi( "Created temporary dprint config at:" . " $dprint_cfg" )
          if $verbose;
    }
}

END { unlink $_ for @tmp_paths; }

# -------------------------
# Tracking
# -------------------------
my %format_needed;        # file => 1 (--check only)
my %validate_failed;      # file => 1
my %link_replacements;    # file => { old_link => new_link }
my $link_report_file = "";
my $spelling_report_file = "";

sub mark_format_needed {
    $format_needed{ $_[0] } = 1
      if defined $_[0] && length $_[0];
}

sub mark_validate_failed {
    $validate_failed{ $_[0] } = 1
      if defined $_[0] && length $_[0];
}

sub register_link_replacement {
    my ( $file, $old, $new ) = @_;
    return
         if !defined($file)
      || !defined($old)
      || !defined($new);
    return if $old eq "" || $new eq "" || $old eq $new;
    $link_replacements{$file} ||= {};
    $link_replacements{$file}{$old} = $new;
}

sub apply_link_replacements {
    return if !%link_replacements;
    return if !$mode_apply;

    my @files = sort keys %link_replacements;
    for my $file (@files) {
        my $content = read_all($file);
        if ( !defined $content ) {
            loge( "Could not read file to apply" . " link fixes: $file" );
            mark_validate_failed($file);
            next;
        }

        my @pairs =
          sort { length( $b->[0] ) <=> length( $a->[0] ) }
          map  { [ $_, $link_replacements{$file}{$_} ] }
          keys %{ $link_replacements{$file} };

        my $changed = 0;
        for my $pair (@pairs) {
            my ( $old, $new ) = @$pair;
            my $quoted = quotemeta($old);
            my $count  = ( $content =~ s/$quoted/$new/g );
            $changed += $count;
        }

        if ($changed) {
            write_all( $file, $content ) or do {
                loge( "Failed to write link fixes" . " to file: $file" );
                mark_validate_failed($file);
                next;
            };
            logi( "Applied $changed link fix(es)" . " in: $file" );
        }
    }
}

sub run_link_checks {
    my @scan_files = ( @html, @xml, @svg, @css, @js );
    return if !@scan_files;

    logi(   "Checking internal/external links and"
          . " preparing temporary report..." );

    my @local_rows;
    my @external_rows;

    for my $file (@scan_files) {
        my $content = read_all($file);
        if ( !defined $content ) {
            loge( "Could not read file for link" . " check: $file" );
            mark_validate_failed($file);
            next;
        }

        my @links = extract_links_from_content($content);
        next if !@links;

        for my $link (@links) {
            if ( is_external_link($link) ) {
                my $status = check_external_link($link);
                my $row    = {
                    file     => $file,
                    link     => $link,
                    status   => ( $status->{ok} ? "ok" : "broken" ),
                    detail   => ( "http=" . $status->{code} ),
                    proposed => "",
                    reason   => "",
                };

                if (  !$status->{ok}
                    || $status->{effective} ne $link )
                {
                    my ( $fix, $reason ) = propose_external_fix($link);
                    if ( defined $fix && $fix ne $link ) {
                        $row->{proposed} = $fix;
                        $row->{reason}   = $reason;
                        register_link_replacement( $file, $link, $fix )
                          if $mode_apply;
                    }
                }

                if ( !$status->{ok} && !$row->{proposed} ) {
                    mark_validate_failed($file);
                }
                push @external_rows, $row;
                next;
            }

            my ( $ok, $resolved, $why ) = resolve_internal_link( $file, $link );
            my $row = {
                file     => $file,
                link     => $link,
                status   => ( $ok ? "ok" : "broken" ),
                detail   => $resolved,
                proposed => "",
                reason   => "",
            };

            if ( !$ok ) {
                my $fixed = "";
                for my $cand ( internal_candidates($link) ) {
                    my ( $cand_ok, undef, undef ) =
                      resolve_internal_link( $file, $cand );
                    if ($cand_ok) {
                        $fixed = $cand;
                        last;
                    }
                }

                if ( $fixed ne "" && $fixed ne $link ) {
                    $row->{proposed} = $fixed;
                    $row->{reason}   = "internal-candidate";
                    register_link_replacement( $file, $link, $fixed )
                      if $mode_apply;
                }
                else {
                    mark_validate_failed($file);
                }
            }

            push @local_rows, $row;
        }
    }

    apply_link_replacements();

    my $report = "";
    $report .= "validate-website.pl" . " --check-links report\n";
    $report .= "Root: $root_dir\n";
    $report .= "Mode: " . ( $mode_apply ? "apply" : "check" ) . "\n\n";

    $report .= "=== LOCAL LINKS ===\n";
    if (@local_rows) {
        for my $r (@local_rows) {
            $report .= join( " | ",
                $r->{status}, $r->{file}, $r->{link},
                ( $r->{detail}   // "" ),
                ( $r->{proposed} // "" ),
                ( $r->{reason}   // "" ) ) . "\n";
        }
    }
    else {
        $report .= "(none)\n";
    }

    $report .= "\n=== EXTERNAL LINKS ===\n";
    if (@external_rows) {
        for my $r (@external_rows) {
            $report .= join( " | ",
                $r->{status}, $r->{file}, $r->{link},
                ( $r->{detail}   // "" ),
                ( $r->{proposed} // "" ),
                ( $r->{reason}   // "" ) ) . "\n";
        }
    }
    else {
        $report .= "(none)\n";
    }

    $link_report_file = make_tmp_file_in_tmp( ".links-report.txt", $report );
    logi( "Temporary link report written to:" . " $link_report_file" );
}

# -------------------------
# Spelling checks
# -------------------------
sub spelling_dictionary_for_html {
    my ( $file, $content ) = @_;

    my $lang = "";
    if ( $content =~ /<html\b[^>]*\blang\s*=\s*(['"])([^'"]+)\1/is ) {
        $lang = lc($2);
        $lang =~ tr/_/-/;
    }

    if ( $lang =~ /^([a-z]{2,3})(?:-|$)/ ) {
        return $spelling_dictionary{$1}
          if exists $spelling_dictionary{$1};
    }

    if ( $lang eq "" ) {
        logw("No HTML lang attribute in $file; using en_US for spelling.");
        return "en_US";
    }

    loge("Unsupported HTML language '$lang' for spelling: $file");
    mark_validate_failed($file);
    return undef;
}

sub visible_html_text {
    my ($content) = @_;

    # Omit non-editorial and technical blocks. The remaining tags are
    # replaced with spaces so adjacent words cannot be joined.
    $content =~ s/<!--.*?-->/ /gs;
    $content =~
      s{<(script|style|pre|code|kbd|samp|var|svg)\b[^>]*>.*?</\1\s*>}{ }gis;
    $content =~ s/<[^>]*>/ /gs;

    # Decode the entities that affect word boundaries and contractions.
    $content =~ s/(?:&#0*39;|&#x0*27;|&apos;)/'/gi;
    $content =~ s/(?:&#0*34;|&#x0*22;|&quot;)/"/gi;
    $content =~ s/(?:&#0*160;|&#x0*a0;|&nbsp;)/ /gi;
    $content =~ s/&amp;/&/gi;
    $content =~ s/&lt;/</gi;
    $content =~ s/&gt;/>/gi;
    $content =~ s/&[A-Za-z][A-Za-z0-9]+;/ /g;

    # Visible literal URLs and addresses are not natural-language words.
    $content =~ s{\b(?:https?|ftp)://\S+}{ }gi;
    $content =~ s{\b[A-Z0-9._%+-]+\@[A-Z0-9.-]+\.[A-Z]{2,}\b}{ }gi;
    $content =~ s/[ \t]+/ /g;

    return $content;
}

sub hunspell_dictionary_available {
    my ($dictionary) = @_;
    my $probe = make_tmp_file_in_tmp( ".spell-probe.txt", "" );
    push @tmp_paths, $probe;

    my ( $rc, $out, $err ) =
      run_capture( 'hunspell', '-d', $dictionary, '-l', '-i', 'UTF-8', $probe );
    return 1 if $rc == 0;

    loge("Hunspell dictionary '$dictionary' is not available.");
    print STDERR $err if defined($err) && $err ne "";
    return 0;
}

sub run_spelling_checks {
    return if !@html;

    logi("Checking spelling in visible HTML text...");

    my %dictionary_ok;
    my @report_rows;

    for my $file (@html) {
        my $content = read_all($file);
        if ( !defined $content ) {
            loge("Could not read file for spelling check: $file");
            mark_validate_failed($file);
            next;
        }

        my $dictionary = spelling_dictionary_for_html( $file, $content );
        next if !defined $dictionary;

        if ( !exists $dictionary_ok{$dictionary} ) {
            $dictionary_ok{$dictionary} =
              hunspell_dictionary_available($dictionary);
        }
        if ( !$dictionary_ok{$dictionary} ) {
            mark_validate_failed($file);
            push @report_rows,
              "$file | $dictionary | ERROR: dictionary unavailable";
            next;
        }

        my $text = visible_html_text($content);
        my $input = make_tmp_file_in_tmp( ".spell-input.txt", $text );
        push @tmp_paths, $input;

        my @cmd = ( 'hunspell', '-d', $dictionary, '-l', '-i', 'UTF-8' );
        my $personal =
          File::Spec->catfile( $root_dir, '.hunspell', $dictionary );
        push @cmd, ( '-p', $personal ) if -f $personal;
        push @cmd, $input;

        my ( $rc, $out, $err ) = run_capture(@cmd);
        if ( $rc != 0 ) {
            loge("Hunspell failed (exit $rc): $file");
            print STDERR $err if defined($err) && $err ne "";
            mark_validate_failed($file);
            push @report_rows,
              "$file | $dictionary | ERROR: hunspell failed";
            next;
        }

        my %unknown;
        for my $word ( split /\R/, ( $out // "" ) ) {
            $word =~ s/^\s+//;
            $word =~ s/\s+$//;
            next if $word eq "";
            $unknown{$word} = 1;
        }

        if (%unknown) {
            mark_validate_failed($file);
            my @words = sort { lc($a) cmp lc($b) || $a cmp $b }
              keys %unknown;
            push @report_rows,
              "$file | $dictionary | " . join( ", ", @words );
        }
    }

    my $report = "validate-website.pl --check-spelling report\n";
    $report .= "Root: $root_dir\n";
    $report .= "Mode: read-only\n\n";
    if (@report_rows) {
        $report .= join( "\n", @report_rows ) . "\n";
    }
    else {
        $report .= "No spelling problems found.\n";
    }

    $spelling_report_file =
      make_tmp_file_in_tmp( ".spelling-report.txt", $report );
    logi("Temporary spelling report written to: $spelling_report_file");
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

    # Non-zero means warnings/errors.
    # Treat as validation failure.
    my ( $rc, $out, $err ) =
      run_capture( $tidy, @tidy_common, "-errors", $file );
    if ( $rc != 0 ) {
        loge( "tidy validation failed" . " (exit $rc): $file" );
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

            # Even in apply, a non-zero indicates
            # issues (warnings/errors)
            loge( "tidy formatting reported" . " issues (exit $rc): $file" );
            mark_validate_failed($file);
        }
        return;
    }

    # --check: compare formatted output with file contents
    my ( $rc, $out, $err ) = run_capture( $tidy, @tidy_common, $file );

    if ( $rc != 0 ) {
        loge( "tidy formatting/parse reported" . " issues (exit $rc): $file" );
        mark_validate_failed($file);

        # Still attempt to mark formatting difference
        # if we got output (but don't trust empty output).
    }

    my $before = read_all($file);
    if (   defined($before)
        && defined($out)
        && $out ne ""
        && $out ne $before )
    {
        mark_format_needed($file);
    }
}

sub xmllint_validate_one {
    my ( $file, $label ) = @_;
    my $ok = run_cmd( $xmllint, "--noout", "--nonet", $file );
    if ( !$ok ) {
        loge( "$label validation failed" . " (xmllint): $file" );
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
        loge( "$label formatting failed" . " (xmllint): $file" );
        mark_validate_failed($file);
        return;
    }

    if ($mode_apply) {
        if ( $out ne $before ) {
            write_all( $file, $out ) or do {
                loge( "Failed to write formatted" . " $label file: $file" );
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

            # Use run_cmd so dprint writes files
            # in-place and inherits stdout/stderr
            my @cmd = ( $dprint, "fmt", "--config", $dprint_cfg, @$chunk );
            print "[cmd] @cmd\n" if $verbose;
            my $ok = run_cmd(@cmd);

            # run_cmd returns true on success
            if ( !$ok ) {
                loge(   "dprint formatting/parse"
                      . " failed for some files"
                      . " in chunk." );
                mark_validate_failed($_)
                  for @$chunk;
            }
        }
        return;
    }

    logi(
        "Checking CSS/JS formatting and" . " validity with dprint (check)..." );
    for my $chunk ( chunked( $files_ref, 120 ) ) {

        my ( $rc, $out, $err ) =
          run_capture( $dprint, "check", "--config", $dprint_cfg,
            "--list-different", @$chunk );

        # If plugin download/resolution fails,
        # skip dprint checks for this run.
        if ( defined($err)
            && $err =~ /Error (downloading|resolving) plugin/i )
        {
            logw(   "dprint plugin download/resolution"
                  . " failed; skipping dprint"
                  . " check in this run." );
            print STDERR $err if $verbose;
            return;
        }

        if ( $rc == 0 ) {
            next;    # formatted + parsed OK
        }

        # When not formatted, dprint often lists
        # file paths (stdout).
        my $any_listed = 0;
        for my $line ( split /\n/, ( $out // "" ) ) {
            $line =~ s/\r$//;
            next unless length $line;
            $any_listed = 1;
            mark_format_needed($line);
        }

        # If no list, conservatively mark the chunk
        # as either "format needed" or
        # "validation failed".
        if ( !$any_listed ) {
            mark_format_needed($_) for @$chunk;
        }

        # If stderr has content, treat as validation
        # failure (parse/plugin/config errors).
        if ( defined($err) && $err =~ /\S/ ) {
            loge(   "dprint reported errors while"
                  . " checking (see stderr with"
                  . " --verbose)." );
            mark_validate_failed($_) for @$chunk;
            print STDERR $err if $verbose;
        }
    }
}

sub run_validations {
    if (@html) {
        logi(
            (
                $mode_apply
                ? "Formatting"
                : "Checking formatting of"
            )
            . " HTML with tidy..."
        );
        tidy_format_or_check_one($_) for @html;

        logi( "Validating HTML with tidy" . " (as supported)..." );
        tidy_validate_one($_) for @html;
    }

    if (@xml) {
        logi(
            (
                $mode_apply
                ? "Formatting"
                : "Checking formatting of"
            )
            . " XML with xmllint..."
        );
        xmllint_format_or_check_one( $_, "XML" )
          for @xml;

        logi( "Validating XML well-formedness" . " with xmllint..." );
        xmllint_validate_one( $_, "XML" ) for @xml;
    }

    if (@svg) {
        logi(
            (
                $mode_apply
                ? "Formatting"
                : "Checking formatting of"
            )
            . " SVG with xmllint..."
        );
        xmllint_format_or_check_one( $_, "SVG" )
          for @svg;

        logi( "Validating SVG well-formedness" . " with xmllint..." );
        xmllint_validate_one( $_, "SVG" ) for @svg;
    }

    if ( @css || @js || @json ) {
        if ($is_openbsd) {
            logw(
                "OpenBSD: skipping dprint for" . " CSS/JS/JSON (not ported)" );
        }
        else {
            my @pfiles = ( @css, @js, @json );
            dprint_validate_and_check_or_apply( \@pfiles );
        }
    }

    if (@json) {
        logi(
            (
                $mode_apply
                ? "Formatting"
                : "Checking formatting of"
            )
            . " JSON with jq..."
        );
        for my $f (@json) {
            my $before = read_all($f);
            if ( !defined $before ) {
                loge("Could not read JSON file: $f");
                mark_validate_failed($f);
                next;
            }

            my ( $rc, $out, $err ) = run_capture( 'jq', '.', $f );
            if ( $rc != 0 ) {
                loge( "jq validation/parse failed" . " (exit $rc): $f" );
                mark_validate_failed($f);
                print STDERR $err if $verbose;
                next;
            }

            if ($mode_apply) {
                if ( $out ne $before ) {
                    write_all( $f, $out ) or do {
                        loge(   "Failed to write"
                              . " formatted JSON"
                              . " file: $f" );
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
}

sub summarize_and_exit {
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
        ? "Done. Formatting applied and" . " validation passed."
        : "Done. Formatting clean and" . " validation passed."
    );
    if ( $check_links && $link_report_file ne "" ) {
        logi("Link report: $link_report_file");
    }
    if ( $check_spelling && $spelling_report_file ne "" ) {
        logi("Spelling report: $spelling_report_file");
    }

    exit 0;
}

sub main {
    run_validations();
    run_link_checks() if $check_links;
    run_spelling_checks() if $check_spelling;
    summarize_and_exit();
}

main();
