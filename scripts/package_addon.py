"""Build the addon-only download from the current sources (stdlib only)."""
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

root = Path(__file__).resolve().parents[1]
addon = root / 'GoldEnvelope'
toc = (addon / 'GoldEnvelope.toc').read_text()
version_match = re.search(r'^## Version:\s*(\S+)\s*$', toc, re.MULTILINE)
if not version_match:
    raise SystemExit('Set a Version in GoldEnvelope.toc before packaging.')
version = version_match.group(1)
changelog = root / 'CHANGELOG.md'
notes = changelog.read_text()
# 0.3.1 predates the requested changelog; all subsequent releases need notes.
if version != '0.3.1':
    entry = re.search(
        rf'^## {re.escape(version)} - \d{{4}}-\d{{2}}-\d{{2}}\n'
        r'(?P<body>[\s\S]*?)(?=^## |\Z)', notes, re.MULTILINE,
    )
    if not entry or not re.search(r'^- \S', entry['body'], re.MULTILINE):
        raise SystemExit(f'Add a dated CHANGELOG.md entry with change bullets for {version} before packaging.')
output = root / 'downloads' / 'GoldEnvelope.zip'
output.parent.mkdir(exist_ok=True)
files = {path.relative_to(root).as_posix(): path for path in sorted(addon.rglob('*')) if path.is_file()}
files['GoldEnvelope/CHANGELOG.md'] = changelog
with ZipFile(output, 'w', compression=ZIP_DEFLATED, compresslevel=9) as archive:
    for name, path in files.items():
        entry = ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        archive.writestr(entry, path.read_bytes(), compresslevel=9)
with ZipFile(output) as archive:
    assert archive.testzip() is None
    for name, path in files.items():
        assert archive.read(name) == path.read_bytes()
    for line in toc.splitlines():
        if line.strip() and not line.startswith('#'):
            assert 'GoldEnvelope/' + line.strip() in archive.namelist()
print(f'{output}: {len(files)} files, {output.stat().st_size} bytes; verified.')
