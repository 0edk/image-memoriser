import math
import os
import os.path
import re
from typing import Optional
from anki.notes import Note
from aqt import AnkiQt
from aqt.qt import *
from aqt.utils import qconnect, tooltip

from .notes import links_from_points, note_from_links

Roles = QDialogButtonBox.ButtonRole

class FileLoadDialog(QMainWindow):
    def __init__(self, mw: AnkiQt, path: Optional[str] = None) -> None:
        super().__init__(mw)
        self.mw = mw
        if path is None:
            self.path, _ = QFileDialog.getOpenFileName(
                self, "Open file", os.environ["HOME"], "Image Memoriser (*)"
            )
        else:
            self.path = path
        self.setWindowTitle("Bidir path from file")
        layout = QVBoxLayout()
        if self.path:
            with open(self.path, "r") as f:
                lines = [line.strip().split(None, 2) for line in f
                    if line.strip()]
        else:
            self.close()
            return
        self.links = links_from_points([(int(x), int(y), label)
            for x, y, label in lines])
        display = QLabel()
        display.setText(f"{os.path.basename(self.path)}\n"
            f"\n{"\n".join(str(entry) for entry in self.links)}")
        scroll = QScrollArea()
        scroll.setWidget(display)
        layout.addWidget(scroll)
        box = QDialogButtonBox()
        buttons = [
            ("Cancel", Roles.RejectRole, self.close),
            ("Add selected", Roles.AcceptRole, self.accept),
        ]
        for label, role, action in buttons:
            button = box.addButton(label, role)
            assert button is not None
            if role == Roles.AcceptRole:
                button.setAutoDefault(True)
            else:
                button.setAutoDefault(False)
            qconnect(button.clicked, action)
        layout.addWidget(box)
        central = QWidget()
        central.setLayout(layout)
        self.setCentralWidget(central)
        vertical = scroll.verticalScrollBar()
        if vertical:
            vertical.setValue(vertical.maximum())
        self.showMaximized()

    def accept(self) -> None:
        col = self.mw.col
        note = note_from_links(self.links, os.path.basename(self.path), col)
        if note:
            default = col.decks.id_for_name("Default")
            assert default is not None
            col.add_note(note, default)
            tooltip(f"Added {len(self.links)}-link note")
            self.close()
        else:
            tooltip(f"Can't add note")

    def keyPressEvent(self, evt: QKeyEvent | None) -> None:
        if evt and evt.key() == Qt.Key.Key_Escape:
            self.close()
        else:
            super().keyPressEvent(evt)
