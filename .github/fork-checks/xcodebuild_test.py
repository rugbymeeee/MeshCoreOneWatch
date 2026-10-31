"""Runs the app test suite on the fork's CI and reports through annotations, because job logs
need a signed-in viewer while annotations are public. FORK ONLY, like fork-checks.yml.

Posts the counts every 20 minutes, warns when the tests stop producing events, interrupts the
run at a deadline and names the tests still running, then ends with a summary: counts,
failures, and the slowest suites and tests.

Usage: python3 -u xcodebuild_test.py <deadline minutes> <log> <xcresult> -- <command...>
"""

import collections
import json
import os
import re
import signal
import subprocess
import sys
import threading
import time

PROGRESS_INTERVAL = 20 * 60
STALL_AFTER = 8 * 60
MAX_STALL_WARNINGS = 3
MAX_MESSAGE = 6000

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
TEST_ISSUE = re.compile(r"^✘ Test (.+?) recorded an issue")
TEST_STARTED = re.compile(r"^◇ Test (.+?) started\.$")
TEST_FINISHED = re.compile(r"^[✔✘] Test (.+?) (passed|failed) after ([\d.]+) seconds")
TEST_SKIPPED = re.compile(r"^➜ Test (.+?) skipped")
SUITE_STARTED = re.compile(r"^◇ Suite (.+?) started\.$")
SUITE_FINISHED = re.compile(r"^[✔✘] Suite (.+?) (?:passed|failed) after ([\d.]+) seconds")
RUN_STARTED = re.compile(r"^◇ Test run started\.")
RUN_FINISHED = re.compile(r"^[✔✘] Test run with ")
XCODE_CASE = re.compile(r"^Test [Cc]ase '(.+?)' (passed|failed|skipped) on '.*?' \(([\d.]+) seconds\)")
# Any other line that looks like a test result: counted, sampled, and keeps the stall timer quiet.
OTHER_TEST_EVENT = re.compile(r"\b[Tt]est\b.*\b(started|passed|failed|skipped)\b")
TROUBLE = re.compile(r"crash|Restarting after|encountered an error|unexpected exit|hung|timed out|\*\* TEST", re.IGNORECASE)

output_lock = threading.Lock()


def write(data):
    with output_lock:
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()


def annotate(level, title, lines):
    message = "\n".join(lines)
    if len(message) > MAX_MESSAGE:
        message = message[:MAX_MESSAGE] + "\n…"
    message = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    title = title.replace("%", "%25").replace(":", "%3A").replace(",", "%2C")
    write(f"::{level} title={title}::{message}\n".encode("utf-8", "replace"))


def minutes(seconds):
    return f"{seconds / 60:.1f} min"


class Progress:
    """What the test output has shown so far. Guarded by `lock`."""

    def __init__(self, started):
        self.lock = threading.Lock()
        self.started = started
        self.running = {}
        self.open_suites = {}
        self.counts = collections.Counter()
        self.failures = []
        self.issues = collections.defaultdict(list)
        self.tests = []
        self.suites = []
        self.xcode_counts = collections.Counter()
        self.xcode_failures = []
        self.xcode_tests = []
        self.run_line = None
        self.other_events = 0
        self.other_samples = []
        self.trouble = []
        self.first_event = None
        self.last_event = None

    def handle(self, line, now):
        if not self.record(line, now):
            if TROUBLE.search(line) and len(self.trouble) < 30:
                self.trouble.append(line[:300])
            return
        if self.first_event is None:
            self.first_event = now
        self.last_event = now

    def record(self, line, now):
        """Updates the counts from a test event line; returns False for any other line."""
        if RUN_STARTED.match(line):
            return True
        if RUN_FINISHED.match(line):
            self.run_line = line
        elif match := TEST_ISSUE.match(line):
            self.issues[match.group(1)].append(line)
        elif match := TEST_STARTED.match(line):
            self.running[match.group(1)] = now
        elif match := TEST_FINISHED.match(line):
            name, result = match.group(1), match.group(2)
            self.running.pop(name, None)
            self.counts[result] += 1
            self.tests.append((float(match.group(3)), name))
            if result == "failed":
                self.failures.append(name)
        elif match := TEST_SKIPPED.match(line):
            self.running.pop(match.group(1), None)
            self.counts["skipped"] += 1
        elif match := SUITE_STARTED.match(line):
            self.open_suites[match.group(1)] = now
        elif match := SUITE_FINISHED.match(line):
            self.open_suites.pop(match.group(1), None)
            self.suites.append((float(match.group(2)), match.group(1)))
        elif match := XCODE_CASE.match(line):
            name, result = match.group(1), match.group(2)
            self.xcode_counts[result] += 1
            self.xcode_tests.append((float(match.group(3)), name))
            if result == "failed":
                self.xcode_failures.append(name)
        elif OTHER_TEST_EVENT.search(line):
            self.other_events += 1
            if len(self.other_samples) < 6:
                self.other_samples.append(line[:200])
        else:
            return False
        return True

    def counts_line(self):
        line = "Swift Testing: " + ", ".join(f"{self.counts[key]} {key}" for key in ("passed", "failed", "skipped"))
        if self.xcode_counts:
            line += " | xcodebuild: " + ", ".join(f"{count} {key}" for key, count in sorted(self.xcode_counts.items()))
        if self.other_events:
            line += f" | {self.other_events} other test lines"
        return line

    def status(self, now):
        lines = [self.counts_line()]
        lines += [f"suite open for {minutes(now - since)}: {name}" for name, since in list(self.open_suites.items())[-3:]]
        lines += [f"test running for {minutes(now - since)}: {name}" for name, since in list(self.running.items())[:15]]
        return lines


