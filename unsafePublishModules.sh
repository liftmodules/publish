#!/bin/bash
#It is called unsafe so most people stay away from this
#But this script MAY TURN OUT TO BE safe to use if you are trying 
#to publish all Lift modules to sonatype e.g., as part of a Lift
#release version (including Milestones and RCs)

## This scripts runs on mac's bash terminal

set -o errexit
set -o nounset

BUILDLOG=/tmp/Liftmodules-do-release-`date "+%Y%m%d-%H%M%S"`.log
date > $BUILDLOG

PUSH_SCRIPT=/tmp/LiftModules-push-`date "+%Y%m%d-%H%M%S"`.sh

SBT_OPTS="-Dfile.encoding=utf8 -Dsbt.log.noformat=true -XX:MaxPermSize=256m -Xmx512M -Xss2M -XX:+CMSClassUnloadingEnabled"


# This script is an attempt to automate the Lift Module release process
# based on the Lift script.  The process is:
# For each module:
#  1. Checkout the module
#  2. Figure out the module version number
#  3. Create a branch based on the Lift version number and the module version number
#  4. Modify the Lift and module version numbers in the module's build.sbt
#  5. Try to build, fail on error.
#  6. Commit the change, log the push command to run.
#  7. +publish
#  

SCRIPTVERSION=2.0

SCRIPT_NAME="${PWD##*/}"
SCRIPT_DIR="${PWD}"

# if the script was started from the base directory, then the
# expansion returns a period
if test "$SCRIPT_DIR" == "." ; then
  SCRIPT_DIR="$PWD"
# if the script was not called with an absolute path, then we need to add the
# current working directory to the relative path of the script
elif test "${SCRIPT_DIR:0:1}" != "/" ; then
  SCRIPT_DIR="$PWD/$SCRIPT_DIR"
fi


SBT_JAR="$SCRIPT_DIR/sbt-launch.jar"


##### Utility functions (break these out into an include?) #####
# Basically yes/no confirmation with customized messages
# Usage: confirm "prompt"
# Returns 0 for yes, 1 for no
function confirm {
    while read -p "$1 [yes/no] " CONFIRM; do
        case "`echo $CONFIRM | tr [:upper:] [:lower:]`" in
            yes)
                return 0
                ;;
            no)
                return 1
                ;;
            *)
                echo "Please enter yes or no"
                ;;
        esac
    done
}

function debug {
    echo $@
    echo -n ""
}

function die {
    echo $@
    exit 1
}

# figure out project folder name from git clone URL
# and return it as $PROJNAME
function projname {
    gitname=$(basename $1)  # git://github.com/liftmodules/paypal.git -> "paypal.git"
    PROJNAME=${gitname%.*}  # "paypal.git" -> "paypal"
    return 0
 }

