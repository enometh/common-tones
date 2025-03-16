(defpackage :common-tones/plugins
  (:use :cl)
  (:import-from "COMMON-TONES"
   "*OFFSET*" "*SRATE*"
   "LAST-DAC-FILENAME"
   "*CLM-FILE-NAME*"
   "*REVERB*"
   "*OUTPUT*"
   "*CLM-HEADER-TYPE*"
   "*CLM-DATA-FORMAT*"
   "*OUTPUT*"

   "LASTX"
   "FULL-MERGE-PATHNAMES"
   "WITH-SOUND"
   "SOUND-SRATE"
   "FILENAME->STRING"
   "DOUBLE"
   "MUS-FILE-NAME"

   "MIX"
   "CLM-CLOSE-OUTPUT"
   "CLM-CLOSE-REVERB"
   "CLM-MIX"
   "SOUND-DATUM-SIZE"
   "SOUND-DURATION"
   "SOUND-COMMENT"
   "SOUND-FRAMPLES"
   "CLM-SCALE-FILE"
   "SOUND-SAMPLES"
   "SOUND-CHANS"
   "CLM-CONTINUE-REVERB"
   "CLM-CONTINUE-OUTPUT"
   )
  (:export
    #:add
    #:cut
    #:db-to-amp
    #:amp-to-db
    #:vol-to-amp
    #:adb-to-amp
    #:amp-to-adb
    #:rmix
    #:with-instruments
    #:load-ins))

(in-package :common-tones/plugins)
