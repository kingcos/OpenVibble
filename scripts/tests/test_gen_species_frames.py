import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from gen_species_frames import parse_species_file


def test_parses_simple_state():
    cpp = Path(__file__).parent / "fixtures" / "sample_buddy.cpp"
    result = parse_species_file(cpp)
    assert result["name"] == "sample"
    idle = result["states"]["idle"]
    assert idle["frames"] == [
        ["A","B","C","D","E"],
        ["a","b","c","d","e"],
    ]
    assert idle["seq"] == [0, 1, 0]
    assert idle["color_rgb565"] == 0xC2A6
