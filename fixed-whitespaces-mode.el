;;; fixed-pitch-whitespace-mode.el --- Enable fixed-pitch whitespaces in a buffer   -*- lexical-binding: t -*-

;; TODO
;; [Done(Maybe?)] [Needs improvement]It triggers gc too frequently.  Maybe it could use
;; a face appending instead of checking for whether it is in block or something
;; to not font look it, as it reduces height further by accumulating the height
;; specification from other faces.

;; [Fixed] turning on/off takes too long and to be lazily loaded by jit-lock,
;; but still needs to optimize for re-search, it takes time the same O(n), so
;; when scrolling fast for the first time after turning on/off the mode, it's a
;; bit laggy.  It's solved by replacing to check each line is in a block that
;; has fixed-pitch font or not by instead checking each line is in fixed-pitch
;; font, this is much faster.  [Note] This way, we probably laterly have to remove two
;; matchers into one, since there's no need todifferentiate the work on org-mode
;; and other modes.

;; Requried by `buffer-face-mode'.
(require 'face-remap)
(require 'org)
(require 'cl-lib)

(defgroup fixed-pitch-whitespace nil
  "Display spaces with a fixed-pitch face inside variable-pitch buffers."
  :group 'faces ;parent group
  :prefix "fixed-pitch-whitespace-")

(defface fixed-pitch-whitespace-face
  '((t (:inherit fixed-pitch)))
  "Face for displaying leading whitespaces in `fixed-pitch-whitespace-local-mode`."
  :group 'fixed-pitch-whitespace)

(defvar-local fpw--results-header-line-regex
  (format "^[ \t]*#\\+%s:" org-babel-results-keyword))
(defvar-local fpw--org-whitespace-regex "^[ \t]+")
(defvar-local fpw--org-block-begin-regex "^[ \t]*#\\+begin_")
(defvar-local fpw--org-block-end-regex "^[ \t]*#\\+end_")

(defun fixed-pitch-face-inheritance-p (face &optional visited)
  "Return t if FACE or any face it inherits from is `fixed-pitch'.
