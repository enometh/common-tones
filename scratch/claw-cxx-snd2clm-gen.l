;;; -*- Mode: LISP; Package: :cl-user; BASE: 10; Syntax: ANSI-Common-Lisp; -*-
;;;
;;;   Time-stamp: <>
;;;   Touched: Thu Aug 27 10:35:07 2026 +0530 <enometh@net.meer>
;;;   Bugs-To: enometh@net.meer
;;;   Status: Experimental.  Do not redistribute
;;;   Copyright (C) 2026 Madhu.  All Rights Reserved.
;;;
#||
(require 'cffi)
;;(require 'cffi-object)
(load "~/cl/extern/claw-cxx/claw-cxx.system")
(require 'claw)
(unless (cffi:find-foreign-library "libresect")
  (cffi:load-foreign-library "/14/build/libresect/build/libresect.so"))
||#
#+nil
(ensure-directories-exist  "/dev/shm/claw-cxx-snd2clm/" :verbose t)

#+nil
(claw:defwrapper (:claw-cxx-snd2clm
		  (:base-path "/dev/shm/claw-cxx-snd2clm/gen/")
		  (:headers "mus-config.h" "sndlib.h")
		  (:includes)
		  (:system-includes "/14/build/common-tones/headers/")
		  (:defines)
		  (:targets ((:and :x86 :linux) "x86_64-pc-linux-gnu"))
		  (:include-definitions  "^[Mm][Uu][Ss].*")
		  (:exclude-definitions))
    :in-package :CLAW-CXX-SND2CLM
    :trim-enum-prefix nil
    :recognize-bitfields nil
    :recognize-strings t
    ;; :with-adapter (:dynamic :path "lib/adapter.c")
    ;;:symbolicate-names (:in-pipeline (:by-removing-prefixes "MUS_"))
    )

#+nil
(claw:generate-wrapper :claw-cxx-snd2clm)

