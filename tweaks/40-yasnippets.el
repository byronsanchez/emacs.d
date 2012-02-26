;; Setup for yasnippets
(require 'yasnippet)
(yas/initialize)

(setq yas/root-directory  (list (concat dotfiles-dir "mysnippets/")
                                (concat dotfiles-dir "elpa/yasnippet-0.6.1/snippets")))

(mapc 'yas/load-directory yas/root-directory)

(defun my-yas-org-hook ()
  (let ((original-command (lookup-key org-mode-map [tab])))
    `(lambda ()
       (setq yasl/fallback-behaviour
             '(apply 'original-command))
       (local-set-key [tab] 'yas/expand))))

(add-hook 'flyspell-incorrect-hook
        #'(lambda (dummy1 dummy2 dymmy3)
            (and yas/active-field-overlay
                 (overlay-buffer yas/active-field-overlay))))

(add-hook 'org-mode-hook 'my-yas-org-hook)
