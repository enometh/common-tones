(in-package :common-tones/plugins)

;;; ------------------------------------------------------------------------

;;; remote play


(defun remote-play (host play-program sound-name)
  (uiop:run-program `("rsh"  ,host ,play-program ,sound-name)))

;;; (remote-play "cmi1" "sfplay" (with-sound (:play nil) (fm-violin 0 1 440 .1)))