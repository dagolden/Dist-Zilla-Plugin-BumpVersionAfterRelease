use 5.008001;
use strict;
use warnings;

package Dist::Zilla::Plugin::BumpVersionAfterRelease;
# ABSTRACT: Bump module versions after distribution release

our $VERSION = '0.010';

use Moose;
with(
    'Dist::Zilla::Role::AfterRelease' => { -version => 5 },
    'Dist::Zilla::Role::FileFinderUser' =>
      { default_finders => [ ':InstallModules', ':ExecFiles' ], },
);

use namespace::autoclean;
use version ();

=attr global

If true, all occurrences of the version pattern will be replaced.  Otherwise,
only the first occurrence is replaced.  Defaults to false.

=cut

has global => (
    is  => 'ro',
    isa => 'Bool',
);

=attr munge_makefile_pl

If there is a F<Makefile.PL> in the root of the repository, its version will be
set as well.  Defaults to true.

=cut

has munge_makefile_pl => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

has _next_version => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build__next_version',
);

sub _build__next_version {
    my ($self) = @_;
    require Version::Next;
    my $version = $self->zilla->version;
    $self->log_fatal("$version is not a valid version string")
      unless version::is_lax($version);
    return Version::Next::next_version($version);
}

sub after_release {
    my ($self) = @_;
    $self->munge_file($_) for @{ $self->found_files };
    $self->rewrite_makefile_pl if -f "Makefile.PL" && $self->munge_makefile_pl;
    return;
}

sub munge_file {
    my ( $self, $file ) = @_;

    return if $file->is_bytes;

    if ( $file->name =~ m/\.pod$/ ) {
        $self->log_debug( [ 'Skipping: "%s" is pod only', $file->name ] );
        return;
    }

    if ( !-r $file->name ) {
        $self->log_debug( [ 'Skipping: "%s" not found in source', $file->name ] );
        return;
    }

    if ( $self->rewrite_version( $file, $self->_next_version ) ) {
        $self->log_debug( [ 'bumped $VERSION in %s', $file->name ] );
    }
    else {
        $self->log( [ q[Skipping: no "our $VERSION = '...'" found in "%s"], $file->name ] );
    }
    return;
}

my $assign_regex = qr{
    our \s+ \$VERSION \s* = \s* (['"])$version::LAX\1 \s* ;
}x;

sub rewrite_version {
    my ( $self, $file, $version ) = @_;

    require Path::Tiny;
    Path::Tiny->VERSION(0.061);

    my $iolayer = sprintf( ":raw:encoding(%s)", $file->encoding );

    # read source file
    my $content = Path::Tiny::path( $file->_original_name )->slurp( { binmode => $iolayer } );

    my $code = "our \$VERSION = '$version';";

    if (
        $self->global
        ? ( $content =~ s{^$assign_regex[^\n]*$}{$code}msg )
        : ( $content =~ s{^$assign_regex[^\n]*$}{$code}ms )
      )
    {
        # append+truncate to preserve file mode
        Path::Tiny::path( $file->name )
          ->append( { binmode => $iolayer, truncate => 1 }, $content );
        return 1;
    }

    return;
}

sub rewrite_makefile_pl {
    my ($self) = @_;

    my $next_version = $self->_next_version;

    require Path::Tiny;
    Path::Tiny->VERSION(0.061);

    my $path = Path::Tiny::path("Makefile.PL");

    my $content = $path->slurp_utf8;

    if ( $content =~ s{"VERSION" => "[^"]+"}{"VERSION" => "$next_version"}ms ) {
        $path->append_utf8( { truncate => 1 }, $content );
        return 1;
    }

    return;
}

1;

=for Pod::Coverage after_release munge_file rewrite_makefile_pl rewrite_version

=head1 SYNOPSIS

In your code, declare C<$VERSION> like this:

    package Foo;
    our $VERSION = '1.23';

In your F<dist.ini>:

    [RewriteVersion]

    [BumpVersionAfterRelease]

=head1 DESCRIPTION

After a release, this module modifies your original source code to replace an
existing C<our $VERSION = '1.23'> declaration with the next number after the
released version as determined by L<Version::Next>.  Only the B<first>
occurrence is affected (unless you set the L</global> attribute) and it must
exactly match this regular expression:

    qr{^our \s+ \$VERSION \s* = \s* '$version::LAX'}mx

It must be at the start of a line and any trailing comments are deleted.  The
original may have double-quotes, but the re-written line will have single
quotes.

The very restrictive regular expression format is intentional to avoid
the various ways finding a version assignment could go wrong and to avoid
using L<PPI>, which has similar complexity issues.

For most modules, this should work just fine.

=head1 USAGE

This L<Dist::Zilla> plugin, along with
L<RewriteVersion|Dist::Zilla::Plugin::RewriteVersion> let you leave a
C<$VERSION> declaration in the code files in your repository but still let
Dist::Zilla provide automated version management.

First, you include a very specific C<$VERSION> declaration in your code:

    our $VERSION = '0.001';

It must be on a line by itself and should be the same in all your files.
(If it is not, it will be overwritten anyway.)

L<RewriteVersion|Dist::Zilla::Plugin::RewriteVersion> is a version provider
plugin, so the version line from your main module will be used as the version
for your release.

If you override the version with the C<V> environment variable,
then L<RewriteVersion|Dist::Zilla::Plugin::RewriteVersion> will overwrite the
C<$VERSION> declaration in the gathered files.

    V=1.000 dzil release

Finally, after a successful release, this module
L<BumpVersionAfterRelease|Dist::Zilla::Plugin::BumpVersionAfterRelease> will
overwrite the C<$VERSION> declaration in your B<source> files to be the B<next>
version after the one you just released.  That version will then be the default
one that will be used for the next release.

You can configure which files have their C<$VERSION> declarations modified,
with the C<finder> option. The default finders are C<:InstallModules> and
C<:ExecFiles>; other predefined finders are listed in
L<Dist::Zilla::Role::FileFinderUser/default_finders>.

If you tag/commit after a release, you may want to tag and commit B<before>
the source files are modified.  Here is a sample C<dist.ini> that shows
how you might do that.

    name    = Foo-Bar
    author  = David Golden <dagolden@cpan.org>
    license = Apache_2_0
    copyright_holder = David Golden
    copyright_year   = 2014

    [@Basic]

    [RewriteVersion]

    ; commit source files as of "dzil release" with any
    ; allowable modifications (e.g Changes)
    [Git::Commit / Commit_Dirty_Files] ; commit files/Changes (as released)

    ; tag as of "dzil release"
    [Git::Tag]

    ; update Changes with timestamp of release
    [NextRelease]

    [BumpVersionAfterRelease]

    ; commit source files after modification
    [Git::Commit / Commit_Changes] ; commit Changes (for new dev)
    allow_dirty_match = ^lib/
    commit_msg = Commit Changes and bump $VERSION

=head1 SEE ALSO

Here are some other plugins for managing C<$VERSION> in your distribution:

=for :list
* L<Dist::Zilla::Plugin::PkgVersion>
* L<Dist::Zilla::Plugin::OurPkgVersion>
* L<Dist::Zilla::Plugin::OverridePkgVersion>
* L<Dist::Zilla::Plugin::SurgicalPkgVersion>
* L<Dist::Zilla::Plugin::PkgVersionIfModuleWithPod>
* L<Dist::Zilla::Plugin::RewriteVersion::Transitional>

=cut

# vim: ts=4 sts=4 sw=4 et:
