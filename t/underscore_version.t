use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Fatal;
use Path::Tiny;

delete $ENV{RELEASE_STATUS};
delete $ENV{TRIAL};
delete $ENV{V};


my $tzil = Builder->from_config(
    { dist_root => 'does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => dist_ini(
                { # configs as in simple_ini, but no version assignment
                    name     => 'DZT-Sample',
                    abstract => 'Sample DZ Dist',
                    author   => 'E. Xavier Ample <example@example.org>',
                    license  => 'Perl_5',
                    copyright_holder => 'E. Xavier Ample',
                },
                [ GatherDir => ],
                [ MetaConfig => ],
                [ RewriteVersion => ],
                [ FakeRelease => ],
                [ BumpVersionAfterRelease => ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n\nour \$VERSION = '0.004_002';\n\n1;\n",
            path(qw(source lib Foo Bar.pm)) => "package Foo::Bar;\n\nour \$VERSION = '0.004_002';\n\$VERSION = '0.004002';\n\n1;\n",
            path(qw(source lib Foo Baz.pm)) => "package Foo::Baz;\n\nour \$VERSION = '0.004_002'; # TRIAL\n\$VERSION = '0.004002';\n\n1;\n",
        },
    },
);

$tzil->chrome->logger->set_debug(1);
is(
    exception { $tzil->release },
    undef,
    'build and release proceeds normally',
);

is(
    $tzil->version,
    '0.004_002',
    'version was properly extracted from .pm file',
);

is(
    path($tzil->tempdir, qw(build lib Foo.pm))->slurp_utf8,
    "package Foo;\n\nour \$VERSION = '0.004_002'; # TRIAL\n\$VERSION = '0.004002';\n\n1;\n",
    'TRIAL comment and second assignment are added',
);

is(
    path($tzil->tempdir, qw(build lib Foo Bar.pm))->slurp_utf8,
    "package Foo::Bar;\n\nour \$VERSION = '0.004_002'; # TRIAL\n\$VERSION = '0.004002';\n\n1;\n",
    'TRIAL comment is added; second assignment is retained',
);

is(
    path($tzil->tempdir, qw(build lib Foo Baz.pm))->slurp_utf8,
    "package Foo::Baz;\n\nour \$VERSION = '0.004_002'; # TRIAL\n\$VERSION = '0.004002';\n\n1;\n",
    'TRIAL comment and second assignment are retained',
);

is(
    path($tzil->tempdir, qw(source lib Foo.pm))->slurp_utf8,
    "package Foo;\n\nour \$VERSION = '0.004_003';\n\$VERSION = '0.004003';\n\n1;\n",
    '.pm contents in source saw the underscore version incremented, and second assignment added',
);

is(
    path($tzil->tempdir, qw(source lib Foo Bar.pm))->slurp_utf8,
    "package Foo::Bar;\n\nour \$VERSION = '0.004_003';\n\$VERSION = '0.004003';\n\n1;\n",
    '.pm contents in source saw the underscore version incremented and second assignment retained',
);

is(
    path($tzil->tempdir, qw(source lib Foo Baz.pm))->slurp_utf8,
    "package Foo::Baz;\n\nour \$VERSION = '0.004_003';\n\$VERSION = '0.004003';\n\n1;\n",
    '.pm contents in source saw the underscore version incremented, TRIAL comment removed and second assignment retained',
);

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
