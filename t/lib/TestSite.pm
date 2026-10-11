package TestSite;

# Minimal, dependency-free helpers shared by the repository's t/*.t
# tests. It deliberately uses only core modules so it runs with the
# same interpreter as the site scripts on OpenBSD and Debian.

use strict;
use warnings;

use File::Basename qw(dirname);
use File::Copy     qw(copy);
use File::Path     qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use IO::Select;
use IPC::Open3 qw(open3);
use Symbol     qw(gensym);

use Exporter 'import';
our @EXPORT_OK =
  qw(repo_root fixture run run_input slurp spew script clone_repo);

# Repository root derived from this file: <root>/t/lib/TestSite.pm
sub repo_root {
    my $here = dirname(__FILE__);    # <root>/t/lib
    return File::Spec->rel2abs( File::Spec->catdir( $here, '..', '..' ) );
}

sub script {
    my ($name) = @_;
    return File::Spec->catfile( repo_root(), 'scripts', $name );
}

sub slurp {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "slurp $path: $!";
    local $/;
    my $c = <$fh>;
    close $fh;
    return $c;
}

sub spew {
    my ( $path, $content ) = @_;
    utf8::encode($content) if utf8::is_utf8($content);
    open my $fh, '>:raw', $path or die "spew $path: $!";
    print {$fh} $content;
    close $fh or die "spew close $path: $!";
    return 1;
}

# Create an isolated temporary repository that contains a copy of the
# real scripts (so that $0-relative root detection points at the
# fixture) plus the supplied fixture files.
sub fixture {
    my (%files) = @_;
    my $dir = tempdir( CLEANUP => 1 );
    make_path("$dir/scripts");

    my $sdir = File::Spec->catdir( repo_root(), 'scripts' );
    opendir my $dh, $sdir or die "opendir $sdir: $!";
    for my $f ( readdir $dh ) {
        next unless $f =~ /\.(?:pl|sh)$/;
        my $src = File::Spec->catfile( $sdir, $f );
        next unless -f $src;
        copy( $src, "$dir/scripts/$f" ) or die "copy $f: $!";
        chmod 0755, "$dir/scripts/$f";
    }
    closedir $dh;

    for my $rel ( sort keys %files ) {
        my $p = "$dir/$rel";
        make_path( dirname($p) );
        spew( $p, $files{$rel} );
    }
    return $dir;
}

sub _run {
    my ( $input, $cmd, $args ) = @_;

    my $wtr = gensym;
    my $rdr = gensym;
    my $err = gensym;
    my $pid = open3( $wtr, $rdr, $err, $cmd, @$args );

    if ( defined $input ) {
        print {$wtr} $input;
    }
    close $wtr;

    my $sel   = IO::Select->new( $rdr, $err );
    my %which = ( fileno($rdr) => 'out', fileno($err) => 'err' );
    my ( $out, $er ) = ( '', '' );
    while ( my @ready = $sel->can_read ) {
        for my $fh (@ready) {
            my $buf = '';
            my $n   = sysread( $fh, $buf, 65536 );
            if ( !defined $n || $n == 0 ) {
                $sel->remove($fh);
                next;
            }
            if ( $which{ fileno($fh) } eq 'out' ) {
                $out .= $buf;
            }
            else {
                $er .= $buf;
            }
        }
    }

    waitpid( $pid, 0 );
    my $raw = $?;
    return {
        status => ( $raw >> 8 ),
        signal => ( $raw & 127 ),
        stdout => $out,
        stderr => $er,
    };
}

sub run {
    my ( $cmd, @args ) = @_;
    return _run( undef, $cmd, \@args );
}

sub run_input {
    my ( $input, $cmd, @args ) = @_;
    return _run( $input, $cmd, \@args );
}

# Copy the repository into an isolated temporary directory, preserving
# permissions and skipping heavy/irrelevant trees. Used to verify that
# the committed generated files match a fresh run of the generators.
sub clone_repo {
    my (@skip) = @_;
    my %skip =
      map { $_ => 1 } ( @skip ? @skip : qw(.git archive files images t) );

    my $src = repo_root();
    my $dst = tempdir( CLEANUP => 1 );

    my @dirs = ('');
    while ( defined( my $rel = shift @dirs ) ) {
        my $sdir =
            $rel eq ''
          ? $src
          : File::Spec->catdir( $src, split m{/}, $rel );
        opendir my $dh, $sdir or next;
        my @entries = readdir $dh;
        closedir $dh;
        for my $e (@entries) {
            next if $e eq '.' || $e eq '..';
            my $r = $rel eq '' ? $e : "$rel/$e";
            next if $skip{$r} || $skip{$e};
            my $s = File::Spec->catfile( $src, split m{/}, $r );
            my $d = File::Spec->catfile( $dst, split m{/}, $r );
            if ( -d $s ) {
                make_path($d);
                push @dirs, $r;
            }
            elsif ( -f $s ) {
                make_path( dirname($d) );
                copy( $s, $d ) or die "copy $r: $!";
                my $mode = ( stat $s )[2] & 07777;
                chmod $mode, $d;
            }
        }
    }
    return $dst;
}

1;
