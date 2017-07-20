;;; org-wiki-search.el --- Advanced wikipedia lookup -*- lexical-binding: t; -*-

;; Copyright (C) 2017 Diego A. Mundo
;; Author: Diego A. Mundo <diegoamundo@gmail.com>
;; URL:
;; Git-Repository:
;; Created: 2016-01-20
;; Version: 0.2.2
;; Keywords: reference search wiki
;; Package-Requires: ((emacs "24.3") (cl-lib "0.5") (deferred "0.5.0") (request-deferred "0.3.0") (org "8.2.10") (toc-org "20170324.103"))

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.


;;; Commentary:

;;; Code:

(require 'request)
(require 'cl-lib)
(require 'org)

(defcustom org-wiki-search-window-select t
  "Wether to select wiki window."
  :group 'org-wiki-search
  :type 'boolean)

;;;###autoload
(defun org-wiki-search (arg &optional search-term)
  "Provide wikipedia summary for given SEARCH-TERM.

With prefix argument ARG, go straight to full page in `org-mode' format."
  (interactive "P")
  (let* ((input (if search-term
                    search-term
                  (read-string
                   (concat "Search wiki ["
                           (if (region-active-p)
                               (buffer-substring (region-beginning) (region-end))
                             (thing-at-point 'word)) "]: ")
                   nil nil
                   (thing-at-point 'word))))
         (params (if arg
                     `(("action" . "query")
                       ("prop" . "revisions")
                       ("rvprop" . "content")
                       ("format" . "json")
                       ("redirects" . "")
                       ("titles" . ,input))
                   `(("action" . "query")
                     ("prop" . "extracts")
                     ("format" . "json")
                     ("redirects" . "")
                     ("exintro" . "")
                     ("explaintext" . "")
                     ("titles" . ,input)))))
    (request
     "https://en.wikipedia.org/w/api.php"
     :type "GET"
     :parser 'json-read
     :params params
     :success (cl-function
               (lambda (&key data &allow-other-keys)
                 (let* ((title (cdr (org-wiki-search--assoc-find-key 'title data)))
                        (content (cdr (org-wiki-search--assoc-find-key (if arg '* 'extract) data))))
                   (when (get-buffer "*wiki*")
                     (kill-buffer "*wiki*"))
                   (get-buffer-create "*wiki*")
                   (if (not arg)
                       (with-current-buffer "*wiki*"
                         (org-mode)
                         (insert (concat "#+TITLE: " input "\n"))
                         (insert content)
                         (insert (format "\n[[elisp:(org-wiki-search\"4\"\"%s\")][Read more]]" input))
                         (goto-char (point-min))
                         (while (re-search-forward "\n" nil t)
                           (replace-match "\n\n"))
                         (fill-region (point-min) (point-max))
                         (read-only-mode)
                         (when (featurep 'evil) (evil-motion-state)))
                     (with-current-buffer "*wiki*"
                       ;; (let ((inhibit-redisplay (when search-term t))))
                       (insert content)
                       (goto-char (point-min))
                       (insert (concat title "\n\n"))
                       (call-process-region (point-min)
                                            (point-max)
                                            "pandoc"
                                            t t nil
                                            "-f" "mediawiki" "-t" "org")
                       (goto-char (point-min))
                       (insert "#+TITLE: ")
                       (dolist (reps '(("\n\\*\\*" . "\n*")
                                       ("\\[\\[file:\\([^]]+?\\)\\]\\]" . "[[elisp:(org-wiki-search\"4\"\"\\1\")][\\1]]" )
                                       ("\\[\\[file:\\([^]]+?\\)\\]\\[\\([^]]+?\\)\\]\\]" . "[[elisp:(org-wiki-search\"4\"\"\\1\")][\\2]]")
                                       ("\\[\\[\\(Category:[^]]+?\\)\\]\\[\\([^]]+?\\)\\]\\]" . "[[https://en.wikipedia.org/wiki/\\1][\\2]]")
                                       ("elisp:(org-wiki-search \"\\(.*?\\.\\(jpg\\|png\\)\\)\")" . "https://en.wikipedia.org/wiki/file:\\1")
                                       ;; ("@@mediawiki{{lang-.\\{2\\}?|link=yes|\\(.*?\\)}}@@". "\\1")
                                       ;; ("@@mediawiki\\(.\\|\n\\)+?@@" . "")
                                       ("-  " . "- ")))
                         (goto-char (point-min))
                         (while (re-search-forward (car reps) nil t)
                           (replace-match (cdr reps))))
                       (org-mode)
                       (org-setup-filling)
                       (org-insert-heading)
                       (insert "Contents")
                       (org-set-tags-to ":toc:TOC_3:")
                       (toc-org-insert-toc)
                       (outline-show-all)
                       (fill-region (point-min) (point-max))
                       (outline-hide-sublevels 1)
                       (read-only-mode)
                       (when (featurep 'evil) (evil-motion-state))))
                   (display-buffer "*wiki*" (when search-term
                                              '(display-buffer-same-window . nil)))
                   ;; (with-current-buffer "*wiki*"
                   ;;   (outline-show-all)
                   ;;   (fill-region (point-min) (point-max))
                   ;;   (outline-hide-sublevels 1)
                   ;;   (read-only-mode))
                   (when (and org-wiki-search-window-select (not (stringp arg)))
                     (other-window 1))))))))

;;; utils

(defun org-wiki-search--assoc-find-key (key tree)
  "Return cons with given KEY in nested assoc list TREE."
  (cond ((consp tree)
         (cl-destructuring-bind (x . y)  tree
           (if (eql x key) tree
             (or (org-wiki-search--assoc-find-key key x) (org-wiki-search--assoc-find-key key y)))))
        ((vectorp tree)
         (org-wiki-search--assoc-find-key key (elt tree 0)))))

(provide 'org-wiki-search)

;;; org-wiki-search.el ends here


