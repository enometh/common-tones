(in-package "COMMON-TONES")

#+(or cmu lispworks clisp ccl)
(import '(walker:walk-form) "COMMON-TONES")
#+(or excl)
(import '(clos:walk-form) "COMMON-TONES")
#+sbcl
(import '(sb-walker:walk-form) "COMMON-TONES")
