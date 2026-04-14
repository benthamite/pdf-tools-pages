;;; pdf-tools-pages-test.el --- Tests for pdf-tools-pages -*- lexical-binding: t -*-

;; Copyright (C) 2024-2026 Pablo Stafforini

;;; Commentary:

;; ERT test suite for `pdf-tools-pages'.  All pdf-tools functions are mocked
;; with `cl-letf' since the pdf server cannot run in CI.
;;
;; Note: `pdf-view-current-page' is a macro expanding to
;; `(image-mode-window-get \\='page WINDOW)', so tests mock
;; `image-mode-window-get' rather than `pdf-view-current-page'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'pdf-tools-pages)

;;;; Helpers

(defmacro pdf-tools-pages-test-with-mock-buffer (&rest body)
  "Execute BODY in a temporary buffer simulating `pdf-view-mode'.
Sets `buffer-file-name' to a dummy path so that functions calling
`buffer-file-name' work without mocking the C primitive."
  (declare (indent 0))
  `(with-temp-buffer
     (setq major-mode 'pdf-view-mode)
     (setq buffer-file-name "/tmp/test-input.pdf")
     (setq pdf-tools-pages-selected-pages '())
     ,@body))

(defmacro pdf-tools-pages-test-with-page (page &rest body)
  "Execute BODY with `image-mode-window-get' returning PAGE.
Mock `image-mode-winprops' to prevent window-related errors."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'image-mode-window-get)
              (lambda (prop &optional _win)
                (when (eq prop 'page) ,page)))
             ((symbol-function 'image-mode-winprops)
              #'ignore))
     ,@body))

;;;; Ensure functions

(ert-deftest pdf-tools-pages-test-ensure-pdf-view-mode-passes ()
  "Succeed when buffer is in `pdf-view-mode'."
  (pdf-tools-pages-test-with-mock-buffer
    (should (eq (pdf-tools-pages-ensure-pdf-view-mode) nil))))

