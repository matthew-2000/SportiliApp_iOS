"""Compile production ImageLoader with controlled Storage/UIKit doubles, no network."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='sportili-image-loader-tests-') as folder:
    work = Path(folder)
    source = (root / 'SportiliApp/ImageLoader.swift').read_text()
    source = source.replace('import FirebaseStorage\n', '').replace('import SwiftUI\n', '')
    (work / 'ImageLoader.swift').write_text(source)
    executable = work / 'image-tests'
    subprocess.run(['swiftc', '-swift-version', '5', str(root / 'Tests/ImageLoaderTests.swift'),
                    str(work / 'ImageLoader.swift'), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
