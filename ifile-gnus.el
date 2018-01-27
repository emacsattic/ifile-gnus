;;; ifile-gnus.el version-0-3-5 -- provides support for using the
;;; 'ifile' mail-classification program with several gnus nnmail
;;; backends.
;;;
;;; Copyright 2002 by Jeremy H. Brown <jhbrown@ai.mit.edu>
;;;
;;; License: GPL
;;;
;;; This file is covered by the GNU General Public License.
;;; 
;;; 
;;; 2002/10/10 20:59:25  jhbrown

;;; Please see the accompanying README for installation,
;;; configuration, usage, etc.

;;;        WARNING    WARNING   WARNING   WARNING   WARNING
;;;
;;; THIS IS ALPHA-QUALITY SOFTWARE.  IT MAY EAT YOUR EMAIL.  IT MAY
;;; CORRUPT YOUR GNUS CONFIGURATION.  IT MAY DO OTHER UNPLEASANT
;;; THINGS TO YOUR COMPUTER.  I'M NOT KIDDING.
;;; 
;;; USE AT YOUR OWN RISK.  NO WARRANTEE.  NO GUARANTEES.  NO REFUNDS,
;;; RETURNS, OR EXCHANGES.  
;;;
;;; HAVE A NICE DAY.


(eval-when-compile 
  (defvar ifile-article-buffer)
  (defvar ifile-backend-request-article)
  (require 'gnus-util)
  (require 'gnus-int))
;;; the requires above are because we need a macro definition for
;;; gnus-group-real-name from gnus-util, and we might as well use the
;;; right definition of gnus-request-article from gnus-int.

;;; ------------------------------------------------------------
;;; Customization variables
;;; ------------------------------------------------------------

;;; point this at the binary
(defvar ifile-program "ifile")

;;; this may be either 'full-classification or 'spam-filter-only
(defvar ifile-classification-mode 'full-classification)

;;; If you're using spam-filter-only, name your spam-groups here
(defvar ifile-spam-groups '("spam"))
(defvar ifile-primary-spam-group "spam")

;;; set this false to disable ifile
(defvar ifile-active t)

;;; you want to ignore some groups, e.g. the drafts group
(defvar ifile-ignore-groups '("drafts"))

;;; ------------------------------------------------------------
;;; How to call ifile
;;; ------------------------------------------------------------

(defvar ifile-classify-flags '("-g" "-c" "-q"))

;;; group name will follow these flags on the command line
(defvar ifile-insert-flags '("-g" "-i"))
(defvar ifile-delete-flags '("-g" "-d"))


;;; ------------------------------------------------------------
;;; user-visible recommendation function
;;; ------------------------------------------------------------


(defun ifile-recommend ()
  (save-excursion 
    (let ((icat-buf (get-buffer-create " *ifile category*")))
      (set-buffer icat-buf)
      (erase-buffer)
      (with-current-buffer ifile-article-buffer
	(message "ifile: generating recommendation...")
	(apply 'call-process-region (point-min) (point-max) 
	       ifile-program nil icat-buf nil ifile-classify-flags)
	)
      (message "ifile: recommendation is \"%s\"" 
	       (buffer-substring (point-min) (- (point-max) 1)))
      (buffer-substring (point-min) (- (point-max) 1)))))

(defun ifile-spam-filter (other-split)
  (if (and ifile-active (equal (ifile-recommend) "spam"))
      ifile-primary-spam-group
    other-split))


;;; ------------------------------------------------------------
;;; Routines for invoking the binary
;;; ------------------------------------------------------------

(defun ifile-spam-filtered-group-name (group)
  (if (equal ifile-classification-mode 'spam-filter-only)
      (setq group (if (member group ifile-spam-groups)
		      "spam"
		    "non-spam")))
  group)

(defun ifile-learn-about-article (flags message-format group-name)
  (let ((filtered-group-name 
	 (ifile-spam-filtered-group-name group-name)))
    (message message-format filtered-group-name)
    (apply 'call-process-region (point-min) (point-max) 
	   ifile-program nil nil nil 
	   `(,@flags ,filtered-group-name))))

(defun ifile-insert-article (group-name)
  (ifile-learn-about-article ifile-insert-flags
			     "ifile: storing classification as \"%s\""
			     group-name))

(defun ifile-delete-article (group-name)
  (ifile-learn-about-article ifile-delete-flags
			     "ifile: descoring classification from \"%s\""
			     group-name))

;;; ------------------------------------------------------------
;;; Functions for back-end bookkeeping
;;; ------------------------------------------------------------

(defun ifile-request-move-article (article group server)
  "tell ifile to de-score the article being moved from the current group"
  (if (and ifile-active (not (member group ifile-ignore-groups)))
      (save-excursion
	(let ((ibuf (get-buffer-create " *ifile gnus article buffer*"))
	      (from-group (gnus-group-real-name group)))
	  (set-buffer ibuf)
	  (erase-buffer)
	  (message "ifile: requesting article...")
	  ;; Will this play well with IMAP?
	  (funcall ifile-backend-request-article article group server ibuf)
	  (ifile-delete-article from-group)
	  (message "ifile: done.")))))

(defun ifile-request-accept-article (group)
  "tell ifile to score the article being moved into some new group, 
   if it's defined;  if it's not, then the split-method will catch it."
  (if (and ifile-active group (not (member group ifile-ignore-groups)))
      (save-excursion
	;; lucky us: article's in the buffer we're in.
	(let ((to-group (gnus-group-real-name group)))
	  (ifile-insert-article to-group)
	  (message "ifile: done.")))))

(defun ifile-request-replace-article (article group buffer)
  "we're replacing text of an article; remove the old text and 
   insert the new text into the ifile database entry for this group"
  (if (and ifile-active (not (member group ifile-ignore-groups)))
      (save-excursion
	(let ((ibuf (get-buffer-create " *ifile gnus article buffer*"))
	      (real-group (gnus-group-real-name group)))
	  (set-buffer ibuf)
	  (erase-buffer)
	  (message "ifile replace-article: fetching article...")
	  ;; Is using a nil server safe for all backends?
	  (funcall ifile-backend-request-article article group nil ibuf)
	  (message "ifile: descoring old version...")
	  (ifile-delete-article real-group)
	  (set-buffer buffer)
	  (message "ifile: scoring new/edited version...")
	  (ifile-insert-article real-group)
	  (message "ifile: done.")))))


;;; ------------------------------------------------------------
;;; Advice and advice template macros
;;; ------------------------------------------------------------

(defadvice nnmail-article-group (around ifile-name-article-buffer (&rest args))
  "pre: name the article buffer for use by ifile in making recommendation
   post: record the actual decision made"
  (let ((ifile-article-buffer (current-buffer)))
    ad-do-it
    (let ((first-group (caar ad-return-value)))
      (ifile-insert-article first-group)
      (message "ifile: done."))))
      

;;; My first elisp macro.  May god have mercy upon my soul.
(defmacro ifile-backend-request-concat(prefixp)
  `(intern (concat (if ,prefixp "ifile-" "") 
		   (symbol-name backend) "-request-" 
		   (symbol-name request-type))))

(defmacro ifile-advise-one-backend-function(backend request-type argslist)
  (let ((tempvar (make-symbol "rest")))
    `(progn
       (defadvice 
	 ,(ifile-backend-request-concat nil)
	 (before ,(ifile-backend-request-concat t)
		 (,@argslist &rest ,tempvar))
	 (let ((ifile-backend-request-article (symbol-function 
					       (quote ,(intern (concat (symbol-name backend) "-request-article"))))))
	   (,(intern (concat "ifile-request-" (symbol-name request-type)))
	    ,@argslist))))))

;;; Using the macros, actually advise a backend
(defmacro ifile-advise-backend (backend)
  `(progn
     (ifile-advise-one-backend-function ,backend move-article 
					(article group server))
     (ifile-advise-one-backend-function ,backend accept-article 
					(group))
     (ifile-advise-one-backend-function ,backend replace-article 
					(article group buffer))))


;;; ------------------------------------------------------------
;;; Per-back-end advice
;;; ------------------------------------------------------------

;;; nnml works.
(ifile-advise-backend nnml)  

;;; these are lightly tested
(ifile-advise-backend nnbabyl)  
(ifile-advise-backend nnfolder)  

;;; these are untested.
(ifile-advise-backend nnmbox)  
(ifile-advise-backend nnmh)  
  

;;; ------------------------------------------------------------
;;; Turn it all on....
;;; ------------------------------------------------------------
(ad-activate-regexp "^ifile")

(provide 'ifile-gnus)