(ert-deftest pdf-tools-pages-test-ensure-pdf-view-mode-fails ()
  "Signal error when buffer is not in `pdf-view-mode'."
  (with-temp-buffer
    (should-error (pdf-tools-pages-ensure-pdf-view-mode)
                  :type 'user-error)))

(ert-deftest pdf-tools-pages-test-ensure-qpdf-passes ()
  "Succeed when `qpdf' is available."
  (cl-letf (((symbol-function 'executable-find)
             (lambda (_prog) "/usr/bin/qpdf")))
    (should (eq (pdf-tools-pages-ensure-qpdf) nil))))

(ert-deftest pdf-tools-pages-test-ensure-qpdf-fails ()
  "Signal error when `qpdf' is not available."
  (cl-letf (((symbol-function 'executable-find)
             (lambda (_prog) nil)))
    (should-error (pdf-tools-pages-ensure-qpdf)
                  :type 'user-error)))

(ert-deftest pdf-tools-pages-test-ensure-selection-passes ()
  "Succeed when pages are selected."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(1 3 5))
    (should (eq (pdf-tools-pages-ensure-selection) nil))))

(ert-deftest pdf-tools-pages-test-ensure-selection-fails ()
  "Signal error when no pages are selected."
  (pdf-tools-pages-test-with-mock-buffer
    (should-error (pdf-tools-pages-ensure-selection)
                  :type 'user-error)))

;;;; Selection functions

(ert-deftest pdf-tools-pages-test-add-page-new ()
  "Add a page that is not already selected."
  (pdf-tools-pages-test-with-mock-buffer
    (pdf-tools-pages-test-with-page 3
      (pdf-tools-pages-add-page)
      (should (equal pdf-tools-pages-selected-pages '(3))))))

(ert-deftest pdf-tools-pages-test-add-page-duplicate ()
  "Adding an already-selected page does not create duplicates."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(3))
    (pdf-tools-pages-test-with-page 3
      (pdf-tools-pages-add-page)
      (should (equal pdf-tools-pages-selected-pages '(3))))))

(ert-deftest pdf-tools-pages-test-add-page-sorted ()
  "Pages are kept in sorted order after adding."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(1 5))
    (pdf-tools-pages-test-with-page 3
      (pdf-tools-pages-add-page)
      (should (equal pdf-tools-pages-selected-pages '(1 3 5))))))

(ert-deftest pdf-tools-pages-test-remove-page ()
  "Remove a selected page from the list."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(1 3 5))
    (pdf-tools-pages-test-with-page 3
      (pdf-tools-pages-remove-page)
      (should (equal pdf-tools-pages-selected-pages '(1 5))))))

(ert-deftest pdf-tools-pages-test-remove-page-not-selected ()
  "Removing a page that is not selected leaves the list unchanged."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(1 5))
    (pdf-tools-pages-test-with-page 3
      (pdf-tools-pages-remove-page)
      (should (equal pdf-tools-pages-selected-pages '(1 5))))))

(ert-deftest pdf-tools-pages-test-clear-page-selection ()
  "Clear all selected pages."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(1 2 3))
    (pdf-tools-pages-clear-page-selection)
    (should (equal pdf-tools-pages-selected-pages '()))))

(ert-deftest pdf-tools-pages-test-get-current-selection ()
  "Return a formatted string of the current selection."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(1 3 5))
    (should (string-match-p "1 3 5"
                            (pdf-tools-pages-get-current-selection)))))

(ert-deftest pdf-tools-pages-test-get-current-selection-empty ()
  "Return a formatted string when selection is empty."
  (pdf-tools-pages-test-with-mock-buffer
    (should (string-match-p "nil"
                            (pdf-tools-pages-get-current-selection)))))

;;;; Select DWIM

(ert-deftest pdf-tools-pages-test-select-dwim-adds-page ()
  "DWIM adds current page when not already selected."
  (pdf-tools-pages-test-with-mock-buffer
    (pdf-tools-pages-test-with-page 2
      (cl-letf (((symbol-function 'pdf-cache-number-of-pages) (lambda () 10))
                ((symbol-function 'pdf-view-next-page) (lambda () nil))
                ((symbol-function 'executable-find)
                 (lambda (_prog) "/usr/bin/qpdf")))
        (pdf-tools-pages-select-dwim)
        (should (member 2 pdf-tools-pages-selected-pages))))))

(ert-deftest pdf-tools-pages-test-select-dwim-removes-page ()
  "DWIM removes current page when already selected."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(2))
    (pdf-tools-pages-test-with-page 2
      (cl-letf (((symbol-function 'pdf-cache-number-of-pages) (lambda () 10))
                ((symbol-function 'pdf-view-next-page) (lambda () nil))
                ((symbol-function 'executable-find)
                 (lambda (_prog) "/usr/bin/qpdf")))
        (pdf-tools-pages-select-dwim)
        (should-not (member 2 pdf-tools-pages-selected-pages))))))

(ert-deftest pdf-tools-pages-test-select-dwim-no-advance-on-last-page ()
  "DWIM does not advance when on the last page."
  (let (advanced)
    (pdf-tools-pages-test-with-mock-buffer
      (pdf-tools-pages-test-with-page 5
        (cl-letf (((symbol-function 'pdf-cache-number-of-pages) (lambda () 5))
                  ((symbol-function 'pdf-view-next-page)
                   (lambda () (setq advanced t)))
                  ((symbol-function 'executable-find)
                   (lambda (_prog) "/usr/bin/qpdf")))
          (pdf-tools-pages-select-dwim)
          (should-not advanced))))))

;;;; Execute qpdf

(ert-deftest pdf-tools-pages-test-execute-qpdf-extract ()
  "Build correct args for extracting pages to an output file."
  (let (captured-args)
    (pdf-tools-pages-test-with-mock-buffer
      (cl-letf (((symbol-function 'call-process)
                 (lambda (_prog _infile _dest _display &rest args)
                   (setq captured-args args)
                   0)))
        (pdf-tools-pages-execute-qpdf '(1 3 5) "/tmp/output.pdf")
        (should (equal (nth 0 captured-args) "/tmp/test-input.pdf"))
        (should (equal (nth 1 captured-args) "--pages"))
        (should (equal (nth 2 captured-args) "."))
        (should (equal (nth 3 captured-args) "1,3,5"))
        (should (equal (nth 4 captured-args) "--"))
        (should (string-match-p "output\\.pdf" (nth 5 captured-args)))))))

(ert-deftest pdf-tools-pages-test-execute-qpdf-replace ()
  "Build correct args for in-place replacement."
  (let (captured-args)
    (pdf-tools-pages-test-with-mock-buffer
      (cl-letf (((symbol-function 'call-process)
                 (lambda (_prog _infile _dest _display &rest args)
                   (setq captured-args args)
                   0)))
        (pdf-tools-pages-execute-qpdf '(2 4))
        (should (equal (nth 0 captured-args) "/tmp/test-input.pdf"))
        (should (equal (nth 3 captured-args) "2,4"))
        (should (equal (nth 5 captured-args) "--replace-input"))))))

(ert-deftest pdf-tools-pages-test-execute-qpdf-warning-exit-code ()
  "Exit code 3 (warnings) should not signal an error."
  (pdf-tools-pages-test-with-mock-buffer
    (cl-letf (((symbol-function 'call-process)
               (lambda (_prog _infile _dest _display &rest _args) 3)))
      (should (eq (pdf-tools-pages-execute-qpdf '(1)) nil)))))

(ert-deftest pdf-tools-pages-test-execute-qpdf-failure ()
  "Non-zero, non-3 exit code should signal an error."
  (pdf-tools-pages-test-with-mock-buffer
    (cl-letf (((symbol-function 'call-process)
               (lambda (_prog _infile _dest _display &rest _args) 2)))
      (should-error (pdf-tools-pages-execute-qpdf '(1))
                    :type 'user-error))))

(ert-deftest pdf-tools-pages-test-execute-qpdf-single-page ()
  "Page spec for a single page is just that number."
  (let (captured-args)
    (pdf-tools-pages-test-with-mock-buffer
      (cl-letf (((symbol-function 'call-process)
                 (lambda (_prog _infile _dest _display &rest args)
                   (setq captured-args args)
                   0)))
        (pdf-tools-pages-execute-qpdf '(7) "/tmp/out.pdf")
        (should (equal (nth 3 captured-args) "7"))))))

;;;; Buffer-local isolation

(ert-deftest pdf-tools-pages-test-buffer-local-isolation ()
  "Each buffer maintains an independent page selection."
  (let (buf-a-pages buf-b-pages)
    (with-temp-buffer
      (setq major-mode 'pdf-view-mode)
      (setq pdf-tools-pages-selected-pages '())
      (pdf-tools-pages-test-with-page 1
        (pdf-tools-pages-add-page))
      (setq buf-a-pages pdf-tools-pages-selected-pages))
    (with-temp-buffer
      (setq major-mode 'pdf-view-mode)
      (setq pdf-tools-pages-selected-pages '())
      (pdf-tools-pages-test-with-page 9
        (pdf-tools-pages-add-page))
      (setq buf-b-pages pdf-tools-pages-selected-pages))
    (should (equal buf-a-pages '(1)))
    (should (equal buf-b-pages '(9)))))

;;;; Extract and delete (integration-level mocks)

(ert-deftest pdf-tools-pages-test-extract-clears-selection ()
  "Extracting pages clears the selection afterward."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(1 2 3))
    (cl-letf (((symbol-function 'call-process)
               (lambda (_prog _infile _dest _display &rest _args) 0)))
      (pdf-tools-pages-extract-selected-pages "/tmp/out.pdf")
      (should (equal pdf-tools-pages-selected-pages '())))))

(ert-deftest pdf-tools-pages-test-extract-requires-selection ()
  "Extracting with no selection signals an error."
  (pdf-tools-pages-test-with-mock-buffer
    (should-error (pdf-tools-pages-extract-selected-pages "/tmp/out.pdf")
                  :type 'user-error)))

(ert-deftest pdf-tools-pages-test-delete-computes-complement ()
  "Deleting selected pages passes the complement to qpdf."
  (let (captured-args)
    (pdf-tools-pages-test-with-mock-buffer
      (setq pdf-tools-pages-selected-pages '(2 4))
      (pdf-tools-pages-test-with-page 1
        (cl-letf (((symbol-function 'pdf-cache-number-of-pages)
                   (lambda () 5))
                  ((symbol-function 'yes-or-no-p) (lambda (_prompt) t))
                  ((symbol-function 'revert-buffer)
                   (lambda (_ignore-auto _noconfirm) nil))
                  ((symbol-function 'call-process)
                   (lambda (_prog _infile _dest _display &rest args)
                     (setq captured-args args)
                     0)))
          (pdf-tools-pages-delete-selected-pages)
          (should (equal (nth 3 captured-args) "1,3,5"))
          (should (equal pdf-tools-pages-selected-pages '())))))))

(ert-deftest pdf-tools-pages-test-delete-aborted-by-user ()
  "Aborting the confirmation prompt leaves selection intact."
  (pdf-tools-pages-test-with-mock-buffer
    (setq pdf-tools-pages-selected-pages '(2 4))
    (pdf-tools-pages-test-with-page 1
      (cl-letf (((symbol-function 'pdf-cache-number-of-pages) (lambda () 5))
                ((symbol-function 'yes-or-no-p) (lambda (_prompt) nil)))
        (pdf-tools-pages-delete-selected-pages)
        (should (equal pdf-tools-pages-selected-pages '(2 4)))))))

(provide 'pdf-tools-pages-test)
;;; pdf-tools-pages-test.el ends here
