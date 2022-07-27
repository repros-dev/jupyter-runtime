# This is the top-level Makefile for this REPRO.
# Type 'make' with no arguments to list the available targets.

# detect if running in a Windows environment
ifeq ('$(OS)', 'Windows_NT')
PWSH=powershell -noprofile -command
endif

# by default invoke the `list` target run if no argument is provided to make
default_target: list

# Include optional repro-config file to to override default REPRO settings.
-include repro-config

#- =============================================================================
#-     --- REPRO settings, supported values, and defaults ---
#- =============================================================================

#- 
#- --- REPRO_SERVICES_STARTUP --------------------------------------------------
#- 
#-    auto : Services start automatically when the REPRO starts (DEFAULT).
#-  manual : Services start when the start-services target is invoked manually.
#
REPRO_SERVICES_STARTUP ?= auto

#- 
#- --- REPRO_LOGGING_LEVEL -----------------------------------------------------
#- 
#-    none : The REPRO framework will perform no logging.
#-   alert : Only alerts and error messages will be logged.
#-    warn : Alerts, errors and warning messages will be logged (DEFAULT).
#-    info : Alerts, errors, warnings and informational messages will be logged.
#-   debug : Detailed messages will be included in log output along with script 
#-           and Makefile target invocation records.
#-   trace : REPRO will additionally log tracepoints placed at function entry
#-           and return points, etc.
#
REPRO_LOGGING_LEVEL ?= warn

#- 
#- --- REPRO_LOGGING_FILENAME --------------------------------------------------
#- 
#-    auto : Name log unqiuely using current time: [timestamp].log (DEFAULT)
#-  [name] : Use variable value to name the log file: [name]
# 
REPRO_LOGGING_FILENAME ?= auto

#- 
#- --- REPRO_LOGGING_OPTIONS ---------------------------------------------------
#- 
#-  NO_TIMESTAMPS : Messages will not be prepended by timestamps.
#-  NO_LOCATIONS  : Source file locations will not be included in trace messages.
#-  NO_APPEND     : Overwrite log file rather than appending to it.
#
REPRO_LOGGING_OPTIONS ?= 

#- 
#- --- REPRO_EXIT_AFTER_STARTUP ------------------------------------------------
#- 
#-  false : REPRO session will not exit automatically (DEFAULT).
#-  true  : REPRO session will automatically exit after REPRO startup completes.
#
REPRO_EXIT_AFTER_STARTUP ?= false

# Use working directory as name of REPRO if REPRO_NAME undefined.
ifndef REPRO_NAME
REPRO_NAME=$(shell basename $$(pwd))
$(warning The REPRO_NAME variable is not set. Defaulting to \
          working directory name '${REPRO_NAME}' for name of REPRO.)
endif

# Use name of user for Docker organization if REPRO_DOCKER_ORG undefined.
ifndef REPRO_DOCKER_ORG
REPRO_DOCKER_ORG=$(shell whoami)
$(warning The REPRO_DOCKER_ORG variable is not set. Defaulting to \
          user name '${REPRO_DOCKER_ORG}' for name of Docker organization.)
endif

# Use 'latest' as image tag if REPRO_IMAGE_TAG undefined
ifndef REPRO_IMAGE_TAG
REPRO_IMAGE_TAG=latest
$(warning The REPRO_IMAGE_TAG variable is not set. Defaulting to \
          '${REPRO_IMAGE_TAG}' for Docker image tag.)
endif

# Assemble REPRO settings available within the running REPRO.
REPRO_SETTINGS=	-e REPRO_SERVICES_STARTUP="$(REPRO_SERVICES_STARTUP)" 		\
				-e REPRO_LOGGING_LEVEL="$(REPRO_LOGGING_LEVEL)"     		\
				-e REPRO_LOGGING_FILENAME="$(REPRO_LOGGING_FILENAME)"		\
 				-e REPRO_LOGGING_OPTIONS="$(REPRO_LOGGING_OPTIONS)"			\
				-e REPRO_EXIT_AFTER_STARTUP="$(REPRO_EXIT_AFTER_STARTUP)"	\
               	-e REPRO_NAME="${REPRO_NAME}"                       		\
               	-e REPRO_MNT="${REPRO_MNT}"

# Identify the Docker image associated with this REPRO
REPRO_IMAGE=${REPRO_DOCKER_ORG}/${REPRO_NAME}:${REPRO_IMAGE_TAG}

## 
#- =============================================================================
##     --- Targets for understanding and maintaining this Makefile ---
#- =============================================================================
## 

list:                   ## List Makefile targets (default target).
ifdef PWSH
	@${PWSH} "Get-ChildItem .repro | Select-String -Pattern '#\# ' | % {$$_.Line.replace('##','')}"
else
	@sed -ne '/@sed/!s/#[#] //p' $(MAKEFILE_LIST)
endif

help:                   ## Show detailed Makefile help.
ifdef PWSH
	@${PWSH} "Get-ChildItem .repro | Select-String -Pattern '#\# ' | % {$$_.Line.replace('##','')}"
else
	@sed -ne '/@sed/!s/#[#-] //p' $(MAKEFILE_LIST)
endif

## 
upgrade-makefile:       ## Replace local REPRO Makefile with latest version 
                        ## of Makefile on repros-dev/repro master branch.
	curl -L https://raw.githubusercontent.com/repros-dev/repro/master/Makefile -o Makefile


ifndef IN_RUNNING_REPRO

## 

#- =============================================================================
##     --- Targets affected by REPRO IMAGE settings ---
#- =============================================================================

## 
#- ---------- Targets for managing the Docker image for this REPRO -------------
#- 
build-image:            ## Build this REPRO's Docker image.
	docker build -t ${REPRO_IMAGE} .

