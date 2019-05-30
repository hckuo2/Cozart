# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::both_str_native_remove;

# this tests verifies that we can remove input and output native
# (non-mod_perl filters)

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Filter ();
use Apache2::FilterRec ();

use APR::Table ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK DECLINED M_POST);

# this filter removes the next filter in chain and itself
sub remove_includes {
    my $f = shift;

    my $args = $f->r->args || '';
    if ($args eq 'remove') {
        my $ff = $f->next;
        $ff->remove if $ff && $ff->frec->name eq 'includes';
    }

    $f->remove;

    return Apache2::Const::DECLINED;
}

# this filter removes the next filter in chain and itself
sub remove_deflate {
    my $f = shift;

    my $args = $f->r->args || '';
    if ($args eq 'remove') {
        for (my $ff = $f->r->input_filters; $ff; $ff = $ff->next) {
            if ($ff->frec->name eq 'deflate') {
                $ff->remove;
                last;
            }
        }
    }
    $f->remove;

    return Apache2::Const::DECLINED;
}

# this filter appends the output filter list at eos
sub print_out_flist {
    my $f = shift;

    unless ($f->ctx) {
        $f->ctx(1);
        $f->r->headers_out->unset('Content-Length');
    }

    while ($f->read(my $buffer, 1024)) {
        $f->print($buffer);
    }

    if ($f->seen_eos) {
        my $flist = join ',', get_flist($f->r->output_filters);
        $f->print("output2: $flist\n");
    }

    return Apache2::Const::OK;
}

sub store_in_flist {
    my $f = shift;
    my $r = $f->r;

    unless ($f->ctx) {
        my $x = $r->pnotes('INPUT_FILTERS') || [];
        push @$x, join ',', get_flist($f->r->input_filters);
        $r->pnotes('INPUT_FILTERS' => $x);
    }

    return Apache2::Const::DECLINED;
}


sub response {
    my $r = shift;

    # just to make sure that print() won't flush, or we would get the
    # count wrong
    local $| = 0;

    $r->content_type('text/plain');
    if ($r->method_number == Apache2::Const::M_POST) {
        $r->print("content: " . TestCommon::Utils::read_post($r) ."\n");
    }

    my $i=1;
    for (@{ $r->pnotes('INPUT_FILTERS')||[] }) {
        $r->print("input$i: $_\n");
        $i++;
    }

    $r->subprocess_env(SSI_TEST => 'SSI OK');
    $r->printf("output1: %s\n", join ',', get_flist($r->output_filters));

    $r->rflush;     # this sends the data in the buffer + flush bucket
    $r->print('x<!--#echo var=');
    $r->rflush;     # this sends the data in the buffer + flush bucket
    $r->print('"SSI_TEST" -->x'."\n");

    Apache2::Const::OK;
}

sub get_flist {
    my $f = shift;

    my @flist = ();
    for (; $f; $f = $f->next) {
        push @flist, $f->frec->name;
    }

    return @flist;
}

1;
__DATA__
Options +Includes
SetHandler modperl
PerlModule              TestFilter::both_str_native_remove
PerlResponseHandler     TestFilter::both_str_native_remove::response
PerlOutputFilterHandler TestFilter::both_str_native_remove::remove_includes
PerlSetOutputFilter     INCLUDES
PerlOutputFilterHandler TestFilter::both_str_native_remove::print_out_flist
PerlInputFilterHandler  TestFilter::both_str_native_remove::store_in_flist
PerlInputFilterHandler  TestFilter::both_str_native_remove::remove_deflate
PerlSetInputFilter      DEFLATE
PerlInputFilterHandler  TestFilter::both_str_native_remove::store_in_flist
