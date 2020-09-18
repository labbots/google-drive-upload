# google-drive-upload contribution guidelines

> A typical contribution includes:
>
> > Code contributions for a new feature or a bug fix.
> > Issue creation for a bug found.

## Table of Contents

- [Creating an issue](#creating-an-issue)
  - [Bug Reports](#bug-reports)
  - [Feature Requests](#feature-requests)
- [Code Contributions](#code-contributions)
  - [Commit Guidelines](#commit-guidelines)
  - [Code Guidelines](#code-guidelines)
    - [Naming Conventions](#naming-conventions)
    - [Documentation](#documentation)
    - [Script Code](#script-code)
  - [Pull Request Guidelines](#pull-request-guidelines)
- [Contact](#contact)

## Creating an issue

There are several reasons to create a new issue, but make sure you search through open and closed issues before opening a new one. There's a good chance that whatever reason you might be opening an issue for might already have been opened or closed by another user.

So, if it's a new issue, then follow the below guidelines:

### Bug Reports

Steps to reproduce and/or sample code to recreate the problem.

Version that you are using, are you on latest ?

Your operating system.

And anything that will help in identifying the issue.

### Feature Requests

In order to help the developer understand the feature request, follow below guidelines:

Title of the issue should be explicit, giving insight into the content of the issue.

The area of the project where your feature would be applied or implemented should be properly stated. Add screenshots of mockup if possible.

It would be great if a detailed use case is included in your request.

**Finally, please be patient. The developer has a lot of things to do. But, be assured that the bug report will receive adequate attention, and will consequently be fixed.**

## Code Contributions

Great, the more, the merrier.

Sane code contributions are always welcome, whether to the code or documentation.

Before making a pull request, make sure to follow below guidelines:

### Commit Guidelines

It is recommended to use small commits over one large commit. Small, focused commits make the review process easier and are more likely to be accepted.

It is also important to summarise the changes made with brief commit messages. If the commit fixes a specific issue, it is also good to note that in the commit message.

The commit message should start with a single line that briefly describes the changes. That should be followed by a blank line and then a more detailed explanation.

As a good practice, use commands when writing the message (instead of "I added ..." or "Adding ...", use "Add ...").

Before committing check for unnecessary whitespace with `git diff --check`.

For further recommendations, see [Pro Git Commit Guidelines](https://git-scm.com/book/en/v2/Distributed-Git-Contributing-to-a-Project#Commit-Guidelines).

### Code Guidelines

#### Naming Conventions

##### Variables and Constants

- Variable names must be meaningful and self-documenting.
- Long variable names must be structured by underscores to improve legibility.
- Global variables and constants must be ALL CAPS with underscores. (eg., INPUT_FILE)
- local variables used within functions must be all lower case with underscores ( only if required ). (eg., post_data)
- Variable names can be alphanumeric with underscores. No special characters in variable names.
- Variables name must not start with number. 

Special instructions for posix scripts:

- All local variables should have function name at the end. This is because posix doesn't have local variable feature. It is not mandatory but should be followed to avoid conflicts.

##### Functions

- Each function must contain a introductory comment. The comment must contain function name, short description of the function and description of the arguments and list of global variables used and modified.

```shell
###################################################
# Create/Check directory in google drive.
# Globals: 2 variables, 3 functions
#   Variables - API_URL, API_VERSION
#   Functions - urlEncode, curlCmd, jsonValue
# Arguments: 3
#   ${1} = dir name
#   ${2} = root dir id of given dir
#   ${3} = Access Token
# Result: print folder id
# Reference:
#   https://developers.google.com/drive/api/v3/folder
###################################################
```
- Function names must be all lower case with underscores to seperate words (snake_case).
- Internal functions must start with underscore.

```shell
# internal function
_check_connection() {
  …
}
```

- For additing new standalone functions, use common-utils.sh and drive-utils.sh, maintain alphabetical order.
- For using a function in install.sh, add to it directly.

#### Documentation

- Refrain from making unnecessary newlines or whitespace.
- Use pure markdown as much as possible, html is accepted but shouldn't be a priority.
- If you are adding a new section, then make sure to update Table of Contents.
- Last but not the least, use proper intendation, if possible, use a markdown linter.

#### Script Code

-   Use [shfmt](https://github.com/mvdan/sh) to format the script. Use below command:

    Repo conatins a format.sh script to format all the files in cli environment.

    ```shell
    ./format.sh
    ```

    You can also install shfmt for various editors, refer their repo for information.

    Note: This is strictly necessary to maintain consistency, do not skip.

    Repo also contains a merge.sh script which basically merges the script to make a single standalone executable file, make sure to run that.

    ```shell
    ./merge.sh
    ```

-   Script should pass all [shellcheck](https://www.shellcheck.net/) warnings, if not, then disable the warning and give a valid reason.
-   Try using bash/sh builtins and string substitution as much as possible instead of external programs like sed, head, etc. This gives the script a performance boost. There are many functions that are present in the script as an alternative to various external programs, use them as much as possible.
-   Before adding a new logic, be sure to check the existing code.
-   If you are adding a code which will print something to the terminal, use `printCenter` function if possible.
-   Use printf everywhere instead of echo.
-   For printing newlines, use newLine function, instead of printf, to respect -q/--quiet flag.
-   Add a functions only if you are going to use it multiple times, otherwise use the code directly, exceptions can be made where it can make the script messier.
-   For more info, start from [tldp guide](https://www.tldp.org/LDP/Bash-Beginners-Guide/html/chap_01.html).

Additional rules to follow:

- Always use force write ( >| ), even in case of writing to /dev/null

### Pull Request Guidelines

The following guidelines will increase the likelihood that your pull request will get accepted:

- Follow the commit and code guidelines.
- Keep the patches on topic and focused.
- Try to avoid unnecessary formatting and clean-up where reasonable.

A pull request should contain the following:

- At least one commit (all of which should follow the Commit Guidelines).
- Title that summarises the issue/feature.
- Description that briefly summarises the changes.

After submitting a pull request, you should get a response within the next 7 days. If you do not, don't hesitate to ping the thread.

## Contact

For further inquiries, you can contact the developer by opening an issue on the repository.
