"""Resume la salida JSON (una línea por evento) de `opencode run --format json` para dispatch.sh.

Uso: python3 tools/agy/summarize_opencode.py <log.jsonl> <código de salida de opencode> [<log.err>]
Imprime el estado, las herramientas denegadas, los errores y el informe final del ejecutor.
Sale con 0 solo si opencode terminó con 0, sin errores de proveedor y con informe final.
"""

import json
import os
import sys


def main() -> int:
    log_path, exit_code = sys.argv[1], int(sys.argv[2])
    err_path = sys.argv[3] if len(sys.argv) > 3 else ""
    texts: list[tuple[str, str]] = []
    denied: list[str] = []
    errors: list[str] = []
    tools = 0
    with open(log_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(event, dict):
                continue
            kind = event.get("type")
            part = event.get("part") or {}
            state = part.get("state") or {}
            if kind == "text":
                texts.append((str(part.get("messageID") or ""), str(part.get("text") or "")))
            elif kind in ("tool_use", "tool"):
                tools += 1
                error = str(state.get("error") or "")
                if "Permission denied" in error:
                    denied.append(f"{json.dumps(state.get('input'), ensure_ascii=False)[:160]} ({error})")
            elif kind == "error":
                errors.append(json.dumps(event.get("error"), ensure_ascii=False)[:400])
    # El informe es el último mensaje: se juntan todos sus bloques de texto
    last_id = texts[-1][0] if texts else ""
    report = "\n".join(t for mid, t in texts if mid == last_id).strip() if texts else ""
    if exit_code in (124, 137):
        status = "TIMEOUT"
    elif exit_code != 0 or errors:
        status = "ERROR"
    elif not report:
        status = "SIN_INFORME"
    else:
        status = "SUCCESS"
    ok = status == "SUCCESS"
    print(f"opencode_exit={exit_code} status={status} herramientas={tools}")
    for error in errors:
        print(f"error={error}")
    if denied:
        print("AVISO: comandos o herramientas denegados al ejecutor (la sesión continúa):")
        for item in denied[:20]:
            print(f"  {item}")
    if not ok and err_path and os.path.exists(err_path):
        with open(err_path, encoding="utf-8", errors="replace") as fh:
            tail = [l.rstrip() for l in fh if "level=INFO" not in l][-20:]
        if tail:
            print("----- últimas líneas de stderr -----")
            print("\n".join(tail))
    print(f"log={log_path}")
    print("----- informe del ejecutor -----")
    print(report)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
