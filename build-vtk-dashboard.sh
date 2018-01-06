#!/bin/bash
# build-vtk-dashboard.sh 
VERSION="v2.2 03/01/2018" 
AUTHOR="John Sincock"

#set -x
DEBUG=
#DEBUG=echo

usage () {
   echo
   echo "Get latest Visualisation Toolkit (VTK)/dashboard update from Git, and use it to configure/make/install VTK/dashboard as required."
   echo 
   echo
   echo "Usage > build-vtk-dashboard.sh [options]"
   echo
   echo "      -h | --help                Lists this usage information."
   echo "      -d | --debug               Echo the commands that will be executed."
   echo
   echo "      --custom                   Clone/pull/configure/build vtk-master, not dashboard."
   echo
   echo "      --clone                    Git clone."
   echo "      --pull                     Git pull."
   echo "      --status                   Lists files which git will pull."
   echo
   echo "      --builddir                 Specify name of the build subdir. Default = username."
   echo "                                   (use for configure, make)"
   echo "      --clean                    Clean build tree."
   echo
   echo "      --configure                Prepare/configure build tree."
   echo "      --make                     Build."
   echo "      --install                  Install."
   echo
   echo "  Additional options for Make stage:"
   echo "      --testing                  Execute automated testing (when running make stage)."
   echo "      --display  \"Xdisplay\"    Export DISPLAY=\"Xdisplay\" (for testing). Default=\":0\""
   echo "      --flags    \"-j6\"         Set build flags. Default=\"-j6\""
   echo "      --model    \"type\"        Set Ctest dashboard model (Continuous|Nightly|Experimental)."
   echo "      --name     \"buildName\"   Set Ctest dashboard build name"
   echo "      --site     \"siteName\"    Set Ctest dashboard site name"
   echo "      --dropsite \"dropSite\"    Set Ctest drop site."
   echo "      --droploc  \"dropLoc\"     Set Ctest drop location."
   echo
   exit
}
function set_date () {
    export DATE="`date +%Y-%m-%d`"
}
function echo_date () {
    echo "${DATE}"
}
function set_time () {
    export TIME="`date +%H-%M-%S`"
}
function echo_time () {
    echo "${TIME}"
}

#Defaults. These should be driven by jenkins/command line args.
ok=0 ; debug=0 ;
clone=0 ; pull=0 ; status=0 ; 
cleanbuild=0 ; configure=0 ; make=0 ; install=0 ;
BUILD_DIRNAME=`whoami`

#dashboard or vtk-master
custom=0                                                     #0=dashboard, 1=vtk-master
if [[ $custom -eq 0 ]] ; then
    MODULE=dashboard
else
    MODULE=vtk-master
fi

export DISPLAY=:0                                            #testing requires a display with openGL.
export MESA_GL_VERSION_OVERRIDE=3.2                          #fix for VNC requesting a compatibility profile which breaks many VTK tests
VNC_START_DISPLAYNO=12                                       #our VNC servers start on DISPLAY=:12

export CTEST_DASHBOARD_BUILD_NAME="vtk-jenkins-default"

#export CTEST_DASHBOARD_MODEL="Nightly"                      #does do git update
#export CTEST_DASHBOARD_MODEL="Continuous"                   #(like nightly but loops and runs every 5 mins or so)
export CTEST_DASHBOARD_MODEL="Experimental"                  #does not do git update

#Note: testing does not work by default over vnc, maybe tweak mesa to fix this, otherwise, requires nvidia.
export CTEST_DASHBOARD_NO_TEST="True"                        #False *enables* testing.
export CTEST_DASHBOARD_BUILD_FLAGS="-j6"                     #use 6 cores for build
export CTEST_DASHBOARD_SITE_NAME="il-duce.homunculoid.com"

#these are exported to dashboard.cmake then vtk_common.cmake
export CTEST_DROP_SITE="homunculoid.com"
export CTEST_DROP_LOCATION="/CDash/submit.php?project=VTK"

#  set(CTEST_DROP_SITE "open.cdash.org")
#  set(CTEST_DROP_LOCATION "/submit.php?project=VTK")

