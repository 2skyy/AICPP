import unittest

from app.constants.region_codes import REGION_ZIP_CODES, zip_codes_for


class RegionCodesTest(unittest.TestCase):
    def test_covers_every_code_extracted_from_the_live_api_exactly_once(self):
        # These 254 codes were pulled directly from a real nationwide policy's
        # zipCd field (see region_codes.py docstring) — every one should be
        # assigned to exactly one region, with none dropped or duplicated.
        all_codes = [code for codes in REGION_ZIP_CODES.values() for code in codes]
        self.assertEqual(len(all_codes), 254)
        self.assertEqual(len(all_codes), len(set(all_codes)))

    def test_every_code_is_five_digits(self):
        for region, codes in REGION_ZIP_CODES.items():
            for code in codes:
                self.assertRegex(code, r"^\d{5}$", f"{region} has a malformed code: {code}")

    def test_zip_codes_for_known_region(self):
        self.assertEqual(zip_codes_for("세종특별자치시"), ["36110"])

    def test_zip_codes_for_unknown_or_missing_region(self):
        self.assertIsNone(zip_codes_for("존재하지않는지역"))
        self.assertIsNone(zip_codes_for(None))


if __name__ == "__main__":
    unittest.main()
