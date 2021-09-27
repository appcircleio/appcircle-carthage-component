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