# Look in the current build.sbt for:
# version <<= liftVersion apply { _ + "-1.1-SNAPSHOT" }
# and return the version number (less any snapshot) in $MODULE_VERSION
function readModuleVersion {
    REASON=""
    # e.g., version <<= liftVersion apply { _ + "-1.1-SNAPSHOT" }
    line=`grep 'liftVersion apply' build.sbt`
    if [ $? -ne 0 ] ; then die "Unable to find version in build.sbt" ; fi
    
    if [[ "$line" =~ \"-?([^-]+)(-SNAPSHOT)?\" ]]
    then
        MODULE_VERSION=${BASH_REMATCH[1]}
        return 0
    else
        REASON="Failed to pick out version from: $line"
        return 1
    fi
 }


# Modify build.sbt to update the module version number and the Lift version number
function updateBuild {
    REASON=""
    LIFT_VER=$1
    MOD_VER=$2

    # TODO: Replace with SBT session saving

    sed -i.bak "s/liftVersion ?? \"[^\"]*\"/liftVersion ?? \"$LIFT_VER\"/g" build.sbt
    if [ $? -ne 0 ] ; then 
        REASON="Failed to update Lift version" 
        return 1
    fi
    rm build.sbt.bak

    sed -i.bak "s/^version <<=.*$/version <<= liftVersion apply { _ + \"-$MOD_VER\" }/g" build.sbt
    if [ $? -ne 0 ] ; then 
        REASON="Failed to update Module version" 
        return 1
    fi
    rm build.sbt.bak

    sed -i.bak "s/^crossScalaVersions.*$/crossScalaVersions := Seq(\"2.9.2\", \"2.9.1-1\", \"2.9.1\")/g" build.sbt
    if [ $? -ne 0 ] ; then 
        REASON="Failed to update Module crossbuilds" 
        return 1
    fi
    rm build.sbt.bak

    return 0

}



##### End Utility Functions #####


echo "\n*********************************************************************"
printf    "* Lift Module Release build script version %-24s *\n" "$SCRIPTVERSION"
printf    "*********************************************************************\n\n"

echo "SCRIPT_DIR is ${SCRIPT_DIR}"
echo "Build output logged to $BUILDLOG\n"

# Any Module set up could go here
# CouchDB will blow up with HTTP proxy set because it doesn't correctly interpret the return codes
#set +o nounset
#if [ ! -z "${http_proxy}" -o ! -z "${HTTP_PROXY}" ]; then
#    echo -e "CouchDB tests will fail with http_proxy set! Please unset and re-run.\n"
#    exit
#fi
#set -o nounset

read -p "Please enter the Lift version of the release: " RELEASE_VERSION

# Sanity check on the release version
if ! echo $RELEASE_VERSION | egrep -x '[0-9]+\.[0-9]+(-(M|RC)[0-9]+)?' > /dev/null; then
    confirm "$RELEASE_VERSION does not appear to be a valid version. Are you sure?" ||
      die "Canceling release build!"
fi

STAGING_DIR="$SCRIPT_DIR/staging"
MODULES=( `cat "$SCRIPT_DIR/modules.txt" `) 


echo "This is what's about to happen:"
echo "1. The following modules will be checked out to a staging directory:"
for m in "${MODULES[@]}"
do
    echo "   $m"
done
echo "2. A branch will be created for each module and configured for this release"
echo "3. Each module will be built"
echo "4. On success, the module will be published".
echo " "

confirm "Are you certain you want a release build?" || die "Canceling release build."

if [ -e $STAGING_DIR ]; then
    confirm "$STAGING_DIR exists. Happy to remove it?" || die "Canceling build"
    rm -rf $STAGING_DIR
fi

mkdir -v $STAGING_DIR
if [ $? -ne 0 ] ; then die "Failed to mkdir" ; fi


echo "-----------------------------------------------------------------"
echo "Starting PHASE 1: The clone of the modules, branch, modify build"
echo "-----------------------------------------------------------------"

for m in "${MODULES[@]}"
do
    projname "$m" || die "Odd git project name, cannot work out directory."
    
    echo "Cloning $m -> $PROJNAME"
    cd $STAGING_DIR
    git clone $m >> ${BUILDLOG}
    if [ $? -ne 0 ] ; then die "Failed to clone $m" ; fi

    cd $PROJNAME
    readModuleVersion || die "Failed to locate module version number: $REASON"
    echo "Version of $PROJNAME is $MODULE_VERSION"

    git checkout -b $RELEASE_VERSION-$MODULE_VERSION
    if [ $? -ne 0 ] ; then die "Failed to branch as $RELEASE_VERSION-$MODULE_VERSION" ; fi

    updateBuild $RELEASE_VERSION $MODULE_VERSION || die "Unable to update build.sbt because $REASON"

    git commit -v -a -m "Prepare for Lift ${RELEASE_VERSION} release" >> ${BUILDLOG} || die "Could not commit project version change!"

    git tag ${RELEASE_VERSION}-${MODULE_VERSION}-release >> ${BUILDLOG} || die "Could not tag release!"


    cd $SCRIPT_DIR
    echo " "
done


echo " "
echo "-----------------------------------------------------------------"
echo "Starting PHASE 2: Build and test"
echo "-----------------------------------------------------------------"

echo " "
echo "If you want to follow along, tail -f $BUILDLOG"
echo " "

echo "Phase 2" >> ${BUILDLOG}
java -version 2>> ${BUILDLOG}
echo $SBT_OPTS >> ${BUILDLOG}

for m in "${MODULES[@]}"
do
    projname "$m" || die "Odd git project name, cannot work out directory this time."
    
    cd $STAGING_DIR
    cd $PROJNAME
  
    echo "$PROJNAME: packaging and testing"

    set +o errexit
    java $SBT_OPTS -jar $SBT_JAR +package +test >> ${BUILDLOG}
    if [ $? -ne 0 ] ; then die "Build or test failure in $PROJNAME - see $BUILDLOG for details" ; fi
    set -o errexit

    cd $SCRIPT_DIR
done


echo " "
echo "-----------------------------------------------------------------"
echo "Starting PHASE 3: Publish and push"
echo "-----------------------------------------------------------------"

echo " "
echo "During this phase you will be asked to enter your PGP passphrase"
echo "i.e., watch this console and response to prompts."
echo " "


confirm "Modules all appear OK. Proceed to publish step?" || die "Canceling release build!"

for m in "${MODULES[@]}"
do
    projname "$m" || die "Worked twice, but now cannot work out directory."
    
    cd $STAGING_DIR
    cd $PROJNAME
  
    echo "$PROJNAME: publishing..."

    readModuleVersion || die "Failed to locate module version number: $REASON"

    java $SBT_OPTS -jar $SBT_JAR +publish 

    echo "cd $STAGING_DIR/$PROJNAME" >> $PUSH_SCRIPT
    echo "# Uncomment if you want to push the branch too:" >> $PUSH_SCRIPT
    echo "# git push origin $RELEASE_VERSION-$MODULE_VERSION" >> $PUSH_SCRIPT
    echo "git push --tags" >> $PUSH_SCRIPT

    cd $SCRIPT_DIR
done


echo "Release build complete `date`" >> ${BUILDLOG}

echo " "
echo "RELEASE BUILD COMPLETE."
echo "To push tags, see $PUSH_SCRIPT"


