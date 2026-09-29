# Crawl Space

Repository: https://github.com/isomorphisms/crawlspace.git
Cat Food role: Android runtime bridge from ordinary Termux to the Android shell identity.

## Device delivery

Phone and tablet consume published binaries. Neither device compiles Crawl Space or installs a compiler for it.

The ARMv7 phone receives:

- `~/opt/bin/crawlspace`, pinned to an exact Crawl Space source commit and SHA-256;
- `~/opt/bin/crawlspace-bootstrap`, the Cat Food-owned post-reboot bootstrap helper;
- Termux `android-tools` only as the runtime facility that provides `adb` for the current one-time shell-daemon start.

The tablet receives the AArch64 client binary but Cat Food does not start an ADB bootstrap there while the tablet ADB boundary remains explicitly deferred.

## Phone use

Check the current daemon first:

```sh
crawlspace discover
```

A ready daemon reports `daemon_uid=2000`. Repeated commands then go directly through Crawl Space:

```sh
crawlspace run /system/bin/id
crawlspace run /system/bin/logcat -d
```

After a reboot, if discovery reports the daemon absent:

```sh
crawlspace-bootstrap
```

The helper uses an already-connected Wireless debugging session to start the daemon, verifies `uid=2000(shell)`, and exits. It does not build source on the phone.

Normal `./catfood` phone provisioning runs the helper in `--if-connected` mode. An unavailable ADB connection leaves the post-reboot start explicitly pending instead of compiling a fallback or failing unrelated runtime package delivery.
