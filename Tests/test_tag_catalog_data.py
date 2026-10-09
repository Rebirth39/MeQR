import json
from pathlib import Path
import unittest


class TagCatalogDataTests(unittest.TestCase):
    def test_confirmed_color_fixes_and_complete_presets(self):
        path = Path(__file__).resolve().parents[1] / "QRID/QRID/tags-v1.json"
        document = json.loads(path.read_text())
        entries = {entry["id"]: entry for entry in document["entries"]}
        self.assertEqual(len(entries), len(document["entries"]), "Duplicate catalog IDs")
        self.assertTrue(entries)
        self.assertNotIn("tag-0006", entries)
        for entry in entries.values():
            self.assertGreater(len(entry["colors"]), 0)
            self.assertLessEqual(len(entry["colors"]), 6)
            self.assertIn(entry["solidColor"], entry["colors"])
            for color in entry["colors"]:
                self.assertRegex(color, r"^#[0-9A-F]{6}$")
            self.assertTrue(any(
                r["start"] <= entry["id"] <= r["end"]
                for c in document["categories"] for r in c["ranges"]
            ))
        for tag_id, color in {
            "tag-0110": "#E4007F", "tag-0352": "#FFB000",
            "tag-0353": "#FFE211", "tag-0355": "#D80000",
        }.items():
            self.assertEqual(entries[tag_id]["solidColor"], color)
        self.assertEqual(entries["tag-0001"]["colors"], [
            "#39C5BB", "#00A0E9", "#88DD44", "#FF9900", "#EE1166", "#884499",
        ])
        self.assertEqual(entries["tag-0001"]["solidColor"], "#00A0E9")
        self.assertEqual(entries["tag-0028"]["colors"], [
            "#39C5BB", "#FFB000", "#FFE211", "#FF69B4", "#D80000", "#0068B7",
        ])
        for tag_id in ["tag-0002", "tag-0005", "tag-0114", "tag-0115", "tag-0120", "tag-0130"]:
            self.assertGreaterEqual(len(entries[tag_id]["colors"]), 5)
        self.assertIn("wsmix", entries["tag-0005"]["aliases"])
        self.assertNotEqual(entries["tag-0145"]["names"]["en"], entries["tag-0146"]["names"]["en"])
        self.assertNotIn("妮可", entries["tag-0300"]["aliases"])
        self.assertNotIn("胡桃", entries["tag-0301"]["aliases"])

    def test_october_6_requested_tags(self):
        path = Path(__file__).resolve().parents[1] / "QRID/QRID/tags-v1.json"
        document = json.loads(path.read_text())
        entries = {entry["id"]: entry for entry in document["entries"]}
        avatar = entries["tag-0526"]
        aventurine = entries["tag-0527"]
        self.assertEqual(avatar["kind"], "work")
        self.assertNotIn("parentID", avatar)
        self.assertEqual(avatar["names"]["zhHans"], "全职高手")
        self.assertEqual(avatar["names"]["en"], "The King's Avatar")
        self.assertEqual(avatar["colors"], ["#D4AF37", "#000000"])
        self.assertEqual(aventurine["kind"], "character")
        self.assertEqual(aventurine["parentID"], "tag-0103")
        self.assertEqual(aventurine["names"]["en"], "Aventurine")
        self.assertEqual(aventurine["names"]["ja"], "アベンチュリン")
        self.assertEqual(aventurine["colors"], ["#D4AF37", "#008C8C"])
        for entry, category_id in [(avatar, "ip-the-kings-avatar"),
                                   (aventurine, "ip-honkai-star-rail")]:
            self.assertEqual(set(entry["names"]), {"zhHans", "zhHantHK", "zhHantTW", "en", "ja"})
            self.assertTrue(all(entry["names"].values()))
            self.assertEqual(entry["solidColor"], "#D4AF37")
            self.assertEqual([category["id"] for category in document["categories"]
                              if any(span["start"] <= entry["id"] <= span["end"]
                                     for span in category["ranges"])], [category_id])
            for name in list(entry["names"].values()) + entry["aliases"]:
                matches = [candidate["id"] for candidate in document["entries"]
                           if name.casefold() in [value.casefold() for value in
                              list(candidate["names"].values()) + candidate["aliases"]]]
                self.assertEqual(matches, [entry["id"]], name)

    def test_expansion_identity_and_palettes(self):
        path = Path(__file__).resolve().parents[1] / "QRID/QRID/tags-v1.json"
        document = json.loads(path.read_text())
        entries = {e["id"]: e for e in document["entries"]}
        names = {e["names"]["zhHans"]: e for e in entries.values()}
        self.assertEqual(names["凑友希那"]["solidColor"], "#881188")
        self.assertEqual(names["奥泽美咲"]["solidColor"], "#006699")
        self.assertEqual(names["米歇尔"]["solidColor"], "#DD33CC")
        self.assertEqual(names["Leo/need"]["solidColor"], "#4455DD")
        self.assertEqual(names["天马咲希"]["solidColor"], "#FFDD44")
        self.assertEqual(names["朝比奈真冬"]["solidColor"], "#8888CC")
        for child, parent in [("荧", "旅行者"), ("空", "旅行者"), ("丹恒·饮月", "丹恒"),
                              ("矢泽妮可", "μ's"), ("放学后茶会", "轻音少女"),
                              ("有刺无刺", "少女乐队的呐喊")]:
            self.assertEqual(names[child]["parentID"], names[parent]["id"])
        for entry in entries.values():
            seen = {entry["id"]}
            parent = entry.get("parentID")
            while parent:
                self.assertIn(parent, entries)
                self.assertNotIn(parent, seen, "Parent cycle")
                seen.add(parent)
                parent = entries[parent].get("parentID")
            self.assertEqual(sum(any(r["start"] <= entry["id"] <= r["end"] for r in c["ranges"])
                                 for c in document["categories"]), 1)
