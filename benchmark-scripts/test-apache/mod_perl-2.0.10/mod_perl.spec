%define         _version 2.0.10
%define         _release 1
%define         _source http://apache.org/dist/perl/mod_perl-2.0.10.tar.gz
%define         _dirname mod_perl-2.0.10
%define         _httpd_min_ver 2.0.47
%define         _perl_min_ver 5.6.1
Name:           mod_perl
Version:        %{_version}
Release:        %{_release}
Summary:        An embedded Perl interpreter for the Apache Web server
Group:          System Environment/Daemons
License:        Apache License, Version 2.0
Packager:       mod_perl Development Team <dev@perl.apache.org>
URL:            http://perl.apache.org/
Source:         %{_source}
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires:       httpd >= %{_httpd_min_ver}
BuildRequires:  perl >= %{_perl_min_ver}
BuildRequires:  httpd-devel >= %{_httpd_min_ver}
BuildRequires:  apr-devel, apr-util-devel

%description
Mod_perl incorporates a Perl interpreter into the Apache web server,
so that the Apache web server can directly execute Perl code.
Mod_perl links the Perl runtime library into the Apache web server and
provides an object-oriented Perl interface for Apache's C language
API.  The end result is a quicker CGI script turnaround process, since
no external Perl interpreter has to be started.

Install mod_perl if you're installing the Apache web server and you'd
like for it to directly incorporate a Perl interpreter.

%package devel
Summary:        Files needed for building XS modules that use mod_perl
Group:          Development/Libraries
Requires:       mod_perl = %{version}-%{release}, httpd-devel

%description devel 
The mod_perl-devel package contains the files needed for building XS
modules that use mod_perl.

%prep
%setup -q -n %{_dirname}

%build
CFLAGS="$RPM_OPT_FLAGS" %{__perl} Makefile.PL </dev/null \
	PREFIX=$RPM_BUILD_ROOT/usr \
	INSTALLDIRS=vendor \
	MP_APXS=%{_sbindir}/apxs
make %{?_smp_mflags} OPTIMIZE="$RPM_OPT_FLAGS"

%install
rm -rf $RPM_BUILD_ROOT
install -d -m 755 $RPM_BUILD_ROOT%{_libdir}/httpd/modules
make install \
    MODPERL_AP_LIBEXECDIR=$RPM_BUILD_ROOT%{_libdir}/httpd/modules \
    MODPERL_AP_INCLUDEDIR=$RPM_BUILD_ROOT%{_includedir}/httpd

# Remove the temporary files.
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} ';'
find $RPM_BUILD_ROOT -type f -name perllocal.pod -exec rm -f {} ';'
find $RPM_BUILD_ROOT -type f -name '*.bs' -a -size 0 -exec rm -f {} ';'
find $RPM_BUILD_ROOT -type d -depth -exec rmdir {} 2>/dev/null ';'

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc Changes LICENSE README* STATUS SVN-MOVE docs/
%{_bindir}/*
%{_libdir}/httpd/modules/mod_perl.so
%{perl_vendorarch}/auto/*
%{perl_vendorarch}/Apache/
%{perl_vendorarch}/Apache2/
%{perl_vendorarch}/Bundle/
%{perl_vendorarch}/APR/
%{perl_vendorarch}/ModPerl/
%{perl_vendorarch}/*.pm
%{_mandir}/man?/*

%files devel
%defattr(-,root,root,-)
%{_includedir}/httpd/*

%changelog
