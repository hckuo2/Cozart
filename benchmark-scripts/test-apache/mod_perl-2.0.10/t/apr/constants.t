# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use ExtUtils::testlib;
use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::TestUtil;

use APR::Const -compile => qw(:common POLLIN :filetype);
use APR::Const qw(:hook);

plan tests => 5;

ok ! defined &POLLIN;
ok t_cmp (APR::Const::SUCCESS, 0, 'APR::Const::SUCCESS');
ok t_cmp (APR::Const::POLLIN, 0x001, 'APR::Const::POLLIN');
ok t_cmp (HOOK_LAST, 20, 'HOOK_LAST');
ok t_cmp (APR::Const::FILETYPE_UNKFILE, 127, 'APR::UNKFILE');
