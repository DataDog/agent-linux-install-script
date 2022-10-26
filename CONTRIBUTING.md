# Contributing

The code is licensed under the Apache License 2.0 (see LICENSE for details).

First of all, thanks for contributing!

This document provides some basic guidelines for contributing to this repository. To propose improvements, feel free to submit a PR.

## Submitting issues

* If you think you've found an issue, search the issue list to see if there's an existing issue.
* Then, if you find nothing, open a Github issue.

## Pull Requests

Have you fixed a bug or written a new feature and want to share it? Many thanks!

In order to ease/speed up our review, here are some items you can check/improve when submitting your PR:

  * Have a proper commit history (we advise you to rebase if needed).
  * Write tests for the code you wrote.
  * Tests can be run using Docker as explained [here][running-tests].
  * Preferably, make sure that the included tests run.
  * Summarize your PR with an explanatory title and a message describing your changes, cross-referencing any related bugs/PRs.
  * Open your PR against the `main` branch.

Your pull request must pass all CI tests before we merge it. If you see an error and don't think it's your fault, it may not be! [Join us on Slack][slack] or send us an email, and together we'll get it sorted out.

### Keep it small, focused

Avoid changing too many things at once. For instance if you're fixing a recipe and at the same time adding some code refactor, it makes reviewing harder and the _time-to-release_ longer.

### Commit messages

Please don't be this person: `git commit -m "Fixed stuff"`. Take a moment to write meaningful commit messages.

The commit message should describe the reason for the change and give extra details that will allow someone later on to understand in 5 seconds the thing you've been working on for a day.

If your commit is only shipping documentation changes or example files, and is a complete no-op for the test suite, add **[skip ci]** in the commit message body to skip the build and give that slot to someone else who does need it.

### Squash your commits

Rebase your changes on `main` and squash your commits whenever possible. This keeps history cleaner and easier to revert things. It also makes developers happier!

## Development

To contribute, follow the contributing guidelines above.


[slack]: https://datadoghq.slack.com
[running-tests]: https://github.com/DataDog/agent-linux-install-script#running-tests
