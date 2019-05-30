package TestApache::deprecated;

use strict;
use warnings;

use Apache::Test qw(-withtestmore);

use Apache::Constants qw(OK);
use Apache::SizeLimit;


sub handler {
    my $r = shift;

    plan $r, tests => 5;

    my $handlers = $r->get_handlers('PerlCleanupHandler');
    is( scalar @$handlers, 0,
        'there is no PerlCleanupHandler before add_cleanup_handler()' );

    Apache::SizeLimit::setmax( 100_000 );
    is( $Apache::SizeLimit::MAX_PROCESS_SIZE, 100_000,
        'setmax changes $MAX_PROCESS_SIZE' );

    Apache::SizeLimit::setmin( 1 );
    is( $Apache::SizeLimit::MIN_SHARE_SIZE, 1,
        'setmax changes $MIN_SHARE_SIZE' );

    Apache::SizeLimit::setmax_unshared( 1 );
    is( $Apache::SizeLimit::MIN_SHARE_SIZE, 1,
        'setmax_unshared changes $MAX_UNSHARED_SIZE' );

    $handlers = $r->get_handlers('PerlCleanupHandler');
    is( scalar @$handlers, 1,
        'there is one PerlCleanupHandler after calling deprecated functions' );


    return OK;
}


1;
