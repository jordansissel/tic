# $Id$
#
# This is fairly straight-forward. If you have a different perl location then
# you should probably specify so on the line below.
#
#
#

PERL       = /usr/bin/perl



# ----------------------------------------------------------------------------
# Nothing user-serviceable below :(

MODULES    = Term::ReadKey Term::Shelly Net::OSCAR

defaut:
	@echo "Run make install-modules to install all the perl modules you need for tic"

install: install-modules install-tic

install-modules:
	@for i in ${MODULES}; do \
		echo -n "Module: $$i "; \
		if perl -M$$i < /dev/null > /dev/null 2>&1; then \
			echo "found"; \
		else \
			echo "not found"; \
			perl -MCPAN -e"install $$i"; \
		fi; \
	done

install-tic:
	install -m 755 -o root -g nobody tic /usr/local/bin

# You don't need this :(
release:
	rm ../tic.tar.gz || true
	tar -C .. -zcf ../tic.tar.gz tic
	scp ../tic.tar.gz fury:public_html/projects/
