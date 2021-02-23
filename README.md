# emacs-sfdx
Emacs transient wrapper for some basic SFDX CLI commands like deploy and retrieve

## Install

### via Doom Emacs
```elisp
;; in package.el
(package! emacs-sfdx
  :recipe (:host github
           :repo "leothelocust/emacs-sfdx"
           :files ("*.el")))
           
;; in config.el
(map! :map global-map
      "C-x C-l s"     #'sfdx/transient-action
      ;;...
      )
```
### via use-package & straight
```elisp
(use-package emacs-sfdx
  :straight (
             :type git
             :host github
             :repo "leothelocust/emacs-sfdx"
             :branch "main")
  :commands sfdx/transient-action
  :bind ("C-x C-l s" . sfdx/transient-action))
```

## Screenshots

![screenshot of transient](screenshot_transient.png)

