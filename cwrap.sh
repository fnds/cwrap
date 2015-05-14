#!/bin/bash
### cwrap.sh - wrapper for cron jobs 
#
#   USAGE: cwrap.sh <script> [ <script parameters> ]
#
#   Executes the script at $scripts/<script>
#   Redirects stdout and stderr to a unique log file for each run: $scripts/logs/<script>.<timestamp>.log
#   Email script status
#   Do not send emails if file cwrap.blackout exists at $scripts
#
#   11/28/12 - fnds - created
#   04/01/13 - fnds - minor tweaks
#   04/17/13 - fnds - fix for blank username
#

## GLOBAL VARS ##

PROG=`basename $0`

# /usr/xpg4/bin/egrep
# supports full regular expressions

EGREP=/usr/xpg4/bin/egrep

# unique job id for messages and log file
# JOBID = YYMMDDHHMMSS (121211133202 = Dec 11 13:32:02 2012)

JOBID=`date '+%y%m%d%H%M%S'`.$$

# keep track of errors
# increment when error found

err_cnt=0

# determine current username
# some servers use $USER, some use $LOGNAME
# and some use both

test -n "$USER"     && username=$USER
test -n "$LOGNAME"  && username=$LOGNAME

# hostname

hostname=`hostname`

## FUNCTIONS ##

# echo formatted date/time
function now {
    date '+%a %m/%y/%d %H:%M:%S'
}

# echo a formatted message
function msg {
    echo "-- $@ (`now`)"
}

# echo a formatted error message
function err {
    let err_cnt++
    echo "** $@ (`now`)"
}

# print current settings
function print_settings {
     echo "MAILTO=$MAILTO"
     echo "LOGDIR=$LOGDIR"
     echo "SCRDIR=$SCRDIR"
     echo "EMAIL_ACTION=$EMAIL_ACTION"
     echo "OUT_INCLUDE=$OUT_INCLUDE"
     echo "SAVEOUT=$SAVEOUT"
     echo "VERBOSE=$VERBOSE"
     echo "JOBID=$JOBID"
}

# list configuration files
function list_cfgfiles {
    test -f "$cfgfile" && ls -l $cfgfile
    test -f "$o_cfg" && ls -l $o_cfg
}

# display usage information
function print_usage {
echo "
USAGE: $PROG [ options ] <script> [ <script parameters> ]

- Executes <script> at default directory: $defdir
  unless <script> includes directory location
- Redirects output to unique file for each run
- Checks for errors
- Sends email with status
- Do not send emails if file cwrap.blackout exists at $defdir

Options: (override any config file settings)
         -c <config file>   : optional config file
         -e a               : (a)lways sends email `[ $def_email_action = 'a' ] && echo '(default)'`
         -e n               : (n)ever sends email `[ $def_email_action = 'n' ] && echo '(default)'`
         -e s               : email only when (s)uccessful `[ $def_email_action = 's' ] && echo '(default)'`
         -e e               : email only when (e)rrors found `[ $def_email_action = 'e' ] && echo '(default)'`
         -h                 : detailed help
         -m <email address> : sends email to this address (default: $def_mailto)
         -o                 : save script output to a separate file (default: $def_saveout)
         -v                 : shows more info on screen (verbose)
         -x                 : do not include script output in email (default: $def_outinc)

Settings search order:
    1) command line options
    2) optional config file (-c)
    3) configuration file: $cfgfile
"
}

## DEFAULTS ##

def_mailto=qnet-prod-dbas@bcssi.sdps.org
def_email_action=e
def_outinc=true
def_saveout=false
def_verbose=false

## default directory

# dir where cwrap.sh is located
# this is the default dir for scripts

defdir=`dirname $0`
[ "$defdir" == "." ] && defdir=`pwd`

## source configuration file

# UPPERCASE variable names indicate they can be
# customized in the config file

# source config file

cfgfile=$defdir/cwrap.conf

if [ -f $cfgfile ]
then
    #msg "sourcing main config file: $cfgfile"
    . $cfgfile
fi

## exit if no parameters are provided

[ $# -eq 0 ] && print_usage && exit 9


## PARSE CMD LINE OPTIONS ##

o_alias=
o_cfg=
o_email=
o_outinc=
o_mailto=
o_saveout=
o_verbose=

while getopts "a:c:e:hm:ovx" o
do
    case "$o" in
    a)    o_alias="$OPTARG";;
    c)    o_cfg="$OPTARG";;
    e)    o_email="$OPTARG";;
    h)    print_usage; exit 0;;
    m)    o_mailto="$OPTARG";;
    o)    o_saveout=true;;
    v)    o_verbose=true;;
    x)    o_outinc=false;;
    *)    print_usage; exit 9;;
    esac
done
shift `expr $OPTIND - 1`

## validating cmd line options ##

## config file

if test -n "$o_cfg"
then
    [ ! -f "$o_cfg" ] && err "file not found: $o_cfg" && exit 9
    #msg "sourcing additional config file: $o_cfg"
    . $o_cfg
fi

# cmd line options override config file settings
# UPPERCASE variables can be set in config file

## email action

test -z "$EMAIL_ACTION" && EMAIL_ACTION=$def_email_action
if test -n "$o_email"
then
    case "$o_email" in
    a|n|e|s) EMAIL_ACTION=$o_email;;
    *) err "invalid option: -e $o_email";
       print_usage;
       exit 9;;
    esac
fi

## include script output in email

test -z "$OUT_INCLUDE" && OUT_INCLUDE=$def_outinc
test -n "$o_outinc"    && OUT_INCLUDE=$o_outinc
case "$OUT_INCLUDE" in
true|false) : valid settings;;
*) err "invalid setting. must be true or false: OUT_INCLUDE=$OUT_INCLUDE"
   exit 9;;
esac

## save output to separate file

test -z "$SAVEOUT"   && SAVEOUT=$def_saveout
test -n "$o_saveout" && SAVEOUT=$o_saveout
case "$SAVEOUT" in
true|false) : valid settings;;
*) err "invalid setting. must be true or false: SAVEOUT=$SAVEOUT"
   exit 9;;
esac

## email list

[ -f $defdir/dba_email_list ] && dba_email_list=`cat $defdir/dba_email_list`

test -n "$dba_email_list" && MAILTO=$dba_email_list
test -z "$MAILTO"         && MAILTO=$def_mailto
test -n "$o_mailto"       && MAILTO="$o_mailto"

## verbose

test -z "$VERBOSE"   && VERBOSE=$def_verbose
test -n "$o_verbose" && VERBOSE=$o_verbose
case "$VERBOSE" in
true|false) : valid settings;;
*) err "invalid setting. must be true or false: VERBOSE=$VERBOSE"
   exit 9;;
esac

## configure log directory ##

# log files are created at $LOGDIR
# dir is created if needed
# default: $defdir/logs

test -z "$LOGDIR" && LOGDIR=$defdir/logs

if [ ! -d $LOGDIR ]
then
    mkdir -p $LOGDIR
    [ $? -ne 0 ] && err "error creating log dir: $LOGDIR" && exit 9
fi

## parse script and parameters

script=$1
shift
params=$@

[ -z "$script" ] && echo "no script provided" && exit 9

## initialize job log

# cwrap.sh output goes to $LOGDIR/cwrap.$JOBID.log
# notice that it is distinct from script output which goes to another file ($outfile)

joblog=$LOGDIR/cwrap.$JOBID.log

if $VERBOSE
then
    msg "running command: $script $params"
    msg "output at: $joblog"
fi

exec > $joblog 2>&1

# find script directory

# if script parameter does not specify a directory,
# script is assumed to be at $defdir or SCRDIR in conf file

test -z "$SCRDIR" && SCRDIR=$defdir

scrdir=`dirname $script`
[ "$scrdir" == "." ] && scrdir=$SCRDIR

# eliminate dir path from $scrname

scrname=`basename $script`

scrfile=$scrdir/$scrname
cmdline="$scrfile $params"

[ ! -f $scrfile ] && err "cant find script file: $scrfile" && exit 9
[ ! -x $scrfile ] && err "script isnt executable: `ls -l $scrfile`" && exit 9

# option -o: initialize unique log file to collect script output
# otherwise output is sent to a temp file and discarded

if $SAVEOUT
then
    outfile=$LOGDIR/$scrname.$JOBID.log
else
    outfile=$LOGDIR/cwrap.$JOBID.tmp
fi
[ -f $outfile ] && err "log file already exists: $outfile" && exit 9
touch $outfile 
[ $? -ne 0 ] && err "cant access log file: $outfile" && exit 9

## RUN JOB (finally) ##

msg "running command: $cmdline"
$SAVEOUT && msg "sending all command output to $outfile"

msg "config files in use:"
list_cfgfiles

msg "Current settings"
print_settings

start_time=`now`
eval $cmdline > $outfile 2>&1
retcode=$?
end_time=`now`
#action=`nawk '/^JOBWRAP\|/,0' $outfile`

msg "end of job"

# check return code

job_err=false
[ $retcode -ne 0 ] && err "script returned OS error: $retcode" && job_err=true

# determine job status

if $job_err || [ $err_cnt -ne 0 ]
then
    error_found=true
    status="ERROR"
else
    error_found=false
    status="SUCCESS"
fi

# job summary

cat <<JOBSUMM | tee -a $outfile
--------------------------------------------------------------------------------
-- command   : $cmdline
-- start     : $start_time
-- end       : $end_time
-- ret code  : $retcode
-- status    : $status
-- output    : $outfile
-- job info  : $joblog
-- hostname  : $hostname
-- username  : $username
-- the command above was executed and the output spooled to this file
-- generated by $defdir/$PROG
--------------------------------------------------------------------------------
JOBSUMM

if $OUT_INCLUDE
then
    email_body=$outfile
else
    email_body=$joblog
fi

send_email=false
case $EMAIL_ACTION in
a) send_email=true;;
n) send_email=false;;
e) $error_found && send_email=true;;
s) $error_found || send_email=true;;
*) err "invalid email_action = $EMAIL_ACTION";;
esac

msg "send_email = $send_email"

if $send_email
then
    if test -f $defdir/cwrap.blackout
    then
         msg "file $defdir/cwrap.blackout is present"
         msg "email blackout. do not send email."
    else
        msg "sending email to $MAILTO"
        mailx -s "$scrname: $status at $hostname" $MAILTO < $email_body
    fi
fi

# end

msg "end"
