# Appcircle Carthage

[Carthage](https://github.com/Carthage/Carthage) is a dependency manager for Swift and Objective-C applications. [Carthage](https://github.com/Carthage/Carthage) handles the installation of external libraries your application depends on during a build.

[Carthage](https://github.com/Carthage/Carthage) is widely used among iOS developers for dependency management and it's very easy to include it in your iOS projects with Appcircle.

## Adding Carthage to your repository
Appcircle will look for a [`Cartfile`](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md) file in your repository and use it to install the dependencies.

Required Input Variables
- `$AC_CARTHAGE_COMMAND`: Specifies the carthage command to run. Defaults to `bootstrap`. \
**Possible values:** bootstrap, update

Optional Input Variables
- `$AC_REPOSITORY_DIR`: Specifies the cloned repository directory.
- `$AC_CARTFILE_PATH`: Specifies the path Cartfile resides. Defaults to the repository directory. **DO NOT** include Cartfile, this is only the path. **This value will be appended** to the `AC_REPOSITORY_DIR`\
**Example:** "./" or "./subpath-to-cartfile/"\

- `$AC_CARTHAGE_FLAGS`: Specifies additional flags after carthage command. Default value is empty.\
 **For Xcode 12 and above, make sure to include** `--use-xcframeworks` **here**. To shorten the build time, make sure to specify the platform: `--platform iOS`. Example usage: `--platform iOS --use-xcframeworks`

## Carthage installation

The step uses the `carthage` found on `PATH` (Appcircle macOS runner images include it). Only if it is missing does the step run `brew install carthage`, which needs access to Homebrew.

## Air-gapped networks

Carthage has no registry: `carthage bootstrap` clones every dependency with git, so an artifact proxy cannot serve them. To run without internet access:

- **Dependencies from an internal git server:** mirror the dependency repositories to your git server and either point the Cartfile at them (`git "https://git.example.com/mirrors/Alamofire.git" ~> 5.0`) or keep `github "Alamofire/Alamofire"` entries and redirect them with a git `insteadOf` rule in a step before this one, for example `git config --global url."https://git.example.com/mirrors/".insteadOf "https://github.com/"`.
- **`--no-use-binaries`:** for `github` entries Carthage asks the GitHub API (`api.github.com`) for prebuilt binaries. Without access, each `github` dependency waits for the request to time out (about 60 seconds) and is then built from source. Add `--no-use-binaries` to `$AC_CARTHAGE_FLAGS` to skip that lookup. `git` entries do not use the GitHub API.
- **`binary` entries:** the JSON specification and the archives it lists must be reachable from the runner, for example through a raw repository in your artifact proxy.
