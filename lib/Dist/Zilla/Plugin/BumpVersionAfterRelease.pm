use 5.008001;
use strict;
use warnings;

package Dist::Zilla::Plugin::BumpVersionAfterRelease;
# ABSTRACT: Bump module versions after distribution release
# VERSION

use Moose;
with(
    'Dist::Zilla::Role::AfterRelease' => { -version => 5 },
    'Dist::Zilla::Role::FileFinderUser' =>
      { default_finders => [ ':InstallModules', ':ExecFiles' ], },
);

use namespace::autoclean;
use version ();

sub after_release {
    my ($self) = @_;
    $self->munge_file($_) for @{ $self->found_files };
    return;
}

sub munge_file {
    my ( $self, $file ) = @_;

    require Version::Next;

    return if $file->is_bytes;

    if ( $file->name =~ m/\.pod$/ ) {
        $self->log_debug( [ 'Skipping: "%s" is pod only', $file->name ] );
        return;
    }

    if ( !-r $file->name ) {
        $self->log_debug( [ 'Skipping: "%s" not found in source', $file->name ] );
        return;
    }

    my $version = $self->zilla->version;

    $self->log_fatal("$version is not a valid version string")
      unless version::is_lax($version);

    if ( $self->rewrite_version( $file, Version::Next::next_version($version) ) ) {
        $self->log_debug( [ 'bumped $VERSION in %s', $file->name ] );
    }
    else {
        $self->log( [ q[Skipping: no "our $VERSION = '...'" found in "%s"], $file->name ] );
    }
    return;
}

my $assign_regex = qr{
    our \s+ \$VERSION \s* = \s* '$version::LAX' \s* ;
}x;

sub rewrite_version {
    my ( $self, $file, $version ) = @_;

    require Path::Tiny;

    my $iolayer = sprintf( ":raw:encoding(%s)", $file->encoding );

    # read source file
    my $content = Path::Tiny::path( $file->name )->slurp( { binmode => $iolayer } );

    my $comment = $self->zilla->is_trial ? ' # TRIAL' : '';
    my $code = "our \$VERSION = '$version';$comment";

    if ( $content =~ s{^$assign_regex[^\n]*$}{$code}ms ) {
        Path::Tiny::path( $file->name )->spew( { binmode => $iolayer }, $content );
        return 1;
    }

    return;
}

1;

=for Pod::Coverage after_release munge_file rewrite_version

=head1 SYNOPSIS

In your code, declare C<$VERSION> like this:

    package Foo;
    our $VERSION = '1.23';

In your F<dist.ini>:

    [VersionFromModule]

    [RewriteVersion]

    [BumpVersionAfterRelease]

=head1 DESCRIPTION

After a release, this module modifies your original source code to replace an
existing C<our $VERSION = '1.23'> declaration with the next number after the
released version as determined by L<Version::Next>.  Only the B<first>
occurrence is affected and it must exactly match this regular expression:

    qr{^our \s+ \$VERSION \s* = \s* '$version::LAX'}mx

It must be at the start of a line and any trailing comments are deleted.

The very restrictive regular expression format is intentional to avoid
the various ways finding a version assignment could go wrong and to avoid
using L<PPI>, which has similar complexity issues.

For most modules, this should work just fine.

=head1 USAGE

This L<Dist::Zilla> plugin, along with
L<RewriteVersion|Dist::Zilla::Plugin::RewriteVersion>, and
L<VersionFromModule|Dist::Zilla::Plugin::VersionFromModule> let you leave a
C<$VERSION> declaration in the code files in your repository but still let
Dist::Zilla provide automated version management.

First, you include a very specific C<$VERSION> declaration in your code:

    our $VERSION = '0.001';

It must be on a line by itself and should be the same in all your files.
(If it is not, it will be overwritten anyway.)

Using L<VersionFromModule|Dist::Zilla::Plugin::VersionFromModule> the version
line from your main module will be used as the version for your release.

If you override the version — e.g. C<V=1.000 dzil build> — then
L<RewriteVersion|Dist::Zilla::Plugin::RewriteVersion> will overwrite the
C<$VERSION> declaration in the gathered files.

Finally, after a successful release, this module
L<BumpVersionAfterRelease|Dist::Zilla::Plugin::BumpVersionAfterRelease> will
overwrite the C<$VERSION> declaration in your B<source> files to be the B<next>
version after the one you just released.  That version will then be the default
one that will be used for the next release.

If you tag/commit after a release, you may want to tag and commit B<before>
the source files are modified.  Here is a sample C<dist.ini> that shows
how you might do that.

    name    = Foo-Bar
    author  = David Golden <dagolden@cpan.org>
    license = Apache_2_0
    copyright_holder = David Golden
    copyright_year   = 2014

    [@Basic]

    [VersionFromModule]

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


=head1 SEE ALSO

Here are some other plugins for managing C<$VERSION> in your distribution:

=for :list
* L<Dist::Zilla::Plugin::PkgVersion>
* L<Dist::Zilla::Plugin::OurPkgVersion>
* L<Dist::Zilla::Plugin::OverridePkgVersion>
* L<Dist::Zilla::Plugin::SurgicalPkgVersion>
* L<Dist::Zilla::Plugin::PkgVersionIfModuleWithPod>

=cut

# vim: ts=4 sts=4 sw=4 et:
