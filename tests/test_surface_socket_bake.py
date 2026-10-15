"""Offline socket export boundaries; no runtime or artwork mutation."""
import json
from pathlib import Path

import pytest
from PIL import Image

from tools import bake_surface_socket_samples as baker


def rig_data():
    return {"rigs": {"neuroclient.modular": {
        "cell_width": 8, "cell_height": 8, "body_anchor": {"x": 2.9, "y": 3.1},
        "facing_rows": {"E": 0, "W": 1},
        "pose_sockets": {"hand": {"Idle": {"E": [{"x": 5.8, "y": 6.2}]}}},
        "clips": {"Idle": {"frames": 3, "sheets": {"Body": "/native/selected.png"}}}}},
        "spells": [{"cast": {"actionClip": "Idle", "releaseFrame": 2}, "banks": [
            {"rig": "", "sockets": {"release": {"W": {"x": 7.1, "y": 1.4}},
                                     "preparation": {"E": [None, {"x": 1.7, "y": 2.6}, None, {"x": 6, "y": 6}]}}}]}],
        "resources": {"/native/selected.png": "/media/selected.png"}, "sheet_components": {}}


def test_exact_authored_frame_view_floor_and_short_pose_hold():
    points = baker.authored_points(rig_data())["neuroclient.modular", "Idle"]
    assert (18, 3) in points  # Anchor at actual final source frame.
    assert (21, 6) in points  # Production holds the last shorter pose point.
    assert (23, 9) in points  # Exact W release, frame2 and row1.
    assert (9, 2) in points  # Authored preparation frame1.
    assert (30, 6) not in points  # No frame3 outside the real source clip.
    assert baker.point({"x": float("nan"), "y": 2}, 8, 8) is None
    assert baker.point({"x": 8, "y": 2}, 8, 8) is None


def test_effective_clip_sheet_mapping_and_registered_aliases():
    data = rig_data()
    points = baker.authored_points(data)
    modular = {"records": {"/media/other.png": {"source_action": "Unknown"}}}
    creatures = {"records": {"/media/creature.png": {"registered_aliases": [
        {"rig": "neuroclient.modular", "clip": "Idle"}]}}}
    mapped = baker.source_points(data, points, modular, creatures)
    assert mapped["/media/selected.png"] == points["neuroclient.modular", "Idle"]
    assert mapped["/media/creature.png"] == points["neuroclient.modular", "Idle"]
    assert "/media/other.png" not in mapped


def test_original_png_channel_bytes_are_exact(tmp_path):
    paths = {}
    for name, colour in {"depth": (118, 7, 3, 64), "support": (129, 0, 0, 255),
                         "solid": (255, 0, 0, 255)}.items():
        path = tmp_path / (name + ".png")
        Image.new("RGBA", (4, 3), colour).save(path)
        paths[name] = path
    size, values = baker.sample_bytes(paths, {(2, 1)})
    assert size == [4, 3]
    assert values == {"2,1": [118, 64, 129, 255]}
    with pytest.raises(ValueError, match="outside"):
        baker.sample_bytes(paths, {(4, 0)})


def test_incremental_partial_bake_cannot_bless_old_authoring(tmp_path, monkeypatch):
    monkeypatch.setattr(baker, "PROJECT", tmp_path)
    geometry = tmp_path / "generated"
    geometry.mkdir()
    optical = tmp_path / "optical"
    optical.mkdir()
    for name in ("depth", "support", "solid-valid"):
        Image.new("RGBA", (24, 16), (118, 0, 0, 255)).save(optical / (name + ".png"))
    original = {p: (p.read_bytes(), baker.stamp(p)) for p in optical.iterdir()}
    records = {source: {"source_action": "Idle", "reference": "reference.json",
                        "files": {"depth": "depth.png", "support": "support.png"}}
               for source in ("/media/one.png", "/media/two.png")}
    (geometry / "character_geometry.json").write_text(json.dumps({"records": records}))
    (geometry / "creature_geometry.json").write_text(json.dumps({"records": {}}))
    authoring = tmp_path / "native.tres"
    authoring.write_text("authored")
    data = rig_data() | {"authoring_inputs": {str(authoring): baker.stamp(authoring)},
                         "roots": {"character_geometry_root": str(optical), "creature_geometry_root": str(optical)},
                         "gallery_sources": ["/media/one.png"]}
    output = tmp_path / "derived"
    first = baker.bake(data, output)
    assert first["written"] == 2
    partial = baker.bake(data, output, gallery=True)
    assert partial["reused"] == 1 and (output / "two.json").is_file()
    authoring.write_text("changed authored source")
    with pytest.raises(ValueError, match="stale"):
        baker.bake(data, output, gallery=True)
    data["authoring_inputs"][str(authoring)] = baker.stamp(authoring)
    baker.bake(data, output, gallery=True)
    assert not (output / "two.json").exists()
    assert (output / "one.json").is_file()
    assert all((p.read_bytes(), baker.stamp(p)) == before for p, before in original.items())
