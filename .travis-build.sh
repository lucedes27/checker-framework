#!/bin/bash

echo "Entering `pwd`/.travis-build.sh, GROUP=$1"

# Optional argument $1 is one of:
#   all, all-tests, jdk.jar, misc, checker-framework-inference, plume-lib, downstream
# It defaults to "all".
export GROUP=$1
if [[ "${GROUP}" == "" ]]; then
  export GROUP=all
fi

if [[ "${GROUP}" != "all" && "${GROUP}" != "all-tests" && "${GROUP}" != "jdk.jar" && "${GROUP}" != "checker-framework-inference" && "${GROUP}" != "downstream" && "${GROUP}" != "misc" && "${GROUP}" != "plume-lib" ]]; then
  echo "Bad argument '${GROUP}'; should be omitted or one of: all, all-tests, jdk.jar, checker-framework-inference, downstream, misc, plume-lib."
  exit 1
fi

# Optional argument $2 is one of:
#  downloadjdk, buildjdk
# If it is omitted, this script uses downloadjdk.
export BUILDJDK=$2
if [[ "${BUILDJDK}" == "" ]]; then
  export BUILDJDK=buildjdk
fi

if [[ "${BUILDJDK}" != "buildjdk" && "${BUILDJDK}" != "downloadjdk" ]]; then
  echo "Bad argument '${BUILDJDK}'; should be omitted or one of: downloadjdk, buildjdk."
  exit 1
fi

# Fail the whole script if any command fails
set -e

## Diagnostic output
# Output lines of this script as they are read.
set -o verbose
# Output expanded lines of this script as they are executed.
set -o xtrace

export SHELLOPTS

