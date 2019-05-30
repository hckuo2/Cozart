# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::perlio;

# to see what happens inside the io layer, assuming that you built
# mod_perl with MP_TRACE=1, run:
# env MOD_PERL_TRACE=o t/TEST -v -trace=debug apr/perlio

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Fcntl ();
use File::Spec::Functions qw(catfile);

use Apache2::Const -compile => qw(OK CRLF);

#XXX: APR::LARGE_FILES_CONFLICT constant?
#XXX: you can set to zero if largefile support is not enabled in Perl
use constant LARGE_FILES_CONFLICT => 1;

# apr_file_dup has a bug on win32,
# should be fixed in apr 0.9.4 / httpd-2.0.48
require Apache2::Build;
use constant APR_WIN32_FILE_DUP_BUG =>
    Apache2::Build::WIN32() && !have_min_apache_version('2.0.48');

sub handler {
    my $r = shift;

    my $tests = 22;
    $tests += 3 unless LARGE_FILES_CONFLICT;
    $tests += 1 unless APR_WIN32_FILE_DUP_BUG;

    require APR::PerlIO;
    plan $r, tests => $tests,
        need  { "This Perl build doesn't support PerlIO layers" =>
                    APR::PerlIO::PERLIO_LAYERS_ARE_ENABLED() };

    my $vars = Apache::Test::config()->{vars};
    my $dir  = catfile $vars->{documentroot}, "perlio";

    t_mkdir($dir);

    my $sep = "-- sep --\n";
    my @lines = ("This is a test: $$\n", "test line --sep two\n");

    my $expected = $lines[0];
    my $expected_all = join $sep, @lines;

    # write file
    my $file = catfile $dir, "test";
    t_debug "open file $file for writing";
    my $foo = "bar";
    open my $fh, ">:APR", $file, $r->pool
        or die "Cannot open $file for writing: $!";
    ok ref($fh) eq 'GLOB';

    t_debug "write to a file:\n$expected\n";
    print $fh $expected_all;
    close $fh;

    # open() failure test
    {
        # workaround for locale setups where the error message may be
        # in a different language
        open my $fh, "perlio_this_file_cannot_exist";
        my $errno_string = "$!";

        # non-existent file
        my $file = "/this/file/does/not/exist";
        if (open my $fh, "<:APR", $file, $r->pool) {
            t_debug "must not be able to open $file!";
            ok 0;
            close $fh;
        }
        else {
            ok t_cmp("$!",
                     $errno_string,
                     "expected failure");
        }
    }

    # seek/tell() tests
    unless (LARGE_FILES_CONFLICT) {
        open my $fh, "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        # read the whole file so we can test the buffer flushed
        # correctly on seek.
        my $dummy = join '', <$fh>;

        # Fcntl::SEEK_SET()
        my $pos = 3; # rewinds after reading 6 chars above
        seek $fh, $pos, Fcntl::SEEK_SET();
        my $got = tell($fh);
        ok t_cmp($got,
                 $pos,
                 "seek/tell the file Fcntl::SEEK_SET");

        # Fcntl::SEEK_CUR()
        my $step = 10;
        $pos = tell($fh) + $step;
        seek $fh, $step, Fcntl::SEEK_CUR();
        $got = tell($fh);
        ok t_cmp($got,
                 $pos,
                 "seek/tell the file Fcntl::SEEK_CUR");

        # Fcntl::SEEK_END()
        $pos = -s $file;
        seek $fh, 0, Fcntl::SEEK_END();
        $got = tell($fh);
        ok t_cmp($got,
                 $pos,
                 "seek/tell the file Fcntl::SEEK_END");

        close $fh;
    }

    # read() tests
    {
        open my $fh, "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        # basic open test
        ok ref($fh) eq 'GLOB';

        # basic single line read
        ok t_cmp(scalar(<$fh>),
                 $expected,
                 "single line read");

        # slurp mode
        seek $fh, 0, Fcntl::SEEK_SET(); # rewind to the start
        local $/;

        ok t_cmp(scalar(<$fh>),
                 $expected_all,
                 "slurp file");

        # test ungetc (a long sep requires read ahead)
        seek $fh, 0, Fcntl::SEEK_SET(); # rewind to the start
        local $/ = $sep;
        my @got_lines = <$fh>;
        my @expect = ($lines[0] . $sep, $lines[1]);
        ok t_cmp(\@got_lines,
                 \@expect,
                 "custom complex input record sep read");

        close $fh;
    }


    # eof() tests
    {
        open my $fh, "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        ok t_cmp(0,
                 int eof($fh), # returns false, not 0
                 "not end of file");
        # go to the end and read so eof will return 1
        seek $fh, 0, Fcntl::SEEK_END();
        my $received = <$fh>;

        t_debug($received);

        ok t_cmp(eof($fh),
                 1,
                 "end of file");
        close $fh;
    }

    # dup() test
    {
        open my $fh, "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        open my $dup_fh, "<&:APR", $fh
            or die "Cannot dup $file for reading: $!";
        close $fh;
        ok ref($dup_fh) eq 'GLOB';

        my $received = <$dup_fh>;

        close $dup_fh;
        unless (APR_WIN32_FILE_DUP_BUG) {
            ok t_cmp($received,
                     $expected,
                     "read/write a dupped file");
        }
    }

    # unbuffered write
    {
        open my $wfh, ">:APR", $file, $r->pool
            or die "Cannot open $file for writing: $!";
        open my $rfh,  "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        my $expected = "This is an un buffering write test";
        # unbuffer
        my $oldfh = select($wfh); $| = 1; select($oldfh);
        print $wfh $expected; # must be flushed to disk immediately

        ok t_cmp(scalar(<$rfh>),
                 $expected,
                 "file unbuffered write");

        # buffer up
        $oldfh = select($wfh); $| = 0; select($oldfh);
        print $wfh $expected; # should be buffered up and not flushed

        ok t_cmp(scalar(<$rfh>),
                 undef,
                 "file buffered write");

        close $wfh;
        close $rfh;

    }

    # tests reading and writing text and binary files
    {
        for my $file ('MoonRise.jpeg', 'redrum.txt') {
            my $in = catfile $dir, $file;
            my $out = catfile $dir, "$file.out";
            my ($apr_content, $perl_content);
            open my $rfh, "<:APR", $in, $r->pool
                or die "Cannot open $in for reading: $!";
            {
                local $/;
                $apr_content = <$rfh>;
            }
            close $rfh;
            open my $pfh, "<", $in
                or die "Cannot open $in for reading: $!";
            binmode($pfh);
            {
                local $/;
                $perl_content = <$pfh>;
            }
            close $pfh;
            ok t_cmp(length $apr_content,
                     length $perl_content,
                     "testing data size of $file");

            open my $wfh, ">:APR", $out, $r->pool
                or die "Cannot open $out for writing: $!";
            print $wfh $apr_content;
            close $wfh;
            ok t_cmp(-s $out,
                     -s $in,
                     "testing file size of $file");
            unlink $out;
        }
    }

    # tests for various CRLF and utf-8 issues
    {
        my $scratch = catfile $dir, 'scratch.dat';
        my $text;
        my $count = 2000;
        open my $wfh, ">:crlf", $scratch
            or die "Cannot open $scratch for writing: $!";
        print $wfh 'a' . ((('a' x 14) . "\n") x $count);
        close $wfh;
        open my $rfh, "<:APR", $scratch, $r->pool
            or die "Cannot open $scratch for reading: $!";
        {
            local $/;
            $text = <$rfh>;
        }
        close $rfh;
        ok t_cmp(count_chars($text, Apache2::Const::CRLF),
                 $count,
                 'testing for presence of \015\012');
        ok t_cmp(count_chars($text, "\n"),
                 $count,
                 'testing for presence of \n');

        open $wfh, ">:APR", $scratch, $r->pool
            or die "Cannot open $scratch for writing: $!";
        print $wfh 'a' . ((('a' x 14) . Apache2::Const::CRLF) x $count);
        close $wfh;
        open $rfh, "<:APR", $scratch, $r->pool
            or die "Cannot open $scratch for reading: $!";
        {
            local $/;
            $text = <$rfh>;
        }
        close $rfh;
        ok t_cmp(count_chars($text, Apache2::Const::CRLF),
                 $count,
                 'testing for presence of \015\012');
        ok t_cmp(count_chars($text, "\n"),
                 $count,
                 'testing for presence of \n');
        open $rfh, "<:crlf", $scratch
            or die "Cannot open $scratch for reading: $!";
        {
            local $/;
            $text = <$rfh>;
        }
        close $rfh;
        ok t_cmp(count_chars($text, Apache2::Const::CRLF),
                 0,
                 'testing for presence of \015\012');
        ok t_cmp(count_chars($text, "\n"),
                 $count,
                 'testing for presence of \n');

        my $utf8 = "\x{042F} \x{0432}\x{0430}\x{0441} \x{043B}\x{044E}";
        open $wfh, ">:APR", $scratch, $r->pool
            or die "Cannot open $scratch for writing: $!";
        binmode($wfh, ':utf8');
        print $wfh $utf8;
        close $wfh;
        open $rfh, "<:APR", $scratch, $r->pool
            or die "Cannot open $scratch for reading: $!";
        binmode($rfh, ':utf8');
        {
            local $/;
            $text = <$rfh>;
        }
        close $rfh;
        ok t_cmp($text,
                 $utf8,
                 'utf8 binmode test');
        unlink $scratch;
    }

    # XXX: need tests
    # - for stdin/out/err as they are handled specially

    # XXX: tmpfile is missing:
    # consider to use 5.8's syntax:
    #   open $fh, "+>", undef;

    # cleanup: t_mkdir will remove the whole tree including the file

    Apache2::Const::OK;
}

sub count_chars {
    my ($text, $chars) = @_;
    my $seen = 0;
    $seen++ while $text =~ /$chars/g;
    return $seen;
}

1;
