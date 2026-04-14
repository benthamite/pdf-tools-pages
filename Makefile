EMACS ?= emacs
ELPACA_REPOS := $(dir $(CURDIR))
LOAD_PATH := -L $(CURDIR) -L $(ELPACA_REPOS)pdf-tools/lisp

.PHONY: test compile clean

test:
	$(EMACS) -Q --batch $(LOAD_PATH) \
	  -l pdf-tools-pages.el \
	  -l pdf-tools-pages-test.el \
	  -f ert-run-tests-batch-and-exit

compile:
	$(EMACS) -Q --batch $(LOAD_PATH) \
	  --eval '(setq byte-compile-error-on-warn t)' \
	  -f batch-byte-compile pdf-tools-pages.el

clean:
	rm -f *.elc
