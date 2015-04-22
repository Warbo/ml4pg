;; Test feature extraction

(defun gen-squared-parentheses (gen-num gen-str)
  `(lambda ()
     (let* ((n        (% (funcall ,gen-num) 11))
            (str1     (strip-parens (funcall ,gen-str)))
            (str2     (strip-parens (funcall ,gen-str)))
            (str3     (strip-parens (funcall ,gen-str)))
            (str4     (strip-parens (funcall ,gen-str)))
            (str5     (strip-parens (funcall ,gen-str)))
            (brackets (case n
                        (0  (list ""  ""  ""  ""))
                        (1  (list "[" "]" ""  ""))
                        (2  (list "{" "}" ""  ""))
                        (3  (list "[" "]" "[" "]"))
                        (4  (list "[" "]" "{" "}"))
                        (5  (list "{" "}" "[" "]"))
                        (6  (list "{" "}" "{" "}"))
                        (7  (list "[" "{" "}" "]"))
                        (8  (list "{" "[" "]" "}"))
                        (9  (list "[" "[" "]" "]"))
                        (10 (list "{" "{" "}" "}"))))
            (str      (concat str1 (nth 0 brackets)
                              str2 (nth 1 brackets)
                              str3 (nth 2 brackets)
                              str4 (nth 3 brackets)
                              str5)))
       (list n str1 str2 str3 str4 str5 str))))

(test-with remove-squared-parenthesis
  "Test what remove-squared-parenthesis does"
  (list-of (gen-squared-parentheses (gen-num) (gen-string))
           (gen-string))
  (lambda (args res)
    (let* ((n      (nth 0 args))
           (str1   (nth 1 args))
           (str2   (nth 2 args))
           (str3   (nth 3 args))
           (str4   (nth 4 args))
           (str5   (nth 5 args))
           (str    (nth 6 args)))
      (should (equal (remove-squared-parenthesis str res)
                     (concat res str1 (case n
                                        (0  (concat str2 str3 str4     str5))
                                        (1  (concat      str3 str4     str5))
                                        (2  (concat      str3 str4     str5))
                                        (3  (concat      str3          str5))
                                        (4  (concat      str3          str5))
                                        (5  (concat      str3          str5))
                                        (6  (concat      str3          str5))
                                        (7  (concat                    str5))
                                        (8  (concat                    str5))
                                        (9  (concat           str4 "]" str5))
                                        (10 (concat           str4 "}" str5)))))))))

(defun trace ()
  (debug))

(test-with numbers-move-arrow
  "Test what numbers-move=> does"
  (list-of (gen-coq-name)
           (gen-coq-name)
           (gen-num)
           (gen-num))
  (lambda (pre post top level)
    (let* ((cmd  (concat pre "=>" post)))
      (generate-and-run `(lambda ()
                           (numbers-move=> ,cmd ,top ,level))))))

(test-with remove-arrow
  "Test what remove=> does"
  (list-of (gen-string) (gen-string))
  (lambda (str1 str2)
    (let ((str (concat str1 "=>" str2)))
      (remove=> (subseq str (+ 2 (search "=>" str)))))))

(test-with numbers-move-aux
  "Test part of numbers-move=>"
  (list-of (gen-squared-parentheses (gen-num) (gen-string))
           (gen-string))
  (lambda (args post)
    (let* ((str   (nth 6 args))
           (post2 (strip-parens post))
           (cmd   (concat str "=>" post2)))
      (numbers-move-aux cmd))))

(test-with extract-params3
  "Test calling convention of extract-params3"
  (list-of (gen-squared-parentheses (gen-num) (gen-coq-name)))
  (lambda (args)
    (let ((str (nth 6 args)))
      (extract-params3 str))))

(test-with get-types-list
  "Test calling convention of get-types-list"
  nil
  (lambda ()
    (get-types-list nil 0)))

(test-with get-type-id
  "Test calling convention of get-type-id"
  nil
  ;; (generate-and-run (lambda ()
  ;;                     (get-type-id (funcall (gen-coq-name)))))
  (lambda ()
     (should nil)))

(test-with export-theorem-aux
  "Test what export-theorem-aux does"
  nil
  (lambda ()
    (export-theorem-aux nil nil)))