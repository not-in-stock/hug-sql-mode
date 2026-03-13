;;; hug-sql-mode.el --- HugSQL syntax highlighting for SQL buffers -*- lexical-binding: t; -*-
;;
;; Author: Andrei Fedorov
;; URL: https://github.com/not-in-stock/hug-sql-mode
;; Version: 0.2.0
;; Package-Requires: ((emacs "25.1"))
;; Keywords: languages sql
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

;;; Commentary:

;; Provides font-lock highlighting for HugSQL (https://www.hugsql.org)
;; SQL template files with embedded Clojure expressions and HugSQL
;; parameters.
;;
;; HugSQL uses special syntax in SQL comments to embed Clojure:
;;   --~ (single-line-expr)        single-line Clojure expression
;;   /*~ multi-line-expr ~*/       multi-line Clojure expression
;;   /*~*/                         Clojure expression separator
;;   :keyword, :v:name, :i*:cols  HugSQL parameter types
;;   -- :name fn-name :? :1       function declaration
;;   /* :require [...] */          Clojure require block
;;
;; Activate with `M-x hug-sql-mode' in a SQL buffer, or add to your
;; init file for automatic activation:
;;   (add-hook 'sql-mode-hook #'hug-sql-mode)

;;; Code:

(eval-when-compile (require 'rx))

(defgroup hug-sql nil
  "HugSQL support for SQL buffers."
  :group 'languages
  :prefix "hug-sql-")

;;; Font-lock regexp matchers

(defconst hug-sql-mode--single-line-exp
  (rx (group "--")
      (group "~")
      " "
      (group "(" (+ nonl) ")"))
  "Single-line Clojure expression: --~ (expr).
Group 2: ~ marker, Group 3: expression.")

(defconst hug-sql-mode--keyword
  (rx (group (or bol (not ":")))
      (group ":" (+ (any alnum "-+_<>.*/?!"))))
  "HugSQL parameter keyword.
Group 2: the keyword including colon.")

(defconst hug-sql-mode--keyword-namespace
  (rx (group (or bol (not ":")))
      (group ":")
      (group (+ (any alnum "-+_<>.*?")))
      (group "/"))
  "Namespaced HugSQL keyword.
Group 3: namespace, Group 4: forward slash.")

(defconst hug-sql-mode--function-name
  (rx ":name "
      (group (+ (any alnum "-+_<>.*/?"))))
  "HugSQL function name declaration.
Group 1: function name.")

(defconst hug-sql-mode--doc-string
  (rx bol (* space) "-- :doc "
      (group (+ nonl)))
  "HugSQL documentation string: -- :doc ...
Group 1: doc text.")

(defun hug-sql-mode--match-require-block (limit)
  "Match /* :require ... */ blocks up to LIMIT.
Sets match groups:
  1 - opening /* :require
  2 - require content
  3 - closing */."
  (when (re-search-forward "/\\* :require" limit t)
    (let ((block-beg (match-beginning 0))
          (content-beg (match-end 0)))
      (when (re-search-forward "\\*/" limit t)
        (let ((content-end (match-beginning 0))
              (block-end (match-end 0)))
          (set-match-data
           (list block-beg block-end
                 block-beg content-beg
                 content-beg content-end
                 (match-beginning 0) block-end))
          t)))))

;;; Font-lock function matchers (for multiline constructs)

(defun hug-sql-mode--match-clj-block (limit)
  "Match /*~...~*/ and /*~...*/ Clojure blocks up to LIMIT.
Uses a search function instead of a regexp so that multiline
content is matched reliably.

Sets match groups:
  1 - opening ~ marker
  2 - Clojure content (may be nil for separators)
  3 - closing ~ marker (may be nil)."
  (when (re-search-forward "/\\*~" limit t)
    (let ((block-beg (match-beginning 0))
          (tilde-beg (- (point) 1))
          (after-open (point)))
      (cond
       ;; /*~*/ — separator (no content)
       ((looking-at "\\*/")
        (goto-char (match-end 0))
        (set-match-data
         (list block-beg (match-end 0)
               tilde-beg (1+ tilde-beg)
               nil nil
               nil nil))
        t)
       ;; /*~ content [~]*/ — block with optional closing tilde
       ((re-search-forward "~?\\*/" limit t)
        (let* ((block-end (match-end 0))
               (match-str (match-string 0))
               (has-closing-tilde (eq ?~ (aref match-str 0)))
               (content-end (match-beginning 0)))
          (set-match-data
           (list block-beg block-end
                 tilde-beg (1+ tilde-beg)
                 after-open content-end
                 (when has-closing-tilde (match-beginning 0))
                 (when has-closing-tilde (1+ (match-beginning 0)))))
          t))))))

;;; Font-lock keywords

(defvar hug-sql-mode--keywords
  `(;; Multiline matchers first (set base face, then overridden by later rules)
    (hug-sql-mode--match-clj-block
     (1 'font-lock-builtin-face t)
     (2 'font-lock-type-face t t)
     (3 'font-lock-builtin-face t t))
    (hug-sql-mode--match-require-block
     (1 'font-lock-preprocessor-face t)
     (2 'font-lock-type-face t)
     (3 'font-lock-preprocessor-face t))
    ;; Inline matchers (override base faces inside blocks)
    (,hug-sql-mode--single-line-exp
     (2 'font-lock-builtin-face t)
     (3 'font-lock-type-face t))
    (,hug-sql-mode--keyword
     2 'font-lock-constant-face t)
    (,hug-sql-mode--keyword-namespace
     (3 'font-lock-type-face t)
     (4 'default t))
    (,hug-sql-mode--function-name
     1 'font-lock-function-name-face t)
    (,hug-sql-mode--doc-string
     1 'font-lock-doc-face t))
  "Font-lock keywords for HugSQL mode.")

;;; Multiline font-lock support

(defvar font-lock-beg)
(defvar font-lock-end)

(defun hug-sql-mode--extend-region ()
  "Extend font-lock region to encompass complete /*~...*/ blocks.
Returns non-nil if the region was extended."
  (save-excursion
    (let ((changed nil))
      ;; If beg is inside a /*~...*/ or /* :require...*/ block, extend
      (goto-char font-lock-beg)
      (let ((open-pos (save-excursion
                        (re-search-backward "/\\*\\(~\\| :require\\)" nil t))))
        (when (and open-pos (< open-pos font-lock-beg))
          (goto-char open-pos)
          ;; Only extend if there's no closing */ between that open and beg
          (unless (re-search-forward "\\*/" font-lock-beg t)
            (setq font-lock-beg open-pos
                  changed t))))
      ;; If end is inside a block, extend to include closing */
      (goto-char font-lock-end)
      (let ((close-pos (save-excursion
                         (re-search-forward "~?\\*/" nil t))))
        (when (and close-pos (> close-pos font-lock-end))
          ;; Check we're actually inside a block
          (save-excursion
            (goto-char font-lock-end)
            (when (re-search-backward "/\\*~" nil t)
              (unless (re-search-forward "\\*/" font-lock-end t)
                (setq font-lock-end close-pos
                      changed t))))))
      changed)))

;;; Minor mode definition

;;;###autoload
(define-minor-mode hug-sql-mode
  "Minor mode for HugSQL support in SQL buffers.
Provides font-lock highlighting for HugSQL-specific syntax
including Clojure expressions, parameter keywords, and function
declarations."
  :lighter " HugSQL"
  (if hug-sql-mode
      (progn
        (font-lock-add-keywords nil hug-sql-mode--keywords)
        (add-hook 'font-lock-extend-region-functions
                  #'hug-sql-mode--extend-region nil t))
    (font-lock-remove-keywords nil hug-sql-mode--keywords)
    (remove-hook 'font-lock-extend-region-functions
                 #'hug-sql-mode--extend-region t))
  (font-lock-flush))

(provide 'hug-sql-mode)
;;; hug-sql-mode.el ends here
