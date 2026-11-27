import importlib.util
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from uuid import uuid4

source = Path(__file__).resolve().parents[1] / "scripts" / "race-reservations.py"
spec = importlib.util.spec_from_file_location("race_reservations", source)
race = importlib.util.module_from_spec(spec)
spec.loader.exec_module(race)


class ReservationsTest(unittest.TestCase):
    def setUp(self):
        directory = TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.database = Path(directory.name) / "reservations.sqlite3"
        race.initialize(self.database)
        self.form = {
            "request_id": str(uuid4()),
            "nombre": "María",
            "apellidos": "García López",
            "email": "maria@example.invalid",
            "privacy": "yes",
            "adultos": "2",
            "ninos": "1",
            "menores": "0",
        }

    def test_retry_reuses_reference_and_rejects_changes(self):
        order = race.parse_order(self.form)
        created, reservation = race.save_order(self.database, order)
        repeated, retry = race.save_order(self.database, order)
        changed, _ = race.save_order(self.database, {**order, "adultos": 1})
        self.assertEqual((created, repeated, changed), (201, 200, 409))
        self.assertEqual(race.reference(reservation), race.reference(retry))

    def test_notification_matches_server_calculated_price(self):
        order = race.parse_order({**self.form, "total_cents": 1})
        _, reservation = race.save_order(self.database, order)
        email = race.make_message(reservation, "sender@example.invalid")
        self.assertEqual(str(email["To"]), "sanpablodelacruz@gmail.com")
        self.assertEqual(reservation["total_cents"], 3500)
        self.assertIn("CARRERA-0001 | María García López | 35,00 €", str(email["Subject"]))
        self.assertIn("Referencia / concepto de pago: CARRERA-0001", email.get_content())
        self.assertIn("Niños: 1 × 5,00 € = 5,00 €", email.get_content())

    def test_under_threes_are_free(self):
        order = race.parse_order({**self.form, "adultos": "0", "ninos": "0", "menores": "1"})
        _, reservation = race.save_order(self.database, order)
        email = race.make_message(reservation, "sender@example.invalid")
        self.assertEqual(reservation["total_cents"], 0)
        self.assertTrue(str(email["Subject"]).endswith("| Sin pago"))

    def test_invalid_and_empty_quantities(self):
        for value in ("-1", "100", "1.5", "0"):
            with self.subTest(value=value), self.assertRaises(race.InvalidOrder):
                race.parse_order({**self.form, "adultos": value, "ninos": "0"})

    def test_dorsal_zero_is_a_donation_without_bibs(self):
        donation = {**self.form, "adultos": "0", "ninos": "0", "donation_cents": 1250}
        _, saved = race.save_order(self.database, race.parse_order(donation))
        self.assertEqual(saved["total_cents"], 1250)
        message = race.make_message(saved, "sender@example.invalid")
        self.assertIn("Dorsal 0: 12,50 €", message.get_content())
        with self.assertRaises(race.InvalidOrder):
            race.parse_order({**donation, "adultos": "1"})
        with self.assertRaises(race.InvalidOrder):
            race.parse_order({**donation, "privacy": ""})
