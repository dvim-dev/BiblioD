#!/usr/bin/env python3
import os
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

def create_deb_package(project_root: Path, output_dir: Path):
    version = "1.0.1-1"
    pkg_name = "bibliod"
    deb_filename = f"{pkg_name}_{version}_amd64.deb"
    output_deb = output_dir / deb_filename

    bundle_dir = project_root / "build" / "linux" / "x64" / "release" / "bundle"
    if not bundle_dir.exists():
        raise FileNotFoundError(f"Bundle directory does not exist: {bundle_dir}")

    packaging_dir = project_root / "packaging"

    with tempfile.TemporaryDirectory() as tmp_dir_str:
        tmp_dir = Path(tmp_dir_str)
        debian_binary = tmp_dir / "debian-binary"
        debian_binary.write_text("2.0\n")

        # 1. Build control.tar.gz
        control_dir = tmp_dir / "control_dir"
        control_dir.mkdir()

        # Calculate installed size in KB
        installed_size_kb = sum(f.stat().st_size for f in bundle_dir.glob("**/*") if f.is_file()) // 1024

        control_content = f"""Package: {pkg_name}
Version: {version}
Section: utils
Priority: optional
Architecture: amd64
Installed-Size: {installed_size_kb}
Depends: libc6 (>= 2.31), libgtk-3-0 (>= 3.24.0), libglib2.0-0 (>= 2.64.0), libsqlite3-0 (>= 3.31.0)
Maintainer: Dvim-dev <dvimdev@proton.me>
Homepage: https://github.com/dvim-dev/bibliod
Description: Application moderne de gestion de bibliothèque personnelle
 BiblioD est une application simple de gestion de bibliothèque, avec
 recherche omnibox, recherche auteur sur Wikipedia et interrogation
 du catalogue mondial Open Library.
"""
        (control_dir / "control").write_text(control_content)

        postinst_content = """#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    if which update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q || true
    fi
    if which gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
    fi
fi
exit 0
"""
        postinst = control_dir / "postinst"
        postinst.write_text(postinst_content)
        postinst.chmod(0o755)

        postrm_content = """#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    if which update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q || true
    fi
    if which gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
    fi
fi
exit 0
"""
        postrm = control_dir / "postrm"
        postrm.write_text(postrm_content)
        postrm.chmod(0o755)

        control_tar = tmp_dir / "control.tar.gz"
        with tarfile.open(control_tar, "w:gz") as tar:
            for file_path in [control_dir / "control", postinst, postrm]:
                tar_info = tar.gettarinfo(str(file_path), arcname=f"./{file_path.name}")
                tar_info.uid = 0
                tar_info.gid = 0
                tar_info.uname = "root"
                tar_info.gname = "root"
                if file_path.name in ("postinst", "postrm"):
                    tar_info.mode = 0o755
                else:
                    tar_info.mode = 0o644
                with open(file_path, "rb") as f:
                    tar.addfile(tar_info, f)

        # 2. Build data.tar.xz
        data_dir = tmp_dir / "data_dir"
        opt_dir = data_dir / "opt" / "bibliod"
        usr_bin = data_dir / "usr" / "bin"
        usr_apps = data_dir / "usr" / "share" / "applications"
        usr_icons = data_dir / "usr" / "share" / "icons" / "hicolor"

        opt_dir.mkdir(parents=True)
        usr_bin.mkdir(parents=True)
        usr_apps.mkdir(parents=True)
        usr_icons.mkdir(parents=True)

        # Copy bundle
        for item in bundle_dir.iterdir():
            dest = opt_dir / item.name
            if item.is_dir():
                shutil.copytree(item, dest)
            else:
                shutil.copy2(item, dest)
                if item.name == "bibliod":
                    dest.chmod(0o755)

        # Wrapper in /usr/bin/bibliod
        wrapper_script = usr_bin / "bibliod"
        wrapper_script.write_text("#!/bin/sh\nexec /opt/bibliod/bibliod \"$@\"\n")
        wrapper_script.chmod(0o755)

        # Desktop file
        shutil.copy2(packaging_dir / "bibliod.desktop", usr_apps / "bibliod.desktop")
        (usr_apps / "bibliod.desktop").chmod(0o644)

        # Scalable SVG Icon
        scalable_dir = usr_icons / "scalable" / "apps"
        scalable_dir.mkdir(parents=True)
        shutil.copy2(packaging_dir / "bibliod.svg", scalable_dir / "bibliod.svg")
        (scalable_dir / "bibliod.svg").chmod(0o644)

        # Raster PNG Icons
        for s in (16, 32, 48, 64, 128, 256, 512):
            png_src = packaging_dir / "icons" / f"{s}x{s}" / "bibliod.png"
            if png_src.exists():
                png_dest_dir = usr_icons / f"{s}x{s}" / "apps"
                png_dest_dir.mkdir(parents=True)
                shutil.copy2(png_src, png_dest_dir / "bibliod.png")
                (png_dest_dir / "bibliod.png").chmod(0o644)

        data_tar = tmp_dir / "data.tar.xz"
        with tarfile.open(data_tar, "w:xz") as tar:
            for root, dirs, files in os.walk(data_dir):
                for d in dirs:
                    full_p = Path(root) / d
                    rel_p = "." + str(full_p.relative_to(data_dir))
                    t_info = tar.gettarinfo(str(full_p), arcname=rel_p)
                    t_info.uid = 0
                    t_info.gid = 0
                    t_info.uname = "root"
                    t_info.gname = "root"
                    t_info.mode = 0o755
                    tar.addfile(t_info)
                for f in files:
                    full_p = Path(root) / f
                    rel_p = "." + str(full_p.relative_to(data_dir))
                    t_info = tar.gettarinfo(str(full_p), arcname=rel_p)
                    t_info.uid = 0
                    t_info.gid = 0
                    t_info.uname = "root"
                    t_info.gname = "root"
                    with open(full_p, "rb") as fl:
                        tar.addfile(t_info, fl)

        # 3. Assemble .deb using ar
        output_dir.mkdir(parents=True, exist_ok=True)
        cmd = [
            "ar", "rcs", str(output_deb),
            str(debian_binary),
            str(control_tar),
            str(data_tar),
        ]
        subprocess.run(cmd, check=True)
        print(f"Created Debian package: {output_deb} ({output_deb.stat().st_size} bytes)")

if __name__ == "__main__":
    project_dir = Path(__file__).resolve().parent.parent
    dist_dir = project_dir / "dist"
    create_deb_package(project_dir, dist_dir)
