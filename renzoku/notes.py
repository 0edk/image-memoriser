import math
import re
from typing import Optional
import aqt
from anki.collection import Collection
from anki.notes import Note

from .models import chain_model

FORMAT_SYNTAX: list[tuple[re.Pattern, str]] = [(re.compile(s), d) for s, d in [
    ("`([^`]+)`", r"<code>\1</code>"),
    (r"\$([^$]+)\$", r"\(\1\)"),
    (r"\^\(([^)]+)\)", r"<sup>\1</sup>"),
    (r"_\(([^)]+)\)", r"<sub>\1</sub>"),
]]

def format_field(field: Optional[str]) -> Optional[str]:
    if isinstance(field, str):
        for short, long in FORMAT_SYNTAX:
            field = short.sub(long, field)
    return field

def note_from_links(
    links: list[tuple[str, str, str]], context: str, col: Collection,
) -> Optional[Note]:
    # https://stackoverflow.com/a/14267825
    n = 1 << (len(links) - 1).bit_length()
    if n <= 32:
        model_name = f"Chain [{n}]"
        model = col.models.id_for_name(model_name)
        if model is None:
            col.models.add_dict(chain_model(n, col))
            model = col.models.id_for_name(model_name)
        note = Note(col, model)
        note["Context"] = context
        for field_index, (node, out_dir, in_dir) in enumerate(links):
            note[f"Node {field_index + 1}"] = format_field(node) or ""
            if field_index < len(links) - 1:
                note[f"Edge {field_index + 1} {field_index + 2}"] = out_dir
                note[f"Edge {field_index + 2} {field_index + 1}"] = in_dir
        return note
    return None

def vector_to_direction(dx: float, dy: float) -> str:
    critical = 1 + math.sqrt(2)
    return ((("N", "S")[dy > 0] if critical * abs(dy) > abs(dx) else "") +
        (("E", "W")[dx < 0] if abs(dy) < critical * abs(dx) else ""))

def opposite_direction(direction: str) -> str:
    opposites = {"N": "S", "S": "N", "E": "W", "W": "E"}
    return "".join(opposites[c] for c in direction)

def links_from_points(
    points: list[tuple[int, int, str]]
) -> list[tuple[str, str, str]]:
    links = []
    for i, (x1, y1, label) in enumerate(points):
        if i == len(points) - 1:
            links.append((label, "", ""))
        else:
            x2, y2, _ = points[i + 1]
            direction = vector_to_direction(x2 - x1, y2 - y1)
            links.append((label, direction, opposite_direction(direction)))
    return links
