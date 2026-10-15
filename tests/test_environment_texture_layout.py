"""Lossless cell addressing when a source ends inside its final page."""
from PIL import Image

from tools.prepare_environment_texture_layout import paginate


def test_partial_final_page_preserves_all_rgba_cells_and_source(tmp_path):
    source = tmp_path / 'numeric-source.png'
    original = Image.new('RGBA', (9, 6))
    original.putdata([(x * 19, y * 31, (x + y) * 13, (x * 23 + y * 7) % 256)
                      for y in range(6) for x in range(9)])
    original.save(source)
    before = source.read_bytes()
    layout = paginate(str(source), (3, 2), str(tmp_path / 'pages'), (6, 4))
    assert layout['verified_cells'] == 9
    assert len(layout['pages']) == 3
    for index in range(9):
        with Image.open(layout['pages'][index // 4]) as page:
            x, y = (index % 3) * 3, (index // 3) * 2
            dx, dy = (index % 4 % 2) * 3, (index % 4 // 2) * 2
            assert page.crop((dx, dy, dx + 3, dy + 2)).tobytes() == original.crop((x, y, x + 3, y + 2)).tobytes()
    with Image.open(layout['pages'][-1]) as page:
        assert page.crop((3, 0, 6, 4)).getbbox() is None
        assert page.crop((0, 2, 3, 4)).getbbox() is None
    assert source.read_bytes() == before
