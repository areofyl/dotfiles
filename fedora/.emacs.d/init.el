;;; init.el --- Emacs config (mirrors nvim setup)

;; ============================================================
;; Package setup
;; ============================================================
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(defvar my-packages
  '(evil
    evil-collection
    gruvbox-theme
    counsel
    ivy
    swiper
    which-key
    company
    flycheck
    diff-hl
    highlight-indent-guides
    doom-modeline
    format-all
    dape
    dashboard
    magit
    evil-surround
    vterm
    projectile))

(unless package-archive-contents
  (package-refresh-contents))
(dolist (pkg my-packages)
  (unless (package-installed-p pkg)
    (package-install pkg)))

;; ============================================================
;; General settings
;; ============================================================
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)
(setq-default tab-width 2)
(setq-default indent-tabs-mode nil)
(setq case-fold-search t)
(global-hl-line-mode 1)
;; Smooth scrolling
(setq scroll-margin 8)
(setq hscroll-margin 8)
(setq scroll-step 1)
(setq scroll-conservatively 10000)
(setq auto-window-vscroll nil)
(pixel-scroll-precision-mode 1)
(setq-default truncate-lines t)
(setq split-width-threshold 0)
(setq split-height-threshold nil)
(setq select-enable-clipboard t)
(setq idle-update-delay 0.25)
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(setq inhibit-startup-message nil)
(setq ring-bell-function 'ignore)
(setq make-backup-files nil)
(setq auto-save-default nil)
(defalias 'yes-or-no-p 'y-or-n-p)

;; ============================================================
;; Dashboard — animated spinning macaroni
;; ============================================================
(require 'dashboard)

(defface macaroni-bright '((t :foreground "#fabd2f")) "Bright.")
(defface macaroni-mid    '((t :foreground "#d79921")) "Mid.")
(defface macaroni-dim    '((t :foreground "#b57614")) "Dim.")
(defface macaroni-dark   '((t :foreground "#7c6f64")) "Dark.")
(defface macaroni-title  '((t :foreground "#fabd2f" :weight bold)) "Title.")

(defvar my/macaroni-dir (expand-file-name "macaroni" user-emacs-directory))
(defvar my/macaroni-num-frames 13)
(defvar my/macaroni-idx 0)
(defvar my/macaroni-timer nil)

(defun my/macaroni-read-frame (n)
  "Read frame N from disk."
  (let ((file (format "%s/%03d.txt" my/macaroni-dir n)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (buffer-string)))))

(defun my/macaroni-colorize (text)
  "Add gruvbox color faces to TEXT."
  (let ((result ""))
    (dotimes (i (length text))
      (let* ((ch (aref text i))
             (face (if (= ch 32) nil 'macaroni-bright)))
        (setq result (concat result
                             (if face
                                 (propertize (char-to-string ch) 'face face)
                               (char-to-string ch))))))
    result))

(defun my/macaroni-centered-frame ()
  "Get current frame, colored, horizontally and vertically centered, with title."
  (let* ((raw (my/macaroni-read-frame my/macaroni-idx))
         (lines (split-string (or raw "") "\n" t))
         (ww (window-width))
         (wh (window-height))
         (content-height (+ (length lines) 3))
         (top-pad (max 0 (/ (- wh content-height) 2)))
         (result ""))
    ;; Vertical centering
    (dotimes (_ top-pad)
      (setq result (concat result "\n")))
    ;; Frame lines
    (dolist (line lines)
      (let ((pad (max 0 (/ (- ww (length line)) 2))))
        (setq result (concat result (make-string pad 32) (my/macaroni-colorize line) "\n"))))
    ;; Title
    (let* ((title (propertize "aarav | emacs" 'face 'macaroni-title))
           (pad (max 0 (/ (- ww (length title)) 2))))
      (setq result (concat result "\n" (make-string pad 32) title "\n")))
    result))

(defun my/macaroni-update ()
  "Show next frame in dashboard."
  (condition-case nil
      (let ((buf (get-buffer "*dashboard*")))
        (when (and buf (buffer-live-p buf) (get-buffer-window buf))
          (setq my/macaroni-idx (mod (1+ my/macaroni-idx) my/macaroni-num-frames))
          (with-current-buffer buf
            (let ((inhibit-read-only t))
              (erase-buffer)
              (insert (my/macaroni-centered-frame))))))
    (error nil)))

(defun my/macaroni-start ()
  "Start the animation."
  (when my/macaroni-timer (cancel-timer my/macaroni-timer))
  (setq my/macaroni-idx 0)
  (setq my/macaroni-timer (run-with-timer 1.0 0.15 #'my/macaroni-update)))

(defun my/macaroni-stop ()
  "Stop the animation."
  (when my/macaroni-timer
    (cancel-timer my/macaroni-timer)
    (setq my/macaroni-timer nil)))

(add-hook 'dashboard-after-initialize-hook #'my/macaroni-start)
(add-hook 'window-configuration-change-hook
          (lambda ()
            (if (and (get-buffer "*dashboard*")
                     (get-buffer-window (get-buffer "*dashboard*")))
                (unless my/macaroni-timer (my/macaroni-start))
              (my/macaroni-stop))))

(setq dashboard-banner-logo-title "")
(setq dashboard-startup-banner nil)
(setq dashboard-items nil)
(setq dashboard-set-footer nil)

;; Override everything — just show the macaroni
(advice-add 'dashboard-insert-banner :override
            (lambda ()
              (insert (my/macaroni-centered-frame))))
(advice-add 'dashboard-insert-footer :override
            (lambda () nil))

(dashboard-setup-startup-hook)

;; ============================================================
;; Theme
;; ============================================================
(load-theme 'gruvbox-dark-medium t)

;; ============================================================
;; Evil mode
;; ============================================================
(setq evil-want-integration t)
(setq evil-want-keybinding nil)
(setq evil-want-C-u-scroll t)
(require 'evil)
(evil-mode 1)
(require 'evil-collection)
(evil-collection-init)
(evil-set-leader 'normal (kbd "SPC"))

;; ============================================================
;; Keymaps
;; ============================================================
(evil-define-key 'normal 'global (kbd "<leader>w") 'save-buffer)
(evil-define-key 'normal 'global (kbd "<leader>q") 'evil-quit)
(evil-define-key 'normal 'global (kbd "C-h") 'evil-window-left)
(evil-define-key 'normal 'global (kbd "C-j") 'evil-window-down)
(evil-define-key 'normal 'global (kbd "C-k") 'evil-window-up)
(evil-define-key 'normal 'global (kbd "C-l") 'evil-window-right)
(evil-define-key 'normal 'global (kbd "H") 'previous-buffer)
(evil-define-key 'normal 'global (kbd "L") 'next-buffer)
(evil-define-key 'normal 'global (kbd "<leader>bd") 'kill-current-buffer)
(evil-define-key 'normal 'global (kbd "M-j") (kbd ":m .+1 RET =="))
(evil-define-key 'normal 'global (kbd "M-k") (kbd ":m .-2 RET =="))
(evil-define-key 'visual 'global (kbd "M-j") (concat ":m '>+1" (kbd "RET") "gv=gv"))
(evil-define-key 'visual 'global (kbd "M-k") (concat ":m '<-2" (kbd "RET") "gv=gv"))
(evil-define-key 'visual 'global (kbd "<") "<gv")
(evil-define-key 'visual 'global (kbd ">") ">gv")
(evil-define-key 'normal 'global (kbd "<escape>") 'evil-ex-nohighlight)

;; Fuzzy finder
(evil-define-key 'normal 'global (kbd "<leader>ff") 'counsel-find-file)
(evil-define-key 'normal 'global (kbd "<leader>fg") 'counsel-rg)
(evil-define-key 'normal 'global (kbd "<leader>fb") 'ivy-switch-buffer)
(evil-define-key 'normal 'global (kbd "<leader>fh") 'counsel-describe-function)

;; Diagnostics
(evil-define-key 'normal 'global (kbd "<leader>xx") 'flycheck-list-errors)
(evil-define-key 'normal 'global (kbd "<leader>e") 'flycheck-display-error-at-point)
(evil-define-key 'normal 'global (kbd "[d") 'flycheck-previous-error)
(evil-define-key 'normal 'global (kbd "]d") 'flycheck-next-error)

;; LSP
(evil-define-key 'normal 'global (kbd "gd") 'xref-find-definitions)
(evil-define-key 'normal 'global (kbd "gr") 'xref-find-references)
(evil-define-key 'normal 'global (kbd "K") 'eldoc-doc-buffer)
(evil-define-key 'normal 'global (kbd "<leader>cr") 'eglot-rename)
(evil-define-key 'normal 'global (kbd "<leader>ca") 'eglot-code-actions)
(evil-define-key 'normal 'global (kbd "gD") 'eglot-find-declaration)
(evil-define-key 'normal 'global (kbd "gi") 'eglot-find-implementation)

;; Debug
(evil-define-key 'normal 'global (kbd "<leader>db") 'dape-breakpoint-toggle)
(evil-define-key 'normal 'global (kbd "<leader>dc") 'dape)
(evil-define-key 'normal 'global (kbd "<leader>di") 'dape-step-in)
(evil-define-key 'normal 'global (kbd "<leader>do") 'dape-step-out)
(evil-define-key 'normal 'global (kbd "<leader>dO") 'dape-next)
(evil-define-key 'normal 'global (kbd "<leader>dr") 'dape-restart)
(evil-define-key 'normal 'global (kbd "<leader>dt") 'dape-quit)

;; :run command — compile and run in a terminal buffer with full I/O
(defun my/run ()
  "Compile current C/C++ file and run it in a vterm buffer with interactive I/O."
  (interactive)
  (save-buffer)
  (let* ((file (buffer-file-name))
         (ext (file-name-extension file))
         (base (file-name-sans-extension file))
         (compile-cmd (cond
                       ((string= ext "c") (format "gcc %s -o %s" file base))
                       ((string= ext "cpp") (format "g++ %s -o %s" file base))
                       (t nil)))
         (run-cmd (cond
                   ((member ext '("c" "cpp")) base)
                   ((string= ext "py") (format "python3 %s" file))
                   (t nil))))
    (unless run-cmd
      (user-error "No run command for .%s" ext))
    ;; Compile first if needed
    (when compile-cmd
      (let ((result (shell-command-to-string (concat compile-cmd " 2>&1"))))
        (unless (= 0 (shell-command (concat compile-cmd " 2>/dev/null")))
          (with-current-buffer (get-buffer-create "*compile-errors*")
            (erase-buffer)
            (insert result))
          (display-buffer "*compile-errors*")
          (user-error "Compilation failed"))))
    ;; Run in a term split with interactive I/O
    ;; term-mode has reliable exit handling
    (let ((buf-name "*run*"))
      (when (get-buffer buf-name)
        (let ((w (get-buffer-window buf-name)))
          (when w (delete-window w)))
        (kill-buffer buf-name))
      (split-window-below)
      (other-window 1)
      (ansi-term "/bin/sh" "run")
      (rename-buffer buf-name)
      (term-send-raw-string (concat run-cmd "\nexit\n"))
      ;; When the shell exits, close the window
      (set-process-sentinel
       (get-buffer-process (current-buffer))
       (lambda (proc _event)
         (when (not (process-live-p proc))
           (let* ((buf (process-buffer proc))
                  (win (and buf (get-buffer-window buf))))
             (when win (delete-window win))
             (when buf (kill-buffer buf)))))))))

;; :stop command — kill the running process
(defun my/stop ()
  "Kill the *run* buffer and close its window."
  (interactive)
  (let ((buf (get-buffer "*run*")))
    (when buf
      (when (get-buffer-window buf)
        (delete-window (get-buffer-window buf)))
      (kill-buffer buf))))

;; Register as ex commands so you can type :run and :stop
(evil-ex-define-cmd "run" 'my/run)
(evil-ex-define-cmd "stop" 'my/stop)
(evil-define-key 'normal 'global (kbd "<leader>r") 'my/run)

;; ============================================================
;; Ivy / Counsel
;; ============================================================
(require 'ivy)
(require 'counsel)
(ivy-mode 1)
(counsel-mode 1)
(setq ivy-use-virtual-buffers t)
(setq ivy-count-format "(%d/%d) ")
(setq ivy-re-builders-alist '((t . ivy--regex-fuzzy)))
(setq ivy-height-alist '((t . (lambda (_caller) (/ (frame-height) 2)))))

;; ============================================================
;; Which-key
;; ============================================================
(require 'which-key)
(which-key-mode 1)
(setq which-key-idle-delay 0.3)

;; ============================================================
;; Company
;; ============================================================
(require 'company)
(global-company-mode 1)
(setq company-idle-delay 0.1)
(setq company-minimum-prefix-length 1)
(setq company-selection-wrap-around t)

;; ============================================================
;; Eglot (LSP)
;; ============================================================
(require 'eglot)
(add-hook 'c-mode-hook 'eglot-ensure)
(add-hook 'c++-mode-hook 'eglot-ensure)
(add-hook 'python-mode-hook 'eglot-ensure)

;; ============================================================
;; Flycheck
;; ============================================================
(require 'flycheck)
(global-flycheck-mode 1)

;; ============================================================
;; Format on save
;; ============================================================
(require 'format-all)
(add-hook 'prog-mode-hook 'format-all-mode)
(add-hook 'format-all-mode-hook 'format-all-ensure-formatter)

;; ============================================================
;; Autopairs
;; ============================================================
(electric-pair-mode 1)

;; ============================================================
;; Git signs
;; ============================================================
(require 'diff-hl)
(global-diff-hl-mode 1)
(add-hook 'magit-pre-refresh-hook 'diff-hl-magit-pre-refresh)
(add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh)

;; ============================================================
;; Indent guides
;; ============================================================
(require 'highlight-indent-guides)
(add-hook 'prog-mode-hook 'highlight-indent-guides-mode)
(setq highlight-indent-guides-method 'character)

;; ============================================================
;; Doom modeline
;; ============================================================
(require 'doom-modeline)
(doom-modeline-mode 1)

;; ============================================================
;; Dape (debugger)
;; ============================================================
(require 'dape)

;; ============================================================
;; Evil-surround
;; ============================================================
(require 'evil-surround)
(global-evil-surround-mode 1)

;; ============================================================
;; Magit
;; ============================================================
(require 'magit)
(evil-define-key 'normal 'global (kbd "<leader>gg") 'magit-status)
(evil-define-key 'normal 'global (kbd "<leader>gl") 'magit-log-current)
(evil-define-key 'normal 'global (kbd "<leader>gb") 'magit-blame)
(evil-define-key 'normal 'global (kbd "<leader>gd") 'magit-diff-dwim)

;; ============================================================
;; Vterm
;; ============================================================
(require 'vterm)
(setq vterm-max-scrollback 10000)
(setq vterm-kill-buffer-on-exit t)

(defun my/vterm-toggle ()
  "Toggle terminal at bottom."
  (interactive)
  (let ((buf (get-buffer "vterm")))
    (if (and buf (get-buffer-window buf))
        (delete-window (get-buffer-window buf))
      (let ((win (split-window-below (- (/ (frame-height) 3)))))
        (select-window win)
        (if buf (switch-to-buffer buf) (vterm))))))

(evil-define-key 'normal 'global (kbd "<leader>tt") 'my/vterm-toggle)
(evil-define-key 'normal 'global (kbd "<leader>tn") 'vterm)

;; ============================================================
;; Projectile
;; ============================================================
(require 'projectile)
(projectile-mode 1)
(setq projectile-completion-system 'ivy)
(evil-define-key 'normal 'global (kbd "<leader>pf") 'projectile-find-file)
(evil-define-key 'normal 'global (kbd "<leader>pp") 'projectile-switch-project)
(evil-define-key 'normal 'global (kbd "<leader>pg") 'projectile-ripgrep)
(evil-define-key 'normal 'global (kbd "<leader>pb") 'projectile-switch-to-buffer)

;;; init.el ends here
