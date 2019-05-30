# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use Apache::TestRequest 'GET_BODY_ASSERT';

# we want r->filename to be "/slurp/slurp.pl", even though the
# response handler is TestAPI::slurp_filename

print GET_BODY_ASSERT "/slurp/slurp.pl";
