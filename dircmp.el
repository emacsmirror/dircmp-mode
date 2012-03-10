;;; dircmp-mode.el --- Compare and sync directories.

;; Copyright (C) 2012 Matt McClure

;; Author: Matt McClure
;; Keywords: unix, tools

;; dircmp-mode is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by the
;; Free Software Foundation, either version 3 of the License, or (at your
;; option) any later version.

;; dircmp-mode is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with dircmp-mode.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Add to your Emacs startup file:
;;
;;    (load "/path/to/dircmp.el")

;;; Code:

(define-derived-mode dircmp-mode
  fundamental-mode "DirCmp"
  "Major mode for comparing and syncing two directories.
\\{dircmp-mode-map}"
  (setq goal-column 7))

(define-key dircmp-mode-map "+" 'toggle-compare-recursively)
(define-key dircmp-mode-map "<" 'dircmp-do-sync-right-to-left)
(define-key dircmp-mode-map "=" 'toggle-show-equivalent)
(define-key dircmp-mode-map ">" 'dircmp-do-sync-left-to-right)
(define-key dircmp-mode-map "G" 'toggle-compare-group)
(define-key dircmp-mode-map "\C-m" 'dircmp-do-ediff)
(define-key dircmp-mode-map "d" 'toggle-preserve-devices-and-specials)
(define-key dircmp-mode-map "g" 'recompare-dirs)
(define-key dircmp-mode-map "l" 'toggle-include-present-only-on-left)
(define-key dircmp-mode-map "n" 'next-line)
(define-key dircmp-mode-map "o" 'toggle-compare-owner)
(define-key dircmp-mode-map "p" 'previous-line)
(define-key dircmp-mode-map "p" 'toggle-compare-permissions)
(define-key dircmp-mode-map "r" 'toggle-include-present-only-on-right)
(define-key dircmp-mode-map "s" 'toggle-preserve-symlinks)
(define-key dircmp-mode-map "t" 'toggle-compare-times)

(defvar rsync-output-buffer " *dircmp-rsync-output*")
(defvar diff-output-buffer " *dircmp-diff-output*")
(defvar comparison-view-buffer "*DirCmp*")
(defcustom dircmp-show-equivalent nil "Show equivalent files")
(make-variable-buffer-local 'dircmp-show-equivalent)
(defun toggle-show-equivalent ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-show-equivalent (not dircmp-show-equivalent))))
(defcustom dircmp-compare-recursively t "Compare directories recursively")
(make-variable-buffer-local 'dircmp-compare-recursively)
(defun toggle-compare-recursively ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-compare-recursively (not dircmp-compare-recursively))))
(defcustom dircmp-preserve-symlinks t "Preserve symlinks when syncing")
(make-variable-buffer-local 'dircmp-preserve-symlinks)
(defun toggle-preserve-symlinks ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-preserve-symlinks (not dircmp-preserve-symlinks))))
(defcustom dircmp-compare-permissions t "Compare permissions")
(make-variable-buffer-local 'dircmp-compare-permissions)
(defun toggle-compare-permissions ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-compare-permissions (not dircmp-compare-permissions))))
(defcustom dircmp-compare-times t "Compare times")
(make-variable-buffer-local 'dircmp-compare-times)
(defun toggle-compare-times ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-compare-times (not dircmp-compare-times))))
(defcustom dircmp-compare-group t "Compare groups")
(make-variable-buffer-local 'dircmp-compare-group)
(defun toggle-compare-group ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-compare-group (not dircmp-compare-group))))
(defcustom dircmp-compare-owner t "Compare owners")
(make-variable-buffer-local 'dircmp-compare-owner)
(defun toggle-compare-owner ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-compare-owner (not dircmp-compare-owner))))
(defcustom dircmp-preserve-devices-and-specials t "Preserve device files and special files")
(make-variable-buffer-local 'dircmp-preserve-devices-and-specials)
(defun toggle-preserve-devices-and-specials ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-preserve-devices-and-specials (not dircmp-preserve-devices-and-specials))))
(defcustom dircmp-include-present-only-on-left t "Include files only present on left in comparison view")
(make-variable-buffer-local 'dircmp-include-present-only-on-left)
(defun toggle-include-present-only-on-left ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-include-present-only-on-left (not dircmp-include-present-only-on-left))))
(defcustom dircmp-include-present-only-on-right t "Include files only present on right in comparison view")
(make-variable-buffer-local 'dircmp-include-present-only-on-right)
(defun toggle-include-present-only-on-right ()
  (interactive)
  (with-current-buffer comparison-view-buffer
    (set 'dircmp-include-present-only-on-right (not dircmp-include-present-only-on-right))))
(defcustom dircmp-compare-content "size" "Method for comparing file content"
  :type '(choice (const "size")
                 (const "checksum")
                 (const "byte by byte")
                 (const "ignore whitespace differences")
                 (const "by file type")))
(make-variable-buffer-local 'dircmp-compare-content)

(defun compare-dirs (dir1 dir2)
  (interactive "DLeft directory: \nDRight directory: ")
  (get-buffer-create comparison-view-buffer)
  (set-buffer comparison-view-buffer)
  (dircmp-mode)
  (recompare-dirs dir1 dir2))

(defun recompare-dirs (&optional dir1 dir2)
  (interactive)
  (get-buffer-create rsync-output-buffer)
  (set-buffer rsync-output-buffer)
  (erase-buffer)
  (let ((normalized-dir1 (if dir1 (normalize-dir-string dir1) left-dir))
        (normalized-dir2 (if dir2 (normalize-dir-string dir2) right-dir)))
    (set (make-local-variable 'left-dir) normalized-dir1)
    (set (make-local-variable 'right-dir) normalized-dir2)
    (compare-with-rsync left-dir right-dir)
    (refine-comparison-with-diff)
    (update-comparison-view left-dir right-dir)))

(defun compare-with-rsync (dir1 dir2)
  (call-process-shell-command
   (format "rsync %s '%s' '%s'" (rsync-comparison-options) dir1 dir2)
   nil rsync-output-buffer))

(defun rsync-comparison-options ()
  (with-current-buffer comparison-view-buffer
    (concat
     "-ni"
     (if dircmp-show-equivalent "i")
     (if dircmp-compare-recursively "r") 
     (if (equal dircmp-compare-content "checksum") "c")
     (if dircmp-preserve-symlinks "l")
     (if dircmp-compare-permissions "p")
     (if dircmp-compare-times "t")
     (if dircmp-compare-group "g")
     (if dircmp-compare-owner "o")
     (if dircmp-preserve-devices-and-specials "D")
     (if (not dircmp-include-present-only-on-left) " --existing")
     (if dircmp-include-present-only-on-right " --delete"))))

(defun refine-comparison-with-diff ()
  (if (equal dircmp-compare-content "ignore whitespace differences")
      (save-excursion
        (get-buffer-create diff-output-buffer)
        (set-buffer diff-output-buffer)
        (erase-buffer)
        (set-buffer rsync-output-buffer)
        (goto-char (point-min))
        (let ((lines (count-lines (point-min) (point-max))))
          (while (<= (line-number-at-pos) lines)
            (if (or (string-equal "c" (substring (comparison-on-current-rsync-line) 2 3))
                    (string-equal "s" (substring (comparison-on-current-rsync-line) 3 4)))
                (progn
                  (set-buffer diff-output-buffer)
                  (erase-buffer)
                  (call-process-shell-command
                   (format "diff -q -s -w '%s' '%s'" (left-on-current-rsync-line) (right-on-current-rsync-line))
                   nil diff-output-buffer)
                  (if (re-search-backward " are identical\n" nil t)
                      (progn
                        (set-buffer rsync-output-buffer)
                        (goto-char (+ (line-beginning-position) 2))
                        (delete-char 2)
                        (insert "..")))))
            (set-buffer rsync-output-buffer)
            (forward-line))))))

(defun normalize-dir-string (dir)
  (file-name-as-directory (expand-file-name dir)))

(defun update-comparison-view (dir1 dir2)
  (set-buffer rsync-output-buffer)
  (let ((rsync-output (buffer-string)))
    (switch-to-buffer comparison-view-buffer)
    (let ((line (line-number-at-pos)))
      (set 'buffer-read-only nil)
      (erase-buffer)
      (insert (format "Directory comparison:\n\n Left: %s\nRight: %s\n\n" dir1 dir2))
      (format-rsync-output rsync-output)
      (switch-to-buffer comparison-view-buffer)
      (insert """
Key:
    .: equivalent
    c: content differs
    l: only present on left
    r: only present on right
    t: timestamps differ
    p: permissions differ
    o: owner differs
    g: group differs
""")
      (set 'buffer-read-only t)
      (goto-char (point-min)) (forward-line (- line 1)))))

(defun dircmp-do-ediff ()
  (interactive)
  (let* ((file-A (left-on-current-view-line))
         (file-B (right-on-current-view-line))
         (buf-A (or (get-file-buffer file-A) (find-file-noselect file-A)))
         (buf-B (or (get-file-buffer file-B) (find-file-noselect file-B))))
    (ediff-buffers buf-A buf-B)))

(defun dircmp-do-sync-left-to-right ()
  (interactive)
  (let ((command (format "rsync -idlptgoD --delete '%s' '%s'"
                         (directory-file-name (left-on-current-view-line))
                         (file-name-directory (directory-file-name (right-on-current-view-line))))))
    (call-process-shell-command command))
  (recompare-dirs))

(defun dircmp-do-sync-right-to-left ()
  (interactive)
  (let ((command (format "rsync -idlptgoD --delete '%s' '%s'"
                         (directory-file-name (right-on-current-view-line))
                         (file-name-directory (directory-file-name (left-on-current-view-line))))))
    (call-process-shell-command command))
  (recompare-dirs))

(defun file-on-current-rsync-line ()
  (save-excursion
    (switch-to-buffer rsync-output-buffer)
    (buffer-substring-no-properties (+ (line-beginning-position) 10) (line-end-position))))

(defun comparison-on-current-rsync-line ()
  (save-excursion
    (switch-to-buffer rsync-output-buffer)
    (buffer-substring-no-properties (line-beginning-position) (+ (line-beginning-position) 9))))

(defun file-on-current-view-line ()
  (save-excursion
    (switch-to-buffer comparison-view-buffer)
    (buffer-substring-no-properties (+ (line-beginning-position) 7) (line-end-position))))

(defun left-on-current-rsync-line ()
  (save-excursion
    (switch-to-buffer rsync-output-buffer)
    (concat left-dir (file-on-current-rsync-line))))

(defun right-on-current-rsync-line ()
  (save-excursion
    (switch-to-buffer rsync-output-buffer)
    (concat right-dir (file-on-current-rsync-line))))

(defun left-on-current-view-line ()
  (save-excursion
    (switch-to-buffer rsync-output-buffer)
    (concat left-dir (file-on-current-view-line))))

(defun right-on-current-view-line ()
  (save-excursion
    (switch-to-buffer rsync-output-buffer)
    (concat right-dir (file-on-current-view-line))))

(defun format-rsync-output (rsync-output)
  (progn
    (switch-to-buffer rsync-output-buffer)
    (goto-char (point-min))
    (while (> (- (line-end-position) (line-beginning-position)) 10)
      (let ((rsync-comparison (comparison-on-current-rsync-line))
            (file (file-on-current-rsync-line)))
        (switch-to-buffer comparison-view-buffer)
        (insert (format "%6s %s\n" (format-comparison rsync-comparison) file))
        (switch-to-buffer rsync-output-buffer)
        (forward-line)))))

(defun format-comparison (rsync-comparison)
  (cond ((string-match "^\*deleting" rsync-comparison)
         "r....")
        ((string-equal ">f+++++++" rsync-comparison)
         "l....")
        ((string-equal "c" (substring rsync-comparison 0 1))
         "l....")
        ((or (string-equal "c" (substring rsync-comparison 2 3))
             (string-equal "s" (substring rsync-comparison 3 4)))
         (concat "c" (substring rsync-comparison 4 8)))
        (t
         (concat (substring rsync-comparison 2 3) (substring rsync-comparison 4 8)))
        ))

(provide 'dircmp-mode)
