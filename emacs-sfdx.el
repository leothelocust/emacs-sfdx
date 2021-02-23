;;; emacs-sfdx --- Emacs wrapper for basic sfdx cli commands

;;; Commentary:

;;; Code:

(require 'transient)


(defvar sfdx-create-css)
(setq-default sfdx-create-css t)

(defun sfdx/next-component-file ()
  "Find next file with the same name, but different file extension."
  (interactive)
  (let (
        (current-file-name (file-name-sans-extension (buffer-file-name)))
        (current-ext (file-name-extension (buffer-file-name)))
        )
    (when (string= current-ext "js")
      (find-file (concat current-file-name ".html")))
    (when (string= current-ext "html")
      (if (file-exists-p (concat current-file-name ".css"))
          (find-file (concat current-file-name ".css"))
        (if (file-exists-p (concat current-file-name ".scss"))
            (find-file (concat current-file-name ".scss"))
          (if (and sfdx-create-css (yes-or-no-p "Do you want to create a CSS file?"))
              (find-file (concat current-file-name ".css"))
            (setq-local sfdx-create-css nil)
            (find-file (concat current-file-name ".js"))))))
    (when (string= current-ext "css")
      (find-file (concat current-file-name ".js")))
    (when (string= current-ext "scss")
      (find-file (concat current-file-name ".js")))
    ))

(defun sfdx--goto-project (project-path)
  "Internal function to load the PROJECT-PATH in current window."
  ;; DEBUG - this isn't working to auto-open the folder.
  ;; (find-file project-path)
  (message project-path))

(defun sfdx/exec-process (cmd name &optional comint)
  "Execute CMD as a process in a buffer NAME, optionally passing COMINT as non-nil to put buffer in `comint-mode'."
  (let ((compilation-buffer-name-function
         (lambda (mode)
           (format "*%s*" name))))
    (message (concat "Running " cmd))
    (compile cmd comint)))

(defun sfdx/create-project ()
  "Create a new 'standard' SFDX project."
  (interactive)
  (let (
        (process "sfdx-create-project")
        (project-name (read-string "Project Name: "))
        (project-dir (read-directory-name "Directory: " "~/Projects"))
        )
    (async-start-process process "sh" `(lambda (result) (sfdx--goto-project (concat (expand-file-name ',project-dir) ',project-name))) "-c" (concat "sfdx force:project:create --projectname " project-name " --outputdir " (expand-file-name project-dir) " --template standard"))
    ))

(defun sfdx/create-component ()
  "Create a new Lightning Web Component."
  (interactive)
  (if (locate-dominating-file buffer-file-name "force-app")
      (let ((process "sfdx-create-component")
            (output-path (concat (locate-dominating-file buffer-file-name "force-app") "force-app/main/default/lwc/"))
            (comp-name (read-string "Component Name: "))
            )
        (async-start-process process "sh" (lambda (result) (message "Component Created")) "-c" (concat "sfdx force:lightning:component:create --type lwc --componentname " comp-name " --outputdir " output-path))
        )
    (message "You must be in an SFDX project to run that command!")))

(defun sfdx/fetch-component ()
  "Fetch a Lightning Web Component from Org."
  (interactive)
  (if (locate-dominating-file buffer-file-name "force-app")
      (let ((process "sfdx-fetch-component")
            (cd-dir (concat (locate-dominating-file buffer-file-name "force-app") "force-app/main/default/lwc/"))
            (comp-name (read-string "Component Name: "))
            )
        (sfdx/exec-process (format "sh -c \"cd %s; sfdx force:source:retrieve -m LightningComponentBundle:%s\"" cd-dir comp-name) "sfdx:retrieve_component" t)
        ;; (async-start-process process "sh" (lambda (result) (message (concat "Component Retrieved: \"" comp-name "\""))) "-c" (concat "sfdx force:source:retrieve -m LightningComponentBundle:" comp-name))
        )
    (message "You must be in an SFDX project to run that command!")))

(defun sfdx--deploy (component comp-name)
  "Internal function to deploy COMP-NAME asyncronously or whole project if COMPONENT is nil after validations."
  (let ((process "sfdx-deploy")
        (buffer "*sfdx-output*")
        (cd-dir (expand-file-name (locate-dominating-file buffer-file-name "force-app")))
        (output-path (concat (locate-dominating-file buffer-file-name "force-app") "force-app/main/default")))
    (if component
        (sfdx/exec-process (format "sh -c \"cd %s; sfdx force:source:deploy --sourcepath ./force-app/main/default/lwc/%s --loglevel fatal\"" cd-dir comp-name) "sfdx:deploy_component" t)
      (sfdx/exec-process (format "sh -c \"cd %s; sfdx force:source:deploy --sourcepath ./force-app/main/default/ --loglevel fatal\"" cd-dir) "sfdx:deploy_project" t))))

(defun sfdx--retrieve (component comp-name)
  "Internal function to retrieve COMP-NAME asyncronously or whole project if COMPONENT is nil after validations."
  (let ((process "sfdx-deploy")
        (buffer "*sfdx-output*")
        (cd-dir (expand-file-name (locate-dominating-file buffer-file-name "force-app")))
        (output-path (concat (locate-dominating-file buffer-file-name "force-app") "force-app/main/default")))
    (if component
        (sfdx/exec-process (format "sh -c \"cd %s; sfdx force:source:retrieve --sourcepath ./force-app/main/default/lwc/%s --loglevel fatal\"" cd-dir comp-name) "sfdx:retrieve_component" t)
      (progn
        (if (yes-or-no-p "Are you sure? This will completely overwrite any local changes! ")
            (sfdx/exec-process (format "sh -c \"cd %s; sfdx force:source:retrieve --sourcepath ./force-app/main/default/ --loglevel fatal\"" cd-dir) "sfdx:retrieve_project" t)
          (message "Cancelled")
          )))))


(defun sfdx/deploy-component-or-project ()
  "Deploy the current component or project to target."
  (interactive)
  (let ((current-folder (file-name-nondirectory
                         (directory-file-name
                          (file-name-directory (buffer-file-name))))))
    (if (locate-dominating-file buffer-file-name "lwc")
        (prog1
            ;; Possibly in a component folder, but lets makes sure its not just the LWC folder.
            (if (string= current-folder "lwc")
                (prog1
                    ;; Not in a component, deploy project.
                    ;; (message "Deploying Project...")
                    (sfdx--deploy nil current-folder))
              ;; In a component, deploy component.
              ;; (message "Deploying Component...")
              (sfdx--deploy t current-folder)))

      (prog1
          ;; Are we in a project?
          (if (locate-dominating-file buffer-file-name "force-app")
              (prog1
                  ;; In project, deploy project.
                  ;; (message "Deploying Project...")
                  (sfdx--deploy nil current-folder))
            (prog1
                ;; Not in an SFDX project.
                (message "You are not in a component folder or an SFDX project!"))
            )
        )
      )
    )
  )

(defun sfdx/retrieve-component ()
  "Retrieve the source for the current component (destructively overwrites)."
  (interactive)
  (let ((current-folder (file-name-nondirectory
                         (directory-file-name
                          (file-name-directory (buffer-file-name))))))
    (if (locate-dominating-file buffer-file-name "lwc")
        (prog1
            ;; Possibly in a component folder, but lets makes sure its not just the LWC folder.
            (if (string= current-folder "lwc")
                (prog1
                    ;; Not in a component, retrieve project.
                    ;; (message "Retrieving Project...")
                    (sfdx--retrieve nil current-folder))
              ;; In a component, retrieve component.
              ;; (message "Retrieving Component...")
              (sfdx--retrieve t current-folder)))

      (prog1
          ;; Are we in a project?
          (if (locate-dominating-file buffer-file-name "force-app")
              (prog1
                  ;; In project, retrieve project.
                  ;; (message "Retrieving Project...")
                  (sfdx--retrieve nil current-folder))
            (prog1
                ;; Not in an SFDX project.
                (message "You are not in a component folder or an SFDX project!"))
            )
        )
      )
    )
  )

(define-transient-command sfdx/transient-action ()
  "SFDX CLI Actions"
  ["Project Specific"
   ("P" "Create New Project"  sfdx/create-project)]
  ["Create Component"
   ("n" "create new"          sfdx/create-component)]
  ["Actions for this Component"
   ("d" "deploy"              sfdx/deploy-component-or-project)
   ("r" "retrieve"            sfdx/retrieve-component)]
  ["Download Component"
   ("f" "fetch by component name"   sfdx/fetch-component)])

(provide 'emacs-sfdx)
;;; emacs-sfdx.el ends here
