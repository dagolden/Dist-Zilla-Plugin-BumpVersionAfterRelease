
use strict;
use warnings;

use Test::More;
use Test::DZil;
use Test::Fatal;
use Path::Tiny;

delete $ENV{RELEASE_STATUS};
delete $ENV{TRIAL};
delete $ENV{V};

subtest "without allow_leading_whitespace" => sub {
    my $tzil = Builder->from_config(
        { dist_root => 'does-not-exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => dist_ini(
                    { # configs as in simple_ini, but no version assignment
                        name             => 'DZT-Sample',
                        abstract         => 'Sample DZ Dist',
                        author           => 'E. Xavier Ample <example@example.org>',
                        license          => 'Perl_5',
                        copyright_holder => 'E. Xavier Ample',
                    },
                    [ GatherDir               => ],
                    [ MetaConfig              => ],
                    [ RewriteVersion          => ],
                    [ FakeRelease             => ],
                    [ BumpVersionAfterRelease => ],
                ),
                path(qw(source lib Foo.pm)) => "package Foo;\n\n    our \$VERSION = '0.004';\n\n1;\n",
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);
    like(
        exception { $tzil->release },
        qr/no version was ever set/,
        'Indented versions are not detected if allow_leading_whitespace is not checked',
    );
};

subtest "with allow_leading_whitespace" => sub {
    $ENV{v} = '0.005';
    my $tzil = Builder->from_config(
        { dist_root => 'does-not-exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => dist_ini(
                    { # configs as in simple_ini, but no version assignment
                        name             => 'DZT-Sample',
                        abstract         => 'Sample DZ Dist',
                        author           => 'E. Xavier Ample <example@example.org>',
                        license          => 'Perl_5',
                        copyright_holder => 'E. Xavier Ample',
                    },
                    [ GatherDir               => ],
                    [ MetaConfig              => ],
                    [ RewriteVersion          => { allow_leading_whitespace => 1 } ],
                    [ FakeRelease             => ],
                    [ BumpVersionAfterRelease => { allow_leading_whitespace => 1 } ],
                ),
                path(qw(source lib NoWhiteSpace.pm)) =>
                  "package Foo;\n\nour \$VERSION = '0.004';\n1;\n",
                path(qw(source lib Foo.pm)) =>
                  "package Foo;\n\n    our \$VERSION = '0.004';\n1;\n",
                path(qw(source lib PostFixBlock.pm)) =>
                  "package Foo {\n\n    our \$VERSION = '0.004';\n\n}\n1;\n",
                path(qw(source lib Tabs.pm)) =>

                  "package Foo;\n\n\t\tour \$VERSION = '0.004';\n1;\n",
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);
    is( exception { $tzil->release }, undef, 'build and release proceeds normally', );

    is( $tzil->version, '0.004', 'version was properly extracted from .pm file', );

    is(
        path( $tzil->tempdir, qw(build lib NoWhiteSpace.pm) )->slurp_utf8,
        "package Foo;\n\nour \$VERSION = '0.004';\n1;\n",
        'allow_leading_whitespace does not force leading whitespace',
    );

    is(
        path( $tzil->tempdir, qw(build lib Foo.pm) )->slurp_utf8,
        "package Foo;\n\n    our \$VERSION = '0.004';\n1;\n",
        'Leading spaces are preserved',
    );

    is(
        path( $tzil->tempdir, qw(build lib PostFixBlock.pm) )->slurp_utf8,
        "package Foo {\n\n    our \$VERSION = '0.004';\n\n}\n1;\n",
        'Leading spaces are preserved with a postfix package block',
    );

    is(
        path( $tzil->tempdir, qw(build lib Tabs.pm) )->slurp_utf8,

        "package Foo;\n\n\t\tour \$VERSION = '0.004';\n1;\n",
        'Leading tabs are preserved',
    );

    is(
        path( $tzil->tempdir, qw(source lib NoWhiteSpace.pm) )->slurp_utf8,
        "package Foo;\n\nour \$VERSION = '0.005';\n1;\n",
        'Source version bumped: allow_leading_whitespace does not force leading whitespace',
    );

    is(
        path( $tzil->tempdir, qw(source lib Foo.pm) )->slurp_utf8,
        "package Foo;\n\n    our \$VERSION = '0.005';\n1;\n",
        'Source version bumped: Leading spaces are preserved',
    );

    is(
        path( $tzil->tempdir, qw(source lib PostFixBlock.pm) )->slurp_utf8,
        "package Foo {\n\n    our \$VERSION = '0.005';\n\n}\n1;\n",
        'Source version bumped: Leading spaces are preserved with a postfix package block',
    );

    is(
        path( $tzil->tempdir, qw(source lib Tabs.pm) )->slurp_utf8,

        "package Foo;\n\n\t\tour \$VERSION = '0.005';\n1;\n",
        'Source version bumped: Leading tabs are preserved',
    );

    diag 'got log messages: ', explain $tzil->log_messages
      if not Test::Builder->new->is_passing;
};

done_testing;
