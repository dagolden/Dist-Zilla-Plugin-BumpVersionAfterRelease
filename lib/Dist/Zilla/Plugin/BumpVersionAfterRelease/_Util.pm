use 5.008001;
use strict;
use warnings;

package Dist::Zilla::Plugin::BumpVersionAfterRelease::_Util;

our $VERSION = '0.019';

use Moose::Role;

requires qw(
  allow_decimal_underscore
  allow_leading_whitespace
);

# version regexes from version.pm
my $FRACTION_PART              = qr/\.[0-9]+/;
my $STRICT_INTEGER_PART        = qr/0|[1-9][0-9]*/;
my $LAX_INTEGER_PART           = qr/[0-9]+/;
my $STRICT_DOTTED_DECIMAL_PART = qr/\.[0-9]{1,3}/;
my $LAX_DOTTED_DECIMAL_PART    = qr/\.[0-9]+/;
my $LAX_ALPHA_PART             = qr/_[0-9]+/;
my $STRICT_DECIMAL_VERSION     = qr/ $STRICT_INTEGER_PART $FRACTION_PART? /x;
my $STRICT_DOTTED_DECIMAL_VERSION =
  qr/ v $STRICT_INTEGER_PART $STRICT_DOTTED_DECIMAL_PART{2,} /x;
my $STRICT = qr/ $STRICT_DECIMAL_VERSION | $STRICT_DOTTED_DECIMAL_VERSION /x;
my $LAX_DECIMAL_VERSION =
  qr/ $LAX_INTEGER_PART (?: \. | $FRACTION_PART $LAX_ALPHA_PART? )?
    |
    $FRACTION_PART $LAX_ALPHA_PART?
    /x;
my $LAX_DOTTED_DECIMAL_VERSION = qr/
    v $LAX_INTEGER_PART (?: $LAX_DOTTED_DECIMAL_PART+ $LAX_ALPHA_PART? )?
    |
    $LAX_INTEGER_PART? $LAX_DOTTED_DECIMAL_PART{2,} $LAX_ALPHA_PART?
    /x;

sub is_strict_version { defined $_[0] && $_[0] =~ qr/\A $STRICT \z /x }

sub is_loose_version {
    defined $_[0] && $_[0] =~ qr/\A (?: $STRICT | $LAX_DECIMAL_VERSION ) \z /x;
}

sub is_tuple_alpha {
    my $v = shift;
    return unless defined $v;
    return unless $v =~ $LAX_DOTTED_DECIMAL_VERSION;
    return $v =~ m{$LAX_ALPHA_PART\z};
}

# Because this is used for *capturing* or *replacing*, we take anything
# that is a lax version (but not literal string 'undef', so we don't want
# version::LAX).  Later anything captured needs to be checked with the
# strict or loose version check functions.
# $1 is optional leading whitespace
# $2 is the quote mark (' or ") around the version number
# $3 is the version number
sub assign_re {
    my ($self) = @_;
    my $maybe_leading_whitespace = $self->allow_leading_whitespace ? qr/(\s*)/ : qr/()/;
    return qr{
        $maybe_leading_whitespace
        our \s+ \$VERSION \s* = \s*
        (['"])($LAX_DECIMAL_VERSION | $LAX_DOTTED_DECIMAL_VERSION)\2 \s* ;
        (?:\s* \# \s TRIAL)? [^\n]*
        (?:\n \$VERSION \s = \s eval \s \$VERSION;)?
        (?:\n \$VERSION \s =~ \s tr/_//d;)?
        (?:\n \$VERSION \s =~ \s s/_//g;)?
    }x;
}

sub matching_re {
    my ( $self, $release_version ) = @_;
    my $maybe_leading_whitespace = $self->allow_leading_whitespace ? qr/(\s*)/ : qr/()/;
    return qr{
        $maybe_leading_whitespace
        our \s+ \$VERSION \s* = \s*
        (['"])(\Q$release_version\E)\2 \s* ;
        (?:\s* \# \s TRIAL)? [^\n]*
        (?:\n \$VERSION \s = \s eval \s \$VERSION;)?
        (?:\n \$VERSION \s =~ \s tr/_//d;)?
        (?:\n \$VERSION \s =~ \s s/_//g;)?
    }x;
}

sub check_valid_version {
    my ( $self, $version ) = @_;

    $self->log_fatal("version tuples with alpha elements are not supported")
      if is_tuple_alpha($version);

    $self->log_fatal(
        "$version is not an allowed version string (maybe you need 'allow_decimal_underscore')"
      )
      unless $self->allow_decimal_underscore
      ? is_loose_version($version)
      : is_strict_version($version);
}

1;

=for Pod::Coverage is_strict_version is_loose_version assign_re
is_tuple_alpha check_valid_version matching_re

=cut

# vim: set ts=4 sts=4 sw=4 et tw=75:
