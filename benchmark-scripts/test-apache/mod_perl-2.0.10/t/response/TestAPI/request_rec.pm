# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::request_rec;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use Apache2::RequestRec ();
use Apache2::RequestUtil ();

use APR::Finfo ();
use APR::Pool ();

use Apache2::Const -compile => qw(OK M_GET M_PUT);
use APR::Const    -compile => qw(FINFO_NORM);

#this test module is only for testing fields in the request_rec
#listed in apache_structures.map
#XXX: GloabalRequest test should be moved elsewhere
#     as should $| test

sub handler {
    my $r = shift;

    plan $r, tests => 55;

    #Apache2::RequestUtil->request($r); #PerlOptions +GlobalRequest takes care
    my $gr = Apache2::RequestUtil->request;

    ok $$gr == $$r;

    my $newr = Apache2::RequestRec->new($r->connection, $r->pool);
    Apache2::RequestUtil->request($newr);
    $gr = Apache2::RequestUtil->request;

    ok $$gr == $$newr;

    Apache2::RequestUtil->request($r);

    ok $r->pool->isa('APR::Pool');

    ok $r->connection->isa('Apache2::Connection');

    ok $r->server->isa('Apache2::ServerRec');

    for (qw(next prev main)) {
        ok (! $r->$_()) || $r->$_()->isa('Apache2::RequestRec');
    }

    ok !$r->assbackwards;

    ok !$r->proxyreq; # see also TestModules::proxy

    ok !$r->header_only;

    ok $r->protocol =~ /http/i;

    # LWP >=6.00 uses HTTP/1.1, other HTTP/1.0
    ok t_cmp $r->proto_num, 1000+substr($r->the_request, -1),
	't->proto_num';

    ok t_cmp lc($r->hostname), lc($r->get_server_name), '$r->hostname';

    {
        my $old_hostname = $r->hostname("other.hostname");
        ok t_cmp $r->hostname, "other.hostname", '$r->hostname rw';
        $r->hostname($old_hostname);
    }

    ok $r->request_time;

    ok $r->status_line || 1;

    ok $r->status || 1;

    ok t_cmp $r->method, 'GET', '$r->method';

    ok t_cmp $r->method_number, Apache2::Const::M_GET, '$r->method_number';

    ok $r->headers_in;

    ok $r->headers_out;

    # tested in TestAPI::err_headers_out
    ok $r->err_headers_out;

    ok $r->subprocess_env;

    ok $r->notes;

    ok $r->content_type;

    ok $r->handler;

    ok $r->ap_auth_type || 1;

    ok $r->no_cache || 1;

    ok !$r->no_local_copy;

    {
        local $| = 0;
        ok t_cmp $r->print("# buffered\n"), 11, "buffered print";
        ok t_cmp $r->print(), "0E0", "buffered print";

        local $| = 1;
        my $string = "# not buffered\n";
        ok t_cmp $r->print(split //, $string), length($string),
            "unbuffered print";
    }

    # GET header components
    {
        my $args      = "my_args=3";
        my $path_info = "/my_path_info";
        my $base_uri  = "/TestAPI__request_rec";

        ok t_cmp $r->unparsed_uri, "$base_uri$path_info?$args";

        ok t_cmp $r->uri, "$base_uri$path_info", '$r->uri';

        ok t_cmp $r->path_info, $path_info, '$r->path_info';

        ok t_cmp $r->args, $args, '$r->args';

	# LWP uses HTTP/1.1 since 6.00
        ok t_cmp $r->the_request, qr!GET
				     \x20
				     \Q$base_uri$path_info\E\?\Q$args\E
				     \x20
				     HTTP/1\.\d!x,
            '$r->the_request';

        {
            my $new_request = "GET $base_uri$path_info?$args&foo=bar HTTP/1.0";
            my $old_request = $r->the_request($new_request);
            ok t_cmp $r->the_request, $new_request, '$r->the_request rw';
            $r->the_request($old_request);
        }

        ok $r->filename;

        my $location = '/' . Apache::TestRequest::module2path(__PACKAGE__);
        ok t_cmp $r->location, $location, '$r->location';
    }

    # bytes_sent
    {
        $r->rflush;
        my $sent = $r->bytes_sent;
        t_debug "sent so far: $sent bytes";
        # at least 100 chars were sent already
        ok $sent > 100;
    }

    # mtime
    {
        my $mtime = (stat __FILE__)[9];
        $r->mtime($mtime);
        ok t_cmp $r->mtime, $mtime, "mtime";
    }

    # finfo
    {
        my $finfo = APR::Finfo::stat(__FILE__, APR::Const::FINFO_NORM, $r->pool);
        $r->finfo($finfo);
        # just one field test, all accessors are fully tested in
        # TestAPR::finfo
        ok t_cmp($r->finfo->fname,
                 __FILE__,
                 '$r->finfo');
    }

    # allowed
    {
        $r->allowed(1 << Apache2::Const::M_GET);

        ok $r->allowed & (1 << Apache2::Const::M_GET);
        ok ! ($r->allowed & (1 << Apache2::Const::M_PUT));

        $r->allowed($r->allowed | (1 << Apache2::Const::M_PUT));
        ok $r->allowed & (1 << Apache2::Const::M_PUT);
    }

    # content_languages
    {
        my $def = [qw(fr)];       #default value
        my $l   = [qw(fr us cn)]; #new value

        if (have_module('mod_mime')) {
            ok t_cmp $r->content_languages, $def, '$r->content_languages';
        }
        else {
            skip "Need mod_mime", 0;
        }

        my $old = $r->content_languages($l);
        if (have_module('mod_mime')) {
            ok t_cmp $old, $def, '$r->content_languages';
        }
        else {
            skip "Need mod_mime", 0;
        }

        ok t_cmp $r->content_languages, $l, '$r->content_languages';

        eval { $r->content_languages({}) };
        ok t_cmp $@, qr/Not an array reference/,
                '$r->content_languages(invalid)';
    }

    ### invalid $r
    {
        my $r = bless {}, "Apache2::RequestRec";
        my $err = q[method `uri' invoked by a `Apache2::RequestRec' ] .
            q[object with no `r' key!];
        eval { $r->uri };
        ok t_cmp $@, qr/$err/, "invalid $r object";
    }
    {
        my $r = bless {}, "NonExisting";
        my $err = q[method `uri' invoked by a `NonExisting' ] .
            q[object with no `r' key!];
        eval { Apache2::RequestRec::uri($r) };
        ok t_cmp $@, qr/$err/, "invalid $r object";
    }
    {
        my $r = {};
        my $err = q[method `uri' invoked by a `unknown' ] .
            q[object with no `r' key!];
        eval { Apache2::RequestRec::uri($r) };
        ok t_cmp $@, qr/$err/, "invalid $r object";
    }

    # out-of-scope pools
    {
        my $newr = Apache2::RequestRec->new($r->connection, APR::Pool->new);
        {
            require APR::Table;
            # try to overwrite the pool
            my $table = APR::Table::make(APR::Pool->new, 50);
            $table->set($_ => $_) for 'aa'..'za';
        }
        # check if $newr is still OK
        ok $newr->connection->isa('Apache2::Connection');
    }

    # tested in other tests
    # - input_filters:    TestAPI::in_out_filters
    # - output_filters:   TestAPI::in_out_filters
    # - per_dir_config:   in several other tests
    # - content_encoding: TestAPI::content_encoding
    # - user:             TestHooks::authz / TestHooks::authen

    # XXX: untested
    # - request_config
    # - allowed_xmethods
    # - allowed_methods

    Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
<Location /TestAPI__request_rec>
    PerlOptions +GlobalRequest
    <IfModule mod_mime.c>
        DefaultLanguage fr
    </IfModule>
    SetHandler modperl
    PerlResponseHandler TestAPI::request_rec
</Location>
</NoAutoConfig>
