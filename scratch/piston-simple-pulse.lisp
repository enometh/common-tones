;;; -*- Mode: LISP; Package: :cl-user; BASE: 10; Syntax: ANSI-Common-Lisp; -*-
;;;
;;;   Time-stamp: <>
;;;   Touched: Mon Aug 24 18:58:03 2026 +0530 <enometh@net.meer>
;;;   Bugs-To: enometh@net.meer
;;;   Status: Experimental.  Do not redistribute
;;;   Copyright (C) 2026 Madhu.  All Rights Reserved.
;;;
;;; push audio samples to a "piston live-audio" thread that calls
;;; "pulse-audio simple" or "alsa" apis to play sound on linux, cffi,
;;; and bordeaux-threads. uses cffi:with-pointer-to-vector-data
;;;
;;; adapted from the audio playing code in
;;; https://github.com/bonkzwonil/cl-piston audio/backend.lisp (commit
;;; 425161a1 (C) Mathias Menzel-Nielsen, GPL), with inputs from the
;;; sbcl-only https://github.com/rolfrm/cl-pulseaudio-simple (commit
;;; dd39e9cV (C) Rolf Madsen, MIT).

(defpackage "PISTON-SIMPLE-PULSE"
  (:use "CL"))
(in-package "PISTON-SIMPLE-PULSE")

