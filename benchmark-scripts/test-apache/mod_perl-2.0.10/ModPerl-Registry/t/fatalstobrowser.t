# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil qw(
                        t_cmp t_write_perl_script 
                        t_client_log_error_is_expected
                       );
use Apache::TestRequest qw(GET);

use File::Spec::Functions qw(catfile);

plan tests => 4, need need_module(qw(mod_alias)),
                      need_cgi,
                      need_min_module_version CGI => 99.99,
                      skip_reason('fatalsToBrowser known not to work');

my $file = catfile(Apache::Test::vars('serverroot'),
                   qw(cgi-bin fatalstobrowser.pl));

t_write_perl_script($file, <DATA>);

foreach my $base (qw(cgi-bin registry)) {

    my $url = "$base/fatalstobrowser.pl";
    my $res = GET $url;

    ok t_cmp($res->code,
             200,
             "error intercepted");

    t_client_log_error_is_expected();

    ok t_cmp($res->content,
             qr/uninitiated_scalar/,
             "error message captured and returned");
}

__END__
use strict;
use CGI::Carp qw (fatalsToBrowser);

use CGI;

my $cgi = new CGI;
print $cgi->header;

print "$uninitiated_scalar";

print "Hello World";
