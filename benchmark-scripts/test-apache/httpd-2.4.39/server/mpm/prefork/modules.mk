libprefork.la: prefork.lo
	$(MOD_LINK) prefork.lo
DISTCLEAN_TARGETS = modules.mk
static = libprefork.la
shared =
