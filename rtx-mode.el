;;; rtx-mode.el --- major mode for editing RTX files

;; Copyright (C) 2021-2023 Kevin Brubeck Unhammer

;; Author: Kevin Brubeck Unhammer <unhammer@fsfe.org>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.0"))
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
;;   :mode (("\\.rtx\\'" . rtx-mode)))

;;; Code:

(defconst rtx-mode-version "0.1.0" "Version of rtx-mode.")

(require 'xref)
(require 'treesit)

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

(defcustom rtx-indent-offset 4
  "Basic size of one indentation step."
  :type 'integer
  :safe 'integerp)

(defvar rtx--treesit-indent-rules
  '((rtx
     ((parent-is "reduce_rule_group") parent-bol rtx-indent-offset)
     ((parent-is "reduce_rule") parent-bol rtx-indent-offset)
     ((parent-is "attr_rule") parent-bol rtx-indent-offset)))
  "Tree-sitter indentation rules for `rtx-mode'.")

(defun rtx--treesit-defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (pcase (treesit-node-type node)
    ("attr_rule" (treesit-node-text
                  (treesit-node-child node 0) t))
    ("reduce_rule_group" (treesit-node-text
                          (treesit-node-child node 0) t))))

(defvar rtx--treesit-settings
  (treesit-font-lock-rules
   :feature 'comment
   :language 'rtx
   '((comment) @font-lock-comment-face)

   :feature 'string
   :language 'rtx
   '(((string) @font-lock-string-face))

   :feature 'keyword
   :language 'rtx
   '([(if_tok)
      (elif_tok)
      (else_tok)
      (always_tok)] @font-lock-keyword-face)

   :feature 'function
   :language 'rtx
   '((reduce_rule_group (ident) @font-lock-function-name-face)
     (pattern_element (ident) @font-lock-function-name-face))

   :feature 'constant
   :language 'rtx
   '(
     (set_var (ident) @font-lock-type-face)
     (source_file (attr_rule name: (ident) @font-lock-type-face))
     (attr_set_insert (ident) @font-lock-type-face)
     (clip attr: (ident) @font-lock-type-face)
     (clip val: (ident) @font-lock-constant-face)
     (reduce_output (blank) @font-lock-constant-face)
     )

   :feature 'variable
   :language 'rtx
   '((ident) @font-lock-variable-name-face)

   ;; :language 'rtx
   ;; :feature 'operator
   ;; `([(str_op) "=" "~=" "^=" "|=" "*=" "$="] @font-lock-operator-face)


   :feature 'weight
   :language 'rtx
   '((weight) @font-lock-property-name-face)

   :feature 'bracket
   :language 'rtx
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :feature 'error
   :language 'rtx
   '((ERROR) @error))
  "Tree-sitter font-lock settings for `rtx-mode'.")

;;;###autoload
(define-derived-mode rtx-mode prog-mode "RTX"
  "Major mode for editing apertium-recursive .rtx-files.
RTX-mode provides the following specific keyboard key bindings:

\\{rtx-mode-map}"
  (set (make-local-variable 'comment-start) "!")
  (set (make-local-variable 'comment-start-skip) "!+[\t ]*")

  (if (not (treesit-ready-p 'rtx))
      (message "Run `M-x rtx-install-tree-sitter' to install syntax highlighting, indentation and imenu support.")
    ;; Tree-sitter specific setup.
    (treesit-parser-create 'rtx)
    (setq-local treesit-simple-indent-rules rtx--treesit-indent-rules)
    (setq-local treesit-defun-type-regexp "reduce_rule_group")
    (setq-local treesit-defun-name-function #'rtx--treesit-defun-name)
    (setq-local treesit-font-lock-settings rtx--treesit-settings)
    (setq-local treesit-font-lock-feature-list
                '((selector comment query keyword function)
                  (property constant string weight)
                  (error variable function operator bracket)))
    (setq-local treesit-simple-imenu-settings
                `(( "Reduction" ,(rx bos "reduce_rule_group" eos)
                    nil nil)
                  ( "Attribute" ,(rx bos "attr_rule" eos)
                    nil nil)))
    (treesit-major-mode-setup)))

(defun rtx-install-tree-sitter ()
  "Install the tree-sitter grammar for rtx."
  (interactive)
  (let ((treesit-language-source-alist
         '((rtx "https://github.com/unhammer/tree-sitter-apertium" "tree-sitter-rtx/src" "tree-sitter-rtx"))))
    (treesit-install-language-grammar 'rtx))
  ;; refresh currently open rtx buffers:
  (mapc (lambda (b) (with-current-buffer b
                 (when (eq major-mode 'rtx-mode)
                   (rtx-mode))))
        (buffer-list)))

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