SLUGOWNER=${TRAVIS_PULL_REQUEST_SLUG%/*}
if [[ "$SLUGOWNER" == "" ]]; then
  SLUGOWNER=${TRAVIS_REPO_SLUG%/*}
fi
if [[ "$SLUGOWNER" == "" ]]; then
  SLUGOWNER=typetools
fi
echo SLUGOWNER=$SLUGOWNER

export CHECKERFRAMEWORK=`readlink -f ${CHECKERFRAMEWORK:-.}`
echo "CHECKERFRAMEWORK=$CHECKERFRAMEWORK"

source checker/bin-devel/build.sh ${BUILDJDK}
# The above command builds or downloads the JDK, so there is no need for a
# subsequent command to build it except to test building it.

set -e

echo "In checker-framework/.travis-build.sh GROUP=$GROUP"

### TESTS OF THIS REPOSITORY

if [[ "${GROUP}" == "all-tests" || "${GROUP}" == "all" ]]; then
  ./gradlew allTests --console=plain --warning-mode=all --no-daemon
  # Moved example-tests-nobuildjdk out of all tests because it fails in
  # the release script because the newest maven artifacts are not published yet.
  ./gradlew :checker:exampleTests --console=plain --warning-mode=all --no-daemon
fi

if [[ "${GROUP}" == "jdk.jar" || "${GROUP}" == "all" ]]; then
  ## Run the tests for the type systems that use the annotated JDK
  ./gradlew IndexTest LockTest NullnessFbcTest OptionalTest printJdkJarManifest -PuseLocalJdk --console=plain --warning-mode=all --no-daemon
fi

if [[ "${GROUP}" == "misc" || "${GROUP}" == "all" ]]; then
  ## jdkany tests: miscellaneous tests that shouldn't depend on JDK version.
  ## (Maybe they don't even need the full checker/bin-devel/build.sh ;
  ## for example they currently don't need the annotated JDK.)

  set -e

  # Code style and formatting
  ./gradlew checkBasicStyle checkFormat --console=plain --warning-mode=all --no-daemon

  # Run error-prone
  ./gradlew runErrorProne --console=plain --warning-mode=all --no-daemon

  # HTML legality
  ./gradlew htmlValidate --console=plain --warning-mode=all --no-daemon

  # Documentation
  ./gradlew javadocPrivate --console=plain --warning-mode=all --no-daemon
  make -C docs/manual all

  # This comes last, in case we wish to ignore it
  git -C /tmp/plume-scripts pull > /dev/null 2>&1 \
    || git -C /tmp clone --depth 1 -q https://github.com/plume-lib/plume-scripts.git
  source /tmp/plume-scripts/git-set-commit-range
  echo "COMMIT_RANGE = $COMMIT_RANGE"
  if [ -n "$COMMIT_RANGE" ] ; then
    (git diff $COMMIT_RANGE > /tmp/diff.txt 2>&1) || true
    (./gradlew requireJavadocPrivate --console=plain --warning-mode=all --no-daemon > /tmp/warnings.txt 2>&1) || true
    [ -s /tmp/diff.txt ] || (echo "/tmp/diff.txt is empty for COMMIT_RANGE=$COMMIT_RANGE; try pulling base branch (often master) into compare branch (often your feature branch)" && false)
    python /tmp/plume-scripts/lint-diff.py --guess-strip /tmp/diff.txt /tmp/warnings.txt
  fi

fi

### TESTS OF DOWNSTREAM REPOSITORIES

if [[ "${GROUP}" == "checker-framework-inference" || "${GROUP}" == "all" ]]; then
  ## checker-framework-inference is a downstream test, but run it in its
  ## own group because it is most likely to fail, and it's helpful to see
  ## that only it, not other downstream tests, failed.

  # checker-framework-inference: 18 minutes
  [ -d /tmp/plume-scripts ] || (cd /tmp && git clone --depth 1 -q https://github.com/plume-lib/plume-scripts.git)
  REPO=`/tmp/plume-scripts/git-find-fork ${SLUGOWNER} typetools checker-framework-inference`
  BRANCH=`/tmp/plume-scripts/git-find-branch ${REPO} ${TRAVIS_PULL_REQUEST_BRANCH:-$TRAVIS_BRANCH}`
  (cd .. && git clone -b ${BRANCH} -q --single-branch --depth 1 ${REPO}) || (cd .. && git clone -b ${BRANCH} --single-branch --depth 1 -q ${REPO})

  export AFU=`readlink -f ${AFU:-../annotation-tools/annotation-file-utilities}`
  export PATH=$AFU/scripts:$PATH
  (cd ../checker-framework-inference && ./gradlew dist test --console=plain --warning-mode=all --no-daemon)

fi

if [[ "${GROUP}" == "plume-lib" || "${GROUP}" == "all" ]]; then
  # plume-lib-typecheck: 15 minutes
  [ -d /tmp/plume-scripts ] || (cd /tmp && git clone --depth 1 -q https://github.com/plume-lib/plume-scripts.git)
  REPO=`/tmp/plume-scripts/git-find-fork ${SLUGOWNER} typetests plume-lib-typecheck`
  BRANCH=`/tmp/plume-scripts/git-find-branch ${REPO} ${TRAVIS_PULL_REQUEST_BRANCH:-$TRAVIS_BRANCH}`
  (cd .. && git clone -b ${BRANCH} --single-branch --depth 1 -q ${REPO}) || (cd .. && git clone -b ${BRANCH} --single-branch --depth 1 -q ${REPO})

  (cd ../plume-lib-typecheck && ./.travis-build.sh)
fi

if [[ "${GROUP}" == "downstream" || "${GROUP}" == "all" ]]; then
  ## downstream tests:  projects that depend on the Checker Framework.
  ## These are here so they can be run by pull requests.  (Pull requests
  ## currently don't trigger downstream jobs.)
  ## Not done in the Travis build, but triggered as a separate Travis project:
  ##  * daikon-typecheck: (takes 2 hours)

  echo "TRAVIS_PULL_REQUEST_BRANCH=$TRAVIS_PULL_REQUEST_BRANCH"
  echo "TRAVIS_BRANCH=$TRAVIS_BRANCH"

  # Checker Framework demos
  [ -d /tmp/plume-scripts ] || (cd /tmp && git clone --depth 1 -q https://github.com/plume-lib/plume-scripts.git)
  REPO=`/tmp/plume-scripts/git-find-fork ${SLUGOWNER} typetools checker-framework.demos`
  BRANCH=`/tmp/plume-scripts/git-find-branch ${REPO} ${TRAVIS_PULL_REQUEST_BRANCH:-$TRAVIS_BRANCH}`
  (cd .. && git clone -b ${BRANCH} --single-branch --depth 1 -q ${REPO} checker-framework-demos) || (cd .. && git clone -b ${BRANCH} --single-branch --depth 1 -q ${REPO} checker-framework-demos)
  ./gradlew :checker:demosTests --console=plain --warning-mode=all --no-daemon

  # Guava
  REPO=`/tmp/plume-scripts/git-find-fork ${SLUGOWNER} typetools guava`
  BRANCH=`/tmp/plume-scripts/git-find-branch ${REPO} ${TRAVIS_PULL_REQUEST_BRANCH:-$TRAVIS_BRANCH} cf-master`
  if [ $BRANCH = "master" ] ; then
    # ${SLUGOWNER} has a fork of Guava, but no branch that corresponds to the pull-requested branch.
    # Use upstream instead.
    REPO=https://github.com/typetools/guava.git
    BRANCH=`/tmp/plume-scripts/git-find-branch ${REPO} ${TRAVIS_PULL_REQUEST_BRANCH:-$TRAVIS_BRANCH} cf-master`
    if [ $BRANCH = "master" ] ; then
      BRANCH=`/tmp/plume-scripts/git-find-branch ${REPO} cf-master master`
    fi
  fi
  (cd .. && git clone -b ${BRANCH} --single-branch --depth 1 -q ${REPO} guava) || (cd .. && git clone -b ${BRANCH} --single-branch --depth 1 -q ${REPO} guava)
  export CHECKERFRAMEWORK=${CHECKERFRAMEWORK:-$ROOT/checker-framework}
  (cd $ROOT/guava/guava && mvn compile -P checkerframework-local -Dcheckerframework.checkers=org.checkerframework.checker.nullness.NullnessChecker)

fi

echo "Exiting `pwd`/.travis-build.sh, GROUP=$1"
