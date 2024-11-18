;;; pdf-tools-pages.el --- Extract and delete pages in PDF documents -*- lexical-binding: t -*-

;; Copyright (C) 2024

;; Author: Pablo Stafforini
;; URL: https://github.com/benthamite/pdf-tools-pages
;; Version: 0.1

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

(require 'pdf-tools)

;;;; Variables

(defvar pdf-tools-pages-selected-pages '()
  "List of pages selected for extraction.")

;;;; Functions

;;;###autoload
(defun pdf-tools-pages-select-dwim ()
  "Add current page to the selection, or remove it if already included."
  (interactive)
  (pdf-tools-pages-ensure-qpdf)
  (if (member (pdf-view-current-page) pdf-tools-pages-selected-pages)
      (pdf-tools-pages-remove-page)
    (pdf-tools-pages-add-page))
  (when (< (pdf-view-current-page) (pdf-cache-number-of-pages))
    (pdf-view-next-page))
  (setq pdf-tools-pages-selected-pages (sort pdf-tools-pages-selected-pages #'<)))

(defun pdf-tools-pages-add-page ()
  "Add current page number to list of selected pages."
  (add-to-list 'pdf-tools-pages-selected-pages (pdf-view-current-page) t)
  (setq pdf-tools-pages-selected-pages (sort pdf-tools-pages-selected-pages #'<))
  (message (concat "Page added. " (pdf-tools-pages-get-current-selection))))

(defun pdf-tools-pages-remove-page ()
  "Remove current page number from list of selected pages."
  (setq pdf-tools-pages-selected-pages (delete (pdf-view-current-page) pdf-tools-pages-selected-pages)
        pdf-tools-pages-selected-pages (sort pdf-tools-pages-selected-pages #'<))
  (message (concat "Page removed. "
		   (if pdf-tools-pages-selected-pages
		       (pdf-tools-pages-get-current-selection)
		     "There are currently no selected pages"))))

;;;;; Ensure

(defun pdf-tools-pages-ensure-qpdf ()
  "Check if `qpdf' is installed and available."
  (unless (executable-find "qpdf")
    (user-error "This package requires `qpdf' (https://github.com/qpdf/qpdf)")))

(defun pdf-tools-pages-ensure-selection ()
  "Ensure that there are pages selected."
  (unless pdf-tools-pages-selected-pages
    (user-error "No pages selected")))

;;;;; Selection

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
  (interactive)
  (pdf-tools-pages-ensure-selection)
  (pdf-tools-pages-execute-qpdf pdf-tools-pages-selected-pages file)
  (pdf-tools-pages-clear-page-selection))

;;;###autoload
(defun pdf-tools-pages-delete-selected-pages ()
  "Delete pages selected in `pdf-tools-pages-selected-pages' from current file."
  (interactive)
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
If OUTPUT-FILE is nil, modify the input file in place."
  (let ((output (or output-file "--replace-input")))
    (condition-case err
        (shell-command
         (format "qpdf '%s' --pages . %s -- %s"
                 (buffer-file-name)
                 (mapconcat #'number-to-string pages ",")
                 output))
      (error (user-error "Failed to execute qpdf command: %s"
                         (error-message-string err))))))

(provide 'pdf-tools-pages)
;;; pdf-tools-pages.el ends here

