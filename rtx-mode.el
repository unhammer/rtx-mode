;;; rtx-mode.el --- major mode for editing RTX files

;; Copyright (C) 2021 Kevin Brubeck Unhammer

;; Author: Kevin Brubeck Unhammer <unhammer@fsfe.org>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (tree-sitter-langs "0.10.7"))
;; Url: http://wiki.apertium.org/wiki/Emacs
;; Keywords: languages

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Provides syntax highlighting for apertium-recursive .rtx files

;; Usage:
;;
;; (use-package rtx-mode
;;   :defer t
;;   :mode (("\\.rtx\\'" . rtx-mode))
;;   :config
;;   (add-hook 'rtx-mode-hook #'tree-sitter-mode))

;;; Code:

(defconst rtx-mode-version "0.1.0" "Version of rtx-mode.")

(require 'xref)

;;;============================================================================
;;;
;;; Define the formal stuff for a major mode named rtx.
;;;

(defgroup rtx-mode nil
  "Major mode for editing RTX source files."
  :tag "RTX"
  :group 'languages)

(defvar rtx-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?% "." table)
    (modify-syntax-entry ?$ "." table)
    (modify-syntax-entry ?= "." table)
    table)
  "Syntax table for RTX mode.")

;;;###autoload
(define-derived-mode rtx-mode prog-mode "RTX"
  "Major mode for editing apertium-recursive .rtx-files.
RTX-mode provides the following specific keyboard key bindings:

\\{rtx-mode-map}"
  (set (make-local-variable 'comment-start) "!")
  (set (make-local-variable 'comment-start-skip) "!+[\t ]*"))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.rtx$" . rtx-mode))

;;; Interactive functions -----------------------------------------------------

(defun rtx-mode-goto-definition ()
  "Go to definition (attribute category or output pattern) of symbol at point."
  ;; TODO: Use tree-sitter query instead
  (interactive)
  (when-let* ((thing (thing-at-point 'symbol))
              (delim (if (save-excursion
                           (goto-char (car (bounds-of-thing-at-point 'symbol)))
                           (looking-back "%" (- (point) 1)))
                         ":"
                       "="))
              (match (save-excursion
                       (goto-char (point-min))
                       (re-search-forward (format "^\\s *%s\\s *%s"
                                                  (regexp-quote thing)
                                                  delim)
                                          nil
                                          'noerror))))
    (xref--push-markers)
    (goto-char match)))

;;; Keybindings --------------------------------------------------------------
(define-key rtx-mode-map (kbd "M-.") #'rtx-mode-goto-definition)
(define-key rtx-mode-map (kbd "M-,") #'pop-to-mark-command)

;;; Run hooks -----------------------------------------------------------------
(run-hooks 'rtx-mode-load-hook)

(provide 'rtx-mode)

;;;============================================================================

;;; rtx-mode.el ends here
