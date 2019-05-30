# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::TestRequest;

my $location = "/TestModperl__post_utf8";

# From A.S.Pushkin's "Evgeniy Onegin"
my $data_ascii = "I love you, (why lying?), but I belong to another";
my $data_utf8  = "\x{042F} \x{0432}\x{0430}\x{0441} \x{043B}\x{044E}" .
    "\x{0431}\x{043B}\x{044E} (\x{043A} \x{0447}\x{0435}\x{043C}\x{0443} " .
    "\x{043B}\x{0443}\x{043A}\x{0430}\x{0432}\x{0438}\x{0442}\x{044C}?),\n" .
    "\x{041D}\x{043E} \x{044F} \x{0434}\x{0440}\x{0443}\x{0433}\x{043E}" .
    "\x{043C}\x{0443} \x{043E}\x{0442}\x{0434}\x{0430}\x{043D}\x{0430};";

my $data = join '=', $data_ascii, $data_utf8;

# must encode the utf8 request body
# we will skip the response any way if perl < 5.008
utf8::encode($data) if $] >= 5.008;

# Accept-Charset is not really needed, since we don't expect the
# server side to send anything back but plain ASCII.
print POST_BODY_ASSERT $location, content => $data,
    'Accept-Charset'  => "ISO-8859-1,UTF-8";


