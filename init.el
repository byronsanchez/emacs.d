;;; init.el -- Emacs init file.

;; Copyright (C) 2011-2014 Phillip Dixon

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

;; This is the entry point of the configuration. It it's up the load
;; paths and executes the rest of config files.

;;; Code:

(setq message-log-max 10000)

;; Please don't load outdated byte code
(setq load-prefer-newer t)

(require 'subr-x)

(defconst *emacs-load-start* (current-time))

(defconst lisp-dir (concat user-emacs-directory "lisp/"))

(add-to-list 'load-path lisp-dir)

(setq custom-file (concat user-emacs-directory "custom.el"))

;; load the customize stuff
(load custom-file 'noerror)

(prefer-coding-system 'utf-8)

(let ((elapsed (float-time (time-subtract (current-time)
                                          *emacs-load-start*))))
  (message "Basic Config...done (%.3fs)" elapsed))

;; package.el setup
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
(setq package-enable-at-startup nil)
(setq package-selected-packages nil)

(defun pd-package--save-selected-packages (&optional value)
  "Set `package-selected-packages' to VALUE."
  (when value
    (setq package-selected-packages value)))

;; Since I'm managing packings with `use-package' I don't ever want to
;; save `package-selected-packages'.
(fset 'package--save-selected-packages 'pd-package--save-selected-packages)

(package-initialize)

(defvar pd-package-refreshed nil)

(defun pd-ensure-elpa (package)
  "Make sure PACKAGE is installed and mark it as user selected."
  (unless (package-installed-p package)
    (unless pd-package-refreshed
      (package-refresh-contents)
      (setq pd-package-refreshed t))
    (package-install package))
  (when (package-installed-p package)
    (add-to-list 'package-selected-packages package)))

;; Boot strap use-package
(pd-ensure-elpa 'use-package)
(require 'use-package)

;; Redefine so we hook in with the package-selected-package mechanism
(fset 'use-package-ensure-elpa 'pd-ensure-elpa)


(let ((elapsed (float-time (time-subtract (current-time)
                                          *emacs-load-start*))))
  (message "Package Config...done (%.3fs)" elapsed))

(let* ((point-size (pcase system-type
                     (`darwin 12)
                     (_ 10)))
       (height (round (* 10 point-size)))
       (font (pcase system-type
               (`darwin "SF Mono")
               (_ "Source Code Pro"))))
  (set-face-attribute 'default nil :font font :height height :weight 'normal)
  (set-face-attribute 'fixed-pitch nil :font font :height height)
  (set-face-attribute 'variable-pitch nil :font "Source Sans Pro" :height 130 :weight 'normal))

;; Basic Apperance
;; (if (not (eq system-type 'darwin))
;;     (menu-bar-mode 0))
(tool-bar-mode 0)
(scroll-bar-mode 0)

(setq use-dialog-box nil)

;; Load up my config stuff
(setq inhibit-startup-message t)

(fset 'yes-or-no-p #'y-or-n-p)
(fset 'display-startup-echo-area-message #'ignore)

(show-paren-mode 1)

;; Transparently open compressed files
(auto-compression-mode t)

;; Enable syntax highlighting for older Emacsen that have it off
(global-font-lock-mode t)

(when window-system
  (setq frame-resize-pixelwise t
        frame-title-format '(buffer-file-name "emacs - %f" ("emacs - %b")))
  (tooltip-mode -1)
  (blink-cursor-mode -1))

(setq vc-handled-backends '(Git Hg))

(setq mail-user-agent 'message-user-agent)
(setq user-mail-address "phil@dixon.gen.nz")
(setq user-full-name "Phillip Dixon")

(electric-pair-mode 1)
;;(electric-indent-mode 1)
;;(electric-layout-mode 1)

(put 'set-goal-column 'disabled nil)

(put 'narrow-to-region 'disabled nil)

(column-number-mode t)
(line-number-mode t)
(size-indication-mode t)

(setq fill-column 78)

(set-default 'sentence-end-double-space nil)

;; (use-package mwheel
;;   :config
;;   (setq mouse-wheel-scroll-amount '(1))
;;   (setq mouse-wheel-progressive-speed nil))

;; Never insert tabs
(set-default 'indent-tabs-mode nil)

;; Show me empty lines after buffer end
(setq indicate-empty-lines t
      require-final-newline t)

(setq diff-switches "-u")

(setq tab-always-indent 'complete)
(setq split-height-threshold 100)

(if (eq system-type 'darwin)
    (progn
      (setq mac-option-modifier 'meta)
      (setq mac-command-modifier 'none)))

(bind-key "M-J" #'delete-indentation-forward)
(bind-key "M-j" #'delete-indentation)

(bind-key "C-h a" #'apropos)

(bind-key "C-c y" #'bury-buffer)

(bind-key "C-x w" 'delete-frame)
(bind-key "C-x k" 'kill-this-buffer)

(bind-keys :prefix-map my-toggle-map
           :prefix "C-x t"
           ("c" . pd-cleanroom-mode)
           ("f" . auto-fill-mode)
           ("r" . dired-toggle-read-only)
           ("w" . whitespace-mode)
           ("v" . visual-line-mode))


(bind-key [remap move-beginning-of-line] #'smarter-move-beginning-of-line)

(bind-key [remap goto-line] #'goto-line-with-feedback)

(defun smarter-move-beginning-of-line (arg)
  "Move point back to indentation of beginning of line.

Move point to the first non-whitespace character on this line.
If point is already there, move to the beginning of the line.
Effectively toggle between the first non-whitespace character and
the beginning of the line.

If ARG is not nil or 1, move forward ARG - 1 lines first.  If
point reaches the beginning or end of the buffer, stop there."
  (interactive "^p")
  (setq arg (or arg 1))

  ;; Move lines first
  (when (/= arg 1)
    (let ((line-move-visual nil))
      (forward-line (1- arg))))

  (let ((orig-point (point)))
    (back-to-indentation)
    (when (= orig-point (point))
      (move-beginning-of-line 1))))

(defun goto-line-with-feedback ()
  "Show line numbers temporarily, while prompting for the line number input."
  (interactive)
  (unwind-protect
      (progn
        (linum-mode 1)
        (call-interactively 'goto-line))
    (linum-mode -1)))

(defun delete-indentation-forward ()
  (interactive)
  (delete-indentation t))

;; Yank line or region
(defadvice kill-ring-save (before slick-copy activate compile)
  "When called interactively with no active region, copy a single line instead."
  (interactive
   (if mark-active (list (region-beginning) (region-end))
     (list (line-beginning-position)
           (line-beginning-position 2)))))

;; Kill line or region
(defadvice kill-region (before slick-cut activate compile)
  "When called interactively with no active region, kill a single line instead."
  (interactive
   (if mark-active (list (region-beginning) (region-end))
     (list (line-beginning-position)
           (line-beginning-position 2)))))

(defun my-kill-word ()
  (interactive)
  (save-excursion
    (let (p1 p2)
      (skip-syntax-backward "w_")
      (setq p1 (point))
      (skip-syntax-forward "w_")
      (setq p2 (point))
      (kill-region p1 p2))))

(defun my-copy-line (arg)
  "Copy ARG lines in to the kill ring."
  (interactive "p")
  (kill-ring-save (line-beginning-position)
                  (line-beginning-position (+ 1 arg)))
  (message "%d line%s copied" arg (if (= 1 arg) "" "s")))

(defun my-isearch-yank-current-word ()
  "Pull current word from buffer into search string."
  (interactive)
  (save-excursion
    (skip-syntax-backward "w_")
    (isearch-yank-internal
     (lambda ()
       (skip-syntax-forward "w_")
       (point)))))

(defun my-search-word-backward ()
  "Find the previous occurrence of the current word."
  (interactive)
  (let ((cur (point)))
    (skip-syntax-backward "w_")
    (goto-char
     (if (re-search-backward (concat "\\_<" (current-word) "\\_>") nil t)
         (match-beginning 0)
       cur))))

(defun my-search-word-forward ()
  "Find the previous occurrence of the current word."
  (interactive)
  (let ((cur (point)))
    (skip-syntax-forward "w_")
    (goto-char
     (if (re-search-forward (concat "\\_<" (current-word) "\\_>") nil t)
         (match-beginning 0)
       cur))))

(defun clean-up-buffer-or-region ()
  "Untabifies, indents and deletes trailing whitespace from buffer or region."
  (interactive)
  (let ((beginning (if (region-active-p) (region-beginning) (point-min)))
        (end (if (region-active-p) (region-end) (point-max))))
    (untabify beginning end)
    (indent-region beginning end)
    (delete-trailing-whitespace beginning end)))


(defun esk-sudo-edit (&optional arg)
  (interactive "p")
  (if (or arg (not buffer-file-name))
      (find-file (concat "/sudo:root@localhost:" (ido-read-file-name "File: ")))
    (find-alternate-file (concat "/sudo:root@localhost:" buffer-file-name))))

(defun esk-eval-and-replace ()
  "Replace the preceding sexp with its value."
  (interactive)
  (backward-kill-sexp)
  (condition-case nil
      (prin1 (eval (read (current-kill 0)))
             (current-buffer))
    (error (message "Invalid expression")
           (insert (current-kill 0)))))

;; source: http://steve.yegge.googlepages.com/my-dot-emacs-file
(defun rename-file-and-buffer (new-name)
  "Renames both current buffer and file it's visiting to NEW-NAME."
  (interactive "sNew name: ")
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not filename)
        (message "Buffer '%s' is not visiting a file!" name)
      (if (get-buffer new-name)
          (message "A buffer named '%s' already exists!" new-name)
        (progn
          (rename-file name new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil))))))


;; From https://github.com/bbatsov/emacs-prelude
(defun prelude-google ()
  "Googles a query or region if any."
  (interactive)
  (browse-url
   (concat
    "http://www.google.com/search?ie=utf-8&oe=utf-8&q="
    (if mark-active
        (buffer-substring (region-beginning) (region-end))
      (read-string "Google: ")))))

;; AppleScript Safari stuff
(defun tell-app (app something)
  "Use Applescript to tell APP to do SOMETHING."
  (decode-coding-string
   (do-applescript
    (concat "tell application\""
            app
            "\" to "
            something))
   'mac-roman))

(defun my-safari-selection ()
  (tell-app "Safari"
            "do Javascript \"getSelection()\" in front document"))

(defun my-safari-url ()
  (tell-app "Safari"
            "URL of front document"))

(defun my-safari-title ()
  (tell-app "Safari"
            "do Javascript \"document.title\" in front document"))

(defun my-safari-all-urls ()
  "Return a list of all the URLs in the front most Safari window."
  (split-string (do-applescript (concat "tell application \"Safari\"\n"
                                        "set links to \"\"\n"
                                        "repeat with t in every tab in front Window\n"
                                        "set links to links & the URL of t & linefeed\n"
                                        "end repeat\n"
                                        "return links\n"
                                        "end tell\n")) "\n" t))

(defun my-safari-all-urls-as-markdown ()
  (interactive)
  (let ((urls (my-safari-all-urls))
        (i 0))
    (dolist (url urls)
      (setq i (1+ i))
      (insert (format "[%d]: %s\n" i url)))))

(defun my-safari-url-as-markdown ()
  (interactive)
  (let ((url (my-safari-url))
        (title (my-safari-title)))
    (insert (concat "[" title "](" url ")"))))

(defun my-organisation ()
  "Return company name if I have one."
  (if (boundp 'my-company)
      (my-company)
    (user-full-name)))

(defun say-text (text)
  (do-applescript
   (concat "say \""
           text
           "\" waiting until completion false stopping current speech true")))

(defun speak-buffer-or-region ()
  "Read buffer or region aloud."
  (interactive)
  (let ((text (if (region-active-p)
                  (buffer-substring (region-beginning) (region-end))
                (buffer-string))))
    (say-text text)))

(defun stop-speech ()
  "Stopping talking."
  (interactive)
  (say-text ""))



;; From emacs start kit v2.
;;; These belong in prog-mode-hook:

;; We have a number of turn-on-* functions since it's advised that lambda
;; functions not go in hooks. Repeatedly evaling an add-to-list with a
;; hook value will repeatedly add it since there's no way to ensure
;; that a lambda doesn't already exist in the list.

(defun pd/local-comment-auto-fill ()
  (set (make-local-variable 'comment-auto-fill-only-comments) t)
  (auto-fill-mode t))

(defun pd/add-watchwords ()
  (font-lock-add-keywords
   nil '(("\\<\\(FIXME\\|TODO\\|FIX\\|HACK\\|REFACTOR\\|NOCOMMIT\\)"
          1 font-lock-warning-face t))))

;; (use-package text-mode
;;   :defer t
;;   :config)
;; TODO Ideally these should be in a text-mode use package. But
;;   there's no (provide 'text-mode) till emacs 26.
(add-hook 'text-mode-hook #'flyspell-mode)
(add-hook 'text-mode-hook #'auto-fill-mode)
(add-hook 'text-mode-hook #'bug-reference-mode)

(let ((elapsed (float-time (time-subtract (current-time)
                                          *emacs-load-start*))))
  (message "Non use-package stuff...done (%.3fs)" elapsed))

(use-package exec-path-from-shell
  :if (eq system-type 'darwin)
  :ensure t
  :init (exec-path-from-shell-initialize))

(use-package zenburn
  :disabled t
  :ensure zenburn-theme
  :defer t
  :init
  (load-theme 'zenburn t))

(use-package solarized
  :disabled t
  :ensure solarized-theme
  :defer t
  :init
  (setq solarized-distinct-fringe-background t
        solarized-high-contrast-mode-line nil
        solarized-use-less-bold t
        solarized-use-more-italic t
        solarized-use-variable-pitch nil
        solarized-height-minus-1 1.0
        solarized-height-plus-1 1.0
        solarized-height-plus-2 1.0
        solarized-height-plus-3 1.0
        solarized-height-plus-4 1.0)
  (load-theme 'solarized-dark t))

(use-package color-theme-sanityinc-tomorrow
  :ensure t
  :config
  (load-theme (color-theme-sanityinc-tomorrow--theme-name 'day) t))

(use-package frame
  :config (add-to-list 'initial-frame-alist '(fullscreen . maximized)))

;; Save a list of recent files visited.
(use-package recentf
  :defer 1
  :config
  (setq  recentf-auto-cleanup 300
         recentf-exclude (list "/\\.git/.*\\'" ; Git contents
                               "/elpa/.*\\'" ; Package files
                               )))

(use-package autorevert
  :init (global-auto-revert-mode)
  :config
  (progn
    (setq global-auto-revert-non-file-buffers t
          auto-revert-check-vc-info t
          auto-revert-verbose nil)))

(use-package savehist
  :init (savehist-mode t))

(use-package applescript-mode
  :defer t
  :ensure t)

(use-package auctex
  :defer t
  :ensure t)

(use-package cmake-mode
  :defer t
  :ensure t)

(use-package go-mode
  :defer t
  :ensure t)

(use-package graphviz-dot-mode
  :defer t
  :ensure t)

(use-package ibuffer-vc
  :defer t
  :ensure t)

(use-package window-number
  :defer t
  :ensure t)

(use-package delsel
  :defer t
  :init (delete-selection-mode))

(use-package ido
  :init
  (ido-mode t)
  :config
  (progn
    (setq ido-enable-prefix nil
          ido-enable-flex-matching t
          ido-auto-merge-work-directories-length nil
          ido-create-new-buffer 'always
          ido-use-filename-at-point 'guess
          ido-use-virtual-buffers t
          ido-max-prospects 10)))

(use-package flx-ido
  :ensure t
  :init
  (flx-ido-mode))

(use-package ido-vertical-mode
  :ensure t
  :init
  (ido-vertical-mode))

(use-package ido-ubiquitous
  :ensure t
  :init (ido-ubiquitous-mode))

(use-package smex
  :ensure t
  :bind (([remap execute-extended-command] . smex)
         ("M-X" . smex-major-mode-commands)))

(use-package whitespace
  :defer t
  :config
  (setq whitespace-style '(face trailing tabs)
        whitespace-line-column 80))

(use-package auth-source
  :defer t
  :config
  (setq auth-sources '("~/.authinfo.gpg")))

(use-package eudc
  :defer t
  :config
  (when (eq system-type 'darwin)
    (eudc-set-server "localhost" 'mab t)
    (eudc-protocol-set 'eudc-inline-expansion-format
                       '("%s %s <%s>" firstname lastname email)
                       'mab)))

(use-package message
  :defer t
  :config
  (setq message-send-mail-function 'smtpmail-send-it
        message-kill-buffer-on-exit t))

(use-package sendmail
  :defer t
  :config
  (setq send-mail-function 'smtpmail-send-it ))

(use-package smtpmail
  :defer t
  :config
  (setq smtpmail-stream-type 'ssl
        smtpmail-smtp-server "smtp.gmail.com"
        smtpmail-smtp-service 465))

(use-package ispell
  :defer t
  :config
  (setq ispell-dictionary "en_GB-ise"
        ispell-extra-args `("--keyboard=dvorak")
        ispell-silently-savep t))

(use-package imenu
  :defer t
  :config
  (progn
    (setq imenu-max-items 200)))

(use-package ibuffer
  :defer t
  :bind ("<f8>" . ibuffer)
  :init
  (defalias 'list-buffers 'ibuffer)
  :config
  (setq ibuffer-expert 1)
  (setq ibuffer-show-empty-filter-groups nil)

  (add-hook 'ibuffer-hook
            (lambda ()
              (ibuffer-vc-set-filter-groups-by-vc-root)
              (unless (eq ibuffer-sorting-mode 'alphabetic)
                (ibuffer-do-sort-by-alphabetic))))

    ;; Use human readable Size column instead of original one

  (define-ibuffer-column size-h
    (:name "Size" :inline t)
    (cond
     ((> (buffer-size) 1000000) (format "%7.1fM" (/ (buffer-size) 1000000.0)))
     ((> (buffer-size) 1000) (format "%7.1fk" (/ (buffer-size) 1000.0)))
     (t (format "%8d" (buffer-size)))))

    ;; Modify the default ibuffer-formats

  (setq ibuffer-formats
        '((mark modified read-only locked vc-status-mini " "
                (name 18 18 :left :elide)
                " "
                (size-h 9 -1 :right)
                " "
                (mode 16 16 :left :elide)
                " "
                ;(vc-status 16 16 :left)
                ;" "
                filename-and-process
                ))))

(use-package uniquify
  :init
  (setq uniquify-buffer-name-style 'reverse
        uniquify-separator "/"
        uniquify-after-kill-buffer-p t
        uniquify-ignore-buffers-re "^\\*"))

(use-package files
  :defer t
  :config
  (when-let (gls (and (eq system-type 'darwin) (executable-find "gls")))
    (setq insert-directory-program gls))
  (setq view-read-only t)
  (setq auto-save-file-name-transforms
        `((".*" ,temporary-file-directory t)))
  (setq backup-directory-alist `(("." . ,(expand-file-name
                                          (concat user-emacs-directory "backups")))))
  (add-hook 'after-save-hook
          'executable-make-buffer-file-executable-if-script-p))

(use-package dired
  :defer t
  :config
  (put 'dired-find-alternate-file 'disabled nil)
  (setq dired-dwim-target t
        dired-recursive-copies 'always
        dired-recursive-deletes 'top
        dired-listing-switches "-alhF")
  (when (or (memq system-type '(gnu gnu/linux))
            (string= (file-name-nondirectory insert-directory-program) "gls"))
    ;; If we are on a GNU system or have GNU ls, add some more `ls' switches:
    ;; `--group-directories-first' lists directories before files, and `-v'
    ;; sorts numbers in file names naturally, i.e. "image1" goes before
    ;; "image02"
    (setq dired-listing-switches
          (concat dired-listing-switches " --group-directories-first -v")))

  (defun pd/dired-do-multi-occur (regexp)
    "Show all in lines in marked files containing REGEXP"
    (interactive "MList lines matching regexp: ")
    (multi-occur (mapcar 'find-file (dired-get-marked-files)) regexp))

  (defun pd-dired-find-alternate-parent ()
    (interactive)
    (find-alternate-file ".."))

  (bind-key "^" 'pd-dired-find-alternate-parent dired-mode-map))

(use-package dired-x
  :bind (("C-x C-j" . dired-jump)
         ("C-x 4 C-j" . dired-jump-other-window)))

(use-package expand-region
  :ensure t
  :bind (("M-\"" . er/contract-region)
         ("M-'" . er/expand-region)))

(use-package change-inner
  :ensure t
  :bind (("M-i" . change-inner)
         ("M-o" . change-outer)))

(use-package hungry-delete
  :ensure t
  :init
  (global-hungry-delete-mode)
  :config
  (setq hungry-delete-chars-to-skip " \t"))

(use-package pd-centered-window
  :load-path "lisp/"
  :commands (pd-centered-window-mode))

(use-package pd-cleanroom
  :load-path "lisp/"
  :commands (pd-cleanroom-mode))

(use-package pinboard
  :load-path "lisp/pinboard"
  :commands (pinboard-list-bookmarks))

(use-package diff-hl
  :ensure t)

(use-package magit
  :ensure t
  :bind (([remap magit-fetch-popup] . magit-pull-and-fetch-popup)
         ([remap magit-pull-popup] . magit-pull-and-fetch-popup)
         ("<f7>" . magit-status))
  :config
  (magit-auto-revert-mode)
  (remove-hook 'magit-refs-sections-hook 'magit-insert-tags)
  (setq magit-display-buffer-function #'display-buffer)
  (setq magit-completing-read-function #'magit-ido-completing-read)
  (setq magit-branch-prefer-remote-upstream '("master"))
  (add-to-list 'git-commit-known-pseudo-headers "Ticket"))

(use-package orgit
  :ensure t
  :defer t)

(use-package gitconfig-mode
  :ensure t
  :defer t)

(use-package gitignore-mode
  :ensure t
  :defer t)

(use-package gitattributes-mode
  :ensure t
  :defer t)

(use-package git-timemachine
  :ensure t
  :defer t)

(use-package git-link
  :ensure t
  :defer t
  :config
  (require 'git-link-bitbucket-server)
  (add-to-list 'git-link-remote-alist '("stash.sw.au.ivc" git-link-bitbucket-server))
  (add-to-list 'git-link-commit-remote-alist '("stash.sw.au.ivc" git-link-commit-bitbucket-server)))

(use-package git-link-bitbucket-server
  :load-path "lisp/"
  :defer t)

(use-package hg-commit-mode
  :mode ("hg-editor-.*\\.txt\\'" . hg-commit-mode))

(use-package ediff
  :defer t
  :config
  (setq ediff-split-window-function #'split-window-horizontally))

(use-package pd-editing-extras
  :bind (("C-c +" . my-increment)
         ("C-t" . transpose-dwim)
         ("M-c". toggle-letter-case)
         ("M-<SPC>" . cycle-spacing)))

(use-package bookmark
  :bind ("<f9>" . bookmark-bmenu-list))

(use-package multiple-cursors
  :ensure t
  :bind (("C-<" . mc/mark-previous-like-this)
         ("C->" . mc/mark-next-like-this)))

(use-package paredit
  :ensure t
  :defer t
  :init
  (add-hook 'emacs-lisp-mode-hook #'enable-paredit-mode))

(use-package hexl-mode
  :mode (("\\.exe\\'" . hexl-mode)
         ("\\.dll\\'" . hexl-mode)))

(use-package groovy-mode
  :ensure t
  :mode (("/Jenkinsfile\\'" . groovy-mode)))

(use-package pd-project
  :bind(("C-c b" . pd-project-compile))
  :commands (pd-project-todo))

(use-package pd-window-extras
  :commands (pd/rotate-windows
             pd/toggle-window-split
             pd/setup-windows
             pd/toggle-just-one-window))

(use-package deft
  :ensure t
  :bind ("<f5>" . deft)
  :config
  (setq deft-default-extension "org")
  (setq deft-directory "~/personal/notes")
  (setq deft-use-filename-as-title t)
  (setq deft-use-filter-string-for-filename t)
  (setq deft-file-naming-rules '((noslash . "-")
                                 (nospace . "-")
                                 (case-fn . downcase))))

(use-package markdown-mode
  :ensure t
  :mode (("\\.md\\'" . markdown-mode)
         ("\\.mdwn\\'" . markdown-mode)
         ("\\.markdown" . markdown-mode))
  :config
  (setq markdown-command "pandoc")
  (add-hook 'markdown-mode-hook #'imenu-add-menubar-index))


(use-package pd-blog-helpers
  :commands (pd-blog-draft
             pd-blog-publish-post))

(use-package writegood-mode
  :ensure t
  :commands (writegood-mode))

(use-package wc-mode
  :ensure t
  :commands (wc-mode))

(use-package bibtex
  :mode (("\\.bibtex\\'" . bibtex-mode)
         ("\\.bib\\'". bibtex-mode)))

(use-package ansi-term
  :bind ("<f10>" . pd-visit-term)
  :init
  (defun pd-visit-term ()
    ""
    (interactive)
    (if (not (get-buffer "*ansi-term*"))
        (ansi-term (getenv "SHELL"))
      (switch-to-buffer "*ansi-term*")))
  :config
  (defun my-term-paste (&optional string)
    (interactive)
    (process-send-string
     (get-buffer-process (current-buffer))
     (if string
         string
       (current-kill 0))))

  (defun my-term-hook ()
    (goto-address-mode))
  (add-hook 'term-mode-hook 'my-term-hook))

;; Used in my blog infrastructure. Remove once that code is a package
;; with dependencies.
(use-package f
  :ensure t
  :defer t)

(use-package s
  :ensure t
  :defer t)

(use-package gnus-start
  :defer t
  :config
  (setq gnus-init-file (concat user-emacs-directory "dot-gnus.el")))

;; Setup for Org
(use-package org-agenda
  :bind (("<f6>" . my-org-agenda)
         ("C-c a" . org-agenda))
  :init
  (defun my-org-agenda ()
    (interactive)
    (org-agenda nil "w"))
  :config
  (setq org-agenda-prefix-format
        '((agenda . " %i %-12:c%?-12t% s %b")
          (timeline . "  % s %b")
          (todo . " %i %-12:c %b")
          (tags . " %i %-12:c %b")
          (search . " %i %-12:c %b"))))

(use-package org-mac-link
  :ensure t
  ;; :bind (:map org-mode-map
  ;;             ("C-c g" . org-mac-grab-link))
  :commands (org-mac-grab-link)
  :config
  (setq org-mac-grab-Addressbook-app-p nil)
  (setq org-mac-grab-devonthink-app-p nil)
  (setq org-mac-grab-Firefox-app-p nil)
  (setq org-mac-grab-Firefox+Vimperator-p nil)
  (setq org-mac-grab-Chrome-app-p nil)
  (setq org-mac-grab-Together-app-p nil)
  (setq org-mac-grab-Skim-app-p nil))

(use-package org-capture
  :bind (("C-c r" . org-capture))
  :config
  (setq org-capture-templates
        '(("i" "Interruption" entry
           (file "~/work/org/inbox.org")
           "* %?\n"
           :clock-in t)
          ("n" "Notes" entry
           (file "~/work/org/inbox.org")
           "* %?\n%U\n%i\n%a")
          ("t" "Todo" entry
           (file "~/work/org/inbox.org")
           "* TODO %?\n%U\n%i\n%a")
          ("b" "Book" entry
           (file+headline "~/personal/notes/reading.org" "Read")
           "** %^{Title}\n:PROPERTIES:\n:Author: %^{Author}p \n:Started: %u\n:Finished: \n:END:\n\n"
           :immediate-finish t))))

(use-package ox-bibtex
  :defer t
  :load-path "vendor/")

(use-package htmlize
  :ensure t
  :defer t)

(use-package ox-html
  :defer t
  :config
  (progn
    (require 'htmlize)
    (setq org-html-htmlize-output-type 'css)))

(use-package ox-latex
  :defer t
  :config
  (setq org-latex-pdf-process
        '("xelatex -interaction nonstopmode -output-directory %o %f"
          "xelatex -interaction nonstopmode -output-directory %o %f"))
   (setq org-latex-default-packages-alist
         '(("" "fixltx2e" nil)
           ("" "graphicx" t)
           ("" "longtable" nil)
           ("" "float" nil)
           ("" "wrapfig" nil)
           ("" "rotating" nil)
           ("normalem" "ulem" t)
           ("" "amsmath" t)
           ("" "textcomp" t)
           ("" "marvosym" t)
           ("" "wasysym" t)
           ("" "amssymb" t)
           ("hidelinks" "hyperref" nil)
           "\\tolerance=1000")))

(use-package ox-publish
  :defer t
  :commands pd/publish-blog
  :config
  (require 'ox-html)
  (require 'pd-html)
  (require 'ox-rss)

  (defun pd/publish-blog ()
    "Publish my blog"
    (interactive)
    (org-publish-project "blog" t))

  (setq org-confirm-babel-evaluate nil)

  (setq org-publish-project-alist
        '(("blog-content"
           :base-directory "~/personal/phil.dixon.gen.nz/"
           :base-extension "org"
           :recursive t
           :publishing-directory "~/Sites/phil.dixon.gen.nz/"
           :publishing-function (pd-html-publish-to-html)
           :with-toc nil
           :html-html5-fancy t
           :section-numbers nil
           :exclude "rss.org")
          ("blog-static"
           :base-directory "~/personal/phil.dixon.gen.nz/"
           :base-extension "jpg\\|png\\|css\\|js\\|ico\\|gif"
           :recursive t
           :publishing-directory "~/Sites/phil.dixon.gen.nz/"
           :publishing-function org-publish-attachment)
          ("blog-rss"
           :base-directory "~/personal/phil.dixon.gen.nz/"
           :base-extension "org"
           :publishing-directory "~/Sites/phil.dixon.gen.nz/"
           :publishing-function (org-rss-publish-to-rss)
           :html-link-home "~/Sites/phil.dixon.gen.nz/"
           :html-link-use-abs-url t
           :exclude ".*"
           :include ("rss.org")
           :with-toc nil
           :section-numbers nil
           :title "Phillip Dixon")
          ("blog"
           :components
           ("blog-content" "blog-static" "blog-rss")))))

(use-package org
  :ensure t
  :mode ("\\.org\\'" . org-mode)
  :config
  (require 'pd-org-extras)
  (setq org-directory "~/work/org/")
  (setq org-default-notes-file (concat org-directory "inbox.org"))
  (setq org-agenda-diary-file (concat org-directory "diary.org"))
  (setq org-agenda-files (list org-directory (concat org-directory "projects/")))

  (setq org-hide-leading-stars t)
  (setq org-use-sub-superscripts "{}")
  (setq org-footnote-define-inline t)
  (setq org-footnote-auto-adjust nil)

  (setq org-fast-tag-selection-single-key 'expert)
  (setq org-log-into-drawer "LOGBOOK")
  (setq org-tag-alist
        '((:startgroup . nil)
          ("@call" . ?c)
          ("@office" . ?o)
          ("@home" . ?h)
          ("@read" . ?r)
          ("@computer" . ?m)
          ("@shops" . ?s)
          ("@dev" . ?d)
          ("@write" . ?w)
          (:endgroup . nil)
          ("REFILE" . ?f)
          ("SOMEDAY" . ?s)
          ("PROJECT" . ?p)))
  (setq org-use-tag-inheritance t)
  (setq org-tags-exclude-from-inheritance '("@call"
                                            "@office"
                                            "@home"
                                            "@read"
                                            "@computer"
                                            "@shops"
                                            "@dev"
                                            "@write"
                                            "PROJECT"))

  (setq org-use-speed-commands t)
  (setq org-use-fast-todo-selection t)
  (setq org-todo-keywords
        '((sequence "TODO(t)" "|" "DONE(d!)")
          (sequence "WAITING(w@/!)" "|" "CANCELLED" "DELEGATED(e@)")))
  (setq org-enforce-todo-dependencies t)
  (add-hook 'org-after-todo-statistics-hook 'pd/org-summary-todo)

  (setq org-agenda-todo-ignore-with-date t)
  (setq org-agenda-skip-deadline-if-done t)
  (setq org-agenda-skip-scheduled-if-done t)
  (setq org-agenda-tags-todo-honor-ignore-options t)
  (setq org-agenda-window-setup 'current-window)
  (setq org-agenda-compact-blocks t)
  (setq org-agenda-custom-commands
        '(("w" "Day's Agenda and Tasks"
           ((agenda "" (( org-agenda-span 1)))
            (tags-todo "-SOMEDAY/!"
                       ((org-agenda-overriding-header "Stuck Projects")
                        (org-agenda-skip-function 'bh/skip-non-stuck-projects)))
            (tags-todo "-SOMEDAY/!"
                       ((org-agenda-overriding-header "Projects")
                        (org-agenda-skip-function 'bh/skip-non-projects)
                        (org-agenda-ignore-scheduled 'future)
                        (org-agenda-ignore-deadlines 'future)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "-CANCELLED/!WAITING"
                       ((org-agenda-overriding-header "Waiting and Postponed Tasks")
                        (org-agenda-skip-function 'pd/skip-projects)
                        (org-agenda-todo-ignore-scheduled t)
                        (org-agenda-todo-ignore-deadlines t)))
            (tags-todo "-SOMEDAY/!-WAITING"
                       ((org-agenda-overriding-header "Tasks")
                        (org-agenda-skip-function 'pd/skip-projects)
                        (org-agenda-todo-ignore-scheduled t)
                        (org-agenda-todo-ignore-deadlines t)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            nil))
          ("#" "Stuck Projects" tags-todo "-SOMEDAY/!"
           ((org-agenda-overriding-header "Stuck Projects")
            (org-agenda-skip-function 'bh/skip-non-stuck-projects)))
          ("R" "Tasks" tags-todo "-REFILE-CANCELLED/!-WAITING"
           ((org-agenda-overriding-header "Tasks")
            (org-agenda-skip-function 'pd/skip-projects)
            (org-agenda-sorting-strategy
             '(category-keep))))
          ("p" "Project Lists" tags-todo "-SOMEDAY/!"
           ((org-agenda-overriding-header "Projects")
            (org-agenda-skip-function 'bh/skip-non-projects)
            (org-agenda-ignore-scheduled 'future)
            (org-agenda-ignore-deadlines 'future)
            (org-agenda-sorting-strategy
             '(category-keep))))
          ("b" "Waiting Tasks" tags-todo "-CANCELLED/!WAITING"
           ((org-agenda-overriding-header "Waiting and Postponed tasks")
            (org-agenda-skip-function 'pd/skip-projects)
            (org-agenda-todo-ignore-scheduled 'future)
            (org-agenda-todo-ignore-deadlines 'future)))
          ("e" "Errand List" tags-todo "@shops"
           ((org-agenda-prefix-format "[ ]")
            (org-agenda-todo-keyword-format "")))
          ("c" todo "TODO"
           ((org-agenda-sorting-strategy '(tag-up priority-down))))))

  (add-hook 'org-agenda-mode-hook #'pd-org-agenda-width)

    ;; Refile setup
  (setq org-refile-targets '((org-agenda-files :maxlevel . 3) (nil :maxlevel . 3)))
  (setq org-refile-use-outline-path 'file)
  (setq org-outline-path-complete-in-steps t)
  (org-babel-do-load-languages
     'org-babel-load-languages
     '((emacs-lisp . t)
       (dot . t)
       (gnuplot . t)
       (plantuml . t)
       (latex . t))))

(use-package ob-plantuml
  :defer t
  :config
  (setq org-plantuml-jar-path "/usr/local/opt/plantuml/plantuml.8041.jar"))

(use-package yasnippet
  :ensure t
  :commands (yas-minor-mode yas-expand yas-hippie-try-expand)
  :mode ("/\\.emacs\\.d/snippets/" . snippet-mode)
  :init
  (add-hook 'text-mode-hook #'yas-minor-mode)
  (add-hook 'prog-mode-hook #'yas-minor-mode)
  :config
  (setq yas-verbosity 1)
  (setq yas-snippet-dirs (list (concat user-emacs-directory "snippets")))
  (setq yas-prompt-functions '(yas-ido-prompt yas-complete-prompt))
  (yas-reload-all))

(use-package hippie-exp
  :defer t
  :config
  ;; Hippie expand: at times perhaps too hip
  (dolist (f '(try-expand-line try-expand-list try-complete-file-name-partially))
    (delete f hippie-expand-try-functions-list))

  ;; Add this back in at the end of the list.
  (add-to-list 'hippie-expand-try-functions-list 'try-complete-file-name-partially t))

(use-package company
  :ensure t
  :defer t
  :init
  (add-hook 'c-mode-common-hook #'company-mode)
  (add-hook 'elisp-mode #'company-mode)
  :config
  (add-to-list 'company-backends #'company-irony)
  (setq company-backends (delete 'company-semantic company-backends))
  (setq company-begin-commands '(self-insert-command))
  (setq company-idle-delay 0.3))

(use-package autoinsert
  :defer t
  :init
  (add-hook 'find-file-hooks 'auto-insert)
  :config
  (defun pd-expand-buffer ()
    "Expand buffer in place as a yasnippet."
    (yas-expand-snippet (buffer-string) (point-min) (point-max)))

  (setq auto-insert-directory (concat user-emacs-directory "mytemplates/")
        auto-insert-query nil)

  (define-auto-insert "setup.py\\'"
    ["template-setup.py" pd-expand-buffer])

  (define-auto-insert "\\.markdown\\'"
    ["post.markdown" pd-expand-buffer])

  (define-auto-insert "\\.mdwn\\'"
    ["template.mdwn" pd-expand-buffer])

  (define-auto-insert "\\.m\\'"
    ["template.m" pd-expand-buffer])

  (define-auto-insert "\\.org\\'"
    ["template.org" pd-expand-buffer]))


(use-package haskell-mode
  :ensure t
  :mode ("\\.l?hs\\'" . haskell-mode)
  :config
  (add-hook 'haskell-mode-hook #'turn-on-haskell-doc-mode)
  (add-hook 'haskell-mode-hook #'turn-on-haskell-indent))

(use-package lua-mode
  :ensure t
  :mode ("\\.lua\\'" . lua-mode)
  :interpreter (("lua" . lua-mode)
                ("luajit" . lua-mode))
  :config
  (setq lua-indent-level 4))

(use-package python
  :mode ("\\.py\\'" . python-mode)
  :interpreter (("python" . python-mode)
                ("python3" . python-mode))
  :config
  (defun pd-python-mode-hook ()
    (electric-indent-mode -1)) ;; This isn't useful in python

  (add-hook 'python-mode-hook #'pd-python-mode-hook))

(use-package wizard-db
  :mode ("\\.xmd\\'" . wizard-db-mode))

(use-package lilypond-mode
  :load-path "vendor/lilypond"
  :mode ("\\.ly\\'" . LilyPond-mode))

(use-package pkgbuild-mode
  :ensure t
  :mode ("PKGBUILD\\'" . pkgbuild-mode))

(use-package conf-mode
  :mode ("hgrc" . conf-mode))

(use-package dummy-h-mode
  :ensure t
  :mode ("\\.h$" . dummy-h-mode))

(use-package google-c-style
  :ensure t
  :defer t
  :after cc-mode
  :init
  (c-add-style "Google" google-c-style)

  (defconst my-c-style
    '("Google"
      (c-basic-offset . 4)
      (c-offsets-alist . ((inextern-lang . -)))))
  (c-add-style "PERSONAL" my-c-style)

  (defconst dcl-c-style
    '("Google"
      (c-basic-offset . 3)))
  (c-add-style "DCL" dcl-c-style))

(use-package cc-mode
  :defer t
  :config
  (defconst my-obj-c-style
    '("bsd"
      (c-basic-offset . 4)
      (indent-tabs-mode . nil)
      (c-offsets-alist . ((case-label . +)))))
  (c-add-style "my-obj-c" my-obj-c-style)

    ;; Customizations for all modes in CC Mode.

  (defun my-c-mode-common-hook ()
    (c-set-style "PERSONAL")
    (setq ff-always-in-other-window nil))

  (add-hook 'c-mode-common-hook #'my-c-mode-common-hook)

  (defun pd/objc-ff-setup-hook ()
    (set (make-local-variable 'cc-other-file-alist)
         '(("\\.m\\'" (".h")) ("\\.h\\'" (".m" ".c" ".cpp")))))

  (add-hook 'objc-mode-hook #'pd/objc-ff-setup-hook)

  (use-package pd-cc-mode-extras
    :commands (pd/toggle-header
               pd/toggle-test)))

(use-package compile
  :defer t
  :config
  (defun pd/compilation-hook ()
    (setq truncate-lines t))

  (add-hook 'compilation-mode-hook #'pd/compilation-hook))

(use-package eldoc
  :diminish eldoc-mode
  :defer t)

(use-package lisp-mode
  :defer t
  :config
  (add-hook 'emacs-lisp-mode-hook 'eldoc-mode))

(use-package irony
  :ensure t
  :defer t
  :init
  (add-hook 'c-mode-hook #'irony-mode)
  (add-hook 'c++-mode-hook #'irony-mode)
  (add-hook 'objc-mode-hook #'irony-mode)
  :config
  (add-hook 'irony-mode-hook #'irony-cdb-autosetup-compile-options))

(use-package company-irony
  :ensure t
  :defer t
  :init
  (add-hook 'irony-mode-hook #'company-irony-setup-begin-commands))

(use-package flycheck-irony
  :ensure t
  :defer t
  :init
  (with-eval-after-load 'flycheck
    (add-hook 'flycheck-mode-hook #'flycheck-irony-setup)))

(use-package flycheck
  :ensure t
  :defer t
  :init
  (add-hook 'c-mode-common-hook #'flycheck-mode)
  (add-hook 'emacs-lisp-mode-hook #'flycheck-mode))

(use-package flycheck-pos-tip
  :ensure t
  :defer t
  :after flycheck
  :init
  (flycheck-pos-tip-mode))

(use-package ace-window
  :ensure t
  :bind (("C-x o" . ace-window)))

(use-package which-func
  :init (which-function-mode))

(use-package saveplace
  :init (save-place-mode))

(use-package prog-mode
  :config
  (add-hook 'prog-mode-hook 'pd/local-comment-auto-fill)
  (add-hook 'prog-mode-hook 'hl-line-mode)
  (add-hook 'prog-mode-hook 'whitespace-mode)
  (add-hook 'prog-mode-hook 'pd/add-watchwords)
  (add-hook 'prog-mode-hook #'bug-reference-prog-mode))

(use-package server
  :defer t)

(use-package mu4e
  :defer t
  :load-path "/usr/local/share/emacs/site-lisp/mu4e"
  :commands (mu4e)
  :config
  (require 'mu4e-contrib)
  (setq mu4e-maildir "~/.mail/gmail"
        mu4e-sent-folder "/sent"
        mu4e-drafts-folder "/drafts"
        mu4e-trash-folder "/trash"
        mu4e-refile-folder "/archive"
        mu4e-get-mail-command "mbsync -a"
        mu4e-view-prefer-html t
        mu4e-html2text-command 'mu4e-shr2text
        mu4e-change-filenames-when-moving t))

(use-package clang-format
  :defer t
  :ensure t)

(use-package info
  :defer t
  :config
  (set-face-attribute 'Info-quoted nil
                      :family 'unspecified
                      :inherit font-lock-type-face))

(use-package mediawiki
  :ensure t
  :defer t
  :config
  (add-to-list 'mediawiki-site-alist
                 '("Software" "http://wiki.sw.au.ivc/mediawiki" "pdixon" "" "The PENSIEVE"))
  (setq mediawiki-site-default "Software"))

(use-package time
  :config
  (setq display-time-world-time-format "%H:%M %d %b, %Z"
        display-time-world-list '(("Pacific/Auckland" "Christchurch")
                                  ("Asia/Shanghai" "Suzhou")
                                  ("Europe/London"    "London")
                                  ("America/Los_Angeles" "San Francisco"))))

(use-package eww
  ;;:init
  ;;(setq browse-url-browser-function 'eww-browse-url)
  :config
  (defun rename-eww-buffer ()
    (rename-buffer (format "*eww : %s *" (plist-get eww-data :title)) t))

  (add-hook 'eww-after-render-hook 'rename-eww-buffer))

(use-package epg
  :config
  (setq epg-gpgconf-program "gpg"))

(use-package flycheck-swift
  :ensure t)

(use-package swift-mode
  :ensure t
  :interpreter "swift")

(use-package ninja-mode
  :ensure t)

(use-package excorporate
  :ensure t
  :config
  (setq excorporate-configuration
        '("pdixon@dynamiccontrols.com" . "https://outlook.office365.com/EWS/Exchange.asmx")))

(use-package restclient
  :ensure t
  :defer t)

(dir-locals-set-class-variables
 'work-directory
 '((nil . ((user-company . "Dynamic Controls")
           (user-mail-address . "pdixon@dynamiccontrols.com")))))

(dir-locals-set-directory-class
 (expand-file-name "~/work/") 'work-directory)

(let ((elapsed (float-time (time-subtract (current-time)
                                          *emacs-load-start*))))
  (message "Loading %s...done (%.3fs)" load-file-name elapsed))
;;; init.el ends here
