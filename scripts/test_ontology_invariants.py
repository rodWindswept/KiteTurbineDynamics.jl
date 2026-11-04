#!/usr/bin/env python3
"""Evaluate the Windswept ontology axioms against KTD telemetry.

Loads the vendored ontology-core.jsonld, the binding.yaml symbol map, and
telemetry.json (from scripts/export_ontology_telemetry.jl). Substitutes the
bound telemetry into each axiom expression and evaluates it. Violations of a
FATAL axiom exit 1 (CI goes red); warnings print and exit 0. An axiom whose
symbols are not supplied (e.g. delta_peak) is SKIPPED visibly, never passed.

Expression grammar (kept small, dependency-free apart from numpy):
  scalar/array literals, symbols, + - * /, parentheses,
  min(x), max(x) — max over an array's LAST axis when the array is 2-D
  (T_section is (n_sections, n_lines); max(T_section) reads per-section maxima,
  the R56 full-section form), comparisons <=, <, >, >=.
"""
import json
import re
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
TESTS = HERE.parent / "tests" / "ontology"


def tokenize(expr):
    return re.findall(r"[A-Za-z_][A-Za-z_0-9]*|\d+\.\d+|\d+|<=|>=|==|!=|<|>|[-+*/()]", expr)


def resolve(sym, bindings, telemetry, parameters):
    if sym in parameters:
        return float(parameters[sym])
    path = bindings.get(sym)
    if path is None:
        raise KeyError(sym)
    if path == "null":
        raise KeyError(sym)
    if re.fullmatch(r"-?\d+(\.\d+)?", str(path)):
        return float(path)
    assert str(path).startswith("telemetry."), f"unsupported binding path: {path}"
    obj = telemetry
    for part in str(path).split(".")[1:]:
        obj = obj[part]
    if isinstance(obj, list):
        obj = np.asarray(obj, dtype=float)
    return obj


class _PEnd(Exception):
    pass


def _parse(tokens, bindings, telemetry, parameters):
    pos = [0]

    def peek():
        return tokens[pos[0]] if pos[0] < len(tokens) else None

    def next_tok():
        t = tokens[pos[0]]
        pos[0] += 1
        return t

    def primary():
        t = next_tok()
        if t == "(":
            v = expr()
            if next_tok() != ")":
                raise _PEnd("expected )")
            return v
        if t in ("min", "max"):
            if next_tok() != "(":
                raise _PEnd("expected ( after func")
            v = expr()
            if next_tok() != ")":
                raise _PEnd("expected ) after func args")
            arr = np.asarray(v, dtype=float)
            if arr.ndim == 2:
                return getattr(np, t)(arr, axis=1)
            return getattr(np, t)(arr)
        if re.fullmatch(r"\d+(\.\d+)?", t):
            return float(t)
        return resolve(t, bindings, telemetry, parameters)

    def term():
        v = primary()
        while peek() in ("*", "/"):
            op = next_tok()
            rhs = primary()
            v = v * rhs if op == "*" else v / rhs
        return v

    def expr():
        v = term()
        while peek() in ("+", "-"):
            op = next_tok()
            rhs = term()
            v = v + rhs if op == "+" else v - rhs
        return v

    def compare():
        v = expr()
        op = peek()
        if op in ("<=", "<", ">", ">=", "==", "!="):
            next_tok()
            rhs = expr()
            ops = {"<=": np.less_equal, "<": np.less, ">": np.greater,
                   ">=": np.greater_equal, "==": np.equal, "!=": np.not_equal}
            return ops[op](v, rhs)
        return v

    v = compare()
    if pos[0] != len(tokens):
        raise _PEnd("trailing tokens")
    return v


def evaluate(expression, bindings, telemetry, parameters):
    tokens = tokenize(expression)
    try:
        out = _parse(tokens, bindings, telemetry, parameters)
    except KeyError:
        raise
    result = np.asarray(out, dtype=bool)
    return bool(result) if result.ndim == 0 else result


def main():
    ontology = json.load(open(TESTS / "ontology-core.jsonld"))
    telemetry = json.load(open(TESTS / "telemetry.json"))

    bindings, parameters = load_binding(TESTS / "binding.yaml")

    axioms = [n for n in ontology["@graph"] if "rule_type" in n]
    if not axioms:
        print("NO AXIOMS FOUND in the vendored JSON-LD")
        return 1

    failed_fatal = []
    skipped = []
    for ax in axioms:
        ax_id = ax.get("id") or ax.get("@id", "").rsplit("/", 1)[-1]
        try:
            result = evaluate(ax["expression"], bindings, telemetry, parameters)
        except KeyError as e:
            skipped.append((ax_id, str(e)))
            continue
        ok = bool(result) if np.ndim(result) == 0 else bool(np.all(result))
        tag = "PASS" if ok else ("FAIL-WARN" if ax["severity"] == "warning" else "FAIL-FATAL")
        print(f"[{tag}] {ax_id}: {ax['expression']} -> {ok}")
        if not ok and ax["severity"] == "fatal":
            failed_fatal.append(ax_id)
        if not ok and ax["severity"] == "warning":
            print(f"        warning: {ax.get('message', '')}")
    for ax_id, why in skipped:
        print(f"[SKIP] {ax_id} — unbound symbol: {why} (supply it in binding.yaml to enable this check)")

    print(f"\nmachine={telemetry.get('machine')}  gate_ok={telemetry.get('gate_ok')}")
    print(f"Cp={telemetry.get('power_coefficient'):.4f}  max_twist_ratio="
          f"{telemetry.get('max_twist_ratio'):.4f}  slack_per_section="
          f"{telemetry.get('slack_per_section')}")
    if failed_fatal:
        print(f"\nFATAL VIOLATIONS: {failed_fatal}")
        return 1
    print("\nontology invariants: no fatal violations")
    return 0


def load_binding(path):
    # Minimal YAML subset: flat key: value lines (the binding file is tiny).
    bindings, parameters = {}, {}
    section = None
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        m = re.match(r"^(bindings|parameters):\s*$", line)
        if m:
            section = m.group(1)
            continue
        m = re.match(r"^  ([A-Za-z_][A-Za-z_0-9]*):\s*(.*)$", line)
        if m and section:
            key, raw = m.group(1), m.group(2).strip()
            if raw in ("null", "~"):
                val = "null"
            elif re.fullmatch(r"-?\d+(\.\d+)?", raw):
                val = raw
            else:
                val = raw.strip("\"'")
            (bindings if section == "bindings" else parameters)[key] = val
    return bindings, parameters


if __name__ == "__main__":
    sys.exit(main())
