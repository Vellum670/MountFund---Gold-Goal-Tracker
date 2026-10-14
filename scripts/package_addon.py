"""Build the addon-only download from the current sources (stdlib only)."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

root = Path(__file__).resolve().parents[1]
addon = root / 'GoldEnvelope'
output = root / 'downloads' / 'GoldEnvelope.zip'
output.parent.mkdir(exist_ok=True)
files = sorted(path for path in addon.rglob('*') if path.is_file())
with ZipFile(output, 'w', compression=ZIP_DEFLATED, compresslevel=9) as archive:
    for path in files:
        entry = ZipInfo(path.relative_to(root).as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        archive.writestr(entry, path.read_bytes(), compresslevel=9)
with ZipFile(output) as archive:
    assert archive.testzip() is None
    for path in files:
        assert archive.read(path.relative_to(root).as_posix()) == path.read_bytes()
    for line in (addon / 'GoldEnvelope.toc').read_text().splitlines():
        if line.strip() and not line.startswith('#'):
            assert 'GoldEnvelope/' + line.strip() in archive.namelist()
print(f'{output}: {len(files)} files, {output.stat().st_size} bytes; verified.')