export jss_clean_build_tree="no"   #set to "yes", to clean, anything else to skip cleaning.

if [ "$#" == "0" ]; then
    echo "No arguments. Halp!"
    usage
fi

while (( "$#" )); do
    case ${1} in    #switches for this shell script begin with '--'
	-h)           usage;;
	--help)       usage;;
	-d)           debug=1; DEBUG=echo ; echo -e "\nDebug mode on.";;
	--debug)      debug=1; DEBUG=echo ; echo -e "\nDebug mode on.";;

	--clone)      ok=1; echo "Cloning dashboard."                  ; clone=1;;
	--pull)       ok=1; echo "Updating dashboard."                 ; pull=1;;
	--status)     ok=1; echo "Getting dashboard repo status."      ; status=1;; 

	--builddir)   BUILD_DIRNAME="$2"                               ; echo "BUILD_DIRNAME = ${BUILD_DIRNAME}"      ; shift ;;
	--clean)      cleanbuild=1 ; export jss_clean_build_tree="yes" ; echo "Will clean build tree."  ;;
	
	--custom)     custom=1 ; cleanbuild=1 ; MODULE=vtk-master ; echo "Performing custom VTK build, not dashboard." ;;
	--configure)  ok=1; configure=1 ; echo "Configuring"  ;;
	--make)       ok=1; make=1      ; echo "Building."    ;;
	--install)    ok=1; install=1   ; echo "Installing."  ;;
	--testing)    export CTEST_DASHBOARD_NO_TEST="False"  ; echo -e "\nExecuting tests.";;
 
	--display)    export DISPLAY="$2"                     ; echo "DISPLAY       = ${DISPLAY}"                     ; shift ;;
        --flags)      export CTEST_DASHBOARD_BUILD_FLAGS="$2" ; echo "Flags         = ${CTEST_DASHBOARD_BUILD_FLAGS}" ; shift ;;
	--model)      export CTEST_DASHBOARD_MODEL="$2"       ; echo "Model         = ${CTEST_DASHBOARD_MODEL}"       ; shift ;;
	--name)       export CTEST_DASHBOARD_BUILD_NAME="$2"  ; echo "Build name    = ${CTEST_DASHBOARD_BUILD_NAME}"  ; shift ;;
        --site)       export CTEST_DASHBOARD_SITE_NAME="$2"   ; echo "Site name     = ${CTEST_DASHBOARD_SITE_NAME}"   ; shift ;;
	--dropsite)   export CTEST_DROP_SITE="$2"             ; echo "Drop site     = ${CTEST_DROP_SITE}"             ; shift ;;
	--droploc)    export CTEST_DROP_LOCATION="$2"         ; echo "Drop location = ${CTEST_DROP_LOCATION}"         ; shift ;;
	
	#--noclean)   cleanbuild=0;;
	*)            ok=0 ; echo "Unrecognised option." ;  usage ;;
    esac;
    shift
done

if [ $ok -eq 0 ] ; then echo "Halp. Something isn't right with the command arguments. Exiting." ; usage ; fi
echo

set_date ; set_time
#DATE="`date +%Y%m%d`"   #used to label CMakeCache and maybe build id
GIT_ID="nightly/1"      #dashboard configs go here. Build occurs in nightly/1/build subdir, as cmake cleans it. 
BUILD_ID=${GIT_ID}      #may switch to #BUILD_ID="nightly/${DATE}"
CI_DIR="/data-ssd/data/development/src/vtk"
JENKINS_DIR="."                      #These scripts & configs are run from jenkins tmp dir after checkout from repo. 
CONFIG_DIR="${JENKINS_DIR}/config"
#CONFIG_DIR="${CI_DIR}/config"
#JENKINS_DIR="/data-ssd/data/development/src/github/jenkins-vtk-dashboard"

GIT_DIRNAME=git
GIT_DIR="${CI_DIR}/${GIT_DIRNAME}"
GIT_LOG_DIR="${GIT_DIR}/z_logs"
GIT_SRC_DIR="${GIT_DIR}/${MODULE}"

