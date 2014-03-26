use v5.10;
use strict;
use warnings;

package Dist::Zilla::Plugin::BumpVersionAfterRelease;
# ABSTRACT: Bump module versions after distribution release

our $VERSION = '0.001';

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

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    # in your code, declare $VERSION like this:
    package Foo;
    our $VERSION = '1.23';

    # in your dist.ini
    [BumpVersionAfterRelease]

=head1 DESCRIPTION

This module overwrites an existing C<our $VERSION = '1.23'> declaration in your
original source code after a release with the next version number after the
released version as determined by L<Version::Next>.  Only the B<first>
occurrence is affected and it must exactly match this regular expression:

    qr{^our \s+ \$VERSION \s* = \s* '$version::LAX'}mx

This is intended to let you keep a version number in your source files that
will be the default version for the next release using
L<Dist::Zilla::Plugin::VersionFromModule>.

The very restrictive regular expression format is intentional to avoid
the various ways finding a version assignment could go wrong and to avoid
using L<PPI>, which has similar complexity issues.

For most modules, this should work just fine.

XXX discuss commit after build, etc.

=cut

# vim: ts=4 sts=4 sw=4 et:
