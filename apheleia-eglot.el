;;; apheleia-eglot.el --- Format buffers on save using eglot -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Mohsin Kaleem

;; Author: Mohsin Kaleem <mohkale@kisara.moe>
;; Keywords: tools, lsp
;; Package-Requires: ((emacs "29.0") (eglot "1.7") (apheleia "25.2"))
;; Version: 0.1

;; Copyright (C) 2021 Mohsin Kaleem

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; This package provides a formatter for apheleia that asynchronously queries
;; a language server, managed by eglot, to edit the current buffer. This works
;; pretty much exactly the same way as `eglot-format-buffer' except this is
;; asynchronous and can be chained for use with other formatters alongside
;; your language server.
;;
;; WARN this formatter must be the first in a formatter pipeline. At the moment
;; there's no performant way to detect this is the case, but if you run this
;; formatter second, or third in a series, then it will most likely corrupt
;; the original buffer.

;;; Code:
(require 'cl-lib)
(require 'apheleia)
(require 'eglot)

;;;###autoload
(defun apheleia-eglot (orig-buffer scratch-buffer callback)
  "Apheleia formatter using a running eglot language server.
This calls textDocument/formatting on SCRATCH-BUFFER using the
server associated with ORIG-BUFFER before calling CALLBACK.

Warn: This formatter cannot be run in a pipeline, or if it is
then it must be the first in that pipeline. The contents of
SCRATCH-BUFFER must match ORIG-BUFFER otherwise you'll get a
broken output buffer."
  ;; TOOD: When formatting a sub-region use textDocument/rangeFormatting.

  (with-current-buffer orig-buffer
    (unless (eglot--server-capable :documentFormattingProvider)
      (error "[eglot-apheleia] Server can't format!"))

    (jsonrpc-async-request
     (eglot--current-server-or-lose)
     :textDocument/formatting
     (list
      :textDocument (eglot--TextDocumentIdentifier)
      :options (list :tabSize tab-width
                     :insertSpaces (if indent-tabs-mode :json-false t)))
     :deferred :textDocument/formatting
     :success-fn
     (lambda (edits)
       (with-current-buffer scratch-buffer
         (let ((inhibit-message t))
           (eglot--apply-text-edits edits)))
       (funcall callback scratch-buffer))
     :error-fn
     (eglot--lambda ((ResponseError) code message)
       (error "[eglot-apheleia] %s: %s" code message)))))

;; Automatically add apheleia-eglot to apheleias formatter repository.
;;;###autoload (with-eval-after-load 'apheleia (push '(eglot . apheleia-eglot) apheleia-formatters))

;;;###autoload
(define-minor-mode apheleia-eglot-mode
  "Minor mode for formatting buffers with apheleia and eglot.
All this mode does is ensure eglot is the first choice formatter
for the current `major-mode', to enable format on save you should
also enable `apheleia-mode'."
  :lighter nil
  (if apheleia-eglot-mode
      (progn
        (make-variable-buffer-local 'apheleia-mode-alist)
        (push (cons major-mode 'eglot)
              apheleia-mode-alist))
    (cl-delete (cons major-mode 'eglot) apheleia-mode-alist)))

(provide 'apheleia-eglot)
;;; apheleia-eglot.el ends here
