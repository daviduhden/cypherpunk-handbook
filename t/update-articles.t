#!/usr/bin/perl
# Regression tests for scripts/update-articles.pl (cypherpunk-handbook).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use TestSite qw(fixture run_input slurp);
use File::Spec;

my $INDEX = <<'HTML';
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Index</title>
</head>
<body>
  <main>
    <section id="operating-systems" class="article-column">
      <h3>Operating systems</h3>

      <section id="openbsd">
        <h4>OpenBSD</h4>

        <ul class="article-list">
          <li>
            <a href="./articles/openbsd.html">Why OpenBSD stands alone</a>
          </li>
        </ul>
      </section>
    </section>
  </main>
</body>
</html>
HTML

sub run_update {
    my ( $dir, $input ) = @_;
    my $script = File::Spec->catfile( $dir, 'scripts', 'update-articles.pl' );
    return run_input( $input, $^X, $script );
}

# --- inserts a link into the requested subsection -------------------
{
    my $dir = fixture( 'index.html' => $INDEX );
    my $r   = run_update(
        $dir,
        "operating-systems/openbsd\nNew Article Title\nnew-article\n"
    );
    is( $r->{status}, 0, 'insert succeeds' ) or diag( $r->{stderr} );
    my $html = slurp("$dir/index.html");
    like( $html, qr{<a href="\./articles/new-article\.html">New Article Title</a>},
        'link inserted with escaped title' );
    like( $html, qr{Why OpenBSD stands alone}, 'existing entry preserved' );
    like( $html, qr{^\s{2}<title>Index</title>}m, 'document still well-formed' );
}

# --- duplicate insert is refused ------------------------------------
{
    my $dir = fixture( 'index.html' => $INDEX );
    run_update( $dir, "operating-systems/openbsd\nT\nslug\n" );
    my $before = slurp("$dir/index.html");
    my $r = run_update( $dir, "operating-systems/openbsd\nT\nslug\n" );
    is( $r->{status}, 0, 'duplicate returns success without change' );
    like( $r->{stderr}, qr/already exists/, 'duplicate reported' );
    is( slurp("$dir/index.html"), $before, 'index unchanged on duplicate' );
}

# --- title is HTML-escaped ------------------------------------------
{
    my $dir = fixture( 'index.html' => $INDEX );
    run_update( $dir, "operating-systems/openbsd\nA & B <c>\nescaped\n" );
    my $html = slurp("$dir/index.html");
    like( $html, qr{A &amp; B &lt;c&gt;}, 'title escaped' );
    unlike( $html, qr{<c>}, 'no raw tag injected' );
}

# --- invalid slug rejected ------------------------------------------
{
    my $dir = fixture( 'index.html' => $INDEX );
    my $r = run_update( $dir, "operating-systems/openbsd\nT\n../evil\n" );
    isnt( $r->{status}, 0, 'invalid slug rejected' );
    like( $r->{stderr}, qr/may only contain letters/, 'message' );
}

# --- invalid subsection format rejected -----------------------------
{
    my $dir = fixture( 'index.html' => $INDEX );
    my $r = run_update( $dir, "just-a-section\n" );
    isnt( $r->{status}, 0, 'subsection must be section/subsection' );
    like( $r->{stderr}, qr/Subsection must be/, 'message' );
}

# --- unknown subsection fails cleanly -------------------------------
{
    my $dir = fixture( 'index.html' => $INDEX );
    my $r = run_update( $dir, "nope/nope\nT\nslug\n" );
    isnt( $r->{status}, 0, 'unknown subsection fails' );
    like( $r->{stderr}, qr/Could not locate subsection/, 'message' );
}

# --- repeated runs on distinct slugs are deterministic --------------
{
    my $dir = fixture( 'index.html' => $INDEX );
    run_update( $dir, "operating-systems/openbsd\nFirst\nfirst\n" );
    my $once = slurp("$dir/index.html");
    unlink "$dir/index.html";
    TestSite::spew( "$dir/index.html", $INDEX );
    run_update( $dir, "operating-systems/openbsd\nFirst\nfirst\n" );
    is( slurp("$dir/index.html"), $once, 'same input gives same output' );
}

done_testing();