def stop(process):
    """Interrupts first, so xcodebuild can still write the result bundle."""
    for sig, grace in ((signal.SIGINT, 90), (signal.SIGTERM, 30), (signal.SIGKILL, 10)):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=grace)
            return
        except subprocess.TimeoutExpired:
            pass


def read_summary(path):
    if not os.path.isdir(path):
        return None
    try:
        result = subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", path],
            capture_output=True, text=True, timeout=300,
        )
        return json.loads(result.stdout) if result.returncode == 0 else None
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def report(progress, code, timed_out, result_path, tail):
    elapsed = time.monotonic() - progress.started
    summary = read_summary(result_path)

    lines = [f"{progress.counts_line()} in {minutes(elapsed)}"]
    if progress.run_line:
        lines.append(progress.run_line)
    if summary:
        keys = ("result", "totalTestCount", "passedTests", "failedTests", "skippedTests", "expectedFailures")
        lines.append("xcresult: " + ", ".join(f"{key}={summary[key]}" for key in keys if key in summary))
    if progress.first_event is None:
        lines.append("no test events seen")
    else:
        lines.append(f"first test event after {minutes(progress.first_event - progress.started)}")
    if progress.other_samples:
        lines += ["other test lines, for example:"] + progress.other_samples
    lines += progress.trouble[:15]
    if timed_out:
        title = "App tests stopped at the deadline"
    elif code == 0:
        title = "App tests passed"
    else:
        title = f"App tests failed with exit code {code}"
    annotate("notice" if code == 0 and not timed_out else "error", title, lines)

    tests = progress.tests or progress.xcode_tests
    slowest = ["slowest suites:"] + [f"{seconds:8.1f} s  {name}" for seconds, name in sorted(progress.suites, reverse=True)[:12]]
    slowest += ["slowest tests:"] + [f"{seconds:8.1f} s  {name}" for seconds, name in sorted(tests, reverse=True)[:15]]
    annotate("notice", "Slowest suites and tests", slowest)

    failures = []
    if summary and summary.get("testFailures"):
        for failure in summary["testFailures"][:40]:
            name = failure.get("testIdentifierString") or failure.get("testName", "?")
            failures.append(f"{name}: {failure.get('failureText', '')[:300]}")
    else:
        for name in (progress.failures or progress.xcode_failures)[:40]:
            issues = progress.issues.get(name)
            failures.append(f"{name}: {issues[0][:300]}" if issues else name)
    if failures:
        annotate("error", f"Failed tests ({len(failures)} listed)", failures)
    elif code != 0 and not timed_out:
        annotate("error", "Log tail", list(tail))


def main():
    deadline_minutes = float(sys.argv[1])
    log_path, result_path = sys.argv[2], sys.argv[3]
    command = sys.argv[sys.argv.index("--") + 1:]

    started = time.monotonic()
    progress = Progress(started)
    tail = collections.deque(maxlen=40)
    process = subprocess.Popen(
        command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True
    )

    def pump():
        with open(log_path, "wb") as log:
            for raw in process.stdout:
                write(raw)
                log.write(raw)
                line = ANSI.sub("", raw.decode("utf-8", "replace")).rstrip("\r\n")
                with progress.lock:
                    tail.append(line)
                    progress.handle(line, time.monotonic())

    reader = threading.Thread(target=pump, daemon=True)
    reader.start()

    deadline = started + deadline_minutes * 60
    next_progress = started + PROGRESS_INTERVAL
    stall_warnings = 0
    reported_quiet_since = None
    timed_out = False
    while process.poll() is None:
        time.sleep(10)
        now = time.monotonic()
        pending = []
        with progress.lock:
            if now >= next_progress:
                pending.append(("notice", f"Tests after {minutes(now - started)}", progress.status(now)))
                next_progress += PROGRESS_INTERVAL
            quiet_since = progress.last_event or started
            if (
                now - quiet_since >= STALL_AFTER
                and quiet_since != reported_quiet_since
                and stall_warnings < MAX_STALL_WARNINGS
            ):
                lines = progress.status(now) + ["log tail:"] + list(tail)[-12:]
                pending.append(("warning", f"No test events for {minutes(now - quiet_since)}", lines))
                reported_quiet_since = quiet_since
                stall_warnings += 1
            if now >= deadline:
                timed_out = True
                lines = progress.status(now) + ["log tail:"] + list(tail)[-12:]
                pending.append(("error", f"Stopped at the {deadline_minutes:g} minute deadline", lines))
        for level, title, lines in pending:
            annotate(level, title, lines)
        if timed_out:
            stop(process)
            break
    process.wait()
    reader.join(timeout=60)
    with progress.lock:
        report(progress, process.returncode, timed_out, result_path, tail)
    sys.exit(1 if timed_out else process.returncode)


if __name__ == "__main__":
    main()
