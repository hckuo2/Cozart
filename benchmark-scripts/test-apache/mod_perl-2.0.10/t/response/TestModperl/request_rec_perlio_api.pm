# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::request_rec_perlio_api;

# this test is relevant only when the PerlIO STDIN/STDOUT are used (when
# $Config{useperlio} is defined.)

use strict;
use warnings FATAL => 'all';

use Apache2::RequestIO ();
use Apache2::RequestRec ();

use Apache::Test;

use File::Spec::Functions qw(catfile catdir);

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->args eq 'STDIN' ? test_STDIN($r) : test_STDOUT($r);

    return Apache2::Const::OK;
}

sub test_STDIN {
    my $r = shift;

    {
        # read the first 10 POST chars
        my $data;
        read STDIN, $data, 10;
        print STDOUT $data;
    }

   {
        # re-open STDIN to something else, and then see if we don't
        # lose any chars when we restore it to the POST stream
        open my $stdin, "<&STDIN" or die "Can't dup STDIN: $!";

        open STDIN, "<", __FILE__
            or die "failed to open STDIN as 'in memory' file : $!";
        my $data;
        read STDIN, $data, length("# please");
        print STDOUT $data;
        close STDIN;

        open STDIN, "<&", $stdin or die "failed to restore STDIN: $!";
    }

    {
        # read the last 10 POST chars
        my $data;
        read STDIN, $data, 10;
        print STDOUT $data;
    }

}

sub test_STDOUT {
    my $r = shift;

    local $| = 0;
    print STDOUT "life is hard ";

    my $vars = Apache::Test::config()->{vars};
    my $target_dir = catdir $vars->{documentroot}, 'perlio';
    my $file = catfile $target_dir, "apache_stdout";

    # re-open STDOUT to something else, and then see if we can
    # continue printing to the client via STDOUT, after restoring it
    open my $stdout, ">&STDOUT" or die "Can't dup STDOUT: $!";

    # this should flush the above print to STDOUT
    open STDOUT, ">", $file or die "Can't open $file: $!";
    print STDOUT "and then ";
    close STDOUT;

    # flush things that went into the file as STDOUT
    open STDOUT, ">&", $stdout or die "failed to restore STDOUT: $!";
    open my $fh, $file or die "Can't open $file: $!";
    local $\;
    print <$fh>;

    # cleanup
    unlink $file;

    # close the dupped fh
    close $stdout;

    print "you die! ";

    # now close it completely and restore it, without using any dupped
    # filehandle
    close STDOUT;
    open STDOUT, ">:Apache2", $r
        or die "can't open STDOUT via :Apache2 layer : $!";
    print "next you reincarnate...";

}

1;
__DATA__
SetHandler perl-script
