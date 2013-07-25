#upp

Uptime monitoring linked to a mailer.

All commands are run relative to the `scripts` directory. An err or stderr on child_process.exec of the command means the host/website is down. Additionally, a `success` regex can be provided for each handler that, failing to test for our `stdout`, fails as well.