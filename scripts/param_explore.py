#!/usr/bin/env python3
"""
Explore parameter values for a template-driven config and run build commands.

This script renders a config from a template file for each case, either random
or a single fixed case via --case-json.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple, Optional

TARGET_DEFAULT = "customrocket"

CUSTOM_CONFIG_PATH = Path(
    "overlay/root/chipyard/generators/chipyard/src/main/scala/config/CustomRocketConfigs.scala"
)
CUSTOM_TEMPLATE_PATH = Path(str(CUSTOM_CONFIG_PATH) + ".tmpl")
CUSTOM_SPACE_PATH = Path(
    "overlay/root/chipyard/generators/chipyard/src/main/scala/config/param_rocket.json"
)
CUSTOM_CONSTRAINT_PATH = Path(
    "overlay/root/chipyard/generators/chipyard/src/main/scala/config/rocket_constraint.py"
)

PARAM_CONFIG_PATH = Path(
    "overlay/root/chipyard/generators/chipyard/src/main/scala/config/ParametricRocketConfig.scala"
)
PARAM_TEMPLATE_PATH = Path(str(PARAM_CONFIG_PATH) + ".tmpl")
PARAM_SPACE_PATH = Path(
    "overlay/root/chipyard/generators/chipyard/src/main/scala/config/param_parametricrocket.json"
)


def target_defaults(target: str) -> Dict[str, Any]:
    if target == "parametricrocket":
        return {
            "config": PARAM_CONFIG_PATH,
            "template": PARAM_TEMPLATE_PATH,
            "space": PARAM_SPACE_PATH,
            "constraint": None,
            "log": Path(f"param_explore_{target}.csv"),
            "log_dir": Path(f"param_explore_logs_{target}"),
            "output_logs": {
                "syn": Path(f"syn.{target}.log"),
                "verilog": Path(f"verilog.{target}.log"),
                "mm": Path(f"mm.{target}.log"),
                "power": Path(f"syn_power.{target}.log"),
            },
            "cmds": [
                "make docker-stop || true",
                "make docker-reset",
                f"make verilog TARGET={target}",
                f"make mm TARGET={target}",
                f"make syn TARGET={target}",
                f"make syn_power TARGET={target}",
            ],
        }

    return {
        "config": CUSTOM_CONFIG_PATH,
        "template": CUSTOM_TEMPLATE_PATH,
        "space": CUSTOM_SPACE_PATH,
        "constraint": CUSTOM_CONSTRAINT_PATH,
        "log": Path(f"param_explore_{target}.csv"),
        "log_dir": Path(f"param_explore_logs_{target}"),
        "output_logs": {
            "syn": Path(f"syn.{target}.log"),
            "verilog": Path(f"verilog.{target}.log"),
            "mm": Path(f"mm.{target}.log"),
            "power": Path(f"syn_power.{target}.log"),
        },
        "cmds": [
            "make docker-stop || true",
            "make docker-reset",
            f"make verilog TARGET={target}",
            f"make mm TARGET={target}",
            f"make syn TARGET={target}",
            f"make syn_power TARGET={target}",
        ],
    }


def parse_output_logs(args, defaults: Dict[str, Path]) -> Dict[str, Path]:
    if not args.output_log:
        return defaults
    out_logs: Dict[str, Path] = {}
    for entry in args.output_log:
        if "=" not in entry:
            print(f"Invalid --output-log entry: {entry}. Must be file_id=path", file=sys.stderr)
            sys.exit(2)
        file_id, path_str = entry.split("=", 1)
        out_logs[file_id.strip()] = Path(path_str.strip())
    return out_logs

def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(description="Explore template-driven parameters (random)")
    ap.add_argument("--target", default=TARGET_DEFAULT, choices=["customrocket", "parametricrocket"], help="Select default config/template/space/commands")
    ap.add_argument("--config", default=None, help="Path to config output file (defaults by --target)")
    ap.add_argument("--template", default=None, help="Path to template file (defaults by --target)")
    ap.add_argument("--space", default=None, help="Path to JSON parameter space definition (defaults by --target)")
    ap.add_argument("--case-json", default=None, help="Path to JSON file with a single fixed parameter set")
    ap.add_argument("--random-cases", type=int, default=100, help="Number of random cases to try (ignored with --case-json)")
    ap.add_argument("--list", action="store_true", help="List template parameters and ranges, then exit")
    ap.add_argument("--run-cmd", action="append", default=[], help="Run custom command per case (repeatable)")
    ap.add_argument("--stop-on-fail", action="store_true", help="Stop after a failing case")
    ap.add_argument("--log", default=None, help="CSV log path (defaults by --target)")
    ap.add_argument("--log-dir", default=None, help="Directory to store per-case logs (defaults by --target)")
    ap.add_argument("--output-log", action="append", default=None, help="Specify output log(s) as file_id=path. Can be repeated. Example: --output-log syn=syn.customrocket.log --output-log verilog=verilog.customrocket.log",
    )
    ap.add_argument(
        "--constraint-file",
        default=None,
        help="Path to constraint file (optional)",
    )
    ap.add_argument("--overwrite-log", action="store_true", help="Overwrite log file if header mismatches")
    ap.add_argument("--log-skips", action="store_true", default=False, help="Record skipped cases in CSV")
    ap.add_argument("--no-log-skips", action="store_false", dest="log_skips", help="Do not record skipped cases")
    return ap.parse_args()


def parse_value(raw: Any) -> Any:
    if not isinstance(raw, str):
        return raw
    v = raw.strip()
    if v.lower() in ("true", "false"):
        return v.lower() == "true"
    if v.startswith("-") and v[1:].isdigit():
        return int(v)
    if v.isdigit():
        return int(v)
    return v



def format_value(v: Any) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str) and v.startswith("raw:"):
        return v[len("raw:") :]
    return str(v)


def render_template(template_text: str, params: Dict[str, Any], param_order: Iterable[str]) -> str:
    rendered = template_text
    for name in param_order:
        placeholder = "{{" + name + "}}"
        if placeholder not in rendered:
            continue
        if name not in params:
            raise ValueError(f"Missing parameter: {name}")
        rendered = rendered.replace(placeholder, format_value(params[name]))
    if "{{" in rendered or "}}" in rendered:
        raise ValueError("Unresolved placeholders in template")
    return rendered



def validate_params(params: Dict[str, Any], constraint_path: Optional[Path]) -> List[str]:
    if constraint_path is None:
        return []
    if not constraint_path.exists():
        raise ValueError(f"constraint_path {constraint_path} does not exist")

    import importlib.util

    spec = importlib.util.spec_from_file_location("rocket_constraint", constraint_path)
    if spec is None or spec.loader is None:
        return []
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    func = getattr(module, "validate_params", None)
    if not callable(func):
        return []
    try:
        return list(func(params))
    except Exception as exc:  # pragma: no cover - defensive
        return [f"constraint_error: {exc}"]


PLACEHOLDER_RE = re.compile(r"\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}")


def extract_placeholders(text: str) -> List[str]:
    names = PLACEHOLDER_RE.findall(text)
    # Preserve first-seen order while de-duplicating.
    return list(dict.fromkeys(names))


def load_space(path: Path) -> Tuple[Dict[str, List[Any]], List[str]]:
    data = json.loads(path.read_text())
    if isinstance(data, dict) and "params" in data:
        params = data.get("params")
        order = data.get("order")
        if not isinstance(params, dict):
            raise ValueError("space JSON 'params' must be an object")
        param_space: Dict[str, List[Any]] = {}
        for k, v in params.items():
            if not isinstance(v, list):
                raise ValueError(f"Range for {k} must be a list")
            param_space[k] = [parse_value(x) for x in v]
        if order is None:
            param_order = list(param_space.keys())
        else:
            if not isinstance(order, list) or not all(isinstance(x, str) for x in order):
                raise ValueError("space JSON 'order' must be a list of strings")
            missing = [k for k in order if k not in param_space]
            if missing:
                raise ValueError(f"space JSON 'order' includes unknown params: {', '.join(missing)}")
            param_order = list(order)
        return param_space, param_order

    if isinstance(data, dict):
        param_space = {}
        for k, v in data.items():
            if not isinstance(v, list):
                raise ValueError(f"Range for {k} must be a list")
            param_space[k] = [parse_value(x) for x in v]
        return param_space, list(param_space.keys())

    raise ValueError("space JSON must be an object or {\"params\": {...}, \"order\": [...]}")


def ensure_csv_header(path: Path, header: List[str], overwrite: bool) -> None:
    if path.exists():
        existing = path.read_text().splitlines()
        if existing:
            if existing[0].strip() == ",".join(header):
                return
            if not overwrite:
                raise ValueError(
                    f"CSV header mismatch in {path}. Use --overwrite-log to replace it."
                )
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)


def append_csv(
    path: Path,
    case_id: str,
    status: str,
    return_code: int,
    failed_cmd: str,
    params: Dict[str, Any],
    param_order: List[str],
    start_time: str,
    end_time: str,
) -> None:
    fields = [case_id, status, str(return_code), failed_cmd, start_time, end_time] + [
        format_value(params.get(k, "")) for k in param_order
    ]
    with path.open("a", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(fields)


def generate_random_cases(
    ranges: Dict[str, List[Any]],
    param_order: List[str],
    constraint_path: Optional[Path],
    count: int,
) -> Tuple[List[Tuple[str, Dict[str, Any], str]], List[Tuple[str, List[str], Dict[str, Any]]]]:
    cases: List[Tuple[str, Dict[str, Any], str]] = []
    skipped: List[Tuple[str, List[str], Dict[str, Any]]] = []
    keys = list(ranges.keys())
    seen: set[str] = set()
    attempts = 0
    max_attempts = count * 50

    while len(cases) < count and attempts < max_attempts:
        attempts += 1
        params: Dict[str, Any] = {}
        for k in keys:
            params[k] = random.choice(ranges[k])
        reasons = validate_params(params, constraint_path)
        case_text = ",".join(f"{k}={format_value(params[k])}" for k in param_order)
        case_id = hashlib.sha256(case_text.encode("utf-8")).hexdigest()
        if case_id in seen:
            continue
        seen.add(case_id)
        if reasons:
            skipped.append((case_id, reasons, params))
        else:
            cases.append((case_id, params, case_text))

    if len(cases) < count:
        print(f"warning: generated {len(cases)} unique cases after {attempts} attempts", file=sys.stderr)

    return cases, skipped


def run_cmds(cmds: Iterable[str]) -> Tuple[int, List[str]]:
    failures: List[str] = []
    for cmd in cmds:
        print(f"[run] {cmd}")
        proc = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if proc.returncode != 0:
            print(f"   error with result code {proc.returncode}")
            failures.append(cmd)
            return proc.returncode, failures
    print(f"   success ...")
    return 0, failures

def compute_space_size(param_space) :
    size : int = 1
    for p,v in param_space.items() :
        size *= len(v)
    return size


def run_cases(
    cases: List[Tuple[str, Dict[str, Any], str]],
    skipped: List[Tuple[str, List[str], Dict[str, Any]]],
    template_text: str,
    param_order: List[str],
    config_path: Path,
    log_path: Path,
    log_dir: Path,
    output_logs: Dict[str, Path],
    run_cmds_list: List[str],
    stop_on_fail: bool,
    log_skips: bool,
) -> int:
    log_dir.mkdir(parents=True, exist_ok=True)

    if skipped:
        print(f"skipped {len(skipped)} cases due to constraints")
        if log_skips:
            for case_id, reasons, params in skipped:
                append_csv(log_path, case_id, "skip", -1, ";".join(reasons), params, param_order, "", "")

    try:
        for case_id, params, case_text in cases:
            print(f"\n[case] {case_id}")
            start_time = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
            rendered = render_template(template_text, params, param_order)
            config_path.write_text(rendered)

            # Track all output logs per case
            case_output_paths: Dict[str, Path] = {}

            # Remove existing outputs
            for file_id, out_path in output_logs.items():
                if out_path.exists():
                    out_path.unlink()

            # Run commands
            # TODO for parallel : DOCKER_OVERLAYS=rocket-configs/overlay DOCKER_CONTAINER=...
            code, failed = run_cmds(run_cmds_list)
            end_time = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
            if code != 0:
                append_csv(log_path, case_id, "fail", code, failed[-1], params, param_order, start_time, end_time)
                if stop_on_fail:
                    return code
            else:
                append_csv(log_path, case_id, "ok", 0, "", params, param_order, start_time, end_time)

            # Copy multiple output logs
            for file_id, out_path in output_logs.items():
                case_log_path = log_dir / f"{case_id}_{file_id}.log"
                if out_path.exists():
                    shutil.copyfile(out_path, case_log_path)
                else:
                    with case_log_path.open("w", encoding="utf-8") as f:
                        f.write(f"{out_path} was not generated for this case\n")
                        f.write(f"status={'fail' if code != 0 else 'ok'}\n")
                        f.write(f"failed_cmd={failed[-1] if failed else ''}\n")
                        f.write(f"params={case_text}\n")
                case_output_paths[file_id] = case_log_path
    finally:
        pass

    print("\n[done]")
    return 0


def main() -> int:
    args = parse_args()
    defaults = target_defaults(args.target)

    config_path = Path(args.config) if args.config else Path(defaults["config"])
    template_path = Path(args.template) if args.template else Path(defaults["template"])
    space_path = args.space if args.space else str(defaults["space"])
    log_path = Path(args.log) if args.log else Path(defaults["log"])
    log_dir = Path(args.log_dir) if args.log_dir else Path(defaults["log_dir"])
    output_logs = parse_output_logs(args, defaults["output_logs"])


    if not template_path.exists():
        print(f"Template not found: {template_path}", file=sys.stderr)
        return 2

    param_space, param_order = load_space(Path(space_path))

    space_size = compute_space_size(param_space)
    print (f"Space size is {space_size}")

    template_text = template_path.read_text()
    placeholders = extract_placeholders(template_text)
    missing = [name for name in placeholders if name not in param_space]
    if missing:
        print("Missing params in space for template placeholders: " + ", ".join(missing), file=sys.stderr)
        return 2
    missing_order = [name for name in placeholders if name not in param_order]
    if missing_order:
        print("Template placeholders missing from space order: " + ", ".join(missing_order), file=sys.stderr)
        return 2
    unused = [name for name in param_space if name not in placeholders]
    if unused:
        print("warning: params in space not used by template: " + ", ".join(unused), file=sys.stderr)

    if args.list:
        for name in placeholders:
            values = param_space.get(name)
            if values is None:
                continue
            formatted = ", ".join(format_value(v) for v in values)
            print(f"{name}: [{formatted}]")
        return 0

    ranges = dict(param_space)
    run_cmds_list: List[str] = args.run_cmd or list(defaults["cmds"])

    if args.constraint_file:
        constraint_path = Path(args.constraint_file)
    else:
        constraint_path = Path(defaults["constraint"]) if defaults.get("constraint") else None

    if args.case_json:
        case_path = Path(args.case_json)
        if not case_path.exists():
            print(f"Case JSON not found: {case_path}", file=sys.stderr)
            return 2
        case_data = json.loads(case_path.read_text())
        if not isinstance(case_data, dict):
            print("Case JSON must be an object of param -> value", file=sys.stderr)
            return 2
        params = {k: parse_value(v) for k, v in case_data.items()}
        missing_case = [name for name in placeholders if name not in params]
        if missing_case:
            print("Missing params in case JSON: " + ", ".join(missing_case), file=sys.stderr)
            return 2
        extra_case = [name for name in params if name not in placeholders]
        if extra_case:
            print("warning: params in case JSON not used by template: " + ", ".join(extra_case), file=sys.stderr)

        # Explicit fixed case: skip constraints to allow manual override.

        case_text = ",".join(f"{k}={format_value(params.get(k, ''))}" for k in param_order)
        case_id = hashlib.sha256(case_text.encode("utf-8")).hexdigest()
        cases = [(case_id, params, case_text)]
        skipped = []
    else:
        cases, skipped = generate_random_cases(
            ranges,
            param_order,
            constraint_path,
            args.random_cases,
        )

    header = ["case", "status", "return_code", "failed_cmd", "start_time", "end_time"] + param_order
    try:
        ensure_csv_header(log_path, header, args.overwrite_log)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    return run_cases(
        cases,
        skipped,
        template_text,
        param_order,
        config_path,
        log_path,
        log_dir,
        output_logs,
        run_cmds_list,
        args.stop_on_fail,
        args.log_skips,
    )


if __name__ == "__main__":
    raise SystemExit(main())
