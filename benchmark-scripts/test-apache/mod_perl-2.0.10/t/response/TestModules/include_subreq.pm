# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModules::include_subreq;

# this test calls a simple response handler, whose output includes a
# simple SSI directive, processed by the INCLUDES output filter, which
# triggers another response handler, which again returns an SSI
# directive, again processed by INCLUDES, which again calls a response
# handler
#
# main
# resp => INCLUDES =>                                        => client
#                  => 1st                                  =>
#                     subreq => INCLUDES =>              =>
#                     response           =>            =>
#                                        => 2nd      =>
#                                           subreq =>
#                                           response
#
#
#
# here we test whether :Apache perlio (STDOUT) is reentrant, since the test
# overrides STDOUT 3 times, recursively.

use strict;
use warnings FATAL => 'all';

use Apache::TestTrace;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    my $path_info = $r->path_info || '';
    my $uri = $r->uri;

    debug "uri: $uri, path_info: $path_info";

    if ($path_info eq '/one') {
        $uri =~ s/one/two/;
        print qq[subreq <!--#include virtual="$uri" -->ok];
    }
    elsif ($path_info eq '/two') {
        $uri = "/TestModules__include_subreq_dup/three";
        #$uri =~ s/two/three/;
        print qq[is <!--#include virtual="$uri" -->];
        #print "is";
    }
    elsif ($path_info eq '/three') {
        print "quite ";
    }
    else {
        die "something is wrong, didn't get path_info";
    }

    Apache2::Const::OK;
}

1;
__END__
# notice that perl-script is used on purpose here - testing whether
# :Apache perlio is reentrant (SetHandler modperl doesn't go through
# :Apache perlio layer)
SetHandler perl-script
PerlSetOutputFilter INCLUDES
Options +IncludesNoExec
<Base>
# it's silly that we have to duplicate the resource, but mod_include
# otherwise thinks we have a recursive call loop
<Location /TestModules__include_subreq_dup>
    PerlSetOutputFilter INCLUDES
    Options +IncludesNoExec
    SetHandler perl-script
    PerlResponseHandler TestModules::include_subreq
</Location>
</Base>
