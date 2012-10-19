Shell script for publishing all the modules listed in `modules-step-1.txt` (by default) to Sonatype.

`modules-step-2.txt` contains modules that depend on the publication of modules in step 1.

Requires that you have:

* Commit rights to all the modules
* Publish permissions to `net.liftmodules` Sonatype repository
* The [SBT GPG plugin](https://github.com/sbt/xsbt-gpg-plugin) in your SBT global plugins.
* A valid PGP key registered with Sonatype.
* Your Sonatype login in `/private/liftmodules/sonatype.credentials`

For details, see [Releasing the modules](https://www.assembla.com/spaces/liftweb/wiki/Releasing_the_modules) on the Lift Wiki.
