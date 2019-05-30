# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPRlib::uri;

# Testing APR::URI (more tests in TestAPI::uri)

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::URI ();
use APR::Pool ();
use APR::Const -compile => qw(URI_UNP_OMITSITEPART URI_UNP_OMITUSER
                              URI_UNP_REVEALPASSWORD URI_UNP_OMITQUERY
                              URI_UNP_OMITPASSWORD URI_UNP_OMITPATHINFO
                             );

my %default_ports = (
    ftp      => 21,
    gopher   => 70,
    http     => 80,
    https    => 443,
    nntp     => 119,
    prospero => 191,
    snews    => 563,
    wais     => 210,
);

my %url = (
    scheme   => ["http",            "ftp"            ],
    user     => ["user",            "log"            ],
    password => ["password",        "pass"           ],
    hostname => ["www.example.com", "ftp.example.com"],
    port     => [8000,               21              ],
    path     => ["/path/file.pl",   "/pub"           ],
    query    => ["query",           undef            ],
    fragment => ["fragment",        undef            ],
);

my @keys_urls = qw(scheme user password hostname port path query
                   fragment);
my @keys_hostinfo = qw(user password hostname port);

sub num_of_tests {
    return 36;
}

sub test {

    my $pool = APR::Pool->new();

    ### parse ###
    my $url0 = sprintf "%s://%s:%s\@%s:%d%s?%s#%s",
        map { $url{$_}[0] } @keys_urls;
    # warn "URL: $url\n";
    my $hostinfo0 =  sprintf "%s:%s\@%s:%d",
        map { $url{$_}[0] } @keys_hostinfo;

    my $parsed = APR::URI->parse($pool, $url0);
    ok $parsed;
    ok $parsed->isa('APR::URI');

    for my $method (keys %url) {
        no strict 'refs';
        ok t_cmp($parsed->$method, $url{$method}[0], $method);
    }

    ok t_cmp($parsed->hostinfo, $hostinfo0, "hostinfo");

    for my $method (keys %url) {
        no strict 'refs';
        $parsed->$method($url{$method}[1]);
        t_debug("$method: " . ($url{$method}[1]||'undef') .
                " => " . ($parsed->$method||'undef'));
    }

    ### unparse ###
    my $url_unparsed = $parsed->unparse;

    # hostinfo is unaffected, since it's simply a field in the parsed
    # record, and it's populated when parse is called, but when
    # individual fields used to compose it are updated, it doesn't get
    # updated: so we see the old value here
    ok t_cmp($parsed->hostinfo, $hostinfo0, "hostinfo");

    # - since 21 is the default port for ftp, unparse omits it
    # - if no flags are passed to unparse, APR::Const::URI_UNP_OMITPASSWORD
    #   is passed by default -- it hides the password
    my $url1 = sprintf "%s://%s\@%s%s",
        map { $url{$_}[1] } qw(scheme user hostname path);
    ok t_cmp($url_unparsed, $url1, "unparsed url");

    # various unparse flags #
    {
        # restore the query/fragment fields first
        my $query_new = "my_query";
        my $fragment_new = "my_fragment";
        $parsed->query($query_new);
        $parsed->fragment($fragment_new);
        local $url{query}[1] = $query_new;
        local $url{fragment}[1] = $fragment_new;

        # omit the site part
        {
            my $url_unparsed = $parsed->unparse(APR::Const::URI_UNP_OMITSITEPART);
            my $url2 = sprintf "%s?%s#%s",
                map { $url{$_}[1] } qw(path query fragment);
            ok t_cmp($url_unparsed, $url2, "unparsed url: omit site");
        }

        # this time the password should appear as XXXXXXXX
        {
            local $url{password}[1] = "XXXXXXXX";
            my $url_unparsed = $parsed->unparse(0);
            my $url2 = sprintf "%s://%s:%s\@%s%s?%s#%s",
                map { $url{$_}[1] } grep !/^port$/, @keys_urls;
            ok t_cmp($url_unparsed, $url2, "unparsed url:reveal passwd");
        }

        # this time the user and the password should appear
        {
            my $url_unparsed = $parsed->unparse(APR::Const::URI_UNP_REVEALPASSWORD);
            my $url2 = sprintf "%s://%s:%s\@%s%s?%s#%s",
                map { $url{$_}[1] } grep !/^port$/, @keys_urls;
            ok t_cmp($url_unparsed, $url2, "unparsed url:reveal passwd");
        }

        # omit the user part / show password
        {
            my $url_unparsed = $parsed->unparse(
                APR::Const::URI_UNP_OMITUSER|APR::Const::URI_UNP_REVEALPASSWORD);
            my $url2 = sprintf "%s://:%s\@%s%s?%s#%s",
                map { $url{$_}[1] } grep !/^(port|user)$/, @keys_urls;
            ok t_cmp($url_unparsed, $url2, "unparsed url:  omit user");
        }

        # omit the path, query and fragment strings
        {
            my $url_unparsed = $parsed->unparse(
                APR::Const::URI_UNP_OMITPATHINFO|APR::Const::URI_UNP_REVEALPASSWORD);
            my $url2 = sprintf "%s://%s:%s\@%s", map { $url{$_}[1] }
                grep !/^(port|path|query|fragment)$/, @keys_urls;
            ok t_cmp($url_unparsed, $url2, "unparsed url: omit path");
        }

        # omit the query and fragment strings
        {
            my $url_unparsed = $parsed->unparse(
                APR::Const::URI_UNP_OMITQUERY|APR::Const::URI_UNP_OMITPASSWORD);
            my $url2 = sprintf "%s://%s\@%s%s", map { $url{$_}[1] }
                grep !/^(password|port|query|fragment)$/, @keys_urls;
            ok t_cmp($url_unparsed, $url2, "unparsed url: omit query");
        }
    }

    ### port_of_scheme ###
    while (my ($scheme, $port) = each %default_ports) {
        my $apr_port = APR::URI::port_of_scheme($scheme);
        ok t_cmp($apr_port, $port, "scheme: $scheme");
    }

    # parse + out-of-scope pools
    {

        my $url0 = sprintf "%s://%s:%s\@%s:%d%s?%s#%s",
            map { $url{$_}[0] } @keys_urls;
        # warn "URL: $url\n";
        my $hostinfo0 =  sprintf "%s:%s\@%s:%d",
            map { $url{$_}[0] } @keys_hostinfo;

        require APR::Pool;
        my $parsed = APR::URI->parse(APR::Pool->new, $url0);

        # try to overwrite the temp pool data
        require APR::Table;
        my $table = APR::Table::make(APR::Pool->new, 50);
        $table->set($_ => $_) for 'aa'..'za';

        for my $method (keys %url) {
            no strict 'refs';
            ok t_cmp($parsed->$method, $url{$method}[0], $method);
        }

        ok t_cmp($parsed->hostinfo, $hostinfo0, "hostinfo");
    }
}

1;
