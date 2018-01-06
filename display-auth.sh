#!/bin/bash
# display-auth.sh
# script to merge XAUTHORITY files from one user to another (run via sudo)

ok=0 ; debug=0 ; verbose=0 ; clean_unix=0 ; clean_unix_0=0 ; clean_tcp=0 ;
DEBUG=""

LOGDIR=~/display-auth
mkdir -p ${LOGDIR}
LOG=${LOGDIR}/display-auth.log
#LOG=/dev/stdout
#LOG="&1"

usage () {
    echo
    echo "Script to merge xauthority entries from one user to another."
    echo 
    echo "Usage > display-auth.sh [options] --a authfile --m mergedfile --u username --clean_tcp --clean_unix"
    echo
    echo "      authfile      : the xauthority file with the auths we want."
    echo "      mergedfile    : the xauthority file we merge the new auths into."
    echo "      username      : user we chown the mergedfile to, if it's a new file."
    echo "      clean_tcp     : clean out tcp cookies."
    echo "      clean_unix    : clean out unix socket cookies."
    echo "      clean_unix_0  : clean out unix:0 socket cookies."
    echo
    exit
}

#############################################
#source /usr/local/bin/bash_functions.sh
function print_log () {
    echo "$1" >> ${LOG}
}
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
function jj-env-stdin () {
    xargs -n 1 -0 | env_clean
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
function process_args () {
    argcount=$# ; min_args=3
    if [[ "$argcount" < "${min_args}" ]]; then
	echo "Not enough arguments! Wanted ${min_args}, got ${argcount}. Halp!"
	usage
    fi

    while (( "$#" )); do
	case ${1} in          #switches for this shell script begin with '--'
            -h | help)        usage;;
            -d | --debug )    export debug=1; export DEBUG=echo ; echo -e "\nDebug mode on.";;
	    --a) export authfile="$2"   ;                         echo "Authfile = ${authfile}" ; shift ;;
	    --m) export mergedfile="$2"   ;                       echo "Merged file = ${mergedfile}" ; shift ;;
	    --u) export myuser="$2"   ;                           echo "User = ${myuser}" ; shift ;;
	    --clean_tcp) export clean_tcp="1"   ;                 echo "Cleaning out tcp cookies." ;;
	    --clean_unix) export clean_unix="1"   ;               echo "Cleaning out unix socket cookies." ;;
	    --clean_unix_0) export clean_unix_0="1"   ;           echo "Cleaning out unix:0 socket cookies." ;;
            *)   ok=0 ; echo "Unrecognised option." ;  usage ;;
	esac;
	shift
    done
    
    #if [ $ok -eq 0 ] ; then echo "Halp. Something isn't right with the command arguments. Exiting." ; usage ; fi
    echo
}

function check_args () {
    if [[ "${mergedfile}" == "${authfile}" ]] ; then 
	echo "No need to merge, aithfile and mergefile are the same. Exiting"
	exit
    fi
}

function xmerge () {
    echo
    echo "Merging xauths from ${authfile} to ${mergedfile} for user ${myuser}."
    touch "${mergedfile}"
    ${DEBUG} xauth -f "${mergedfile}" merge "$authfile"
    chown "${myuser}" "${mergedfile}"
    echo
}

function xclean_tcp () {
    echo "Cleaning tcp xauths out of ${mergedfile}, we only want unix sockets."
    for i in `xauth -f "${mergedfile}" list | grep local.vorpal | cut -f 1 -d ' '` ; do 
	     dpyname="$i"
	     echo "Removing $dpyname"
	     xauth -f "${mergedfile}" remove $dpyname
	     xauth -f "${mergedfile}" list
    done
}
function xclean_unix () {
    echo "Cleaning unix xauths out of ${mergedfile}, we only want tcp."
    for i in `xauth -f "${mergedfile}" list | grep unix | cut -f 1 -d ' '` ; do 
	     dpyname="$i"
	     echo "Removing $dpyname"
	     xauth -f "${mergedfile}" remove $dpyname
	     xauth -f "${mergedfile}" list
    done
}
function xclean_unix_0 () {
    echo "Cleaning xauth for unix:0 out of ${mergedfile}. For some reason jss can use this, jenkins cant."
    echo "Jenkins needs to use the xauth for :0 from /run/user/1000/gdm/Xauthority."
    for i in `xauth -f "${mergedfile}" list | grep 'unix:0' | cut -f 1 -d ' '` ; do 
	     dpyname="$i"
	     echo "Removing $dpyname"
	     xauth -f "${mergedfile}" remove $dpyname   #this lists the contents with auth removed
	     #auth -f "${mergedfile}" list
    done
}

#############################################
set_date ; set_time
echo
echo "$(echo_date)-$(echo_time)"
echo
#jj-env-pid >> "${LOG}"
#print_log ""

process_args "$@" #>> "${LOG}"
check_args        #>> "${LOG}"

echo "Original auth file contains:"
${DEBUG} xauth -f "$authfile" list
echo

xmerge            #>> "${LOG}"

if [[ $clean_tcp > 0 ]]    ; then xclean_tcp ; fi
if [[ $clean_unix > 0 ]]   ; then xclean_unix ; fi
if [[ $clean_unix_0 > 0 ]] ; then xclean_unix_0 ; fi

echo
echo "Merged file contains:"
xauth -v -f "${mergedfile}" list
echo
