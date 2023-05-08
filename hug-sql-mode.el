;;; hug-sql-mode.el --- HugSQL mode
;;
;; Author: Andrei Fedorov
;; URL: https://github.com/yourusername/my-package
;; Version: 0.1
;; Package-Requires: ((emacs "24.4") (clojure-mode "5.1.0"))
;; Keywords: sql clojure hugsql
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

;;; Commentary:

;; Provides font-lock for HugSQL (https://www.hugsql.org).

;;; Code:

(require 'rx)

(defconst clj-string
  (rx "\"" (* nonl) "\"")
  "Matches Clojure string literal.")

(defconst clj-single-line-exp
  (rx (group "--")
      (group "~")
      " "
      (group "(" (+ nonl) ")"))
  "Group 3 matches Clojure single line expressions.")

(defconst clj-multiline-exp
  (rx (group "/*")
      (group "~")
      " "
      (group (+? nonl))
      (? (group "~"))
      (group "*/"))
  "Group 3 matches Clojure multiline expressions.")

(defconst clj-keyword
  (rx (group (or bol (not ":")))
      (group ":"
             (+ (group (any alnum "-+_<>.*/?")))))
  "Group 2 matches Clojure keyword.")

(defconst clj-keyword-namespace
  (rx (group (or bol (not ":")))
      (group ":")
      (group (+ (any alnum "-+_<>.*?")))
      (group "/"))
  "Group 3 matches Clojure keyword namespace.
   Group 4 matches forward slash.")

(defconst sql-functon-name
  (rx (group ":name ")
      (group (+ (any alnum "-+_<>.*/?"))))
  "Group 3 matches HugSQL function name.")

(defvar hug-sql-mode-keywords
  `((,clj-string 0 'clojure-character-face t)
    (,clj-multiline-exp 3 'font-lock-function-name-face t)
    (,clj-keyword 2 'clojure-keyword-face t)
    (,clj-keyword-namespace (3 'font-lock-type-face t)
                            (4 'default t))
    (,sql-functon-name 2 'font-lock-function-name-face t)))

(defvar hug-sql--installed-keywords nil)

(defun hug-sql-add-keywords ()
  (when (local-variable-p 'hug-sql--installed-keywords)
    (font-lock-remove-keywords nil hug-sql--installed-keywords))
  (let ((keywords hug-sql-mode-keywords))
    (set (make-local-variable 'hug-sql--installed-keywords)
         keywords)
    (font-lock-add-keywords nil keywords 'append)))

(defun hug-sql-remove-keywords ()
  (font-lock-remove-keywords nil hug-sql--installed-keywords))

(define-minor-mode hug-sql-mode
  "Minor mode for HugSQL support in SQL buffers."
  :lighter "HugSQL"
  :keymap (make-sparse-keymap)
  (if hug-sql-mode
      (font-lock-add-keywords nil hug-sql-mode-keywords 'append)
    (font-lock-remove-keywords nil hug-sql-mode-keywords))
  ;; (if hug-sql-mode
  ;;     (hug-sql-add-keywords)
  ;;   (hug-sql-remove-keywords))
  (font-lock-flush))

;;;###autoload
(add-hook 'sql-mode-hook 'hug-sql-mode)

(provide 'hug-sql-mode)
