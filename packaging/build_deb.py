#!/usr/bin/env python3
import os
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

def get_package_version(project_root: Path) -> str:
    if "APP_VERSION" in os.environ and os.environ["APP_VERSION"].strip():
        return os.environ["APP_VERSION"].strip()
    pubspec = project_root / "pubspec.yaml"
    if pubspec.exists():
        for line in pubspec.read_text(encoding="utf-8").splitlines():
            if line.startswith("version:"):
                raw = line.split(":", 1)[1].strip().strip('"').strip("'")
                base_ver = raw.split("+")[0]
                return f"{base_ver}-1"
    return "1.0.1-1"

def build_deb_fallback(staging_dir: Path, output_deb: Path, tmp_dir: Path):
    """Builds a .deb archive manually using ar and tar without PAX headers."""
    debian_binary = tmp_dir / "debian-binary"
    debian_binary.write_text("2.0\n", encoding="utf-8")

    # 1. control.tar.gz
    control_tar = tmp_dir / "control.tar.gz"
    debian_dir = staging_dir / "DEBIAN"
    with tarfile.open(control_tar, "w:gz", format=tarfile.GNU_FORMAT) as tar:
        for item in sorted(debian_dir.iterdir()):
            if not item.is_file():
                continue
            ti = tar.gettarinfo(str(item), arcname=f"./{item.name}")
            ti.uid = 0
            ti.gid = 0
            ti.uname = "root"
            ti.gname = "root"
            ti.mtime = int(ti.mtime)
            ti.pax_headers = {}
            if item.name in ("postinst", "postrm"):
                ti.mode = 0o755
            else:
                ti.mode = 0o644
            with open(item, "rb") as f:
                tar.addfile(ti, f)

    # 2. data.tar.xz
    data_tar = tmp_dir / "data.tar.xz"
    with tarfile.open(data_tar, "w:xz", format=tarfile.GNU_FORMAT) as tar:
        for root, dirs, files in os.walk(staging_dir):
            root_path = Path(root)
            # Skip the DEBIAN directory
            if root_path == debian_dir or debian_dir in root_path.parents:
                continue

            # Sort dirs and files for deterministic packaging
            dirs.sort()
            files.sort()

            # Add directories with proper ./ prefix
            if root_path != staging_dir:
                rel_dir = root_path.relative_to(staging_dir)
                arcname = f"./{rel_dir}"
                ti = tar.gettarinfo(str(root_path), arcname=arcname)
                ti.uid = 0
                ti.gid = 0
                ti.uname = "root"
                ti.gname = "root"
                ti.mtime = int(ti.mtime)
                ti.pax_headers = {}
                ti.mode = 0o755
                tar.addfile(ti)

            # Add files with proper ./ prefix
            for f in files:
                full_f = root_path / f
                rel_f = full_f.relative_to(staging_dir)
                arcname = f"./{rel_f}"
                ti = tar.gettarinfo(str(full_f), arcname=arcname)
                ti.uid = 0
                ti.gid = 0
                ti.uname = "root"
                ti.gname = "root"
                ti.mtime = int(ti.mtime)
                ti.pax_headers = {}
                if full_f.name == "bibliod" or full_f.parent.name == "bin":
                    ti.mode = 0o755
                else:
                    ti.mode = 0o644
                with open(full_f, "rb") as fp:
                    tar.addfile(ti, fp)

    # 3. Assemble .deb with ar
    cmd = [
        "ar", "rcs", str(output_deb),
        str(debian_binary),
        str(control_tar),
        str(data_tar),
    ]
    subprocess.run(cmd, check=True)

