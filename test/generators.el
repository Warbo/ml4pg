(defun list-of (&rest gens)
  `(lambda ()
     (mapcar 'funcall ',gens)))

(defun gen-bool ()
  "Generate t or nil"
  (lambda () (equal (random 2) 0)))

(defun gen-num (&optional max)
  "Generate positive random numbers"
  `(lambda () (random (or ,max ml4pg-test-complexity))))

(defun gen-char (&optional source)
  "Generate a random ASCII character. If an optional SOURCE string is given, its
   characters are used."
  (if source (gen-elem (split-string source "" t))
             (lambda () (format "%c" (random 255)))))

(defun gen-string (&optional op-len)
  "Generate a random ASCII string, of given (or random) length"
  (let ((len (cond ((functionp op-len)  op-len)
                   ((null      op-len) (gen-num))
                   (t                  (gen-const op-len)))))
    `(lambda ()
       (let ((str ""))
         (dotimes (i (funcall ,len) str)
           (setq str (concat str (funcall (gen-char)))))))))

(defun gen-nonempty-string (&optional op-len)
  "Generate a random ASCII string of at least one char"
  (gen-string (compose '1+ (or op-len (gen-num)))))

(defun gen-list (elem-gen &optional op-len)
  "Generate a random list, using the given element-generating function, of the
   given (or random) length"
  (let ((len (cond ((functionp op-len)  op-len)
                   ((null      op-len) (gen-num))
                   (t                  (gen-const op-len)))))
    `(lambda ()
       (let (lst)
         (dotimes (i (funcall ,len) lst)
           (setq lst (cons (funcall ,elem-gen) lst)))))))