rebuild-image:          ## Force rebuild of this REPRO's Docker image.
	docker build --no-cache -t ${REPRO_IMAGE} .

pull-image:             ## Pull this REPRO's Docker image from Docker Hub.
	docker pull ${REPRO_IMAGE}

push-image:             ## Push this REPRO's Docker image to Docker Hub.
	docker push ${REPRO_IMAGE}

#-  
#- ---------- Targets for building a custom parent image  ----------------------
#- 
ifdef PARENT_IMAGE

build-parent-image:     #- Build the custom parent Docker image.
	docker build -f Dockerfile-parent -t ${PARENT_IMAGE} .

rebuild-parent-image:   #- Force rebuild of the custom Docker image.
	docker build --no-cache -f Dockerfile-parent -t ${PARENT_IMAGE} .

pull-parent-image:      #- Pull the custom parent image from Docker Hub.
	docker pull ${PARENT_IMAGE}

push-parent-image:      #- Push the custom parent image to Docker Hub.
	docker push ${PARENT_IMAGE}

endif # ifdef PARENT_IMAGE

endif # ifndef IN_RUNNING_REPRO

ifeq ($(REPRO_LOGGING_LEVEL), debug)
QUIET=
else ifeq ($(REPRO_LOGGING_LEVEL), trace)
QUIET=
else 
QUIET=@
endif

## 
#- =============================================================================
##    --- Targets also affected by REPRO RUN settings ---
#- =============================================================================

# define mount point for REPRO directory tree in running container
REPRO_MNT=/mnt/${REPRO_NAME}

# define command for running the REPRO Docker image
REPRO_RUN_COMMAND=$(QUIET)docker run -it --rm $(REPRO_DOCKER_OPTIONS)       \
                             --volume "$(CURDIR)":"$(REPRO_MNT)"            \
							 $(REPRO_SETTINGS)								\
                             $(REPRO_MOUNT_OTHER_VOLUMES)                   \
                             $(REPRO_IMAGE)

# define command for running a command in a running or currently-idle REPRO
ifdef IN_RUNNING_REPRO
RUN_IN_REPRO=$(QUIET)bash -ic
else
RUN_IN_REPRO=$(REPRO_RUN_COMMAND) bash -ilc
endif


## 
#- ---------- Targets for starting this REPRO  ---------------------------------
#- 
ifndef IN_RUNNING_REPRO
start-repro:            ## Start this REPRO in interactive mode. 
	$(REPRO_RUN_COMMAND)
else
start-repro:
	$(warning INFO: The REPRO is already running.)
endif

clean-repro:            ## Delete REPRO run logs in .repro-log directory.
	rm .repro-log/*.log

## 
ifdef IN_RUNNING_REPRO
start-services:         ## Start the services provided by this REPRO.
	$(RUN_IN_REPRO) 'repro.start_services'
else
start-services:
	$(RUN_IN_REPRO) 'repro.start_services --wait-for-key'
endif

REPRO_TESTS_FILE=repro-tests
test-repro:
	@make -f Makefile-tests --quiet

## 
#- ---------- Targets for running the examples in this REPRO --------------------
#- 
run-demos:              ## Run this REPRO's demos.
	$(RUN_IN_REPRO) 'repro.run_target run-demos'

clean-demos:            ## Delete all artifacts created by the demos.
	$(RUN_IN_REPRO) 'repro.run_target clean-demos'

## 
#- ---------- Targets for performing the analyses in this REPRO -----------------
#- 
run-analyses:           ## Run the analyses in this REPRO.
	$(RUN_IN_REPRO) 'repro.run_target run-analyses'

clean-analyses:         ## Delete all artificats created by the analyses.
	$(RUN_IN_REPRO) 'repro.run_target clean-analyses'

## 
#- ---------- Targets for creating the reports in this REPRO -------------------
#- 
build-reports:          ## Generate this REPRO's reports.
	$(RUN_IN_REPRO) 'repro.run_target build-reports'

clean-reports:          ## Delete all generated reports.
	$(RUN_IN_REPRO) 'repro.run_target clean-reports'

## 
#- ---------- Targets for maintaining the databases in this REPRO --------------
#- 
clean-databases:        ## Delete the database logs.
	$(RUN_IN_REPRO) 'repro.run_target clean-databases'
	
drop-databases:         ## Delete the database storage files.
	$(RUN_IN_REPRO) 'repro.run_target drop-databases'

purge-databases:        ## Delete all artifacts associated with database instances.
	$(RUN_IN_REPRO) 'repro.run_target purge-databases'

## 
#- =============================================================================
##    --- Targets further affected by REPRO CODE settings ---
#- =============================================================================

## 
#- ---------- Targets for building and testing custom code in this REPRO -------
#- 
build-code:             ## Build the custom code in this REPRO.
	$(RUN_IN_REPRO) 'repro.run_target build-code'

test-code:              ## Run tests on custom code in this REPRO.
	$(RUN_IN_REPRO) 'repro.run_target test-code'

install-code:           ## Install built artifacts in REPRO.
	$(RUN_IN_REPRO) 'repro.run_target install-code'

package-code:           ## Package custom artifacts for distribution.
	$(RUN_IN_REPRO) 'repro.run_target package-code'

clean-code:             ## Delete artifacts generated by builds of the code.
	$(RUN_IN_REPRO) 'repro.run_target clean-code'

purge-code:             ## Delete all downloaded, cached, and built artifacts.
	$(RUN_IN_REPRO) 'repro.run_target purge-code'\

## 
#- =============================================================================
##    --- Target aliases defined in repro-config ---
#- =============================================================================
## 

