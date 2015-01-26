;; This function starts Matlab

(defvar my-buffer "")

(defun my-config-display ()
  (delete-other-windows)
  (switch-to-display)
  (erase-buffer)
  (other-window -1))

(defvar signal 0
  "The variable signal is used to indicate the function which has called to matlab and to process the result")

(defun my-output-filter (output)
  "This is in charge of processing the output produced by Matlab"
  (setq my-buffer (concat my-buffer output))
  (when (and output (get-buffer "*display*"))
    (with-current-buffer "*display*"
      (erase-buffer)
      (cond ((equal signal 0) nil)
            ((equal signal 1)
             (print-similarities (split-clusters-aux2 my-buffer nil)))
            ((equal signal 4)
             (print-clusters-bis (split-clusters-aux my-buffer nil)
                                 (split-frequencies my-buffer nil)))
            ((equal signal 3)
             (compute-clusters-and-values (split-clusters-aux (remove-jumps (subseq my-buffer (search "load" my-buffer :from-end t))) nil)
                                          (split-frequencies (remove-jumps  (subseq my-buffer (search "load" my-buffer :from-end t))) nil)))
            (t nil))))
  output)

(add-hook 'comint-preoutput-filter-functions 'my-output-filter)

(defun split-clusters-aux2 (str res)
  (let ((init (search "ans =" str)))
    (if init
        (list (cluster-string-to-list (remove-jumps (subseq str (+ 5 init)
                                                            (search ">>" str :from-end t)))))
      nil)))

(defun split-clusters-aux (str res)
  (let ((init (search "ans =" str)))
    (if init
        (let ((end (search "[" str :start2 (1+ init))))
          (split-clusters-aux (subseq str (1+ end))
                              (cons (cluster-string-to-list (remove-jumps (subseq str (+ 5 init)
                                                                                  end)))
                                    res)))
      res)))


(defun split-frequencies (str res)
  (let ((init (search "[" str)))
    (if init
        (let ((end (search "]" str :start2 (1+ init))))
          (if (not (search "char" (subseq str init end)))
              (split-frequencies (subseq str (1+ end))
                                 (cons (string-to-number (remove-jumps (subseq str (1+ init) end))) res))
            (split-frequencies (subseq str (1+ (search "[" str :start2 (1+ end))))  res)))
      res)))

