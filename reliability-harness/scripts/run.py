#!/usr/bin/env python3
import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
import math
import os
import plistlib
import re
import secrets
import signal
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "reliability-harness"
STATE = HARNESS / ".state"
PROCESS_STATE = STATE / "processes"
NODE20_BIN = Path(os.environ.get("NODE20_BIN", "/opt/homebrew/opt/node@20/bin"))
NODE = NODE20_BIN / "node"
MONGOD = Path(os.environ.get("MONGOD_BIN", "/opt/homebrew/opt/mongodb-community/bin/mongod"))
APP_BUNDLE_ID = "de.my-wan.dhe.nightguard"
TEST_NAME = "nightguardUITests/AlarmReliabilityUITests/testAlarmSession"
TOKEN_ASSIGNMENT = re.compile(r"(?i)(token=)[^&\s\"'<>]+")
XCODE_TEST_LAUNCH_LOCK = threading.Lock()
MIN_DEVELOPER_FREE_SPACE_BYTES = 20 * 1024 ** 3
CHILD_PROCESS_GROUPS = {}
CHILD_PROCESS_GROUPS_LOCK = threading.RLock()
RUN_INTERRUPTED = False
CLEANUP_STARTED = False
INTERRUPT_SIGNALS = []


def reserve_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def ensure_port_free(port):
    with socket.socket() as listener:
        try:
            listener.bind(("127.0.0.1", port))
        except OSError as error:
            raise RuntimeError(f"Port {port} is already in use") from error


def node_environment(extra=None):
    environment = os.environ.copy()
    environment["PATH"] = f"{NODE20_BIN}:{environment.get('PATH', '')}"
    if extra:
        environment.update(extra)
    return environment


def require_simulator_disk_space():
    developer_dir = Path.home() / "Library" / "Developer"
    volume_path = developer_dir
    while not volume_path.exists():
        volume_path = volume_path.parent
    free_bytes = shutil.disk_usage(volume_path).free
    if free_bytes < MIN_DEVELOPER_FREE_SPACE_BYTES:
        free_gib = free_bytes / (1024 ** 3)
        raise RuntimeError(
            f"Insufficient free space on the volume containing {developer_dir}: "
            f"{free_gib:.1f} GiB free; at least 20 GiB is required before "
            "simulator startup."
        )


def jwt_key_signature(nightscout):
    key_file = nightscout / "node_modules/.cache/_ns_cache/randomString"
    try:
        stat = key_file.stat()
    except OSError as error:
        raise RuntimeError(f"Nightscout JWT signing key is missing: {key_file}") from error
    if not key_file.read_text(encoding="utf-8").strip():
        raise RuntimeError(f"Nightscout JWT signing key is empty: {key_file}")
    return (stat.st_ino, stat.st_mtime_ns, stat.st_size)


def command_output(command, cwd=None, env=None, timeout=30):
    return subprocess.run(
        [str(item) for item in command],
        cwd=cwd,
        env=env,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
    ).stdout


def register_child_process_group(process):
    with CHILD_PROCESS_GROUPS_LOCK:
        CHILD_PROCESS_GROUPS[process.pid] = process


def unregister_child_process_group(process):
    with CHILD_PROCESS_GROUPS_LOCK:
        CHILD_PROCESS_GROUPS.pop(process.pid, None)


def signal_child_process_groups(signum):
    with CHILD_PROCESS_GROUPS_LOCK:
        process_ids = list(CHILD_PROCESS_GROUPS)
    for process_id in process_ids:
        try:
            os.killpg(process_id, signum)
        except ProcessLookupError:
            pass


def terminate_child_process_groups(timeout=8):
    with CHILD_PROCESS_GROUPS_LOCK:
        processes = list(CHILD_PROCESS_GROUPS.values())
    errors = []
    for process in reversed(processes):
        try:
            terminate_process(process, timeout=timeout)
        except Exception as error:
            errors.append(f"terminate process group {process.pid}: {error}")
    return errors