#+nil
(progn
(require 'cffi)
(require 'bordeaux-threads))


;;; Simple PulseAudio

;; -1 = PA_SAMPLE_INVALID (+ s24-32le 1) PA_SAMPLE_MAX=10 (see
;; -sample.h)
(cffi:defcenum pa-sample-format
  u8 alaw ulaw s16le s16be float32le float32be s32le s32be S24-32le)

(cffi:defcenum pa-stream-direction
  no-direction playback record upload)

(cffi:defcstruct pa-sample-spec
  (format pa-sample-format)
  (rate :uint32)
  (channels :uint8))

(cffi:defcfun ("pa_simple_new" %pa-simple-new) :pointer
  (server :pointer) (name :string) (dir pa-stream-direction) (dev :string)
  (stream-name :string) (ss (:pointer (:struct pa-sample-spec)))
  (map :pointer) (attr :pointer)
  (error :pointer))
(cffi:defcfun ("pa_simple_write" %pa-simple-write) :int
  (s :pointer) (data :pointer) (bytes :unsigned-long) (error :pointer))
(cffi:defcfun ("pa_simple_read" %pa-simple-read) :int
  (s :pointer) (data :pointer) (bytes :unsigned-long) (error :pointer))
(cffi:defcfun ("pa_simple_get_latency" %pa-simple-get-latency) :uint64
  (s :pointer) (data :pointer) (bytes :unsigned-long) (error :pointer))
(cffi:defcfun ("pa_simple_drain" %pa-simple-drain) :int
  (s :pointer) (error :pointer))
(cffi:defcfun ("pa_simple_free" %pa-simple-free) :void (s :pointer))
(cffi:defcfun ("pa_strerror" %pa-strerror) :string (e :int))
(cffi:defcfun ("pa_simple_flush" %pa-simple-flush) :int
  (s :pointer)(error :pointer))

(defun %load-pulse ()
  (unless (cffi:find-foreign-library "libpulse-simple")
    (cffi:load-foreign-library "libpulse-simple.so.0"))
  t)

(defun %open-pulse (name rate channels &key
		    (stream-name "pa")
		    (format 's16le)
		    (direction 'playback))
  (cffi:with-foreign-objects ((ss '(:struct pa-sample-spec)) (err :int))
    (setf (cffi:foreign-slot-value ss '(:struct pa-sample-spec) 'format)
	  format
          (cffi:foreign-slot-value ss '(:struct pa-sample-spec) 'rate)
          rate
          (cffi:foreign-slot-value ss '(:struct pa-sample-spec) 'channels)
          channels)
    (setf (cffi:mem-ref err :int) 0)
    (let ((s (%pa-simple-new (cffi:null-pointer) name
                             direction (cffi:null-pointer)
                             stream-name ss (cffi:null-pointer) (cffi:null-pointer)
                             err)))
      (if (cffi:null-pointer-p s)
          (progn (warn "PulseAudio refused a stream: ~a"
                       (%pa-strerror (cffi:mem-ref err :int)))
                 nil)
          s))))

(defun %close-pulse (handle)
  (cffi:with-foreign-object (err :int)
    (%pa-simple-drain handle err))
  (%pa-simple-free handle))

(defun array-element-size(buffer)
  (let ((tp (array-element-type buffer)))
    (cond ((eq tp 'single-float) 4)
	  ((eq tp 'double-float) 8)
	  ((equal tp '(unsigned-byte 8)) 1)
	  ((equal tp '(unsigned-byte 16)) 2)
	  ((equal tp '(unsigned-byte 32)) 4)
	  ((equal tp '(unsigned-byte 64)) 8)
	  ((equal tp '(signed-byte 8)) 1)
	  ((equal tp '(signed-byte 16)) 2)
	  ((equal tp '(signed-byte 32)) 4)
	  ((equal tp '(signed-byte 64)) 8)
	  (t (error "Unsupported array type ~a" tp)))))

(defun %pa-read (handle samples)
  (cffi:with-foreign-object (err :int)
    (cffi:with-pointer-to-vector-data (ptr samples)
      (%pa-simple-read handle ptr (* (array-element-size samples)
				     (array-total-size samples))
		       err))))

(defun %pa-write (handle samples)
  (cffi:with-foreign-object (err :int)
    (cffi:with-pointer-to-vector-data (ptr samples)
      (%pa-simple-write handle ptr (* (array-element-size samples)
				      (array-total-size samples))
		       err))))

(defun %pa-flush (handle)
  (cffi:with-foreign-object (err :int)
    (%pa-simple-flush handle err)))

(defun sine-wave  (frequency amplitude duration sample-rate)
  ;; for testing
  (let ((samples (round (* duration sample-rate))))
    (loop for n from 0 below samples
	  collect
	  (* amplitude (sin (* 2 pi frequency (/ n sample-rate)))))))

#||
pactl list short
(%load-pulse)
;; create a client for playback
(defparameter *pa-out* (%open-pulse "play" 44100 1
				    :format float32le
				    :direction playback))
;; create a client for recording
(defparameter *pa-in* (%open-pulse "record" 44100 1
				    :format float32le
				   :direction record))
;; a buffer for one sec of samples (at 44100 hz).
(defvar *buffer* (make-array 44100 :element-type 'single-float))
;; flush the record client, to clear existing daa
(%pa-flush *pa-in*)
(%pa-read *pa-in* *buffer*) ; record for 1 sec
(%pa-write *pa-out* *buffer*) ; playback for 1 sec
;; play a sine wave
(map-into *buffer* (lambda (x) (coerce x 'single-float))
	  (sine-wave 440 0.3 1 44100))
(%pa-write *pa-out* *buffer*)
;; free things up again.
(%close-pulse *pa-in*)
(%close-pulse *pa-out*)
||#

;;; ALSA

(defconstant +snd-pcm-stream-playback+ 0)
(defconstant +snd-pcm-format-s16-le+ 2)
(defconstant +snd-pcm-access-rw-interleaved+ 3)

(cffi:defcfun ("snd_pcm_open" %snd-pcm-open) :int
  (pcm :pointer) (name :string) (stream :int) (mode :int))
(cffi:defcfun ("snd_pcm_set_params" %snd-pcm-set-params) :int
  (pcm :pointer) (format :int) (access :int) (channels :unsigned-int)
  (rate :unsigned-int) (soft-resample :int) (latency :unsigned-int))
(cffi:defcfun ("snd_pcm_writei" %snd-pcm-writei) :long
  (pcm :pointer) (buffer :pointer) (frames :unsigned-long))
(cffi:defcfun ("snd_pcm_recover" %snd-pcm-recover) :int
  (pcm :pointer) (err :int) (silent :int))
(cffi:defcfun ("snd_pcm_drain" %snd-pcm-drain) :int (pcm :pointer))
(cffi:defcfun ("snd_pcm_close" %snd-pcm-close) :int (pcm :pointer))
(cffi:defcfun ("snd_strerror" %snd-strerror) :string (e :int))

(defun %load-alsa ()
  (unless (cffi:find-foreign-library "libasound.so.2")
    (cffi:load-foreign-library "libasound.so.2"))
  t)

(defun %open-alsa (rate channels)
  (cffi:with-foreign-object (pcm :pointer)
    (let ((rc (%snd-pcm-open pcm "default" +snd-pcm-stream-playback+ 0)))
      (if (minusp rc)
          (progn (warn "ALSA could not open `default': ~a" (%snd-strerror rc))
                 nil)
          (let* ((h (cffi:mem-ref pcm :pointer))
                 ;; 100 ms of latency: enough that a bursty writer does not
                 ;; underrun, short enough that the throttle still feels
                 ;; connected to the sound.
                 (rc (%snd-pcm-set-params h +snd-pcm-format-s16-le+
                                          +snd-pcm-access-rw-interleaved+
                                          channels rate 1 100000)))
            (if (minusp rc)
                (progn (warn "ALSA rejected the format: ~a" (%snd-strerror rc))
                       (%snd-pcm-close h)
                       nil)
                h))))))

(defun %alsa-write (handle samples channels &optional (n (length samples)))
  ;; writei counts *frames*, not samples, and an underrun is
  ;; recoverable rather than fatal — snd_pcm_recover is what turns
  ;; a click into a click instead of into a crash.
  (let* ((frames (floor n channels)))
    (cffi:with-pointer-to-vector-data (ptr samples)
      (let ((rc (%snd-pcm-writei handle ptr frames)))
	(when (minusp rc)
	  (let ((rc2 (%snd-pcm-recover handle rc 1)))
	    (when (minusp rc2)
	      (error "snd_pcm_writei failed: ~a" (%snd-strerror rc)))
	    (%snd-pcm-writei handle ptr frames)))))))

(defun %close-alsa (handle)
  (%snd-pcm-drain handle)
  (%snd-pcm-close handle))


;;; PISTON Audio sink

(defparameter +sample-rate+ 48000)
(defconstant +pa-stream-playback+ 'playback)
(defconstant +pa-sample-s16le+ 's16le)

(defstruct (audio-sink (:constructor %make-audio-sink))
  (backend nil :type symbol)            ; :pulse, :alsa, or NIL for silence
  (handle (cffi:null-pointer) :type cffi:foreign-pointer)
  (rate +sample-rate+ :type fixnum)
  (channels 1 :type fixnum))

(defun open-audio-sink (&key (name "engine") (rate +sample-rate+) (channels 1)
			(backend :pulse))
  (let ((handle (ecase backend
		  (:pulse (%open-pulse "cl-piston" rate channels
				       :stream-name name
				       :format +pa-sample-s16le+
				       :direction +pa-stream-playback+))
		  (:alsa (%open-alsa rate channels))
		  ('nil nil))))
    (if (and handle (not (cffi:null-pointer-p handle)))
        (%make-audio-sink :backend backend :handle handle
                          :rate rate :channels channels)
        (progn
          (format *error-output*
                  "~&cl-piston: no audio backend answered; running silent.~%")
          (%make-audio-sink :backend nil :rate rate :channels channels)))))

(defun audio-write (sink samples)
  (declare (type audio-sink sink) (type (simple-array (signed-byte 16) (*)) samples))
  (let ((backend (audio-sink-backend sink))
        (n (length samples)))
    (when (or (null backend) (zerop n))
      (return-from audio-write (values)))
    (ecase backend
      (:pulse
       (%pa-write (audio-sink-handle sink) samples))
      (:alsa
       (%alsa-write (audio-sink-handle sink) samples (audio-sink-channels sink) n)))
    (values)))

(defun close-audio-sink (sink)
  (declare (type audio-sink sink))
  (ecase (audio-sink-backend sink)
    (:pulse (%close-pulse (audio-sink-handle sink)))
    (:alsa (%close-alsa (audio-sink-handle sink)))
    ('nil nil))
  (setf (audio-sink-backend sink) nil
        (audio-sink-handle sink) (cffi:null-pointer))
  (values))


;;; PISTON LIVE AUDIO

(defstruct (live-audio (:constructor %make-live-audio))
  (sink nil)
  (thread nil)
  (lock (bordeaux-threads-2:make-lock :name "cl-piston audio"))
  (queue nil :type list)
  (running t)
  (dropped 0 :type fixnum))

(defvar +live-audio-thread-name+ "cl-piston audio writer")

(defun stop-live-audio (la)
  (when la
    (setf (live-audio-running la) nil)
    ;; should check thread-alive-p here instead of join-thread.
    (ignore-errors (bordeaux-threads-2:join-thread (live-audio-thread la)))
    (close-audio-sink (live-audio-sink la)))
  nil)

(defun ensure-live-audio-thread (la)
  (unless (and (live-audio-thread la)
	       (bordeaux-threads-2:thread-alive-p (live-audio-thread la)))
    (setf (live-audio-thread la)
	  (bordeaux-threads-2:make-thread
	   (lambda ()
	     (unwind-protect
		  (loop while (live-audio-running la)
			do (let* ((sink (live-audio-sink la))
				  (chunk
				   (bordeaux-threads-2:with-lock-held ((live-audio-lock la))
				     (pop (live-audio-queue la)))))
			     (if chunk
				 (ignore-errors (audio-write sink chunk))
				 ;; nothing to play: yield rather than spin
				 (sleep 0.002))))
	       (stop-live-audio la)))
	   :name +live-audio-thread-name+))))

(defun start-live-audio (&key (name "engine") (backend :pulse))
  (assert (not
	   (loop for thread in (bordeaux-threads-2:all-threads)
		 if (equal +live-audio-thread-name+
			   (bordeaux-threads-2:thread-name thread))
		 collect it))
      nil
      "Thread ~A already running" +live-audio-thread-name+)
  (let ((sink (open-audio-sink :name name :backend backend)))
    (unless (audio-sink-backend sink)
      (close-audio-sink sink)
      (return-from start-live-audio nil))
    (let ((la (%make-live-audio :sink sink)))
      (ensure-live-audio-thread la)
      la)))

(defun live-audio-push (la samples)
  "Hand a chunk to the writer.  Drops rather than blocks if the queue has
run away, because a render loop that stalls on audio is worse than a
gap in the sound."
  (when (and la (plusp (length samples)))
    (bordeaux-threads-2:with-lock-held ((live-audio-lock la))
      (if (> (length (live-audio-queue la)) 12)
          (incf (live-audio-dropped la))
          (setf (live-audio-queue la)
                (append (live-audio-queue la) (list samples)))))))

#||
(setq $la (start-live-audio :backend :pulse))
(live-audio-push $la
		 (let ((ret (sine-wave 440 4096 1 44100)))
		   (make-array (length ret)
		     :element-type '(signed-byte 16)
		     :initial-contents
		     (mapcar 'floor ret))))
(stop-live-audio $la)
;; (setq $la (start-live-audio :backend :alsa))
||#