#relative:
BUILD_MODULE_SUBDIR="build/${BUILD_DIRNAME}/${MODULE}" #eg build/jenkins/dashboard
BUILD_SUBDIR="${BUILD_MODULE_SUBDIR}/${BUILD_ID}"      #eg build/jenkins/dashboard/nightly/1

#full paths:
BUILD_MODULE_DIR="${CI_DIR}/${BUILD_MODULE_SUBDIR}"    #eg /data-ssd/.../vtk/build/jenkins/dashboard
BUILD_DIR="${CI_DIR}/${BUILD_SUBDIR}"                  #real build goes under here

#used by custom build:
#can use --builddir to set BUILD_DIR to jenkins, if building this as jss
CONFIG_ARCHIVE_DIR="${BUILD_MODULE_DIR}/config_archive"
mkdir -p "${CONFIG_ARCHIVE_DIR}"

GIT_ROOT="https://gitlab.kitware.com/vtk/vtk.git"
GIT_LOGFILE="${GIT_LOG_DIR}/git-vtk-dashboard-${DATE}--${TIME}.log"

BUILD_LOGFILE="${CONFIG_ARCHIVE_DIR}/build-vtk-dashboard-${DATE}--${TIME}.log"

#By default, source and build trees go in "../My Tests/" relative to your script location.
#Better locations:
#VTK git checkout goes under: CTEST_DASHBOARD_ROOT/dashboard_source_name
#Build goes under:            CTEST_DASHBOARD_ROOT/dashboard_binary_name
#Test Data goes under         CTEST_DASHBOARD_ROOT/dashboard_store_name

export CTEST_DASHBOARD_ROOT="${CI_DIR}"                         #Where to put source and build trees
#cmake cleans the build dir (dashboard_binary_name_dir)
#so our dashboard configs go in ${BUILD_SUBDIR} and cmake builds in ${BUILD_SUBDIR}/some-subdir:
export CTEST_DASHBOARD_BUILD_DIR="${BUILD_SUBDIR}/vtk-build"    #Name of binary (build) directory (default VTK-build)
export CTEST_DASHBOARD_VTK_GIT_DIR="${GIT_DIRNAME}/vtk-master"  #Name of source directory (VTK)
export CTEST_DASHBOARD_TESTDATA_DIR="${GIT_DIRNAME}/Test-Data"  #Name of ExternalData store (Test-Data)

function env_clean () {
    #Pipe data into this function
    #Strip lines starting with "}" created by effing BASH_FUNC shellshock mangling shiteballs
    #If you just export single line functions, you still get closing } on separate line
    #grep -v "BASH_FUNC" | sort   #So let's not strip this, we want to see this garbage
    grep -v -e "^}.*" - | sort    #But let's strip the trailing } we dont need to see those after sorting
}
function jj-env-pid () { 
    #display environemnt of pid
    #handles stupid null terminated vars from /prox/blah/environ
    self=$$  #pid of self
    xargs -n 1 -0 < /proc/${1:-$self}/environ   #use given pid or pid of self if not specified
}
function jj-env-pid-clean () { 
    jj-env-pid | env_clean
}

