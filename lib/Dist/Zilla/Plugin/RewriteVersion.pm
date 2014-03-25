use 5.008001;
use strict;
use warnings;

package Dist::Zilla::Plugin::RewriteVersion;
# ABSTRACT: Rewrite version declarations to match the distribution version

our $VERSION = '0.001';

use Moose;
with(
    'Dist::Zilla::Role::FileMunger' => { -version => 5 },
    'Dist::Zilla::Role::FileFinderUser' =>
      { default_finders => [ ':InstallModules', ':ExecFiles' ], },
);

use namespace::autoclean;
use version ();

sub munge_files {
    my $self = shift;
    $self->munge_file($_) for @{ $self->found_files };
    return;
}

sub munge_file {
    my ( $self, $file ) = @_;

    return if $file->is_bytes;

    if ( $file->name =~ m/\.pod$/ ) {
        $self->log_debug( [ 'Skipping: "%s" is pod only', $file->name ] );
        return;
    }

    my $version = $self->zilla->version;

    $self->log_fatal("$version is not a valid version string")
      unless version::is_lax($version);

    if ( $self->rewrite_version( $file, $version ) ) {
        $self->log_debug( [ 'adding $VERSION assignment to %s', $file->name ] );
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

    my $content = $file->content;

    my $comment = $self->zilla->is_trial ? ' # TRIAL' : '';
    my $code = "our \$VERSION = '$version';$comment";

    if ( $content =~ s{^$assign_regex[^\n]*$}{$code}ms ) {
        $file->content($content);
        return 1;
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    # in your code, declare $VERSION like this:
    package Foo;
    our $VERSION = '1.23';

    # in your dist.ini
    [RewriteVersion]

=head1 DESCRIPTION

This module overwrites an existing C<our $VERSION = '1.23'> declaration in
your code.  Only the B<first> occurance is affected and it must exactly
match this regular expression:

    qr{^our \s+ \$VERSION \s* = \s* '$version::LAX'}mx

This is intended to let you leave a C<$VERSION> in your module files in the
repository, but replacing the C<$VERSION> with the distribution release
version when you build/release with C<Dist::Zilla>.

The very restrictive regular expression format is intentional to avoid
the various ways finding a version assignment could go wrong and to avoid
using L<PPI>, which has similar complexity issues.

For most modules, this should work just fine.

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::Plugin::PkgVersion>
* L<Dist::Zilla::Plugin::OurPkgVersion>
* L<Dist::Zilla::Plugin::OverridePkgVersion>

=cut

# vim: ts=4 sts=4 sw=4 et:
