# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPRlib::finfo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;
use Apache::TestConfig;

use File::Spec::Functions qw(catfile);
use Fcntl qw(:mode);

use APR::Finfo ();
use APR::Pool ();

use constant WIN32 => Apache::TestConfig::WIN32;
use constant OSX   => Apache::TestConfig::OSX;

use constant APACHE_2_0_49_PLUS => have_min_apache_version('2.0.49');
use constant APACHE_2_2_PLUS    => have_min_apache_version('2.2.0');

use APR::Const -compile => qw(SUCCESS FINFO_NORM FILETYPE_REG
                              FPROT_WREAD FPROT_WWRITE
                              FPROT_WEXECUTE);

sub num_of_tests {
    return 27;
}

sub test {

    # for the file to be tested, use the httpd.conf generated
    # by testing, so that it has a ctime that won't (usually)
    # encounter a bug in Win32's stat() function for files that
    # span across DST season boundaries.
    my $file = catfile Apache::Test::vars->{t_dir}, 'conf', 'httpd.conf';

    my $pool = APR::Pool->new();
    # populate the finfo struct first
    my $finfo = APR::Finfo::stat($file, APR::Const::FINFO_NORM, $pool);

    ok $finfo->isa('APR::Finfo');

    # now, get information from perl's stat()
    my %stat;

    @stat{qw(device inode protection nlink user group size atime mtime
             ctime)} = (stat $file)[0..5, 7..10];

    compare_with_perl($finfo, \%stat);

    # tests for stuff not in perl's stat
    {
        # BACK_COMPAT_MARKER - fixed as of 2.0.49.
        if (WIN32 && !APACHE_2_0_49_PLUS) {
            skip "finfo.fname requires Apache 2.0.49 or later", 0;
        }
        else {
            ok t_cmp($finfo->fname,
                     $file,
                     '$finfo->fname()');
        }

        ok t_cmp($finfo->filetype,
                 APR::Const::FILETYPE_REG,
                 '$finfo->filetype()');
    }

    # stat() on out-of-scope pools
    {
        my $finfo = APR::Finfo::stat($file, APR::Const::FINFO_NORM, APR::Pool->new);

        # try to overwrite the temp pool data
        require APR::Table;
        my $table = APR::Table::make(APR::Pool->new, 50);
        $table->set($_ => $_) for 'aa'..'za';

        # now test that we are still OK
        compare_with_perl($finfo, \%stat);
    }

}


sub compare_with_perl {
    my ($finfo, $stat) = @_;
    # skip certain tests on Win32 and others
    my %skip = ();

    if (WIN32) {
        # atime is wrong on NTFS, but OK on FAT32
        %skip = map {$_ => 1} qw(device inode user group atime);
    }
    elsif (OSX) {
        # XXX both apr and perl report incorrect group values.  sometimes.
        # XXX skip until we can really figure out what is going on.
        %skip = (group => 1);
    }

    # compare stat fields between perl and apr_stat
    {
        foreach my $method (qw(device inode nlink user group
                               size atime mtime ctime)) {
            if ($skip{$method}) {
                skip "different file semantics", 0;
            }
            else {
                ok t_cmp($finfo->$method(),
                         $stat->{$method},
                         "\$finfo->$method()");
            }
        }
    }

    # stat tests (same as perl's stat)
    {

        # XXX: untested
        # ->name

        # XXX: are there any platforms csize is available at all?
        # We don't want to see the skipped message all the time if
        # it's not really used anywhere
        # if (my $csize = $finfo->csize) {
        #     # The storage size is at least as big as the file size
        #     # perl's stat() doesn't have the equivalent of csize
        #     t_debug "csize=$csize, size=$stat{size}";
        #     ok $csize >= $stat{size};
        # }
        # else {
        #     skip "csize is not available on this platform", 0;
        # }

        # match world bits

        # on Win32, there's a bug in the apr library supplied
        # with Apache/2.2 that causes the following two tests
        # to fail. This is slated to be fixed after apr-1.2.7.
        if (WIN32 and APACHE_2_2_PLUS) {
            skip "broken apr stat on Win32", 0;
        }
        else {
            ok t_cmp($finfo->protection & APR::Const::FPROT_WREAD,
                     $stat->{protection} & S_IROTH,
                     '$finfo->protection() & APR::Const::FPROT_WREAD');
        }
        if (WIN32 and APACHE_2_2_PLUS) {
            skip "broken apr stat on Win32", 0;
        }
        else {
            ok t_cmp($finfo->protection & APR::Const::FPROT_WWRITE,
                     $stat->{protection} & S_IWOTH,
                     '$finfo->protection() & APR::Const::FPROT_WWRITE');
        }
        if (WIN32) {
            skip "different file semantics", 0;
        }
        else {
            ok t_cmp($finfo->protection & APR::Const::FPROT_WEXECUTE,
                     $stat->{protection} & S_IXOTH,
                     '$finfo->protection() & APR::Const::FPROT_WEXECUTE');
        }
    }
}

1;