git_dashboard_clone () {
    echo "Cloning dashboard into <${GIT_SRC_DIR}>:"
    $DEBUG mkdir --parents "${GIT_SRC_DIR}"
    $DEBUG cd "${GIT_SRC_DIR}"
    $DEBUG git init                                         | tee --append "${GIT_LOGFILE}"
    $DEBUG git remote add -t dashboard origin "${GIT_ROOT}" | tee --append "${GIT_LOGFILE}"
    $DEBUG git pull origin                                  | tee --append "${GIT_LOGFILE}"
}
git_vtk_clone () {
    echo "Cloning vtk into <${GIT_SRC_DIR}>:"
    $DEBUG mkdir --parents "${GIT_SRC_DIR}"
    $DEBUG cd "${GIT_SRC_DIR}"
    $DEBUG git init                                         | tee --append "${GIT_LOGFILE}"
    $DEBUG git remote add origin "${GIT_ROOT}"              | tee --append "${GIT_LOGFILE}"
    $DEBUG git pull origin                                  | tee --append "${GIT_LOGFILE}"
}
git_runcmd () {
    gitcmd="$1"
    msg="$2"
    echo "$msg"
    $DEBUG cd "${GIT_SRC_DIR}"
    $DEBUG git $gitcmd 2>&1 | tee --append "${GIT_LOGFILE}"
}
git_pull () {
    git_runcmd "pull" "Updating <${GIT_SRC_DIR}>:"
}
git_status () {
    git_runcmd "status" "Status of <${GIT_SRC_DIR}>:"
}
screen_on () {
    displayno=${DISPLAY:1}  #value of display from 1st char on (skips the 0'th char, which is the :)
    if [[ ${displayno} -ge ${VNC_START_DISPLAYNO} ]] ; then
	echo "Allis Clar, we are runnning on a VNC head."
    else
        #Must ensure X display is on *active vt*

	vtstring=$( cat "/var/log/Xorg.${displayno}.log" | grep -i "using VT number" )
	vt=${vtstring##*number }  #double # strips longest matching prefix, leaving just vt number
	echo "Activating virtual terminal VT${vt}, for X display ${displayno}:"
	sudo chvt "${vt}"
	
	#When using nvidia drivers, tests fail if DPMS kicks in and screen turns off. 
	#Nvidia drivers then "optimise" away all the drawing operations. Nothing is actually drawn. 
	#So then when the drawn image is captured, it's blank, & does not match reference image, so tests fail.
	
	#So we have to disable screen blanking and DPMS.
	#
	#xset will be over-ridden if xfce4-power-manager is running (or other desktop power manager). 
	#If so, ensure xfce/other power managers are configured to disable screensaver & have DPMS off.
	
	if [[ $( ps -ef | grep xfce4-power-manager ) ]] ; then 
	    echo "WARNING: xfce4-power-manager is running."
	    #echo "Attempting to kill it."
            #killall -KILL xfce4-power-manager
	fi
	if [[ $( xset q | grep "DPMS is Enabled" ) ]] ; then 
	    echo "WARNING: DPMS is Enabled on display=$DISPLAY"   #DPMS is Enabled
	fi
	if [[ $( xset q | grep "Monitor is Off" ) ]] ; then 
	    echo "WARNING: Monitor is OFF on display=$DISPLAY"    #Monitor is Off
	fi
	$DEBUG xset s off -dpms
	#$DEBUG sudo -u jss /usr/bin/xhost +    #We take care of Xauthority/mit magic cookies now
    fi
}
configure () {
    echo "Configuring <${BUILD_DIR}> :"
    
    if [[ ! -d  "${BUILD_DIR}" ]] ; then
	echo "Creating build tree <${BUILD_DIR}> :"
	$DEBUG mkdir --parents "${BUILD_DIR}"
    else
	echo "Build dir already exists."
    fi

    echo "Copying dashboard configs into <${BUILD_DIR}>:"
    #copy the basic dashboard config into place from the dashboard git checkout:
    #$DEBUG cp -vf "${GIT_DIR}/vtk_common.cmake" "${BUILD_DIR}/"      #open.cdash.org
    $DEBUG cp -vf "${CONFIG_DIR}/vtk_common.cmake" "${BUILD_DIR}/"    #homunculoid.com
    
    #restore our customised dashboard cmake config:
    $DEBUG cp -vf "${CONFIG_DIR}/dashboard.cmake" "${BUILD_DIR}/"

    echo "Configure for <${BUILD_DIR}> done."
}
safe_dir () {
    #ensure the tested directory exists and contains the build dir
    #(and build dir must contain a "build" dir somewhere in path)
    
    somedir=$1
    echo "Testing <$somedir> :"
    safe=0
    if [[ -d  "${somedir}" && "m${somedir}" != "m/" && "${BUILD_DIR}" =~ .*"/build/".* && "${somedir}" =~ "${BUILD_DIR}".* ]] ; then
	echo -e "Safe.\n"
	safe=1
    else
	echo -e "UNSAFE!\n"
    fi
    return $safe
}
function clean () {
    #Trying to avoid cleaning build dir here will be pointless until we can stop cmake cleaning it.
    #Have had to hack vtk_common.cmake to check additional var jss_clean_build_tree, and skip cleaning if it is not set to yes
    if [ $cleanbuild -eq 1 ] ; then
	echo "Cleaning build dir <${BUILD_DIR}> :"
	safe_dir "${BUILD_DIR}"
	safe=$?
	if [[ "${safe}" -eq 1 ]] ; then
	    echo "Deleting build dir <${BUILD_DIR}> in 5 seconds:"
	    $DEBUG sleep 5
	    $DEBUG rm -Rf "${BUILD_DIR}"   #If interactive, could use -I to wait for confirmation
	else
	    echo -e "Woah. Not safe to clean build dir <${BUILD_DIR}>\n"
	fi
    fi
}
fix_perms () {
    echo "Fixing perms:"
    #setgid on parent should ensure jenkins.jss, but jenkins can and does explicitly chgrp some folders to group jenkins.
    #have added jss to jenkins group, so as long as everything is g+rwX, jss can still delete if jenkins has group ownership of files.
    chmod -Rf g+rwX "${BUILD_MODULE_DIR}"
    
    #chmod -Rf g-s "${BUILD_MODULE_DIR}"          #cannot chown some subdirs which jenkins has done setgid on, til we remove it.
    #chown -Rvf jenkins.jss "${BUILD_MODULE_DIR}" #In order to chown back to group jss, jenkins must be a member of group jss, which i don't want.
}
build () {
    #Builds vtk dashboard.
    echo "Building <${BUILD_DIR}> :"

    if [[ -d  "${BUILD_DIR}" ]] ; then
	#echo "Building with $CORES cores:"
	echo "Building VTK dashboards:"
	$DEBUG cd "${BUILD_DIR}"
	#clean   #leave cleaning up to cmake. vtk_common.cmake now cleans if jss_clean_build_tree is set to yes, skips if anything else.
	screen_on #Ensure screen blanking & DPMS are disabled. Must *STILL* ensure x display is on active tty with Ctrl-Alt-Fx

	#Build and submit dashboards:
	$DEBUG ctest -S "${BUILD_DIR}/dashboard.cmake" -V            ##--build-noclean
	fix_perms
    else
	echo "Have not configured <${BUILD_DIR}>. It does not exist. Cannot build."
    fi
}
configure_custom () {
    echo "Configuring <${BUILD_DIR}> :"
    clean
    if [[ ! -d  "${BUILD_DIR}" ]] ; then
	echo "Creating build tree <${BUILD_DIR}> :"
	$DEBUG mkdir --parents "${BUILD_DIR}"
    #elif [[ $refresh -eq 1 ]] ; then   #i think cmake will update/refresh any existing build directory.
	#echo "Updating build tree : <${BUILD_DIR}> :"
	#$DEBUG cd "${BUILD_DIR}"
	#$DEBUG lndir "${GIT_SRC_DIR}"      # link to new files
	#echo "Removing stale links from build tree : <${BUILD_DIR}> :"
	#could use "cleanlinks" #from X11
	###$DEBUG find . -xtype l -exec rm '{}' \; # remove links pointing to non-existent files
    else
	echo "Build dir already exists."
    fi
    
    #restore our saved cmake config from git checkout:
    #$DEBUG cp -vf "${CONFIG_DIR}/CMakeCache-current.txt" "${BUILD_DIR}/CMakeCache.txt"
    #$DEBUG cp -vf "${CONFIG_DIR}/CMakeCache-testing-on.txt" "${BUILD_DIR}/CMakeCache.txt"
    #$DEBUG cp -vf "${CONFIG_DIR}/CMakeCache-testing-off.txt" "${BUILD_DIR}/CMakeCache.txt"
    $DEBUG cp -vf "${CONFIG_DIR}/CMakeCache-experimental.txt" "${BUILD_DIR}/CMakeCache.txt"
    
    $DEBUG cd "${BUILD_DIR}"
    #$DEBUG ccmake "${GIT_SRC_DIR}"    #interactive
    $DEBUG cmake "${GIT_SRC_DIR}"      #non-interactive, specify options on cmdline, or use pre-made config

    #save config for later:
    $DEBUG mkdir --parents "${CONFIG_ARCHIVE_DIR}"
    $DEBUG cp -vf "${BUILD_DIR}/CMakeCache.txt" "${CONFIG_ARCHIVE_DIR}/CMakeCache-${DATE}.txt"

    echo "Configure for <${BUILD_DIR}> done."
}
build_custom () {
    #Builds VTK master checkout, not dashboard.
    echo "Building <${BUILD_DIR}> :"
    if [[ -d  "${BUILD_DIR}" ]] ; then
	echo "Building with flags: ${CTEST_DASHBOARD_BUILD_FLAGS}"
	$DEBUG cd "${BUILD_DIR}"
	#clean   #leave cleaning up to cmake. vtk_common.cmake now cleans if jss_clean_build_tree is set to yes, skips if anything else.
	screen_on #Ensure screen blanking & DPMS are disabled. Must *STILL* ensure x display is on active tty with Ctrl-Alt-Fx

	#$DEBUG make -j$CORES 	                #Simple build:	
	$DEBUG make "${CTEST_DASHBOARD_BUILD_FLAGS}"
	fix_perms
    else
	echo "Have not configured <${BUILD_DIR}>. It does not exist. Cannot build."
    fi
}
install () {
    echo "Installing <${BUILD_DIR}> :"
    if [[ -d  "${BUILD_DIR}" ]] ; then
	echo "Running make install in <${BUILD_DIR}> :"
	$DEBUG cd "${BUILD_DIR}"
	$DEBUG make install
    else
	echo "Have not configured <${BUILD_DIR}>. It does not exist. Cannot install."
    fi
}
test_safedir () {
    safedir ""
    safedir "/"
    safedir "/data-ssd/data/development/src/vtk/"
}
function git_stuff () {
    if [[ $clone -eq 1 && $custom -eq 0 ]] ; then git_dashboard_clone ; fi
    if [[ $clone -eq 1 && $custom -eq 1 ]] ; then git_vtk_clone       ; fi
    if [[ $pull      -eq 1 ]] ; then git_pull            ; fi
    if [[ $status    -eq 1 ]] ; then git_status          ; fi
}
function build_stuff () {
    if [[ $configure -eq 1  && $custom -eq 0 ]] ; then configure  ; fi
    if [[ $make      -eq 1  && $custom -eq 0 ]] ; then build      ; fi
    if [[ $configure -eq 1  && $custom -eq 1 ]] ; then configure_custom  ; fi
    if [[ $make      -eq 1  && $custom -eq 1 ]] ; then build_custom      ; fi
    if [[ $install   -eq 1 ]] ; then install    ; fi
}
function setup_xauth () {
    export XAUTHORITY_JSS_GDM=/run/user/1000/gdm/Xauthority     #Gdm puts our cookie for :0 here.
    export XAUTHORITY_JSS=/home/jss/.Xauthority                 #Cookies for our vncservers are in here.
    
    export XAUTHORITY="${HOME}/.Xauthority.vtk"
    jj-env-pid-clean > "${BUILD_LOGFILE}"
    
    rm -f "${XAUTHORITY}" #start with a clean, empty xauth.
    touch "${XAUTHORITY}"
    
    if [[ $DISPLAY == ":0" ]] ; then 
	#merge XAUTHORITY_JSS_GDM=/run/user/1000/gdm/Xauthority if running on display :0
	XAUTH="${XAUTHORITY_JSS_GDM}"
    else
	#merge XAUTHORITY_JSS=/home/jss/.Xauthority if running on any other (non-gdm) display
	XAUTH="${XAUTHORITY_JSS}"
    fi
    echo "Using Xauthority=${XAUTH}"
    sudo /usr/local/bin/display-auth.sh --a "${XAUTH}" --m "${XAUTHORITY}" --u ${USER} >> "${BUILD_LOGFILE}" 2>&1
}

#############################################
#main stuff start here:

#echo "Logging to: ${BUILD_LOGFILE}"
setup_xauth

#test_safedir
git_stuff
build_stuff # >> "${BUILD_LOGFILE}" 2>&1
echo        # >> "${BUILD_LOGFILE}" 2>&1
