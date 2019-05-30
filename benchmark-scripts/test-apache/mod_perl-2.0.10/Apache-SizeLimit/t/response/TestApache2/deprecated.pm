package TestApache2::deprecated;

use strict;
use warnings;

use Apache::Test qw(-withtestmore);

use Apache2::Const -compile => qw(OK);
use Apache2::SizeLimit;


sub handler {
    my $r = shift;

    plan $r, tests => 3;

    Apache2::SizeLimit::setmax( 100_000 );
    is( $Apache2::SizeLimit::MAX_PROCESS_SIZE, 100_000,
        'setmax changes $MAX_PROCESS_SIZE' );

    Apache2::SizeLimit::setmin( 1 );
    is( $Apache2::SizeLimit::MIN_SHARE_SIZE, 1,
        'setmax changes $MIN_SHARE_SIZE' );

    Apache2::SizeLimit::setmax_unshared( 1 );
    is( $Apache2::SizeLimit::MIN_SHARE_SIZE, 1,
        'setmax_unshared changes $MAX_UNSHARED_SIZE' );

    return Apache2::Const::OK;
}

1;

__DATA__
<NoAutoConfig>
    <IfDefine !APACHE1>
        <Location /TestApache2__deprecated>
            PerlOptions +GlobalRequest
            SetHandler modperl
            PerlResponseHandler TestApache2::deprecated
        </Location>
    </IfDefine>
</NoAutoConfig>