(defun remove-jumps (str)
  (do ((temp str)
       (temp2 "")
       (i 0 (1+ i))
       (jump (search "\n" str)))
      ((not jump)
       (if (= i 0)
           str temp2))
    (progn (setf temp2 (concatenate 'string temp2 (subseq temp 0 jump)))
           (setf temp (subseq temp (1+ jump)))
           (setf jump (search "\n" temp)))))

(defun search-cluster (res n)
  (do ((temp res (cdr temp))
       (temp2 nil))
      ((endp temp)
       temp2)
    (if (member (format "%s" n)
                (car temp))
        (append temp2 (list (car temp))))))

(defun cluster-string-to-list (cluster)
  (do ((temp cluster)
       (temp2 nil))
      ((not (search "," temp))
       (append temp2 (list temp)))
    (progn (setf temp2 (append temp2 (list (subseq temp 0 (search "," temp)))))
           (setf temp (subseq temp (1+ (search "," temp)))))))

(defun remove-occurrence (list n)
  (do ((temp list (cdr temp))
       (temp2 nil))
      ((endp temp)
       temp2)
    (if (not (equal (format "%s" n)
                    (car temp)))
        (setf temp2 (append temp2 (list (car temp)))))))

(defvar granularity-level-temp 1)

(defun print-similarities (res)
  (print-similarities-aux (lambda (&rest args)) res))


(defun print-similarities-matlab ()
  (with-current-buffer "*display*"
    (while (string= "0" (car (read-lines (expand-file-name "available.txt"))))

      (progn (erase-buffer)
             (insert (format "Searching clusters...\n"))
             (sleep-for 1))
      )
    (erase-buffer)
    (let* ((clu (car (read-lines (expand-file-name "matlab_res.txt")))))
      (cond
       ((search "None" clu)
        (if (not iterative)
            (insert (format "Sorry, but we have not found any similarity using granularity %s\n" granularity-level))
          (if (eq granularity-level-temp 5)
              (format "Sorry, but we have not found any similarity at any ganularity level\n")
            (progn (setf granularity-level-temp (1+ granularity-level-temp))
                   (show-clusters-of-theorem-iterative)))))
       (t (progn (insert (format "Similarities:\n"))
                 (insert (format "------------------------------------------------------------------------------------------------------------\n"))
                 (insert (format "This lemma is similar to the lemmas:\n "))
                 (do ((temp2 (remove-occurrence (cluster-string-to-list clu)
                                                (1+ (length saved-theorems)))
                             (cdr temp2)))
                     ((endp temp2)
                      )
                   (if (<= (string-to-number (car temp2))
                           (length saved-theorems))
                       (progn (insert (format "- "))
                              (insert-button-lemma (remove_last_colon(car (nth (- (string-to-number (car temp2))
                                                                                  1)
                                                                               saved-theorems)))))
                     (progn (shell-command (concat "cat "(expand-file-name "names_temp.txt")
                                                   " | sed -n '"
                                                   (format "%s" (- (string-to-number (car temp2))
                                                                   (length saved-theorems)))
                                                   "p'"))

                            (with-current-buffer "*Shell Command Output*"
                              (beginning-of-buffer)
                              (read (current-buffer))
                              (setf temp-res (remove_last_colon (format "%s"  (read (current-buffer))))))
                            (insert (format "- "))
                            (insert-button-lemma temp-res)))))
          (insert (format "------------------------------------------------------------------------------------------------------------\n"))
          (if iterative (insert (format "Similarities found using granularity level %s\n" granularity-level-temp))))))))

(defun insert-button-lemma (lemma)
  (progn (insert-button lemma 'action (insert-button-lemma-macro lemma)
                        'face (list 'link)
                        'follow-link t)))

(defun insert-button-lemma-macro (test)
  (list 'lambda '(x)
        (list 'progn
              (list 'proof-shell-invisible-cmd-get-result (list 'format '"Unset Printing All."))
              (list 'if (list 'get-buffer '"*display2*")
                    (list 'with-current-buffer '"*display2*" (list 'delete-window)))
              (list 'with-current-buffer '"*display*" (list 'split-window-vertically))
              (list 'switch-to-buffer-other-window '"*display2*")
              (list 'with-current-buffer '"*display2*" (list 'erase-buffer))
              (list 'with-current-buffer '"*display2*"
                    (list 'insert (list 'proof-shell-invisible-cmd-get-result
                                        (list 'format '"Print %s." test)))))))

(defvar times 0)

(defun print-clusters (res freq)
  (interactive)
  (setf times (1+ times))
  (if (not (caar res))
      (insert (format "Searching clusters...\n"))
    (let* ((temp0 (unzip (quicksort-pair (zip res freq))))
           (res1 (car temp0))
           (freq1 (cadr  temp0)))
      (insert (format "We have found the following clusters:\n" ))
      (insert (format "------------------------------------------------------------------------------------------------------------\n"))
      (do ((temp res1 (cdr temp))
           (temp-freq freq1 (cdr temp-freq))
           (i 1 (1+ i)))
          ((endp temp)
           (insert (format "------------------------------------------------------------------------------------------------------------\n"))
           )
        (progn (insert (format "Cluster %s with frequency %s%%\n" i (car temp-freq)))

               (do ((temp2 (car temp)
                           (cdr temp2)))
                   ((endp temp2)
                    (insert (format "\n")))
                 (progn (insert (format "Lemma "))
                        (insert-button-lemma
                         (remove_last_colon
                          (car (nth (string-to-number (car temp2))
                                    saved-theorems)))))))))))

(defun print-clusters-bis (res freq)
  (interactive)
  (setf times (1+ times))
  (if (not (caar res))
      (insert (format "Searching clusters...\n"))
    (let* ((temp0 (unzip (quicksort-pair (zip res freq))))
           (res1 (car temp0))
           (freq1 (cadr  temp0)))
      (insert (format "We have found the following clusters:\n" ))
      (insert (format "------------------------------------------------------------------------------------------------------------\n"))
      (do ((temp res1 (cdr temp))
           (temp-freq freq1 (cdr temp-freq))
           (i 1 (1+ i)))
          ((endp temp)
           (insert (format "------------------------------------------------------------------------------------------------------------\n")))
        (progn (insert (format "Cluster %s with frequency %s%%\n" i (car temp-freq)))
               (do ((temp2 (car temp)
                           (cdr temp2)))
                   ((endp temp2)
                    (insert (format "\n")))
                 (if (< (string-to-number (car temp2))
                        (length saved-theorems))
                     (progn (insert (format "Lemma "))
                            (insert-button-lemma (remove_last_colon
                                                  (car (nth (string-to-number (car temp2))
                                                            saved-theorems)))))
                   (progn (shell-command (concat "cat "(expand-file-name "names_temp.txt")
                                                 " | sed -n '"
                                                 (format "%s" (- (string-to-number (car temp2))
                                                                 (length saved-theorems)))
                                                 "p'"))
                          (with-current-buffer "*Shell Command Output*"
                            (beginning-of-buffer)
                            (read (current-buffer))
                            (setf temp-res (format "%s"  (read (current-buffer)))))
                          (insert (format "Lemma " ))
                          (insert-button-lemma temp-res)))))))))

(defun extract_clusters_freq (list)
  (do ((temp list (cdr temp))
       (clusters nil)
       (freq nil))
      ((endp temp)
       (list clusters freq))
    (if (not (string= (subseq (car temp)
                              0 1)
                      "["))
        (setf clusters (append clusters (list (car temp))))
      (setf freq (append freq (list (string-to-number (subseq (car temp)
                                                              1 (search "]" (car temp))))))))))

(defun print-clusters-matlab ()
  (with-current-buffer "*display*"
    (while (string= "0" (car (read-lines (expand-file-name "available.txt"))))

      (progn (erase-buffer)
             (insert (format "Searching clusters...\n"))
             (sleep-for 1)))
    (erase-buffer)
    (let* ((clu-freq (extract_clusters_freq (read-lines (expand-file-name "matlab_res.txt"))))
           (clu (car clu-freq))
           (freq (cadr clu-freq))
           (temp0 (unzip (quicksort-pair (zip clu freq))))
           (res1 (car temp0))
           (freq1 (cadr  temp0)))

      (insert (format "We have found the following clusters:\n" ))
      (insert (format "------------------------------------------------------------------------------------------------------------\n"))
      (do ((temp res1 (cdr temp))
           (temp-freq freq1 (cdr temp-freq))
           (i 1 (1+ i)))
          ((endp temp)
           (insert (format "------------------------------------------------------------------------------------------------------------\n")))
        (progn (insert (format "Cluster %s with frequency %s%%\n" i (car temp-freq)))

               (do ((temp2 (cluster-string-to-list (car temp)) (cdr temp2)))
                   ((endp temp2)
                    (insert (format "\n")))
                 (if (< (string-to-number (car temp2))
                        (length saved-theorems))
                     (progn (insert (format "Lemma "))
                            (insert-button-lemma (remove_last_colon
                                                  (car (nth (string-to-number (car temp2))
                                                            saved-theorems)))))
                   (progn (shell-command (concat "cat "(expand-file-name "names_temp.txt")
                                                 " | sed -n '"
                                                 (format "%s" (- (string-to-number (car temp2))
                                                                 (length saved-theorems)))
                                                 "p'"))

                          (with-current-buffer "*Shell Command Output*"
                            (beginning-of-buffer)
                            (read (current-buffer))
                            (setf temp-res (format "%s"  (read (current-buffer)))))
                          (insert (format "Lemma " ))
                          (insert-button-lemma temp-res)))))))))

(defun print-clusters-weka (gra)
  (let* ((clusters (extract-clusters-from-file))
         (res1     (remove-alone (cdr (form-clusters clusters gra))))
         (i        0))
    (with-current-buffer "*display*"
      (erase-buffer)
      (insert "We have found the following clusters:\n" )
      (insert "-------------------------------------------------------------------------------------\n")

      (dotimes (j (length res1) (insert "-------------------------------------------------------------------------------------\n"))
        (let ((i    (1+ j))
              (elems (nth j res1)))
          (insert (format "Cluster %s: (" i))
          (ignore-errors (insert-button-automaton2 (which-lemmas-in-cluster elems) elems))
          (insert ")\n")
          (dolist (elem elems (insert "\n"))
            (ignore-errors
              (if (<= elem (length saved-theorems))
                  (progn (insert "Lemma ")
                         (insert-button-lemma (remove_last_colon
                                               (remove-jumps (car (nth (1- elem)
                                                                       saved-theorems)))))
                         (insert (format " (%s)\n" (which-patch (1- elem)
                                                                1))))
                  (progn (shell-command (concat "cat "(expand-file-name "names_temp.txt")
                                                " | sed -n '"
                                                (format "%s" (- elem
                                                                (length saved-theorems)))
                                                "p'"))

                         (with-current-buffer "*Shell Command Output*"
                           (beginning-of-buffer)
                           (read (current-buffer))
                           (setf temp-res (format "%s"  (read (current-buffer)))))
                         (insert "Lemma ")
                         (unless (search "home" temp-res)
                           (insert (format "%s\n" temp-res))))))))))))

(defun which-patch (n m)
  (cond ((equal n 0)
         "first patch")
        ((and (not (equal (car (nth n saved-theorems))
                          (car (nth (- n 1)
                                    saved-theorems))))
              (not (equal (car (nth n saved-theorems))
                          (car (nth (+ n 1)
                                    saved-theorems)))))
         "unique patch")
        ((and (equal (car (nth n saved-theorems))
                     (car (nth (- n 1)
                               saved-theorems)))
              (not (equal (car (nth n saved-theorems))
                          (car (nth (+ n 1)
                                    saved-theorems)))))
         "last patch")
        ((equal (car (nth n saved-theorems))
                (car (nth (- n 1)
                          saved-theorems)))

         (which-patch (1- n)
                      (1+ m)))
        (t (format "patch %s" m))))

(defun which-lemmas-in-cluster (l)
  (do ((temp l (cdr temp))
       (res nil))
      ((endp temp) res)
    (if (<= (car temp) (length saved-theorems))
        (setf res (append res (list (remove_last_colon
                                     (remove-jumps (car (nth (1- (car temp))
                                                             saved-theorems)))))))
      (progn (shell-command (concat "cat "(expand-file-name "names_temp.txt") " | sed -n '"
                                    (format "%s" (- (car temp) (length saved-theorems)))
                                    "p'"))
             (with-current-buffer "*Shell Command Output*"
               (beginning-of-buffer)
               (read (current-buffer))
               (setf temp-res (format "%s" (read (current-buffer)))))
             (if (not (search "home" temp-res))
                 (setf res (append res (list temp-res))))))))

(defun insert-button-automaton (l)
  (progn (insert-button "automaton" 'action (insert-button-automaton-macro (list 'quote l))
                        'face (list 'link)
                        'follow-link t)))

(defun insert-button-automaton2 (l l2)
  (progn (insert-button "automaton" 'action (insert-button-automaton-macro2 (list 'quote l)
                                                                            (list 'quote l2))
                        'face (list 'link)
                        'follow-link t)))

(defun insert-button-automaton-macro2 (l l2)
  (list 'lambda '(x)
        (list 'generate-automaton2 l l2)))

(defun insert-button-automaton-macro (l)
  (list 'lambda '(x)
        (list 'generate-automaton l)))

(defun insert-button-automaton2-macro (l)
  (list 'lambda '(x)
        (list 'generate-automaton-patches l)))

(defun remove_last_colon (str)
  (if (string= (subseq str (1- (length str)))
               ":")
      (subseq str 0 (1- (length str)))
    str))

(defun show-clusters-alg (str)
  (if (string= "g" str) "find_cluster_with_gaussian"
                        "find_cluster_with_kmeans"))

(defun show-clusters-of-theorem-iterative ()
  "Show the cluster of a theorem"
  (interactive)
  (let* ((alg (show-clusters-alg algorithm))
         (gra (case (if iterative granularity-level-temp granularity-level)
                (2 5)
                (3 10)
                (4 15)
                (5 20)
                (t 3))))
    (setf signal 1)
    (shell-command  (concat "echo 0 > " (expand-file-name "available.txt")))
    (require 'comint)
    (comint-send-string (get-buffer-process "*matlab*")
                        (concat "load " (expand-file-name "temp.csv")
                                (format "; %s(temp,%s,%s,'%s'); csvwrite('%s',1)\n" alg gra (1+ (length saved-theorems))
                                        (expand-file-name "matlab_res.txt")
                                        (expand-file-name "available.txt"))))
    (print-similarities-matlab)))

(defun show-clusters-of-theorem ()
  (interactive)
  (let* ((alg (show-clusters-alg algorithm))
         (gra (case (if iterative granularity-level-temp granularity-level)
                (2 8)
                (3 15)
                (4 25)
                (5 50)
                (t 5))))
    (setq my-buffer "")
    (setf buf (current-buffer))
    (setf res (extract-info-up-to-here))
    (with-temp-file (expand-file-name "temp.csv")
      (cond ((string= level "g")
             (insert (extract-features-1-bis res)))
            ((string= level "t")
             (insert (extract-features-2-bis tactic-temp tactic-level)))
            ((string= level "p")
             (insert (extract-features-2-bis proof-tree-temp proof-tree-level)))))
    (when libs-menus
      (add-libraries-temp)
      (add-names))
    (setf saved-theorems-libs (mapcar 'cadr saved-theorems))
    (switch-to-display)
    (cond ((string= ml-system "m")
           (setf signal 1)
           (shell-command  (concat "echo 0 > " (expand-file-name "available.txt")))
           (require 'comint)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       (format "; %s(temp,%s,%s,'%s'); csvwrite('%s',1)\n" alg gra (1+ (length saved-theorems))
                                               (expand-file-name "matlab_res.txt")
                                               (expand-file-name "available.txt"))))
           (print-similarities-matlab))

          ((string= ml-system "w")
           (setf signal 5)
           (let* ((arg (lambda () (floor (size-temp)
                                         (case granularity-level
                                           (2 7)
                                           (3 5)
                                           (4 4)
                                           (5 2)
                                           (t 8)))))
                  (out_bis (weka (funcall arg))))
             (sleep-for 1)
             (print-similarities-weka-str (funcall arg) out_bis)))))

  (proof-shell-invisible-cmd-get-result (format "Unset Printing All")))

(defun show-clusters ()
  "Show all the clusters which have been obtained from all the theorems exported up to now"
  (interactive)
  (let* ((alg (cond ((string= "g" algorithm)
                     "gaussian_clusters")
                    (t "kmeans_clusters_and_frequencies")))
         (gra (cond  ((eq 2 granularity-level)
                      5)
                     ((eq 3 granularity-level)
                      10)
                     ((eq 4 granularity-level)
                      15)
                     ((eq 5 granularity-level)
                      20)
                     (t 3)))
         (freq (cond  ((eq 2 frequency-precision)
                       500)
                      ((eq 3 frequency-precision)
                       1000)
                      (t 100))))

    (progn
      (setf signal 2)
      (setf my-buffer "")
      (setf buf (current-buffer))
      (progn (with-temp-file (expand-file-name "temp1.csv")
               (insert (extract-features-1)))
             (switch-to-display)
             (require 'comint)
             (comint-send-string (get-buffer-process "*matlab*")

                                 (concat "load " (expand-file-name "temp1.csv")
                                         (format "; %s(temp1,%s,%s)\n" alg gra freq)))))))

(defun show-clusters-bis ()
  (interactive)
  (setf saved-theorems (remove-nil-cases))
  (setf buf (current-buffer))
  (let* ((alg (cond ((string= "g" algorithm)
                     "gaussian_clusters")
                    (t "kmeans_clusters_and_frequencies")))
         (gra (cond  ((eq 2 granularity-level)
                      5)
                     ((eq 3 granularity-level)
                      10)
                     ((eq 4 granularity-level)
                      15)
                     ((eq 5 granularity-level)
                      20)
                     (t 3)))
         (freq (cond  ((eq 2 frequency-precision)
                       500)
                      ((eq 3 frequency-precision)
                       1000)
                      (t 100))))

    (progn
      (setf signal 4)
      (setf my-buffer "")
      (if libs-menus
          (progn (with-temp-file (expand-file-name "temp.csv")
                   (cond ((string= level "g")
                          (insert (extract-features-1)))
                         ((string= level "t")
                          (insert (extract-features-2 tactic-level)))
                         ((string= level "p")
                          (insert (extract-features-2 proof-tree-level)))))
                 (add-libraries-temp)
                 (add-names))
        (with-temp-file (expand-file-name "temp.csv")
          (insert (extract-features-1))))
      (setf saved-theorems-libs (mapcar (lambda (x)
                                          (cadr x))
                                        saved-theorems))
      (switch-to-display)
      (cond ((string= ml-system "m")
             (progn
               (shell-command  (concat "echo 0 > " (expand-file-name "available.txt")))
               (require 'comint)
               (comint-send-string (get-buffer-process "*matlab*")
                                   (concat "load " (expand-file-name "temp.csv")
                                           (format "; %s(temp,%s,%s,'%s'); csvwrite('%s',1)\n" alg gra freq
                                                   (expand-file-name "matlab_res.txt")
                                                   (expand-file-name "available.txt"))))
               (print-clusters-matlab)))
            ((string= ml-system "w")
             (progn (setf signal 5)
                    (weka (cond  ((eq 2 granularity-level)
                                  (floor (size-temp)
                                         7))
                                 ((eq 3 granularity-level)
                                  (floor (size-temp)
                                         5))
                                 ((eq 4 granularity-level)
                                  (floor (size-temp)
                                         4))
                                 ((eq 5 granularity-level)
                                  (floor (size-temp)
                                         2))
                                 (t (floor (size-temp)
                                           8))))
                    (sleep-for 1)
                    (print-clusters-weka (cond  ((eq 2 granularity-level)
                                                 (floor (size-temp)
                                                        7))
                                                ((eq 3 granularity-level)
                                                 (floor (size-temp)
                                                        5))
                                                ((eq 4 granularity-level)
                                                 (floor (size-temp)
                                                        4))
                                                ((eq 5 granularity-level)
                                                 (floor (size-temp)
                                                        2))
                                                (t (floor (size-temp)
                                                          8)))))))))
  (proof-shell-invisible-cmd-get-result (format "Unset Printing All")))

(defun size-temp ()
  (shell-command  (concat "wc -l " (expand-file-name "temp.csv")))
  (let ((n nil)
        (i 0))
    (with-current-buffer "*Shell Command Output*"
      (beginning-of-buffer)
      (setq n (string-to-number (format "%s"  (read (current-buffer))))))
    n))

(defvar saved-theorems-libs nil)

(defun add-to-saved-theorems-libs (file)
  (let* ((lines (read-lines file))
         (res (mapcar (lambda (x)
                        (mapcar (lambda (y)
                                  (car (read-from-string y)))
                                (cluster-string-to-list x)))
                      lines)))
    (setf saved-theorems-libs (append saved-theorems-libs res))))

(defun add-libraries ()
  (do ((temp libs-menus (cdr temp)))
      ((endp temp)
       nil)
    (cond ((string= level "g")
           (progn
             (shell-command  (concat "cat " home-dir "libs/coq/" (car temp)
                                     ".csv >> " (expand-file-name "temp1.csv")))
             (add-to-saved-theorems-libs (concat home-dir "libs/coq/" (car temp)
                                                 ".csv"))))
          ((string= level "t")
           (shell-command  (concat "cat " home-dir "libs/coq/" (car temp)
                                   "_tactics.csv >> " (expand-file-name "temp1.csv"))))
          ((string= level "p")
           (shell-command  (concat "cat " home-dir "libs/coq/" (car temp)
                                   "_tree.csv >> " (expand-file-name "temp1.csv")))))))

(defun add-libraries-temp ()
  (do ((temp libs-menus (cdr temp)))
      ((endp temp)
       nil)
    (cond ((string= level "g")
           (progn
             (shell-command  (concat "cat " home-dir "libs/coq/" (car temp)
                                     ".csv >> " (expand-file-name "temp.csv")))
             (add-to-saved-theorems-libs (concat home-dir "libs/coq/" (car temp)
                                                 ".csv"))))
          ((string= level "t")
           (shell-command  (concat "cat " home-dir "libs/coq/" (car temp)
                                   "_tactics.csv >> " (expand-file-name "temp.csv"))))
          ((string= level "p")
           (shell-command  (concat "cat " home-dir "libs/coq/" (car temp)
                                   "_tree.csv >> " (expand-file-name "temp.csv")))))))

(defun add-names ()
  (shell-command (concat "rm " (expand-file-name "names_temp.txt")))
  (shell-command (concat "touch " (expand-file-name "names_temp.txt")))
  (do ((temp libs-menus (cdr temp)))
      ((endp temp)
       nil)
    (shell-command  (concat "cat " home-dir "libs/coq/" (car temp)
                            "_names >> " (expand-file-name "names_temp.txt")))))

(defvar names-values nil)

(defun print-clusters2 (res freq)
  (interactive)
  (let* ((temp0 (unzip (quicksort-pair (zip res freq))))
         (res1 (car temp0))
         (freq1 (cadr  temp0)))
    (insert (format "We have found the following clusters:\n"))
    (insert (format "------------------------------------------------------------------------------------------------------------\n"))
    (do ((temp res1 (cdr temp))
         (temp-freq freq1 (cdr temp-freq))
         (i 1 (1+ i)))
        ((endp temp)
         (insert (format "------------------------------------------------------------------------------------------------------------\n")))
      (progn (insert (format "Cluster %s with frequency %s%%\n" i (car temp-freq)))
             (do ((temp2 (car temp)
                         (cdr temp2)))
                 ((endp temp2)
                  (insert (format "\n")))
               (insert (format "Lemma %s\n"
                               (remove_last_colon
                                (car (nth (- (string-to-number (car temp2))
                                             1)
                                          saved-theorems2))))))))))

(defun compute-clusters-and-values (list fr)
  (if (not (left-strings saved-theorems2))
      (print-clusters2 list fr)
    (progn (setf names-values (extract-names-dynamic))
           (do ((temp list (cdr temp))
                (n 200 (+ n 5)))
               ((endp temp)
                (progn (setf names-values (complete-names-values names-values n))
                       (setf saved-theorems2 (recompute-saved-theorems saved-theorems2))
                       (setf my-buffer "")
                       (show-clusters-dynamic-b)
                       )
                nil
                )
             (assign-values (car temp)
                            n)))))

(defvar granularity-dynamic 0)

(defun show-clusters-dynamic ()
  (interactive)
  (setf buf (current-buffer))
  (setf granularity-dynamic (read-string "Introduce the granularity level (values from 1 to 5): "))
  (progn
    (setf signal 3)
    (setf my-buffer "")
    (with-temp-file (expand-file-name "temp.csv")
      (insert (extract-features-dynamic)))
    (switch-to-display)
    (require 'comint)
    (cond ((string= "1" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,3,100)\n")))
          ((string= "2" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,5,100)\n")))
          ((string= "3" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,10,100)\n")))
          ((string= "4" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,15,100)\n")))
          ((string= "5" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,20,100)\n")))
          (t (show-clusters-dynamic)))))

(defun show-clusters-dynamic-b ()
  (interactive)
  (progn
    (setf signal 3)
    (setf buf (current-buffer))
    (setf my-buffer "")
    (with-temp-file (expand-file-name "temp.csv")
      (insert (extract-features-dynamic)))
    (require 'comint)
    (cond ((string= "1" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,3,100)\n")))
          ((string= "2" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,5,100)\n")))
          ((string= "3" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,10,100)\n")))
          ((string= "4" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,15,100)\n")))
          ((string= "5" granularity-dynamic)
           (comint-send-string (get-buffer-process "*matlab*")
                               (concat "load " (expand-file-name "temp.csv")
                                       "; kmeans_clusters_and_frequencies(temp,20,100)\n")))
          (t (show-clusters-dynamic)))))
