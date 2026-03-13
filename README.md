# hug-sql-mode

An Emacs minor mode that adds syntax highlighting for [HugSQL](https://www.hugsql.org/) SQL template files.

HugSQL embeds Clojure expressions and parameter declarations inside SQL comments. This mode highlights them on top of the standard `sql-mode`.

## Highlighted syntax

| Syntax | Description |
|---|---|
| `-- :name fn-name :? :1` | Function declarations |
| `-- :doc description` | Documentation strings |
| `:id`, `:v:name`, `:i*:cols`, `:tuple*:values` | Parameter keywords |
| `--~ (clojure-expr)` | Single-line Clojure expressions |
| `/*~ clojure-expr ~*/` | Multi-line Clojure expressions |
| `/*~*/` | Clojure expression separators |
| `/* :require [...] */` | Clojure require blocks |

## Installation

### straight.el

```elisp
(straight-use-package
 '(hug-sql-mode :type git :host github :repo "not-in-stock/hug-sql-mode"))
```

### use-package + straight.el

```elisp
(use-package hug-sql-mode
  :straight (:host github :repo "not-in-stock/hug-sql-mode")
  :hook (sql-mode . hug-sql-mode))
```

### Manual

Clone the repository and add to your load path:

```elisp
(add-to-list 'load-path "/path/to/hug-sql-mode")
(require 'hug-sql-mode)
(add-hook 'sql-mode-hook #'hug-sql-mode)
```

## Usage

The mode does not activate automatically. Add the hook to your init file:

```elisp
(add-hook 'sql-mode-hook #'hug-sql-mode)
```

Or enable manually in a SQL buffer with `M-x hug-sql-mode`.

## Requirements

- Emacs 25.1+

## License

GPLv3
