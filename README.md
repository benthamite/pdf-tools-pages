# `pdf-tools-pages`: Extract and delete pages in PDF documents

## Overview

`pdf-tools-pages` extends [pdf-tools](https://github.com/politza/pdf-tools), the Emacs PDF viewer, with page-level manipulation capabilities. While `pdf-tools` provides excellent support for viewing, annotating, and searching PDF documents, it does not offer built-in commands for structural operations such as extracting a subset of pages into a new file or removing unwanted pages from an existing document. `pdf-tools-pages` fills this gap.

The package provides a simple two-phase workflow: first, navigate through the PDF and toggle pages into a selection set using a single DWIM command; then, either extract the selected pages to a new PDF file or delete them from the current document. The selection is maintained per buffer, so you can work with multiple PDFs simultaneously without interference.

Under the hood, page manipulation is performed by [qpdf](https://github.com/qpdf/qpdf), a mature command-line tool for structural, content-preserving transformations of PDF files. `qpdf` must be installed separately.

## Installation

`pdf-tools-pages` requires Emacs 26.1 or later.

### Dependencies

- [pdf-tools](https://github.com/politza/pdf-tools) 1.0 or later, installed and configured.
- [qpdf](https://github.com/qpdf/qpdf), available on your system's `PATH`.

On macOS, you can install `qpdf` with Homebrew:

```shell
brew install qpdf
```

On Debian/Ubuntu:

```shell
sudo apt install qpdf
```

### package-vc (built-in since Emacs 30)

```emacs-lisp
(package-vc-install "https://github.com/benthamite/pdf-tools-pages")
```

### Elpaca

```emacs-lisp
(use-package pdf-tools-pages
  :ensure (pdf-tools-pages :host github :repo "benthamite/pdf-tools-pages"))
```

### straight.el

```emacs-lisp
(straight-use-package
 '(pdf-tools-pages :type git :host github :repo "benthamite/pdf-tools-pages"))
```

## Quick start

```emacs-lisp
(use-package pdf-tools-pages
  :after pdf-tools
  :bind (:map pdf-view-mode-map
              ("C-c s" . pdf-tools-pages-select-dwim)))
```

Open a PDF, navigate to a page you want to select, and press `C-c s`. The command toggles the current page in the selection and automatically advances to the next page. Repeat for additional pages. Once your selection is complete, run `M-x pdf-tools-pages-extract-selected-pages` to save the selected pages to a new file, or `M-x pdf-tools-pages-delete-selected-pages` to remove them from the current document.

## Documentation

For a comprehensive description of all user options, commands, and functions, see the [manual](readme.org).

## License

`pdf-tools-pages` is licensed under the [GPL-3.0](COPYING.txt).
