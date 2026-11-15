"""Check the game functions and events the addon uses against Blizzard's API docs for WoW Forever.

Usage, from the repo root:  python -I tests/check_api.py
Source: Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua of github.com/Gethe/wow-ui-source,
branch `forever`, cached in tests/.apidoc/ (delete that folder to download it again).

Fails (exit 1) if a `C_X.Y` or a `RegisterEvent("...")` in the addon files, or a fake in tests/smoke.lua,
is not in the docs. Lists, with file:line, what the docs mark Secret*/Restricted (SecretArguments aside:
nearly every function has it). A missing `C_X.Y` guarded on its line (`C_X.Y and`, `C_X and C_X.Y`, ...)
is only a warning. Global functions (UnitName, ...) are checked for marks only: many real globals are
not in the docs, so a missing one proves nothing.
"""
import pathlib
import re
import shutil
import sys
import tarfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = ROOT / "tests" / ".apidoc"
URL = "https://codeload.github.com/Gethe/wow-ui-source/tar.gz/refs/heads/forever"
DOC_DIR = "/Interface/AddOns/Blizzard_APIDocumentationGenerated/"
ADDON = ["Locales.lua", "Data.lua", "BuffDigger.lua", "UI.lua", "Comm.lua"]
FLAG = re.compile(r"^(Secret(?!Arguments)\w*|RequiresNonSecret\w*|HasRestrictions|\w*Restricted\w*)$")


def fetch():
    if CACHE.is_dir() and any(CACHE.glob("*.lua")):
        return
    tmp = CACHE.with_suffix(".tmp")  # renamed at the end: an interrupted download leaves no half cache
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)
    req = urllib.request.Request(URL, headers={"User-Agent": "api-doc-check"})
    with urllib.request.urlopen(req, timeout=60) as r, tarfile.open(fileobj=r, mode="r|gz") as tar:
        for m in tar:
            if m.isfile() and DOC_DIR in m.name and m.name.endswith(".lua"):
                # basename only: nothing from the archive decides where we write
                (tmp / pathlib.PurePosixPath(m.name).name).write_bytes(tar.extractfile(m).read())
    shutil.rmtree(CACHE, ignore_errors=True)
    tmp.rename(CACHE)


def parse_docs():
    """-> functions {"C_X.Y" or "Global": flags}, events {"EVENT_NAME": flags}."""
    functions, events = {}, {}
    for path in CACHE.glob("*.lua"):
        namespace, kind, section, entry = None, None, None, None
        for line in path.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^\t(\w+) =\s*\"?([^\",]*)\"?,?$", line)
            if m:
                key, value = m.groups()
                if key == "Namespace":
                    namespace = value
                elif key == "Type":
                    kind = value
                elif value == "":
                    section = key  # Functions, Events, Tables, Predicates
                continue
            if line == "\t\t{":
                entry = {}
                if section == "Functions" and kind == "System":
                    entry["_into"] = functions
                elif section == "Events":
                    entry["_into"] = events
                continue
            m = re.match(r"^\t\t\t(\w+) = (.*?),?$", line)
            if m and entry is not None:
                entry.setdefault(m.group(1), m.group(2).strip('"'))
            if line == "\t\t}," and entry is not None:
                into = entry.pop("_into", None)
                flags = sorted(k for k, v in entry.items() if FLAG.match(k) and v != "false")
                if into is events:
                    events[entry["LiteralName"]] = flags
                elif into is functions:
                    name = f"{namespace}.{entry['Name']}" if namespace else entry["Name"]
                    functions[name] = flags
                entry = None
    return functions, events


def strip_comment(line):
    # ponytail: ignores strings and --[[ ]] blocks (none in the addon); a "--" in a string cuts the line
    return line.split("--", 1)[0]


def uses(text, smoke=False):
    """-> list of (line_no, kind, name, guarded); kind is "C", "global" or "event"."""
    found = []
    for no, line in enumerate(text.splitlines(), 1):
        code = strip_comment(line)
        for ns, fn in set(re.findall(r"\b(C_\w+)\.(\w+)", code)):
            name = f"{ns}.{fn}"
            guarded = bool(re.search(rf"\b{ns}\.{fn}\s+(and|then|or)\b|\b{ns}\s+and\s+{ns}\.{fn}\b(?!\s*\()", code))
            found.append((no, "C", name, guarded))
        for g in set(re.findall(r"(?<![\w.:])([A-Z]\w*)\s*\(", code)):
            found.append((no, "global", g, False))
        event_re = r'\bfire\("([A-Z_0-9]+)"' if smoke else r'Register(?:Unit)?Event\("([A-Z_0-9]+)"'
        for ev in set(re.findall(event_re, code)):
            found.append((no, "event", ev, False))
    if smoke:  # fakes built as tables: C_X={A=function..., B=function...}, possibly over several lines
        # ponytail: one level of nested braces inside the table; enough for tests/smoke.lua
        for m in re.finditer(r"\b(C_\w+)\s*=\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}", text):
            for k in re.finditer(r"[{,]\s*(\w+)\s*=\s*function", m.group(0)):
                no = text.count("\n", 0, m.start() + k.start(1)) + 1
                found.append((no, "C", f"{m.group(1)}.{k.group(1)}", False))
    return found


def main():
    fetch()
    functions, events = parse_docs()
    if not functions or not events:
        sys.exit(f"Could not read the API docs in {CACHE} (format changed?)")
    errors, warnings, marked = [], [], []
    guarded_names = set()
    files = [(f, False) for f in ADDON] + [("tests/smoke.lua", True)]
    all_uses = []
    for f, smoke in files:
        for no, kind, name, guarded in uses((ROOT / f).read_text(encoding="utf-8"), smoke):
            all_uses.append((f, no, kind, name, guarded, smoke))
            if guarded and not smoke:
                guarded_names.add(name)
    for f, no, kind, name, guarded, smoke in all_uses:
        where = f"{f}:{no}"
        table = events if kind == "event" else functions
        if name not in table:
            if kind == "global":
                continue
            what = f"{where}  {name}  not in the Forever API docs"
            # a fake of a function the addon guards somewhere is fine: the fake stands for "it exists"
            (warnings if guarded or (smoke and name in guarded_names) else errors).append(what)
            continue
        if table[name] and not smoke:
            marked.append(f"{where}  {name}  {', '.join(table[name])}")
    print(f"Forever API docs: {len(functions)} functions, {len(events)} events")
    for title, lines in (("Marked secret/restricted", marked), ("Warnings (guarded, missing)", warnings),
                         ("ERRORS (missing)", errors)):
        print(f"\n{title}: {len(lines)}")
        for line in lines:
            print("  " + line)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
