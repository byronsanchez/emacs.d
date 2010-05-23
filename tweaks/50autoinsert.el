;;; 50autoinsert.el --- Setup for autoinsert

;; Copyright (C) 2010  Phillip Dixon

;; Author: Phillip Dixon <phil@dixon.gen.nz>
;; Keywords: 

;; This program is free software; you can redistribute it and/or modify
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

;; 

;;; Code:

(add-hook 'find-file-hooks 'auto-insert)
(setq auto-insert-directory (concat dotfiles-dir "mytemplates/"))
(setq auto-insert-query nil)
(setq auto-insert-alist
      '(
        ("\\.el" . ["template.el" pd-auto-insert-substitute])
        ("\\.sh" . ["template.sh" pd-auto-insert-substitute])
        ("\\.py" . ["template.py" pd-auto-insert-substitute])
        ))

(defun pd-auto-insert-substitute ()
)

(provide '50autoinsert)
;;; 50autoinsert.el ends here
