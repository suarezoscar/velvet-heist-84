"""Resume la salida JSON (una línea por evento) de `opencode run --format json` para dispatch.sh.

Uso: python3 tools/agy/summarize_opencode.py <log.jsonl> <código de salida de opencode>
Imprime el estado, las herramientas denegadas, los errores y el texto final del ejecutor.
Sale con 0 solo si opencode terminó con 0 y sin errores de proveedor.
"""

import json
import sys


def main() -> int:
    log_path, exit_code = sys.argv[1], int(sys.argv[2])
    texts: list[str] = []
    denied: list[str] = []
    errors: list[str] = []
    tools = 0
    with open(log_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            kind = event.get("type")
            part = event.get("part") or {}
            state = part.get("state") or {}
            if kind == "text":
                texts.append(str(part.get("text") or ""))
            elif kind in ("tool_use", "tool"):
                tools += 1
                error = str(state.get("error") or "")
                if "Permission denied" in error:
                    denied.append(f"{json.dumps(state.get('input'), ensure_ascii=False)[:160]} ({error})")
            elif kind == "error":
                errors.append(json.dumps(event.get("error"), ensure_ascii=False)[:400])
    timed_out = exit_code == 124
    ok = exit_code == 0 and not errors
    status = "SUCCESS" if ok else ("TIMEOUT" if timed_out else "ERROR")
    print(f"opencode_exit={exit_code} status={status} herramientas={tools}")
    for error in errors:
        print(f"error={error}")
    if denied:
        print("AVISO: comandos o herramientas denegados al ejecutor (la sesión continúa):")
        for item in denied[:20]:
            print(f"  {item}")
    print(f"log={log_path}")
    print("----- informe del ejecutor -----")
    # El informe de entrega es el último bloque de texto; si viene partido, se juntan los finales
    print(texts[-1] if texts else "")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