def create_deb_package(project_root: Path, output_dir: Path):
    version = get_package_version(project_root)
    pkg_name = "bibliod"
    deb_filename = f"{pkg_name}_{version}_amd64.deb"
    output_deb = output_dir / deb_filename

    bundle_dir = project_root / "build" / "linux" / "x64" / "release" / "bundle"
    if not bundle_dir.exists():
        raise FileNotFoundError(f"Bundle directory does not exist: {bundle_dir}")

    packaging_dir = project_root / "packaging"

    with tempfile.TemporaryDirectory() as tmp_dir_str:
        tmp_dir = Path(tmp_dir_str)
        staging_dir = tmp_dir / "pkg_root"
        debian_dir = staging_dir / "DEBIAN"
        debian_dir.mkdir(parents=True)
        staging_dir.chmod(0o755)

        installed_size_kb = sum(
            f.stat().st_size for f in bundle_dir.glob("**/*")
            if f.is_file() and not f.is_symlink()
        ) // 1024

        control_content = f"""Package: {pkg_name}
Version: {version}
Section: utils
Priority: optional
Architecture: amd64
Installed-Size: {installed_size_kb}
Depends: libc6 (>= 2.34), libgtk-3-0 (>= 3.24.0) | libgtk-3-0t64, libglib2.0-0 (>= 2.64.0) | libglib2.0-0t64, libsqlite3-0 (>= 3.31.0)
Maintainer: Dvim-dev <dvimdev@proton.me>
Homepage: https://github.com/dvim-dev/bibliod
Description: Application moderne de gestion de bibliothèque personnelle
 BiblioD est une application simple de gestion de bibliothèque, avec
 recherche omnibox, recherche auteur sur Wikipedia et interrogation
 du catalogue mondial Open Library.
"""
        (debian_dir / "control").write_text(control_content, encoding="utf-8")
        (debian_dir / "control").chmod(0o644)

        postinst_content = """#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q /usr/share/applications || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
    fi
fi
exit 0
"""
        postinst = debian_dir / "postinst"
        postinst.write_text(postinst_content, encoding="utf-8")
        postinst.chmod(0o755)

        postrm_content = """#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q /usr/share/applications || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
    fi
fi
exit 0
"""
        postrm = debian_dir / "postrm"
        postrm.write_text(postrm_content, encoding="utf-8")
        postrm.chmod(0o755)

        # 2. Build filesystem layout
        opt_dir = staging_dir / "opt" / "bibliod"
        usr_bin = staging_dir / "usr" / "bin"
        usr_apps = staging_dir / "usr" / "share" / "applications"
        usr_icons = staging_dir / "usr" / "share" / "icons" / "hicolor"
        usr_pixmaps = staging_dir / "usr" / "share" / "pixmaps"

        opt_dir.mkdir(parents=True)
        usr_bin.mkdir(parents=True)
        usr_apps.mkdir(parents=True)
        usr_icons.mkdir(parents=True)
        usr_pixmaps.mkdir(parents=True)

        # Copy bundle to /opt/bibliod/
        for item in bundle_dir.iterdir():
            dest = opt_dir / item.name
            if item.is_dir():
                shutil.copytree(item, dest, symlinks=True)
            else:
                shutil.copy2(item, dest)
                if item.name == "bibliod":
                    dest.chmod(0o755)

        # Wrapper in /usr/bin/bibliod
        wrapper_script = usr_bin / "bibliod"
        wrapper_script.write_text("#!/bin/sh\nexec /opt/bibliod/bibliod \"$@\"\n", encoding="utf-8")
        wrapper_script.chmod(0o755)

        # Desktop file
        shutil.copy2(packaging_dir / "bibliod.desktop", usr_apps / "bibliod.desktop")
        (usr_apps / "bibliod.desktop").chmod(0o644)

        # Scalable SVG Icon
        scalable_dir = usr_icons / "scalable" / "apps"
        scalable_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(packaging_dir / "bibliod.svg", scalable_dir / "bibliod.svg")
        (scalable_dir / "bibliod.svg").chmod(0o644)

        # Pixmaps fallback
        shutil.copy2(packaging_dir / "bibliod.svg", usr_pixmaps / "bibliod.svg")
        (usr_pixmaps / "bibliod.svg").chmod(0o644)

        # Raster PNG Icons
        for s in (16, 32, 48, 64, 128, 256, 512):
            png_src = packaging_dir / "icons" / f"{s}x{s}" / "bibliod.png"
            if png_src.exists():
                png_dest_dir = usr_icons / f"{s}x{s}" / "apps"
                png_dest_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(png_src, png_dest_dir / "bibliod.png")
                (png_dest_dir / "bibliod.png").chmod(0o644)
                if s == 256:
                    shutil.copy2(png_src, usr_pixmaps / "bibliod.png")
                    (usr_pixmaps / "bibliod.png").chmod(0o644)

        output_dir.mkdir(parents=True, exist_ok=True)

        # Check if dpkg-deb is available
        dpkg_deb_bin = shutil.which("dpkg-deb")
        if dpkg_deb_bin:
            print(f"Building .deb using official tool: {dpkg_deb_bin}...")
            # Fix permissions of all directories and files before calling dpkg-deb
            for root, dirs, files in os.walk(staging_dir):
                for d in dirs:
                    (Path(root) / d).chmod(0o755)
                for f in files:
                    p = Path(root) / f
                    if p.name in ("bibliod", "postinst", "postrm") or p.parent == usr_bin or (p.parent == opt_dir and p.name == "bibliod"):
                        p.chmod(0o755)
                    else:
                        p.chmod(0o644)

            cmd = [
                dpkg_deb_bin,
                "-Zxz",
                "--root-owner-group",
                "--build",
                str(staging_dir),
                str(output_deb),
            ]
            subprocess.run(cmd, check=True)
        else:
            print("Info: dpkg-deb not found. Using pure Python fallback...")
            build_deb_fallback(staging_dir, output_deb, tmp_dir)

        print(f"Created Debian package: {output_deb} ({output_deb.stat().st_size} bytes)")

if __name__ == "__main__":
    project_dir = Path(__file__).resolve().parent.parent
    dist_dir = project_dir / "dist"
    create_deb_package(project_dir, dist_dir)
