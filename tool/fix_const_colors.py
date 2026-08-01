"""Removes `const` from any expression containing a runtime AppColors getter.

The dark-mode change turned these fields into getters, which are not
compile-time constants, so every enclosing `const` is now invalid.
"""
import pathlib, re

# Colours that vary with brightness. red/green/white/onImage/onAccent and
# bannerScrim stay `static const`, so they remain legal inside const.
DYNAMIC = ['background', 'surface', 'surfaceElevated', 'divider', 'accent',
           'accentDim', 'textPrimary', 'textSecondary', 'textTertiary',
           'success', 'danger', 'warning', 'info']
# Longest first so `surfaceElevated` is not matched as `surface`.
PATTERN = re.compile(r'AppColors\.(' + '|'.join(
    sorted(DYNAMIC, key=len, reverse=True)) + r')\b')

OPEN = {'(': ')', '[': ']', '{': '}'}


def span_after(src, i):
    """End index of the bracketed group that follows position i."""
    j = i
    while j < len(src) and src[j] not in OPEN:
        # Only skip identifier characters, dots and whitespace between the
        # keyword and its bracket; anything else means no group follows.
        if not (src[j].isalnum() or src[j] in '_. \n\t<>,'):
            return None
        j += 1
    if j >= len(src):
        return None

    depth = 0
    in_str = None
    k = j
    while k < len(src):
        ch = src[k]
        if in_str:
            if ch == '\\':
                k += 2
                continue
            if ch == in_str:
                in_str = None
        elif ch in "'\"":
            in_str = ch
        elif ch in OPEN:
            depth += 1
        elif ch in OPEN.values():
            depth -= 1
            if depth == 0:
                return k
        k += 1
    return None


def strip_pass(src):
    """Removes the outermost offending `const`; returns (text, changed)."""
    for m in re.finditer(r'\bconst\b', src):
        start = m.start()
        end = span_after(src, m.end())
        if end is None:
            continue
        if PATTERN.search(src[m.end():end]):
            after = src[m.end():]
            # Drop the keyword and the single space that follows it.
            trimmed = after[1:] if after.startswith(' ') else after
            return src[:start] + trimmed, True
    return src, False


total = 0
for f in sorted(pathlib.Path('lib').rglob('*.dart')):
    src = f.read_text()
    original = src
    count = 0
    while True:
        src, changed = strip_pass(src)
        if not changed:
            break
        count += 1
        if count > 200:
            raise SystemExit(f'runaway loop in {f}')
    if src != original:
        f.write_text(src)
        print(f'  {f}: removed {count} const')
        total += count

print(f'\ntotal const removed: {total}')
