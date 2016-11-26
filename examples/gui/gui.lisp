;; is working file as I test features...please don't use. Use tutorial05 instead.

(ql:quickload :clinch)
(ql:quickload :clinch-cairo)
(ql:quickload :clinch-pango)
(ql:quickload :clinch-freeimage)
(use-package :clinch)

(defparameter *node* nil)
(defparameter *projection* nil)
(defparameter *q* nil)
(defparameter *buttons* nil)

(defclass button ()
  ((node :initform (make-instance 'node)
	 :initarg :node
	 :accessor node)
   (entity :initform nil
	   :initarg :entity
	   :accessor entity)
   (texture :initform nil
	    :initarg :texture
	    :accessor texture)
   (events :initform (make-hash-table)
	   :accessor events)))
   

(defparameter *on-click-objects* (make-hash-table))
(defparameter *on-hover-objects* (make-hash-table))
(defparameter *on-exit-objects* (make-hash-table))
(defparameter *last-hover-target* nil)

(defmethod initialize-instance :after ((this button) &key width height events)
  (describe this))
		   

    

    
    ;; (unless tex
    ;;   (unless (and width height)
    ;; 	(error "You must have a texture or a width and height!"))
    ;;   (setf tex (make-instance 'texture :width width :height height)))


    ;; ))
    
    ;; (unless e
    ;;   (setf e (make-quad-for-texture tex :width width :height height)))))	


