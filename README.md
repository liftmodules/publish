Shell script for publishing all the modules listed in `modules-step-1.txt` (by default) to Sonatype.

Run: `sh unsafePublishModules.sh [file]` and follow the prompts.

Requires that you have:

* Commit rights to all the modules
* Publish permissions to `net.liftmodules` Sonatype repository
* The [SBT GPG plugin](https://github.com/sbt/xsbt-gpg-plugin) in your SBT global plugins.
* A valid PGP key registered with Sonatype.
* Your Sonatype login in `/private/liftmodules/sonatype.credentials`

For details, see [Releasing the modules](https://www.assembla.com/spaces/liftweb/wiki/Releasing_the_modules) on the Lift Wiki.

Version numbers
---------------

The file passed to `unsafePublishModules.sh` contains the location of the GIT project to build. E.g.,

    git@github.com:liftmodules/textile.git

It can optionally include a version number:

    git@github.com:liftmodules/textile.git,0.2

When a version number is supplied, that version number is used as the module version number, replacing anything in the module's `build.sbt`

If no version number is supplied, the version is taken from `build.sbt`.


Snapshot builds
---------------

When prompted for a Lift version, we normally enter a final, milestone or RC Lift version such as `2.5-RC4`.  However, you can also enter a snapshot version number such as `3.0-SNAPSHOT`. If you do this, the module version has -SNAPSHOT added to it and the module will be published to the Sonatype snapshot repository.


Lift series support
-------------------

This script support the 2.x and 3.x series of Lift.  The difference is in which Scala cross-build versions are force into a module build when the script runs.


