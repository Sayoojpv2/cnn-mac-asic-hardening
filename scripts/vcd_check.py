#!/usr/bin/env python3
"""Sanity-check a VCD before it is used for power: timescale, time span and the
clock period seen in each DUT scope.

usage: vcd_check.py FILE EXPECTED_PERIOD_NS SCOPE [SCOPE ...]    (scope e.g. tb_mac.u_base)
Exits non-zero if a scope has no 'clk' variable or its period (span / half the number of
clock transitions, as OpenSTA computes it) differs from the expected period by > 0.5 %.
"""
import sys

UNIT_NS = {"s": 1e9, "ms": 1e6, "us": 1e3, "ns": 1.0, "ps": 1e-3, "fs": 1e-6}


def main() -> int:
    path, expected, scopes = sys.argv[1], float(sys.argv[2]), sys.argv[3:]
    clk_ids, stack, scale = {}, [], None
    with open(path) as f:
        header = []
        for line in f:
            header.append(line)
            if "$enddefinitions" in line:
                break
        tok = " ".join(header).split()
        i = 0
        while i < len(tok):
            if tok[i] == "$timescale":
                j, ts = i + 1, ""
                while tok[j] != "$end":
                    ts += tok[j]
                    j += 1
                num = "".join(c for c in ts if c.isdigit())
                scale, i = int(num) * UNIT_NS[ts[len(num):]], j
            elif tok[i] == "$scope":
                stack.append(tok[i + 2])
                i += 3
            elif tok[i] == "$upscope":
                stack.pop()
                i += 1
            elif tok[i] == "$var":
                # Aliased nets (tb clk -> DUT clk ports) share one identifier code.
                if tok[i + 4] == "clk" and ".".join(stack) in scopes:
                    clk_ids.setdefault(tok[i + 3], []).append(".".join(stack))
                i += 5
            else:
                i += 1
        last = {c: None for c in clk_ids}
        edges = {c: 0 for c in clk_ids}
        t_first = t_last = None
        for line in f:
            if line[0] == "#":
                t_last = int(line[1:])
                t_first = t_last if t_first is None else t_first
            elif line[0] in "01xz":
                code = line[1:].strip()
                if code in last:
                    if last[code] is not None and last[code] != line[0]:
                        edges[code] += 1
                    last[code] = line[0]
    span = (t_last - t_first) * scale
    print(f"VCD {path}: timescale {scale:g} ns, start {t_first * scale:g} ns, "
          f"end {t_last * scale:g} ns, span {span:g} ns")
    ok = True
    for scope in scopes:
        codes = [c for c, s in clk_ids.items() if scope in s]
        if not codes:
            print(f"VCD {scope}: no clk variable found")
            ok = False
            continue
        n = edges[codes[0]]
        period = span / (n / 2) if n else float("inf")
        good = abs(period - expected) / expected <= 0.005
        ok &= good
        print(f"VCD {scope}.clk: {n} transitions, period {period:.4f} ns "
              f"(expected {expected:g}) {'OK' if good else 'MISMATCH'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
