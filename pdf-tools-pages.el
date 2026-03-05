;;; pdf-tools-pages.el --- Extract and delete pages in PDF documents -*- lexical-binding: t -*-

;; Copyright (C) 2024-2026 Pablo Stafforini

;; Author: Pablo Stafforini
;; URL: https://github.com/benthamite/pdf-tools-pages
;; Version: 0.2
;; Package-Requires: ((emacs "26.1") (pdf-tools "1.0"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Simple `pdf-tools' extension to extract and delete pages in PDF documents.

;;; Code:

(require 'cl-lib)
(require 'pdf-tools)

;;;; Variables

(defvar-local pdf-tools-pages-selected-pages '()
  "List of pages selected for extraction.
This variable is buffer-local so that each PDF buffer maintains its own
independent page selection.")

;;;; Functions

;;;;; Ensure

(defun pdf-tools-pages-ensure-pdf-view-mode ()
  "Signal an error unless the current buffer is in `pdf-view-mode'."
  (unless (derived-mode-p 'pdf-view-mode)
    (user-error "This command can only be used in a `pdf-view-mode' buffer")))

(defun pdf-tools-pages-ensure-qpdf ()
  "Signal an error unless `qpdf' is installed and available."
  (unless (executable-find "qpdf")
    (user-error "This package requires `qpdf' (https://github.com/qpdf/qpdf)")))

(defun pdf-tools-pages-ensure-selection ()
  "Signal an error unless there are pages selected."
  (unless pdf-tools-pages-selected-pages
    (user-error "No pages selected")))

;;;;; Selection

;;;###autoload
(defun pdf-tools-pages-select-dwim ()
  "Add current page to the selection, or remove it if already included.
After toggling, advance to the next page if not on the last page."
  (interactive)
  (pdf-tools-pages-ensure-pdf-view-mode)
  (pdf-tools-pages-ensure-qpdf)
  (if (member (pdf-view-current-page) pdf-tools-pages-selected-pages)
      (pdf-tools-pages-remove-page)
    (pdf-tools-pages-add-page))
  (when (< (pdf-view-current-page) (pdf-cache-number-of-pages))
    (pdf-view-next-page)))

(defun pdf-tools-pages-add-page ()
  "Add current page number to list of selected pages."
  (let ((page (pdf-view-current-page)))
    (unless (member page pdf-tools-pages-selected-pages)
      (push page pdf-tools-pages-selected-pages)
      (setq pdf-tools-pages-selected-pages
            (sort pdf-tools-pages-selected-pages #'<))))
  (message (concat "Page added. " (pdf-tools-pages-get-current-selection))))

(defun pdf-tools-pages-remove-page ()
  "Remove current page number from list of selected pages."
  (setq pdf-tools-pages-selected-pages
        (delq (pdf-view-current-page) pdf-tools-pages-selected-pages))
  (message (concat "Page removed. "
                   (if pdf-tools-pages-selected-pages
                       (pdf-tools-pages-get-current-selection)
                     "There are currently no selected pages."))))

(defun pdf-tools-pages-get-current-selection ()
  "Return the current selection of pages as a string."
  (format "Current selection: %s." pdf-tools-pages-selected-pages))

;;;###autoload
(defun pdf-tools-pages-clear-page-selection ()
  "Clear the list of pages selected in `pdf-tools-pages-selected-pages'."
  (interactive)
  (setq pdf-tools-pages-selected-pages '())
  (message "Page selection cleared."))

;;;;; Extraction & deletion

;;;###autoload
(defun pdf-tools-pages-extract-selected-pages (file)
  "Save pages selected in `pdf-tools-pages-selected-pages' to FILE."
  (interactive "FOutput file: ")
  (pdf-tools-pages-ensure-pdf-view-mode)
  (pdf-tools-pages-ensure-selection)
  (pdf-tools-pages-execute-qpdf pdf-tools-pages-selected-pages file)
  (pdf-tools-pages-clear-page-selection))

;;;###autoload
(defun pdf-tools-pages-delete-selected-pages ()
  "Delete pages selected in `pdf-tools-pages-selected-pages' from current file."
  (interactive)
  (pdf-tools-pages-ensure-pdf-view-mode)
  (pdf-tools-pages-ensure-selection)
  (when (yes-or-no-p (concat (pdf-tools-pages-get-current-selection)
                             " Delete selected pages from current PDF? "))
    (let ((pages-to-keep (cl-set-difference
                          (number-sequence 1 (pdf-cache-number-of-pages))
                          pdf-tools-pages-selected-pages)))
      (pdf-tools-pages-execute-qpdf pages-to-keep)
      (revert-buffer nil t)
      (pdf-tools-pages-clear-page-selection)
      (message "Selected pages deleted."))))

(defun pdf-tools-pages-execute-qpdf (pages &optional output-file)
  "Execute qpdf command on PAGES with optional OUTPUT-FILE.
If OUTPUT-FILE is nil, modify the input file in place.
Uses `call-process' to avoid shell injection vulnerabilities."
  (let* ((input-file (buffer-file-name))
         (page-spec (mapconcat #'number-to-string pages ","))
         (args (if output-file
                   (list input-file "--pages" "." page-spec "--"
                         (expand-file-name output-file))
                 (list input-file "--pages" "." page-spec "--"
                       "--replace-input")))
         (exit-code (apply #'call-process "qpdf" nil nil nil args)))
    ;; qpdf exit code 0 = success, 3 = warnings (operation succeeded).
    ;; Any other code indicates failure.
    (unless (memq exit-code '(0 3))
      (user-error "qpdf failed (exit code %d); check *Messages* for details"
                  exit-code))))

(provide 'pdf-tools-pages)
;;; pdf-tools-pages.el ends here