(defun gen-nonempty-list (elem-gen)
  (gen-list elem-gen (compose '1+ (gen-num))))

(defun gen-pair (first second)
  `(lambda ()
     (cons (funcall ,first) (funcall ,second))))

(defun gen-types-id ()
  "Generator for types_id values"
  (gen-list (gen-pair (gen-string) (gen-num))))

(defun gen-filtered (elem-gen filter)
  "Filters a generator using a predicate"
  `(lambda ()
     (let ((val (funcall ,elem-gen)))
       (while (not (funcall ,filter val))
         (setq val (funcall ,elem-gen)))
       val)))

(defun gen-any (&rest gens)
  "Generate using any one of the arguments, randomly"
  (unless gens (error "No generators to choose between"))
  `(lambda ()
     (funcall (random-elem ,gens))))

(defun gen-string-without (&rest strs)
  "Generate a string which doesn't contain any of the arguments"
  (dolist (str strs)
    (when (equal str "")
      (error "You can't generate string without an empty string!")))
  (compose `(lambda (s) (apply 'strip-str (cons s ',strs)))
           (gen-nonempty-string)))

(defun gen-elem (lst)
  "Generate an element of LST"
  (unless lst (error "Cannot generate elements from an empty list"))
  `(lambda ()
     (random-elem ',lst)))

(defun gen-const (&rest args)
  "Generate one of the arguments"
  (unless args (error "No constants to generate"))
  (gen-elem args))

(defun coq-namep (n)
  (not (or (string= n "")
           (string-match "[^a-zA-Z0-9_]" n)
           (string-match "[^a-zA-Z]" (subseq n 0 1)))))

(defun gen-coq-name ()
  (lambda ()
    (let* ((alpha "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
           (alnum (concat alpha "_0123456789"))
           (c     (funcall (gen-char alpha)))
           (cs    (funcall (gen-list (gen-char alnum))))
           (cs2   (if cs (apply 'concat cs) "")))
      (concat c cs2))))

(defun gen-coq-arg (&optional types)
  (let ((gen-type (or types (gen-coq-name))))
    (compose (lambda (names type)
               (list (if type
                         (concat "(" (join-strings names " ") " : " type ")")
                         (concat (join-strings names " ")))))
             (list-of (gen-list (gen-coq-name) (compose '1+ (gen-num)))
                      (gen-any  (gen-const nil) gen-type)))))

(defun gen-coq-theorem-statement (&optional name arg type)
  "Generate a Coq theorem declaration. Optionally, the name will be generated by
   NAME, arguments by ARGS and the theorem's type by TYPE; otherwise they're
   random, syntactically-correct, but logically nonsense."
  (let ((gen-name (or name  (gen-coq-name)))
        (gen-args (gen-list (or arg (gen-coq-arg))))
        (gen-type (or type  (gen-coq-name))))
    (compose (uncurry (lambda (dec name args type)
                        (concat dec " " name " "
                                (join-strings args " ") " "
                                " : " type ".")))
             (list-of (gen-elem (list "Theorem" "Lemma" "Remark" "Fact"
                                      "Corollary" "Proposition"))
                      gen-name
                      gen-args
                      gen-type))))

(defun uncurry (f)
  `(lambda (args) (apply ,f args)))

(defun gen-coq-inhabited-type ()
  "Generate a Coq type which is trivially inhabited; ie. a trivially-provable
   theorem."
  (compose (lambda (nums)
             (concat (join-strings (mapcar 'any-to-string nums) " + ")
                     " = " (any-to-string (apply '+ nums))))
           (gen-list (gen-num) (compose '1+ (gen-num)))))

(defun gen-coq-correct-statement (&optional name)
  "Generate a Coq theorem declaration for a correct theorem. Optionally, the
   name will be generated by NAME, otherwise it's random but syntactically
   correct. Generated theorems are always solvable by 'tauto'."
  (gen-coq-theorem-statement name (gen-const nil) (gen-coq-inhabited-type)))

(defun gen-ltac-step ()
  )

(defun gen-coq-proof (ltac)
  "Generate a Coq proof, including 'Proof' and 'Qed' or 'Defined' markers.
   The proof will probably not be correct!"
  (compose (uncurry (lambda (steps end)
                      (concat "Proof. " (join-strings steps " ") end ".\n")))
           (list-of ltac (gen-elem (list " Qed" " Defined")))))

(defun gen-coq-correct-proof ()
  "Generate a Coq proof whihc will work for trivial theorems, like those from
   gen-coq-inhabited-type"
  (gen-coq-proof (gen-elem (list (list "auto.")
                                 (list "tauto.")
                                 (list "intros." "auto.")
                                 (list "simpl." "reflexivity.")
                                 (list "compute." "auto.")))))

(defun gen-coq-correct-theorem (&optional name)
  (compose (uncurry (lambda (stmt proof)
                      (concat stmt "\n" proof "\n")))
           (list-of (gen-coq-correct-statement name) (gen-coq-correct-proof))))

(defun gen-balanced-parens-aux (pre count gen-str gen-choice)
  "Recursive helper for gen-balanced-parens"
  (if (funcall gen-choice)
      (gen-balances-parens-aux (concat pre (funcall gen-str) "(")
                               (1+ count)
                               gen-str
                               gen-choice)
      (if (= 0 count)
          (concat pre (funcall gen-str))
          (gen-balanced-parens-aux (concat pre (funcall gen-str) ")")
                                   (1- count)
                                   gen-str
                                   gen-choice))))

(defun gen-balanced-parens ()
  "Generate random strings where any parentheses are balanced"
  (lambda ()
    (gen-balanced-parens-aux ""
                             0
                             ;; Don't allow (, ), [ or ] in our strings
                             (gen-string)
                             (gen-filtered (gen-string)
                                           (lambda (x)
                                             (not (or (search "(" x)
                                                      (search ")" x)
                                                      (search "[" x)
                                                      (search "]" x)))))
                             ;; gen-bool gives trees of unlimited expected depth
                             (compose (lambda (x) (= 0 (% x 3)))
                                      (gen-num)))))

(defun gen-readable ()
  "Generate strings suitable for the 'read' function"
  (lambda ()
    (let ((str    (strip-str (strip-control-chars (funcall
                                                   (gen-nonempty-string)))
                             "["  "]"  "" "" "\f" "" "" "" " " ""
                             ","  "" "" "" "" "" "" "" "?"  "\\"
                             ";"  "#"  "."  "\"" " "  "'"  "`"))
          (opens  nil)
          (closes nil))
      (while (not (balanced-parens str))
        (setq opens  (count-occurences (regexp-quote "(") str))
        (setq closes (count-occurences (regexp-quote ")") str))
        (when (< opens closes) (setq str (concat "(" str    )))

        (when (> opens closes) (setq str (concat     str ")"))))

      ;; Last-ditch effort if we've stripped all characters
      (if (equal str "")
          (funcall (gen-readable))
          str))))

;; "Sized" generators take an explicit size limit, rather than using
;; ml4pg-test-complexity, and distribute it amongst 'child' generators.
;; This lets us generate recursive structures of an arbitrary, but finite,
;; expected size.

;; Consider 3 examples:
;; 1) Lists of elements, with random length
;; 2) Lists of lists (or lists...) of a fixed depth
;; 3) Trees (lists of lists, of random depth)

;; gen-sized-list, with size S, gives us a list with the guarantee that the
;; sizes of the elements sum to S (or below). Hence:
;; 1) We get long lists of small elements, short lists of large elements, or
;; something in-between. Size is conserved.
;; 2) Each sub-list gets a smaller size, so size is still conserved: it governs
;; the total number of "leaf" elements.
;; 3) Size is still conserved, so trees with a high branching factor will be
;; shallow; trees with a low branching factor can be deep.

;; Compare this to gen-list, which uses a fixed complexity C:
;; 1) Each element has complexity C, so the overall complexity increases
;; geometrically with the length of the list.
;; 2) Since each sub-list has the same complexity as its parent, complexity
;; increases exponentially with the depth of the nesting.
;; 3) Since complexity doesn't decrease, the branching factor is the expected
;; number of recursive calls at each point. A factor >= 1 generates trees of
;; infinite expected size. A factor < 1 makes depth decay exponentially.

;; Sized generators don't make much practical difference for case 1; for case 2
;; they speed up generation considerably; for case 3, they're the only practical
;; way to generate trees of a useful (not exponentially-shallow) size.

(defun gen-sized-list (elem-gen &optional conserve)
  "Generate a list using the sized generator ELEM-GEN. If CONSERVE is nil, size
   may decrease; if non-nil it will be strictly conserved. It never increases!"
  `(lambda (size)
     (let ((len (if ,conserve size (random size))))
       (if (= 0 len)
           nil
           (mapcar ,elem-gen (choose-partitions len))))))

(defun gen-nested-sized-list (elem-gen depth)
  (if (= 0 depth)
      elem-gen
      (gen-sized-list (gen-nested-sized-list elem-gen (1- depth)))))

(defun gen-nested-list (elem-gen depth)
  `(lambda ()
     (funcall (gen-nested-sized-list (unsized ,elem-gen) ,depth)
              ml4pg-test-complexity)))

(defmacro unsized (f)
  "Treat a regular generator as sized (the size gets accepted, but ignored)"
  `(lambda (size)
     (funcall ,f)))

(defmacro unsize (f)
  "Provides a size to a sized generator"
  `(lambda ()
     (funcall ,f ml4pg-test-complexity)))

(defun gen-sized-list-of (&rest gens)
  `(lambda (size)
     (zip-with (lambda (gen s) (funcall gen s))
               ',gens
               (choose-partitions (max size (length ',gens))
                                  (length ',gens)))))