def run_logged(command, logfile, cwd=None, env=None, timeout=None):
    logfile = Path(logfile)
    logfile.parent.mkdir(parents=True, exist_ok=True)
    with logfile.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(
            [str(item) for item in command],
            cwd=cwd,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=output,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        register_child_process_group(process)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            terminate_process(process)
            raise
        except BaseException:
            terminate_process(process)
            raise
        finally:
            unregister_child_process_group(process)


def load_average_1m():
    try:
        return os.getloadavg()[0]
    except (AttributeError, OSError):
        return float("inf")


def wait_for_load_below(threshold, timeout_seconds):
    started = time.monotonic()
    while True:
        load_average = load_average_1m()
        elapsed = time.monotonic() - started
        if load_average < threshold:
            return {
                "waitMs": int(elapsed * 1000),
                "loadAverage1m": round(load_average, 2),
                "timedOut": False,
            }
        remaining = timeout_seconds - elapsed
        if remaining <= 0:
            return {
                "waitMs": int(elapsed * 1000),
                "loadAverage1m": round(load_average, 2),
                "timedOut": True,
            }
        time.sleep(min(5, remaining))


def run_logged_with_load_gate(command, logfile, cwd, env, timeout, logical_cpus):
    logfile = Path(logfile)
    logfile.parent.mkdir(parents=True, exist_ok=True)
    with logfile.open("w", encoding="utf-8") as output:
        with XCODE_TEST_LAUNCH_LOCK:
            gate = wait_for_load_below(3 * logical_cpus, 120)
            if gate["timedOut"]:
                raise RuntimeError(
                    "1-minute load average remained above "
                    f"{3 * logical_cpus} for 120 seconds"
                )
            output.write(
                f"Load gate passed after {gate['waitMs']} ms "
                f"at 1-minute load {gate['loadAverage1m']}\n"
            )
            process = subprocess.Popen(
                [str(item) for item in command],
                cwd=cwd,
                env=env,
                stdout=output,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            register_child_process_group(process)
        try:
            return process.wait(timeout=timeout), gate
        except subprocess.TimeoutExpired:
            terminate_process(process)
            raise
        except BaseException:
            terminate_process(process)
            raise
        finally:
            unregister_child_process_group(process)


def tail(path, lines=60):
    try:
        return "\n".join(Path(path).read_text(encoding="utf-8", errors="replace").splitlines()[-lines:])
    except OSError:
        return ""


def redact_result_artifacts(run_dir):
    for artifact in Path(run_dir).rglob("*"):
        if not artifact.is_file():
            continue
        try:
            contents = artifact.read_bytes().decode("utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        redacted = TOKEN_ASSIGNMENT.sub(r"\1[REDACTED]", contents)
        if redacted != contents:
            artifact.write_text(redacted, encoding="utf-8")


def require_tools():
    missing = [
        str(path)
        for path in (NODE, NODE20_BIN / "npm", MONGOD)
        if not path.exists()
    ]
    for executable in ("git", "xcodebuild", "xcrun", "python3"):
        if shutil.which(executable) is None:
            missing.append(executable)
    if missing:
        raise RuntimeError("Required tools are missing: " + ", ".join(missing))
    major = command_output([NODE, "-p", "process.versions.node.split('.')[0]"]).strip()
    if major != "20":
        raise RuntimeError(f"Nightscout requires Node 20; found {command_output([NODE, '--version']).strip()}")


def ensure_nightscout(log_dir):
    nightscout = STATE / "cgm-remote-monitor"
    tag = "v15.0.9"
    pinned_commit = command_output(
        ["git", "-C", nightscout, "rev-parse", f"refs/tags/{tag}^{{commit}}"]
    ).strip()
    current_commit = command_output(
        ["git", "-C", nightscout, "rev-parse", "HEAD"]
    ).strip()
    if current_commit != pinned_commit:
        raise RuntimeError(
            f"Expected cgm-remote-monitor at {tag} ({pinned_commit}), "
            f"found commit {current_commit}"
        )
    key_file = nightscout / "node_modules/.cache/_ns_cache/randomString"
    if not (nightscout / "node_modules").is_dir() or not key_file.is_file():
        npm_log = log_dir / "npm-ci.log"
        returncode = run_logged(
            [NODE20_BIN / "npm", "ci"],
            npm_log,
            cwd=nightscout,
            env=node_environment(),
            timeout=900,
        )
        if returncode:
            raise RuntimeError(f"npm ci failed; see {npm_log}\n{tail(npm_log)}")
    if not key_file.is_file() or not key_file.read_text(encoding="utf-8").strip():
        raise RuntimeError(f"Nightscout JWT signing key is missing: {key_file}")
    return nightscout


def wait_for_tcp(port, process, logfile, seconds=90):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Service stopped unexpectedly; see {logfile}\n{tail(logfile)}")
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.5):
                return
        except OSError:
            time.sleep(0.5)
    raise RuntimeError(f"Service did not listen on port {port}; see {logfile}\n{tail(logfile)}")


def http_json(port, route, timeout=2):
    request = urllib.request.Request(f"http://127.0.0.1:{port}{route}")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = response.read()
            return response.status, json.loads(payload) if payload else None
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8", errors="replace")


def wait_for_nightscout(port, process, logfile):
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Nightscout stopped on port {port}; see {logfile}\n{tail(logfile)}")
        try:
            status, _ = http_json(port, "/api/v3/version")
            if 200 <= status < 300:
                return
        except (OSError, ValueError, TimeoutError):
            pass
        time.sleep(1)
    raise RuntimeError(f"Nightscout did not become ready on port {port}; see {logfile}\n{tail(logfile)}")


def spawn_service(command, logfile, cwd=None, env=None, stdout=subprocess.DEVNULL):
    logfile = Path(logfile)
    logfile.parent.mkdir(parents=True, exist_ok=True)
    log_handle = logfile.open("ab")
    process = subprocess.Popen(
        [str(item) for item in command],
        cwd=cwd,
        env=env,
        stdin=subprocess.DEVNULL,
        stdout=log_handle if stdout == subprocess.DEVNULL else stdout,
        stderr=log_handle,
        start_new_session=True,
    )
    process._harness_log_handle = log_handle
    register_child_process_group(process)
    return process


def track_service(process, port, command, cwd):
    PROCESS_STATE.mkdir(parents=True, exist_ok=True)
    manifest = PROCESS_STATE / f"{port}.json"
    manifest.write_text(
        json.dumps({
            "pid": process.pid,
            "port": port,
            "command": [str(item) for item in command],
            "cwd": str(Path(cwd).resolve()) if cwd else str(ROOT),
        }) + "\n",
        encoding="utf-8",
    )
    process._harness_pid_manifest = manifest


def terminate_stale_services():
    if not PROCESS_STATE.exists():
        return
    for manifest in PROCESS_STATE.glob("*.json"):
        try:
            details = json.loads(manifest.read_text(encoding="utf-8"))
            pid = int(details["pid"])
            port = int(details["port"])
        except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
            raise RuntimeError(
                f"Invalid tracked service manifest {manifest}; refusing to start services"
            ) from error
        actual_command = subprocess.run(
            ["ps", "-p", str(pid), "-o", "command="],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        ).stdout
        if not actual_command:
            manifest.unlink(missing_ok=True)
            continue
        actual_files = subprocess.run(
            ["lsof", "-p", str(pid)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        ).stdout
        expected_command = details.get("command")
        expected_cwd = details.get("cwd")
        if (
            not isinstance(expected_command, list)
            or not isinstance(expected_cwd, str)
            or not all(str(item) in actual_command for item in expected_command)
            or expected_cwd not in actual_files
        ):
            raise RuntimeError(
                f"Tracked harness PID {pid} no longer matches port {port}; "
                "refusing to start services"
            )
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            manifest.unlink(missing_ok=True)
            continue
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.2)
        else:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        manifest.unlink(missing_ok=True)


def terminate_process(process, timeout=8):
    if process is None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    if process.poll() is None:
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    if process.poll() is None:
        process.wait(timeout=timeout)
    unregister_child_process_group(process)
    handle = getattr(process, "_harness_log_handle", None)
    if handle and not handle.closed:
        handle.close()
    if process.stdout and not process.stdout.closed:
        process.stdout.close()
    manifest = getattr(process, "_harness_pid_manifest", None)
    if manifest:
        Path(manifest).unlink(missing_ok=True)


def start_mongo(log_dir, processes):
    mongo_dir = STATE / "mongo"
    mongo_dir.mkdir(parents=True, exist_ok=True)
    port = 27017
    with socket.socket() as existing:
        if existing.connect_ex(("127.0.0.1", port)) == 0:
            raise RuntimeError("Port 27017 is already in use; refusing to reuse an existing MongoDB")
    log_path = log_dir / "mongod.log"
    process = spawn_service(
        [
            MONGOD,
            "--dbpath",
            mongo_dir,
            "--bind_ip",
            "127.0.0.1",
            "--port",
            port,
            "--quiet",
        ],
        log_path,
        cwd=ROOT,
    )
    track_service(
        process,
        port,
        [MONGOD, "--dbpath", mongo_dir, "--bind_ip", "127.0.0.1", "--port", port],
        ROOT,
    )
    processes.append(process)
    wait_for_tcp(port, process, log_path, seconds=90)
    return process, port


def start_nightscout(nightscout, slot_count, mongo_port, api_secret, run_dir, processes):
    services = []
    service_details = {}
    slots = {}
    key_signature = jwt_key_signature(nightscout)
    for slot in range(1, slot_count + 1):
        ports = {"A": reserve_port(), "B": reserve_port()}
        slots[str(slot)] = {}
        for replica_name, port in ports.items():
            ensure_port_free(port)
            if jwt_key_signature(nightscout) != key_signature:
                raise RuntimeError("Nightscout JWT signing key changed while starting replicas")
            env = node_environment({
                "PORT": str(port),
                "MONGODB_URI": f"mongodb://127.0.0.1:{mongo_port}/ns_slot_{slot}",
                "API_SECRET": api_secret,
                "AUTH_DEFAULT_ROLES": "denied",
                "DISPLAY_UNITS": "mg/dl",
                "ENABLE": "careportal",
                "INSECURE_USE_HTTP": "true",
                "NODE_ENV": "production",
            })
            logfile = run_dir / "services" / f"nightscout-slot-{slot}-{replica_name}.log"
            process = spawn_service(
                [NODE, "lib/server/server.js"],
                logfile,
                cwd=nightscout,
                env=env,
            )
            track_service(process, port, [NODE, "lib/server/server.js"], nightscout)
            services.append(process)
            processes.append(process)
            wait_for_nightscout(port, process, logfile)
            if jwt_key_signature(nightscout) != key_signature:
                raise RuntimeError("Nightscout JWT signing key changed while starting replicas")
            slots[str(slot)][replica_name] = {"port": port}
            service_details[(slot, replica_name)] = {
                "port": port,
                "logfile": logfile,
                "process": process,
                "env": env,
                "keySignature": key_signature,
            }
    return services, slots, service_details


def restart_secondary_replica(slot, nightscout, service_details, processes):
    details = service_details[(int(slot), "B")]
    if jwt_key_signature(nightscout) != details["keySignature"]:
        raise RuntimeError("Nightscout JWT signing key changed before replica restart")
    terminate_process(details["process"])
    process = spawn_service(
        [NODE, "lib/server/server.js"],
        details["logfile"],
        cwd=nightscout,
        env=details["env"],
    )
    track_service(
        process,
        details["port"],
        [NODE, "lib/server/server.js"],
        nightscout,
    )
    processes.append(process)
    wait_for_nightscout(details["port"], process, details["logfile"])
    if jwt_key_signature(nightscout) != details["keySignature"]:
        raise RuntimeError("Nightscout JWT signing key changed during replica restart")
    details["process"] = process


def create_subjects(slots, api_secret, run_dir, nightscout, service_details, processes):
    subject_data = {}
    for slot, replicas in slots.items():
        def run_admin(port_b):
            return command_output(
                [
                    NODE,
                    HARNESS / "scripts" / "nightscout-admin.js",
                    "--portA",
                    replicas["A"]["port"],
                    "--portB",
                    port_b,
                    "--subject",
                    f"synthetic-slot-{slot}",
                ],
                cwd=ROOT,
                env=node_environment({"HARNESS_API_SECRET": api_secret}),
                timeout=60,
            )

        try:
            run_admin(replicas["A"]["port"])
        except subprocess.CalledProcessError as error:
            raise RuntimeError(
                f"Nightscout verification failed for synthetic slot {slot}: "
                f"{error.stdout.strip()}"
            ) from error
        restart_secondary_replica(
            slot,
            nightscout,
            service_details,
            processes,
        )
        output = run_admin(replicas["B"]["port"])
        result = json.loads(output.splitlines()[-1])
        state_path = STATE / "slots" / f"slot-{slot}-token.json"
        state_path.parent.mkdir(parents=True, exist_ok=True)
        state_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        subject_data[slot] = result
        (run_dir / "services" / f"slot-{slot}-api-checks.json").write_text(
            json.dumps(result["checks"], indent=2) + "\n",
            encoding="utf-8",
        )
    return subject_data


def simulator_source():
    devices = json.loads(command_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
    preferred_runtimes = ("iOS-26-5", "iOS-27-0")
    for runtime in preferred_runtimes:
        for device in devices["devices"].get(f"com.apple.CoreSimulator.SimRuntime.{runtime}", []):
            if device.get("isAvailable") and device.get("name") == "iPhone 17":
                subprocess.run(
                    ["xcrun", "simctl", "shutdown", device["udid"]],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                    timeout=60,
                )
                return device["udid"], runtime
    raise RuntimeError("No available iPhone 17 simulator on iOS 26.5 or 27.0")


def persistent_simulator_devices(device_listing):
    return {
        device.get("name"): device
        for runtime_devices in device_listing["devices"].values()
        for device in runtime_devices
        if device.get("name", "").startswith("Nightguard Reliability slot ")
    }


def simulator_runtime_id(device_listing, simulator_id):
    return next(
        (
            runtime_id
            for runtime_id, runtime_devices in device_listing["devices"].items()
            for device in runtime_devices
            if device.get("udid") == simulator_id
        ),
        None,
    )


def create_simulators(count, run_dir):
    source_id, runtime = simulator_source()
    runtime_id = f"com.apple.CoreSimulator.SimRuntime.{runtime}"
    device_listing = json.loads(
        command_output(["xcrun", "simctl", "list", "devices", "-j"])
    )
    named_devices = persistent_simulator_devices(device_listing)
    simulators = []
    methods = []
    for index in range(count):
        name = f"Nightguard Reliability slot {index + 1}"
        existing = named_devices.get(name)
        recreated = False
        if existing:
            recreated = (
                not existing.get("isAvailable", False)
                or simulator_runtime_id(device_listing, existing.get("udid"))
                != runtime_id
            )
            if not recreated:
                simulators.append(existing["udid"])
                methods.append("reused")
                continue
            command_output(
                ["xcrun", "simctl", "delete", existing["udid"]],
                timeout=120,
            )
        try:
            output = command_output(["xcrun", "simctl", "clone", source_id, name], timeout=120)
            methods.append("recreated" if recreated else "clone")
        except subprocess.CalledProcessError as clone_error:
            device_type = "com.apple.CoreSimulator.SimDeviceType.iPhone-17"
            try:
                output = command_output(
                    ["xcrun", "simctl", "create", name, device_type, runtime_id],
                    timeout=120,
                )
                methods.append("recreated" if recreated else "create-fallback")
            except subprocess.CalledProcessError as create_error:
                raise RuntimeError(
                    "Simulator clone and clean-device creation both failed. "
                    f"clone: {(clone_error.stdout or '').strip()}; "
                    f"create: {(create_error.stdout or '').strip()}"
                ) from create_error
        match = re.search(r"[0-9A-Fa-f-]{36}", output)
        if not match:
            raise RuntimeError(f"Could not parse cloned simulator UDID from: {output}")
        simulator_id = match.group(0)
        simulators.append(simulator_id)
        named_devices[name] = {
            "name": name,
            "udid": simulator_id,
            "isAvailable": True,
        }
    (run_dir / "simulators.json").write_text(
        json.dumps({
            "source": source_id,
            "runtime": runtime,
            "requestedDevices": simulators,
            "devices": simulators,
            "creationMethods": methods,
        }, indent=2) + "\n",
        encoding="utf-8",
    )
    return source_id, simulators, runtime


def handle_run_signal(signum, _frame):
    global RUN_INTERRUPTED
    RUN_INTERRUPTED = True
    INTERRUPT_SIGNALS.append(signum)
    if CLEANUP_STARTED:
        return
    signal_child_process_groups(signal.SIGTERM)
    time.sleep(0.5)
    signal_child_process_groups(signal.SIGKILL)
    if signum == signal.SIGINT:
        raise KeyboardInterrupt
    raise SystemExit(128 + signum)


def install_run_signal_handlers():
    signal.signal(signal.SIGINT, handle_run_signal)
    signal.signal(signal.SIGTERM, handle_run_signal)


def cleanup_run(run_dir, simulators, processes, keep_services_running):
    global CLEANUP_STARTED
    CLEANUP_STARTED = True
    errors = []
    try:
        redact_result_artifacts(run_dir)
    except Exception as error:
        errors.append(f"redact results: {error}")
    for simulator_id in simulators:
        try:
            result = subprocess.run(
                ["xcrun", "simctl", "shutdown", simulator_id],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
                timeout=60,
            )
            if result.returncode:
                errors.append(f"shutdown simulator {simulator_id}: exit {result.returncode}")
        except Exception as error:
            errors.append(f"shutdown simulator {simulator_id}: {error}")
    if not keep_services_running or RUN_INTERRUPTED:
        for process in reversed(processes):
            try:
                terminate_process(process)
            except Exception as error:
                errors.append(f"terminate process {process.pid}: {error}")
        errors.extend(terminate_child_process_groups())
    else:
        print(f"Services left running for {run_dir}; simulators are shut down")
    for error in errors:
        print(f"Cleanup error: {error}", file=sys.stderr)


def run_if_not_interrupted(task):
    if RUN_INTERRUPTED:
        return None
    return task()


def boot_simulators(simulators, run_dir, logical_cpus):
    boot_log = run_dir / "services" / "simulator-boot.log"
    boot_results = []
    active_simulators = []
    for index, simulator_id in enumerate(simulators):
        started = time.monotonic()
        result = {
            "simulator": simulator_id,
            "status": "booted",
            "bootMs": None,
        }
        try:
            devices = json.loads(command_output([
                "xcrun", "simctl", "list", "devices", "available", "-j"
            ]))
            state = next(
                (
                    device.get("state")
                    for runtime_devices in devices["devices"].values()
                    for device in runtime_devices
                    if device.get("udid") == simulator_id
                ),
                None,
            )
            if state is None:
                raise RuntimeError("Simulator no longer appears in simctl device list")
            with boot_log.open("a", encoding="utf-8") as output:
                output.write(f"Booting simulator {simulator_id}\n")
                if state != "Booted":
                    subprocess.run(
                        ["xcrun", "simctl", "boot", simulator_id],
                        stdout=output,
                        stderr=subprocess.STDOUT,
                        check=True,
                        timeout=60,
                    )
                subprocess.run(
                    ["xcrun", "simctl", "bootstatus", simulator_id, "-b"],
                    stdout=output,
                    stderr=subprocess.STDOUT,
                    check=True,
                    timeout=600,
                )
            result["bootMs"] = int((time.monotonic() - started) * 1000)
            active_simulators.append(simulator_id)
            print(f"Simulator {simulator_id} booted in {result['bootMs']} ms", flush=True)
        except Exception as error:
            result["status"] = "failed"
            result["bootMs"] = int((time.monotonic() - started) * 1000)
            result["error"] = f"{type(error).__name__}: {error}"
            with boot_log.open("a", encoding="utf-8") as output:
                output.write(
                    f"Simulator {simulator_id} failed to boot; dropping slot: "
                    f"{result['error']}\n"
                )
            print(
                f"Simulator {simulator_id} failed to boot; dropping slot: "
                f"{result['error']}",
                flush=True,
            )
            try:
                subprocess.run(
                    ["xcrun", "simctl", "shutdown", simulator_id],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                    timeout=60,
                )
            except Exception:
                pass
        if index + 1 < len(simulators):
            result["loadWaitAfter"] = wait_for_load_below(2 * logical_cpus, 90)
            with boot_log.open("a", encoding="utf-8") as output:
                output.write(
                    f"Inter-boot load wait after {simulator_id}: "
                    f"{result['loadWaitAfter']}\n"
                )
        boot_results.append(result)

    simulator_file = run_dir / "simulators.json"
    simulator_data = json.loads(simulator_file.read_text(encoding="utf-8"))
    simulator_data["devices"] = active_simulators
    simulator_data["bootResults"] = boot_results
    simulator_file.write_text(
        json.dumps(simulator_data, indent=2) + "\n",
        encoding="utf-8",
    )
    return active_simulators, boot_results


def prepare_build_worktree(app_ref, worktree, source_root):
    command_output(["git", "worktree", "add", "--detach", worktree, app_ref], cwd=source_root, timeout=120)
    test_source = worktree / "nightguardUITests" / "AlarmReliabilityUITests.swift"
    project_file = worktree / "nightguard.xcodeproj" / "project.pbxproj"
    app_delegate = worktree / "nightguard" / "AppDelegate.swift"
    project = project_file.read_text(encoding="utf-8") if project_file.is_file() else ""
    delegate = app_delegate.read_text(encoding="utf-8") if app_delegate.is_file() else ""
    registered_test = (
        "AlarmReliabilityUITests.swift" in project
        and "AlarmReliabilityUITests.swift in Sources" in project
    )
    if (
        not test_source.is_file()
        or not registered_test
        or "--reliability-host-uri" not in delegate
    ):
        raise RuntimeError(
            f"app ref {app_ref} doesn't include the harness; merge "
            "origin/devin/za-135-alarm-reliability-harness into it first"
        )
    tracked_diff = subprocess.run(
        ["git", "diff", "--binary", "HEAD"],
        cwd=source_root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    if tracked_diff:
        subprocess.run(
            ["git", "apply", "--binary", "-"],
            cwd=worktree,
            input=tracked_diff,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    project_file = worktree / "nightguard.xcodeproj" / "project.pbxproj"
    project = project_file.read_text(encoding="utf-8")
    for reference in (
        "\t\t\t\t43647C1C1BFF6435004389F9 /* Embed Watch Content */,\n",
        "\t\t\t\t43647BF51BFF6435004389F9 /* PBXTargetDependency */,\n",
    ):
        if project.count(reference) != 1:
            raise RuntimeError("Could not isolate the WatchKit app build dependency")
        project = project.replace(reference, "", 1)
    project_file.write_text(project, encoding="utf-8")
    build_only_env = worktree / "nightguard" / ".env"
    if not build_only_env.exists():
        build_only_env.write_text("", encoding="utf-8")
    return worktree


def cached_xctestrun(derived_data):
    manifest = derived_data / "harness-build.json"
    try:
        metadata = json.loads(manifest.read_text(encoding="utf-8"))
        xctestrun = (derived_data / metadata["xctestrun"]).resolve()
        xctestrun.relative_to(derived_data.resolve())
        with xctestrun.open("rb") as source:
            document = plistlib.load(source)
    except (OSError, KeyError, TypeError, ValueError, plistlib.InvalidFileException):
        return None
    if not xctestrun.is_file() or not isinstance(document, dict):
        return None
    products = xctestrun.parent / "Debug-iphonesimulator"
    product_names = ("nightguard.app", "nightguardUITests-Runner.app")
    if not all((products / name).is_dir() for name in product_names):
        return None
    targets = []
    configurations = document.get("TestConfigurations", [])
    if isinstance(configurations, list):
        for configuration in configurations:
            if isinstance(configuration, dict):
                test_targets = configuration.get("TestTargets", [])
                if isinstance(test_targets, list):
                    targets.extend(
                        target for target in test_targets if isinstance(target, dict)
                    )
    if not targets:
        targets = [
            target
            for name, target in document.items()
            if name != "__xctestrun_metadata__" and isinstance(target, dict)
        ]
    for target in targets:
        host_path = target.get("TestHostPath")
        product_paths = [
            value
            for name, value in target.items()
            if name.endswith("Path") and isinstance(value, str)
        ]
        if (
            isinstance(host_path, str)
            and any(name in host_path for name in product_names)
            and all(
                any(name in value for value in product_paths)
                for name in product_names
            )
        ):
            return xctestrun
    return None


def record_xctestrun(derived_data, xctestrun):
    manifest = derived_data / "harness-build.json"
    manifest.write_text(
        json.dumps({"xctestrun": str(xctestrun.relative_to(derived_data))}, indent=2) + "\n",
        encoding="utf-8",
    )
    os.utime(manifest, None)


def prune_derived_data(derived_data_root, active_key):
    if not derived_data_root.is_dir():
        return
    directories = [
        path for path in derived_data_root.iterdir()
        if path.is_dir() and not path.is_symlink()
    ]
    most_recent = sorted(
        directories,
        key=lambda path: (path / "harness-build.json").stat().st_mtime
        if (path / "harness-build.json").is_file()
        else path.stat().st_mtime,
        reverse=True,
    )
    retained = {active_key.resolve()}
    for path in most_recent:
        resolved_path = path.resolve()
        if resolved_path != active_key.resolve():
            retained.add(resolved_path)
            if len(retained) == 2:
                break
    for path in directories:
        if path.resolve() not in retained:
            shutil.rmtree(path)


def build_for_testing(worktree, source_id, derived_data, log_path):
    result = run_logged(
        [
            "xcodebuild",
            "build-for-testing",
            "-project",
            worktree / "nightguard.xcodeproj",
            "-scheme",
            "nightguard",
            "-destination",
            f"platform=iOS Simulator,id={source_id}",
            "-derivedDataPath",
            derived_data,
            "CODE_SIGNING_ALLOWED=NO",
        ],
        log_path,
        cwd=worktree,
        timeout=1800,
    )
    if result:
        raise RuntimeError(f"xcodebuild build-for-testing failed; see {log_path}\n{tail(log_path)}")
    candidates = sorted(derived_data.rglob("*.xctestrun"), key=lambda item: item.stat().st_mtime)
    if not candidates:
        raise RuntimeError(f"No .xctestrun file found under {derived_data}")
    xctestrun = candidates[-1]
    record_xctestrun(derived_data, xctestrun)
    return xctestrun


def configure_test_run(source_xctestrun, session_config, xctestrun_path):
    with source_xctestrun.open("rb") as input_file:
        document = plistlib.load(input_file)
    targets = [
        target
        for configuration in document.get("TestConfigurations", [])
        for target in configuration.get("TestTargets", [])
    ]
    if not targets:
        targets = [
            target
            for name, target in document.items()
            if name != "__xctestrun_metadata__" and isinstance(target, dict)
        ]
    if not targets:
        raise RuntimeError(f"No test targets found in {source_xctestrun}")
    for target in targets:
        for variable_name in ("EnvironmentVariables", "TestingEnvironmentVariables"):
            environment = target.setdefault(variable_name, {})
            environment["TEST_RUNNER_SESSION_CONFIG"] = str(session_config["_path"])
            environment.pop("TEST_RUNNER_SESSION_CONFIG_JSON", None)
    with xctestrun_path.open("wb") as output_file:
        plistlib.dump(document, output_file)


def reset_simulator(udid, logfile):
    boot_log = Path(logfile)
    boot_log.parent.mkdir(parents=True, exist_ok=True)
    with boot_log.open("a", encoding="utf-8") as output:
        subprocess.run(
            ["xcrun", "simctl", "terminate", udid, APP_BUNDLE_ID],
            stdout=output,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=60,
        )
        group_result = subprocess.run(
            ["xcrun", "simctl", "get_app_container", udid, APP_BUNDLE_ID, "groups"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
            timeout=60,
        )
        if group_result.returncode == 0:
            output.write(group_result.stdout)
            group_container = Path(group_result.stdout.strip())
            owned_group_root = (
                Path.home()
                / "Library"
                / "Developer"
                / "CoreSimulator"
                / "Devices"
                / udid
                / "data"
                / "Containers"
                / "Shared"
                / "AppGroup"
            )
            if (
                group_container.parent == owned_group_root
                and not group_container.is_symlink()
                and group_container.exists()
            ):
                shutil.rmtree(group_container)
        elif group_result.stderr:
            output.write(group_result.stderr)
        subprocess.run(
            ["xcrun", "simctl", "uninstall", udid, APP_BUNDLE_ID],
            stdout=output,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=120,
        )
        subprocess.run(
            ["xcrun", "simctl", "keychain", udid, "reset"],
            stdout=output,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=60,
        )
        output.write("App state reset; simulator remains booted\n")


def run_node_json(command, env, timeout, logfile=None):
    if logfile:
        returncode = run_logged(command, logfile, cwd=ROOT, env=env, timeout=timeout)
        if returncode:
            raise RuntimeError(f"Command failed; see {logfile}\n{tail(logfile)}")
        return json.loads(tail(logfile, 5).splitlines()[-1])
    output = command_output(command, cwd=ROOT, env=env, timeout=timeout)
    return json.loads(output.splitlines()[-1])


def start_gateway(slots, gateway_log):
    server = subprocess.Popen(
        [
            str(NODE),
            str(HARNESS / "gateway" / "gateway.js"),
            "--port",
            "0",
            "--slots",
            json.dumps(slots, separators=(",", ":")),
            "--log",
            str(gateway_log),
        ],
        cwd=ROOT,
        env=node_environment(),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        start_new_session=True,
    )
    register_child_process_group(server)
    ready_line = server.stdout.readline()
    if not ready_line:
        raise RuntimeError("Gateway exited before reporting readiness")
    ready = json.loads(ready_line)
    if ready.get("status") != "ready":
        raise RuntimeError(f"Unexpected gateway startup response: {ready_line}")
    track_service(
        server,
        int(ready["port"]),
        [NODE, HARNESS / "gateway" / "gateway.js"],
        ROOT,
    )
    return server, ready["port"]


def post_json(port, route, body):
    serialized = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}{route}",
        data=serialized,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read())


def wait_for_resources(futures, measurement):
    max_cpu = 0.0
    max_rss = 0
    samples = 0
    host_samples = []
    memory_bytes = int(command_output(["sysctl", "-n", "hw.memsize"]).strip())
    pending = set(futures)
    while pending:
        completed, pending = concurrent.futures.wait(
            pending,
            timeout=60,
            return_when=concurrent.futures.FIRST_COMPLETED,
        )
        if completed:
            for future in completed:
                future.result()
        try:
            output = command_output(
                ["ps", "-A", "-o", "%cpu=,rss=,command="],
                timeout=10,
            )
            sample_cpu = 0.0
            sample_rss = 0
            for line in output.splitlines():
                fields = line.strip().split(None, 2)
                if len(fields) < 3:
                    continue
                command = fields[2]
                if any(name in command for name in (
                    "Simulator.app",
                    "CoreSimulator",
                    "xcodebuild",
                    "nightguard.app",
                    "nightguardUITests-Runner",
                )):
                    sample_cpu += float(fields[0])
                    sample_rss += int(fields[1])
            max_cpu = max(max_cpu, sample_cpu)
            max_rss = max(max_rss, sample_rss)
            samples += 1
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
        host_samples.append(sample_host_resources(memory_bytes))
    measurement.update({
        "maxObservedTotalCpuPercent": round(max_cpu, 1),
        "maxObservedTotalProcessRssMiB": round(max_rss / 1024, 1),
        "resourceSamples": samples,
        "hostResourceSamples": host_samples,
    })
    free_percent = [
        sample["freeMemoryPercent"] for sample in host_samples
        if sample["freeMemoryPercent"] is not None
    ]
    pressure = [
        sample["vmPressureLevel"] for sample in host_samples
        if isinstance(sample["vmPressureLevel"], (int, float))
    ]
    measurement["minimumFreeMemoryPercent"] = min(free_percent) if free_percent else None
    measurement["vmPressureLevel"] = max(pressure) if pressure else None
    measurement["swapUsage"] = host_samples[-1]["swapUsage"] if host_samples else None
    load_values = {
        f"{window}m": [
            sample[f"loadAverage{window}m"] for sample in host_samples
            if sample[f"loadAverage{window}m"] is not None
        ]
        for window in (1, 5, 15)
    }
    measurement["loadAverage"] = {
        key: {"minimum": min(values), "maximum": max(values)}
        for key, values in load_values.items() if values
    }


def sample_host_resources(memory_bytes):
    sample = {
        "sampledAtMs": int(time.time() * 1000),
        "freeMemoryPercent": None,
        "vmPressureLevel": None,
        "swapUsage": None,
    }
    try:
        vm_stat = command_output(["vm_stat"], timeout=10)
        page_size = re.search(r"page size of ([\d,]+) bytes", vm_stat)
        free_pages = re.search(r"Pages free:\s*([\d,]+)", vm_stat)
        if page_size and free_pages and memory_bytes:
            page_bytes = int(page_size.group(1).replace(",", ""))
            free_count = int(free_pages.group(1).replace(",", ""))
            sample["freeMemoryPercent"] = round(
                free_count * page_bytes * 100 / memory_bytes, 2
            )
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    try:
        value = command_output(["sysctl", "-n", "vm.memory_pressure"], timeout=5).strip()
        sample["vmPressureLevel"] = int(value)
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    try:
        sample["swapUsage"] = command_output(
            ["sysctl", "-n", "vm.swapusage"], timeout=5
        ).strip()
    except (OSError, subprocess.SubprocessError):
        pass
    try:
        loads = os.getloadavg()
        sample.update({
            f"loadAverage{window}m": round(value, 2)
            for window, value in zip((1, 5, 15), loads)
        })
    except (AttributeError, OSError):
        sample.update({f"loadAverage{window}m": None for window in (1, 5, 15)})
    return sample


def execute_session(
    index,
    slot_number,
    simulator_id,
    profile,
    run_seed,
    args,
    shape,
    slots,
    tokens,
    gateway_port,
    run_dir,
    xctestrun,
    logical_cpus,
):
    session_id = f"{args.label}-{index:03d}"
    session_dir = run_dir / "sessions" / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    event_file = run_dir / "events" / f"{session_id}.jsonl"
    event_file.parent.mkdir(parents=True, exist_ok=True)
    session_log = session_dir / "xcodebuild.log"
    session_started_ms = int(time.time() * 1000)
    test_exit_code = None
    harness_error = None
    live_readings = []
    seed_result = {}
    registration = {}
    launch_load_gate = {}
    seed_env = node_environment({
        "HARNESS_NIGHTSCOUT_TOKEN": tokens[str(slot_number)]["accessToken"],
    })

    try:
        reset_simulator(simulator_id, session_dir / "simulator.log")
        seed_result = run_node_json(
            [
                NODE,
                HARNESS / "scripts" / "trace-feeder.js",
                "--mode",
                "seed",
                "--shape",
                HARNESS / "config" / "session-shape.json",
                "--nightscoutRoot",
                STATE / "cgm-remote-monitor",
                "--mongoUri",
                f"mongodb://127.0.0.1:{args.mongo_port}/ns_slot_{slot_number}",
                "--portA",
                slots[str(slot_number)]["A"]["port"],
                "--portB",
                slots[str(slot_number)]["B"]["port"],
            ],
            env=seed_env,
            timeout=300,
            logfile=session_dir / "trace-seed.log",
        )
        token = tokens[str(slot_number)]["accessToken"]
        host_uri = (
            f"http://127.0.0.1:{gateway_port}/s/{session_id}"
            f"?token={urllib.parse.quote(token, safe='')}"
        )
        control_url = f"http://127.0.0.1:{gateway_port}/__control"
        registration = post_json(gateway_port, "/__control/register", {
            "sessionId": session_id,
            "sessionIndex": index,
            "slot": slot_number,
            "profile": profile,
            "runSeed": run_seed,
            "eventFile": str(event_file),
        })
        session_config = {
            "sessionId": session_id,
            "sessionIndex": index,
            "controlURL": control_url,
            "hostURI": host_uri,
            "t0Sgv": int(seed_result["t0Sgv"]),
            "sessionSeed": registration["sessionSeed"],
            "durationSeconds": int(shape["duration_seconds"]),
            "lowThresholdMgdl": int(shape["low_threshold_mgdl"]),
            "missedThresholdMinutes": int(shape["missed_readings_threshold_minutes"]),
            "units": shape["units"],
        }
        config_path = STATE / "session-configs" / f"{session_id}.json"
        config_path.parent.mkdir(parents=True, exist_ok=True)
        config_path.write_text(json.dumps(session_config, indent=2) + "\n", encoding="utf-8")
        session_config["_path"] = str(config_path)
        session_xctestrun = Path(xctestrun).with_name(f"{session_id}.xctestrun")
        configure_test_run(xctestrun, session_config, session_xctestrun)

        feeder_log = session_dir / "trace-live.log"
        feeder_log_handle = feeder_log.open("wb")
        feeder = subprocess.Popen(
            [
                str(NODE),
                str(HARNESS / "scripts" / "trace-feeder.js"),
                "--mode",
                "feed",
                "--shape",
                str(HARNESS / "config" / "session-shape.json"),
                "--nightscoutRoot",
                str(STATE / "cgm-remote-monitor"),
                "--mongoUri",
                f"mongodb://127.0.0.1:{args.mongo_port}/ns_slot_{slot_number}",
                "--portA",
                str(slots[str(slot_number)]["A"]["port"]),
                "--portB",
                str(slots[str(slot_number)]["B"]["port"]),
                "--eventFile",
                str(event_file),
                "--t0Sgv",
                str(seed_result["t0Sgv"]),
            ],
            cwd=ROOT,
            env=seed_env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=feeder_log_handle,
            text=True,
            bufsize=1,
            start_new_session=True,
        )
        register_child_process_group(feeder)
        result_bundle_dir = STATE / "xcresults" / run_dir.name
        result_bundle_dir.mkdir(parents=True, exist_ok=True)
        result_bundle = result_bundle_dir / f"{session_id}.xcresult"
        test_env = node_environment()
        test_env.pop("TEST_RUNNER_SESSION_CONFIG", None)
        test_env.pop("TEST_RUNNER_SESSION_CONFIG_JSON", None)
        test_exit_code, launch_load_gate = run_logged_with_load_gate(
            [
                "xcodebuild",
                "test-without-building",
                "-xctestrun",
                session_xctestrun,
                "-destination",
                f"platform=iOS Simulator,id={simulator_id}",
                "-only-testing:" + TEST_NAME,
                "-resultBundlePath",
                result_bundle,
                "-parallel-testing-enabled",
                "NO",
            ],
            session_log,
            ROOT,
            test_env,
            int(shape["duration_seconds"]) + 900,
            logical_cpus,
        )
        if test_exit_code:
            harness_error = f"xcodebuild exited {test_exit_code}"
        if feeder.poll() is None:
            feeder.terminate()
        feeder_output, _ = feeder.communicate(timeout=30)
        feeder_log_handle.close()
        for line in feeder_output.splitlines():
            try:
                item = json.loads(line)
                if "reading" in item:
                    live_readings.append(item["reading"])
                elif item.get("complete"):
                    live_readings.extend(item.get("readings", []))
            except json.JSONDecodeError:
                continue
        if feeder.returncode not in (0, -15):
            harness_error = harness_error or f"trace feeder exited {feeder.returncode}"
    except Exception as error:
        harness_error = str(error)
        if test_exit_code is None:
            test_exit_code = 1
    finally:
        if "feeder" in locals() and feeder.poll() is None:
            terminate_process(feeder, timeout=5)
        if "feeder" in locals():
            unregister_child_process_group(feeder)
        if "feeder_log_handle" in locals() and not feeder_log_handle.closed:
            feeder_log_handle.close()
        metadata = {
            "sessionId": session_id,
            "sessionIndex": index,
            "slot": slot_number,
            "profileMode": "healthy" if profile is None else "profile",
            "sessionSeed": registration.get("sessionSeed"),
            "t0Ms": seed_result.get("t0Ms"),
            "t0DisplayedAtMs": first_t0_display(event_file, seed_result.get("t0Sgv")),
            "testStartedMs": session_started_ms,
            "testFinishedMs": int(time.time() * 1000),
            "testExitCode": test_exit_code,
            "harnessError": harness_error,
            "eventFile": str(event_file),
            "readings": seed_result.get("readings", []) + live_readings,
            "episodes": registration.get("episodes", []),
            "launchLoadGate": launch_load_gate,
            "overheadMs": (
                first_t0_display(event_file, seed_result.get("t0Sgv")) - session_started_ms
                if first_t0_display(event_file, seed_result.get("t0Sgv")) is not None
                else None
            ),
        }
        metadata_path = run_dir / "sessions" / f"{session_id}.json"
        metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
        print(
            json.dumps({
                "sessionId": session_id,
                "sessionIndex": index,
                "slot": slot_number,
                "testExitCode": test_exit_code,
                "harnessError": harness_error,
            }),
            flush=True,
        )
    return metadata


def first_t0_display(event_file, t0_sgv):
    if not t0_sgv or not Path(event_file).exists():
        return None
    with Path(event_file).open(encoding="utf-8") as source:
        for line in source:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            try:
                if int(event.get("bgValue", "")) == int(t0_sgv):
                    return int(event["hostWallClockMs"])
            except (TypeError, ValueError, KeyError):
                continue
    return None


def parse_shard(value):
    try:
        shard_index, shard_count = (int(part) for part in value.split("/", 1))
    except (ValueError, TypeError):
        raise argparse.ArgumentTypeError("shard must be in the form i/k") from None
    if shard_count < 1 or not 1 <= shard_index <= shard_count:
        raise argparse.ArgumentTypeError("shard index must be between 1 and k")
    return shard_index, shard_count


def parse_args():
    parser = argparse.ArgumentParser(description="Run synthetic Nightguard alarm reliability sessions.")
    parser.add_argument("--app-ref", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--n", required=True, type=int)
    profile_group = parser.add_mutually_exclusive_group()
    profile_group.add_argument("--profile", type=Path)
    profile_group.add_argument("--healthy", action="store_true")
    profile_group.add_argument("--control-treatment-profile", type=Path)
    parser.add_argument("--seed", type=int)
    parser.add_argument("--workers", type=int, default=1)
    parser.add_argument("--session-index", type=int)
    parser.add_argument("--shard", type=parse_shard)
    parser.add_argument("--estimate-sessions", type=int, default=50)
    parser.add_argument("--keep-services-running", action="store_true")
    args = parser.parse_args()
    if args.n < 1 or args.workers < 1 or args.estimate_sessions < 1:
        parser.error("--n, --workers and --estimate-sessions must be positive")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", args.label):
        parser.error("--label may contain only letters, numbers, dot, underscore and hyphen")
    if args.session_index is not None and not 0 <= args.session_index < args.n:
        parser.error("--session-index must be in [0, n)")
    if args.session_index is not None and args.shard is not None:
        parser.error("--session-index and --shard cannot be combined")
    if args.control_treatment_profile and (
        args.n != 2 or args.shard is not None or args.session_index is not None
    ):
        parser.error("--control-treatment-profile requires --n 2 without sharding or replay")
    return args


def main():
    args = parse_args()
    install_run_signal_handlers()
    require_tools()
    app_commit = command_output([
        "git", "-C", ROOT, "rev-parse", f"{args.app_ref}^{{commit}}"
    ]).strip()
    overlay = subprocess.run(
        ["git", "diff", "--binary", "HEAD"],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    overlay_hash = hashlib.sha256(overlay).hexdigest() if overlay else None
    derived_data_key = app_commit + (
        f"-dirty-{overlay_hash}" if overlay_hash else ""
    )
    derived_data_root = STATE / "derived-data"
    derived_data = derived_data_root / derived_data_key
    prune_derived_data(derived_data_root, derived_data)
    require_simulator_disk_space()
    STATE.mkdir(parents=True, exist_ok=True)
    now = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    run_id = f"{args.label}-{now}-{time.time_ns() % 1_000_000:06d}"
    run_dir = HARNESS / "results" / run_id
    run_dir.mkdir(parents=True, exist_ok=False)
    (run_dir / "services").mkdir()
    (run_dir / "sessions").mkdir()
    shape = json.loads((HARNESS / "config" / "session-shape.json").read_text(encoding="utf-8"))

    profile = None
    profile_path = args.profile or args.control_treatment_profile
    if profile_path:
        profile = json.loads(profile_path.resolve().read_text(encoding="utf-8"))
    profile_seed = profile.get("run_seed", 135) if profile else 135
    run_seed = args.seed if args.seed is not None else profile_seed
    shape_fingerprint = hashlib.sha256(
        json.dumps(shape, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    if args.session_index is not None:
        session_indexes = [args.session_index]
    elif args.shard is not None:
        shard_index, shard_count = args.shard
        start = (shard_index - 1) * args.n // shard_count
        end = shard_index * args.n // shard_count
        if start == end:
            raise ValueError(f"shard {shard_index}/{shard_count} has no sessions for N={args.n}")
        session_indexes = list(range(start, end))
    else:
        session_indexes = list(range(args.n))
    requested_workers = min(args.workers, len(session_indexes))
    workers = requested_workers
    profile_fingerprint = None
    if profile is not None:
        profile_fingerprint = hashlib.sha256(
            json.dumps(profile, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
    args.mongo_port = None
    processes = []
    simulators = []
    try:
        terminate_stale_services()
        logical_cpus = int(command_output(["sysctl", "-n", "hw.logicalcpu"]).strip())
        source_id, simulator_clones, runtime = create_simulators(workers, run_dir)
        simulators = simulator_clones
        simulators, simulator_boots = boot_simulators(simulators, run_dir, logical_cpus)
        workers = len(simulators)
        if not workers:
            raise RuntimeError("No simulator clones booted successfully")
        nightscout = ensure_nightscout(run_dir / "services")
        mongo_process, args.mongo_port = start_mongo(run_dir / "services", processes)
        api_secret = secrets.token_urlsafe(36)
        nightscout_services, slots, service_details = start_nightscout(
            nightscout,
            workers,
            args.mongo_port,
            api_secret,
            run_dir,
            processes,
        )
        tokens = create_subjects(
            slots,
            api_secret,
            run_dir,
            nightscout,
            service_details,
            processes,
        )
        gateway_log = run_dir / "gateway.jsonl"
        gateway_process, gateway_port = start_gateway(slots, gateway_log)
        processes.append(gateway_process)
        worktree = STATE / "worktrees" / f"{run_id}-build"
        worktree.parent.mkdir(parents=True, exist_ok=True)
        prepare_build_worktree(args.app_ref, worktree, ROOT)
        xctestrun = cached_xctestrun(derived_data)
        derived_data_reused = xctestrun is not None
        if derived_data_reused:
            os.utime(derived_data / "harness-build.json", None)
            print(f"Reusing derived data for {derived_data_key}", flush=True)
        else:
            xctestrun = build_for_testing(
                worktree,
                source_id,
                derived_data,
                run_dir / "services" / "xcodebuild-build.log",
            )
        prune_derived_data(derived_data_root, derived_data)

        measurement = {
            "requestedWorkers": requested_workers,
            "activeWorkers": workers,
            "simulatorRuntime": runtime,
            "simulatorSource": source_id,
            "sessionIndexes": session_indexes,
            "runSeed": run_seed,
        }
        (run_dir / "run.json").write_text(
            json.dumps({
                "runId": run_id,
                "appRef": args.app_ref,
                "appCommit": app_commit,
                "label": args.label,
                "requestedSessions": args.n,
                "executedSessions": len(session_indexes),
                "sessionIndexes": session_indexes,
                "runSeed": run_seed,
                "profile": str(profile_path.resolve()) if profile_path else None,
                "profileFingerprint": profile_fingerprint,
                "shapeFingerprint": shape_fingerprint,
                "controlTreatmentValidation": bool(args.control_treatment_profile),
                "requestedWorkers": requested_workers,
                "workers": workers,
                "nightscoutTag": "v15.0.9",
                "nodeVersion": command_output([NODE, "--version"]).strip(),
                "mongoPort": args.mongo_port,
                "gatewayPort": gateway_port,
                "slots": slots,
                "simulators": simulators,
                "simulatorBoots": simulator_boots,
                "derivedDataKey": derived_data_key,
                "derivedDataReused": derived_data_reused,
                "xctestrun": str(xctestrun),
            }, indent=2) + "\n",
            encoding="utf-8",
        )

        session_args = []
        for position, index in enumerate(session_indexes):
            slot_number = position % workers + 1
            session_profile = profile
            if args.control_treatment_profile and index == 0:
                session_profile = None
            session_args.append((
                index,
                slot_number,
                simulators[slot_number - 1],
                session_profile,
            ))
        slot_locks = {slot: threading.Lock() for slot in range(1, workers + 1)}

        def run_slot_session(session):
            if RUN_INTERRUPTED:
                return None
            index, slot_number, simulator_id, session_profile = session
            with slot_locks[slot_number]:
                return run_if_not_interrupted(
                    lambda: execute_session(
                        index,
                        slot_number,
                        simulator_id,
                        session_profile,
                        run_seed,
                        args,
                        shape,
                        slots,
                        tokens,
                        gateway_port,
                        run_dir,
                        xctestrun,
                        logical_cpus,
                    )
                )

        executor = concurrent.futures.ThreadPoolExecutor(max_workers=workers)
        try:
            futures = [executor.submit(run_slot_session, session) for session in session_args]
            wait_for_resources(futures, measurement)
        except (KeyboardInterrupt, SystemExit):
            global RUN_INTERRUPTED
            RUN_INTERRUPTED = True
            executor.shutdown(wait=True, cancel_futures=True)
            raise
        else:
            executor.shutdown(wait=True)
        session_metadata = [
            json.loads(path.read_text(encoding="utf-8"))
            for path in (run_dir / "sessions").glob("*.json")
        ]
        overheads = [
            item["overheadMs"]
            for item in session_metadata
            if item.get("overheadMs") is not None
        ]
        median_overhead_ms = sorted(overheads)[len(overheads) // 2] if overheads else 0
        memory_bytes = int(command_output(["sysctl", "-n", "hw.memsize"]).strip())
        memory_gib = memory_bytes / (1024 ** 3)
        estimated_batches = math.ceil(args.estimate_sessions / workers)
        measurement.update({
            "logicalCpus": logical_cpus,
            "physicalMemoryGiB": round(memory_gib, 1),
            "measuredMedianSessionOverheadMs": median_overhead_ms,
            "recommendedWorkers": None,
            "recommendationNote": (
                "Not calculated: summed process RSS double-counts shared pages; "
                "use empirical capacity evidence."
            ),
            "estimateUsesMeasuredWorkers": workers,
            "estimateTargetSessions": args.estimate_sessions,
            "estimatedTargetMinutes": round(
                estimated_batches * (
                    shape["duration_seconds"] / 60 + median_overhead_ms / 60_000
                ),
                1,
            ),
        })
        (run_dir / "capacity.json").write_text(
            json.dumps(measurement, indent=2) + "\n",
            encoding="utf-8",
        )
        returncode = run_logged(
            [
                sys.executable,
                HARNESS / "scorer" / "score.py",
                "--run-dir",
                run_dir,
                "--shape",
                HARNESS / "config" / "session-shape.json",
            ],
            run_dir / "services" / "scorer.log",
            cwd=ROOT,
            timeout=60,
        )
        if returncode:
            raise RuntimeError(f"Scorer failed; see {run_dir / 'services' / 'scorer.log'}")
        print(f"Run complete: {run_dir}")
        print(f"Results: {run_dir / 'results.json'}")
        print(f"Scorecard: {run_dir / 'scorecard.md'}")
        return 0
    finally:
        cleanup_run(run_dir, simulators, processes, args.keep_services_running)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Run interrupted; cleanup completed.", file=sys.stderr)
        raise SystemExit(130)
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