(defun init-test ()
  (setf *node* (make-instance 'clinch:node :parent nil))
  (clinch:translate *node* (clinch:v! 0 0 -450))
  ;; (setf *q* (make-quad-and-texture 200 200))
  ;; (add-child *node* *q*)

  ;; Enable a few opengl features.
  (gl:enable :blend :depth-test :line-smooth :point-smooth :texture-2d :cull-face)

  ;; Set the blending mode.
  (%gl:blend-func :src-alpha :one-minus-src-alpha)
  (gl:polygon-mode :front-and-back :fill)
  (gl:clear-color .8 .8 .8 0)
  (make-button "Hello world" 600 400)
  )

;; Next runs one time before the next on-idle.
(clinch:defevent clinch:*next* ()

  ;; Enable a few opengl features.
  (gl:enable :blend :depth-test :line-smooth :point-smooth :texture-2d :cull-face)

  ;; Set the blending mode.
  (%gl:blend-func :src-alpha :one-minus-src-alpha)
  (gl:polygon-mode :front-and-back :fill)

  (gl:clear-color 0 0 1 0)

  ;; run init once
  (init-test))

(clinch:defevent clinch:*on-idle* ()

  (gl:clear :color-buffer-bit :depth-buffer-bit)
  ;;(clinch:render entity :projection *projection*)
  (clinch:update *node*)
  (clinch:render *node* :projection *projection*)

  )

(defun map-event (f h)
  (let ((ret))
    (maphash (lambda (k v)
	       (push (funcall f k v) ret))
	     h)
    ret))


(clinch:defevent clinch:*on-mouse-down* (win mouse x y button state clicks ts)

  ;;(format t "win: ~A mouse: ~A x: ~A y: ~A button: ~A state: ~A clicks: ~A ts: ~A~%" win mouse x y button state clicks ts)

  (map-event (lambda (k v)
	       (let ((collisions (check-intersect (car (children k)) k x y *viewport* *projection*)))
		 (when collisions (funcall v k collisions))))
	     *on-click-objects*))

  ;; (loop for n in *buttons*
  ;;     collect (check-intersect (car (children n)) n x y *viewport* *projection*)))

;; Rotate and translate with mouse
(clinch:defevent clinch:*on-mouse-move* (win mouse state x y xrel yrel ts)
  ;;(format t "win: ~A mouse: ~A x: ~A y: ~A button: ~A state: ~A clicks: ~A ts: ~A~%" win mouse state x y xrel yrel ts)

  (map-event (lambda (k v)
	       (let ((collisions (check-intersect (car (children k)) k x y *viewport* *projection*)))
		 (if collisions
		     (unless (eq k *last-hover-target*)
		       (setf *last-hover-target* k)
		       (funcall v k collisions))
		     (when (eq k *last-hover-target*)
		       (let ((f (gethash k *on-exit-objects*)))
			 (when f (funcall f k))
			 (setf *last-hover-target* nil))))))
	     *on-hover-objects*))

  
  ;; (loop for n in *buttons*
  ;;    for q = (car (children n))
  ;;    if (some (lambda (x)
  ;; 		(not (null x)))
  ;; 	      (alexandria:flatten (check-intersect q n x y *viewport* *projection*)))
  ;;    do (draw-button q 
  ;; 		     "Hello World!" 		 
  ;; 		     :line-width 12
  ;; 		     :foreground '(.1 .1 .1 1)
  ;; 		     :fill '(0 0 0 .4)
  ;; 		     :line '(0 0 .9 1))
  ;;    else 
  ;;    do (draw-button q 
  ;; 		     "Hello World!" 		 
  ;; 		     :line-width 10
  ;; 		     :foreground '(.1 .1 .1 1)
  ;; 		     :fill '(0 0 0 .2)
  ;; 		     :line '(0 0 .8 1))))



;; on window resize
(clinch:defevent clinch:*on-window-resized* (win width height ts)
  (format t "Resized: ~A ~A~%" width height)

  (setf *projection* (clinch::make-perspective-transform (clinch:degrees->radians 45)
                                                         (/ width height) .1 1000)))

(clinch:defevent clinch:*on-key-down* (win keysym state ts)
  )


(clinch:defevent clinch:*text-editing* (win text ts)
  (format t "text editing: ~A ~A ~A~%" win text ts))

(clinch:defevent clinch:*on-text-input* (win text ts)
  (format t "on-text-event: ~A ~A ~A ~%" win (code-char text) ts))


;; zoom in and out
(clinch:defevent clinch:*on-mouse-wheel-move* (win mouse x y ts)
  ;;(format t "win=~A mouse=~A x=~A y=~A ts=~A~%" win mouse x y ts)

  (clinch:translate *node* (clinch:v! 0 0 (/ y .1))))

(clinch:init :asynchronous t :init-controllers nil)

(defun check-intersect (quad node x y viewport projection)
  (multiple-value-bind (origin ray) (unproject x y (width viewport) (height viewport) (m4:inverse projection))
    (let ((ret (clinch::ray-triangles-intersect (clinch::transform-points
						 (pullg (attribute quad "v"))
						 (clinch::current-transform node))
						(pullg (indexes quad))
						origin
						ray)))
      (when (some (lambda (x)
		    x)
		  ret)
	ret))))

(defun make-button (text width height &key line-width line fill background foreground)
  (! (let* ((node (make-instance 'node))
	 (quad (make-quad-and-texture width height)))
    (draw-button quad text
		 :line-width 10
		 :foreground '(.1 .1 .1 1)
		 :fill '(0 0 0 .2)
		 :line '(0 0 .8 1))
    (add-child node quad)
    ;;(setf (gethash node *gui-objects*)
    (setf (gethash node *on-click-objects*)
	  (lambda (n c)
	    (format t "clicked!~%" n)))
    (setf (gethash node *on-hover-objects*)
	  (lambda (n c)
	    (format t "hovered!~%" n)))
    (setf (gethash node *on-exit-objects*)
	  (lambda (n)
	    (format t "exited!~%" n)))
    (add-child *node* node)
    node)))

(defun remove-button (node)
  (remhash node *on-hover-objects*)
  (remhash node *on-click-objects*)
  (setf (enabled node) nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun draw-button (quad text &key
                                (line-width 20)
                                (line '(.1 .1 .1 1))
                                (fill '(0 0 0 0))
                                (background '(0 0 0 0))
                                (foreground '(.1 .1 .1 1)))
  (with-context-for-mapped-texture (:texture (uniform quad "t1") :width-var w :height-var h)
    (let* ((aspect 1.0)
           (corner-radius (/ h 5))
           (radius (/ corner-radius aspect)))
      
      (apply #'clear-cairo-context background)
      (clinch:draw-rounded-rectangle  w h
			       :line-width line-width
			       :line line
			       :fill fill)

      (apply #'cairo:set-source-rgba foreground)
      (cairo:move-to 0 (/ h 3))
      (cairo:move-to 0 0)
      (position-text `("span" (("font_desc" "Mono 70")); "Century Schoolbook L Roman bold 50"))
                              ,text)
                     :width w
                     :height h
                     :%y .4
                     :alignment :pango_align_center))))