FACE may be a symbol or a list of symbols. VISITED is used to avoid cycles.
If FACE is nil or `unspecified', the function returns nil."
  (cond
   ;; If there's no valid face, return nil.
   ((or (null face) (eq face 'unspecified)) nil)
   ;; If face is a list, check if any member qualifies.
   ((listp face)
    (cl-some (lambda (f)
               (fixed-pitch-face-inheritance-p f visited))
             face))
   ;; Direct match.
   ((eq face 'fixed-pitch) t)
   ;; Prevent cycles in case of recursive inheritance.
   ((memq face visited) nil)
   (t
    (let ((inherit (face-attribute face :inherit nil nil)))  ; NOINHERIT=nil, so inheritance is followed.
      (if inherit
          (fixed-pitch-face-inheritance-p inherit (cons face (or visited nil)))
        nil)))))
(defun char-at-point-displayed-fixed-pitch-p ()
  "Return t if the character at POS (or point) is rendered with a fixed-pitch face.
This means the text property `face' is either directly `fixed-pitch'
or inherits from it—even when the inheritance field contains multiple faces.
If the face is nil or `unspecified', it returns nil."
  (let* ((pos (point))
         ;; (face (or (get-text-property pos 'face)
         ;;           ;; fallback to retrive the face by overlays, defaults, etc.
         ;;           (face-at-point pos))))
         (face (get-text-property pos 'face))
         )
    (if (or (null face) (eq face 'unspecified))
        nil
      (if (listp face)
          (cl-some #'fixed-pitch-face-inheritance-p face)
        (fixed-pitch-face-inheritance-p face)))))
(defun my/leading-whitespace-matcher-org-mode (limit)
  "Match leading whitespaces outside of org-src-blocks up to LIMIT."
  (let* ((found nil)
         (case-fold-search t))
    (while (and (not found)
                ;; Match leading whitespaces, use "^[ \t]+" instead of
                ;; "^\\(\\s-+\\)" to match only spaces and tabs instead of all
                ;; types of whitespaces for better performance.
                ;; (re-search-forward "^[ \t]+" limit t))
                (re-search-forward fpw--org-whitespace-regex limit t))
      ;; (message "Inside fixed-space.")
      (save-excursion
        (beginning-of-line)
        (unless ;; Testing whether every line for if its leading spaces are
                ;; fixed-pitch or not results in much better performance than
                ;; the previous chunk of code that checks each line is in a org
                ;; block that is displayed in fixed-pitch or not.
                 (save-match-data
                   (char-at-point-displayed-fixed-pitch-p))
          (set-match-data (list (match-beginning 0) (match-end 0)))
          (setq found t))))
    found))
(defun my/leading-whitespace-matcher-other-modes (limit)
  "Match leading whitespaces outside of org-src-blocks up to LIMIT. Better
performance for other modes than org-mode, by simplifying matching without
addtional org-syntax conditions."
  (let ((case-fold-search t))
    ;; (if (re-search-forward "^[ \t]+" limit t)
    (if (re-search-forward fpw--org-whitespace-regex limit t)
        (progn
          (set-match-data (list (match-beginning 0) (match-end 0)))
          t)
      nil)))
(defun variable-pitch-mode-p ()
  "Return non-nil if current buffer is in `variable-pitch-mode'."
  (and buffer-face-mode           ; the minor mode is on
       (eq buffer-face-mode-face 'variable-pitch)))

(defvar fpw--theme-switch-timer nil)
(defvar fixed-pitch-whitespace-theme-switch-defer-time 0.005
  "The reason to run refontification code in a timer `fpw--theme-switch-timer` is
to prevents it from running multiple times when switching to a theme, switching
to a theme runs multiple times of `enable-theme` and `disable-theme` especially
when the theme configuration is complex in a user setup.  A defer time variable
`fixed-pitch-whitespace-theme-switch-defer-time` is provided to let user set,
its time should exceed between the gap of two executions of either
`enable-theme` and `disable-theme` depending on the host's performance and user
config's overhead, so the refontification won't run when each enable-theme or
disable-theme runs, only after the last execution of either of these two
functions.  Since when several files that have the mode enabled, it becomes
expensive to refontify when intensely switching through themes like with
`consult-theme`.")
(defun fpw--theme-switch-refontify-in-timer (&rest _)
    (when (timerp fpw--theme-switch-timer)
      (cancel-timer fpw--theme-switch-timer))
    (setq fpw--theme-switch-timer
          (run-with-timer
           fixed-pitch-whitespace-theme-switch-defer-time
           nil
           'fpw--theme-switch-buffers--refontify)))
(define-minor-mode fixed-pitch-whitespace-local-mode
  ;; Needs better performance improvement, consult the implementation of
  ;; org-mode headings, and org-superstar.
  "Minor mode to display leading space and tab characters at each line in
`fixed-pitch' font, for better visualization of indentation. Used in cases like
in variable-pitch-mode. Asked to & Provided by copilot from microsoft with some
improvements by me."
  :lighter " FP-SPC"
  :group 'fixed-pitch-whitespace
  (if fixed-pitch-whitespace-local-mode
    (progn
      (if (fpw--is-buffer-tabbed-p)
            (setq-local fpw--org-whitespace-regex "^[ \t]+"
                        fpw--results-header-line-regex
                        (format "^[ \t]*#\\+%s:" org-babel-results-keyword)
                        fpw--org-block-begin-regex "^[ \t]*#\\+begin_"
                        fpw--org-block-end-regex "^[ \t]*#\\+end_"
                        )
        (setq-local fpw--org-whitespace-regex "^ +"
                    fpw--results-header-line-regex
                    (format "^ *#\\+%s:" org-babel-results-keyword)
                    fpw--org-block-begin-regex "^ *#\\+begin_"
                    fpw--org-block-end-regex "^ *#\\+end_")
        )
      (font-lock-add-keywords
       nil
       '((my/leading-whitespace-matcher-org-mode 0 'fixed-pitch-whitespace-face append))
       'append)
      (add-hook 'enable-theme-functions
                'fpw--theme-switch-refontify-in-timer)
      (add-hook 'disable-theme-functions
                'fpw--theme-switch-refontify-in-timer)
      (add-hook 'indent-tabs-mode-hook
                'fpw--in-indent-tabs-mode nil t)
      )
    (font-lock-remove-keywords
     nil
     '((my/leading-whitespace-matcher-org-mode 0 'fixed-pitch-whitespace-face append)))
    (remove-hook 'enable-theme-functions
                 'fpw--theme-switch-refontify-in-timer)
    (remove-hook 'disable-theme-functions
                 'fpw--theme-switch-refontify-in-timer)
    (remove-hook 'indent-tabs-mode-hook 'fpw--in-indent-tabs-mode t)
    )
  ;; (when font-lock-mode (save-restriction (widen) (font-lock-flush)
  ;;   (font-lock-ensure)))
  ;; Lazy, so much faster like rocket. Putting characters's fontified property
  ;; to nil causes jit-lock will fontify it again when emacs rediplays or is not
  ;; busy. Just like `jit-lock-after-change` in `after-change-functions` does.
  ;; Out of `(if fixed-pitch-whitespace-local-mode)`, so enabling/disabling the mode
  ;; will both get jit-refresh the font-lock.
  (when font-lock-mode
    (jit-lock-refontify))
  )

(defun fpw--enable-theme-refontify (&rest _)
  (when (and font-lock-mode
             fixed-pitch-whitespace-local-mode)
    (jit-lock-refontify)))

(defun fpw--theme-switch-buffers--refontify (&rest _)
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when fixed-pitch-whitespace-local-mode
        (message "`fpw--enable-theme-refontify` executed")
        (fpw--enable-theme-refontify)))))

(define-globalized-minor-mode fixed-pitch-whitespace-global-mode fixed-pitch-whitespace-local-mode
  (lambda ()
    (when (and (variable-pitch-mode-p)
               (not (minibufferp)))
      (fixed-pitch-whitespace-local-mode 1)
      ))
  )

;;; This section implements to replace regexps that contain "[ \t]" to be "[ ]"
;;; only for those buffers that don't use tabs, for better performance.
;;; This may not be a good idea that may cause potential issues.
(defun fpw--is-buffer-tabbed-p ()
  "Test if the buffer has not tabs and indent-tabs-mode is not turned on."
  (or (save-excursion
        (without-restriction
          (goto-char (point-min))
          (re-search-forward "^ *\t" nil t)
          ;; For fastest speed, that just
          ;; checks the buffer has tabs or not.  But other searches based on
          ;; this that turn to search for spaces & tabs might be affected
          ;; greatly by this result. Needs thorough consideration.
          ;; (re-search-forward "\t" nil t)
          ))
      indent-tabs-mode
      ))
(defun fpw--in-indent-tabs-mode ()
  ;; when toggling `indent-tabs-mode`, execute `fixed-pitch-whitespace-local-mode`
  ;; again when it's enabled, for refershing tab-related settings of
  ;; `fixed-pitch-whitespace-local-mode`.
  (when fixed-pitch-whitespace-local-mode
    (fixed-pitch-whitespace-local-mode 1)
    )
  )

(provide 'fixed-pitch-whitespace-mode)
;;; fixed-pitch-whitespace-mode.el ends here

;; The following feature leared from `breadcrumb-mode` is documented in the
;; section of "Top > Symbols > Shorthands".

;; Local Variables:
;; read-symbol-shorthands: (("fpw-" . "fixed-pitch-whitespace-"))
;; End:
