"""Database-free checks for the committed data and generator reproducibility.

Run from the repository root:
    python3 -m unittest discover -s tests -v
"""
from __future__ import annotations

import csv
import subprocess
import sys
import tempfile
import unittest
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import validate_data  # noqa: E402  (path is set above for unittest discovery)

DATA = ROOT / "data"

GENERATED_FILES = (
    "customers.csv",
    "orders.csv",
    "order_items.csv",
    "dark_stores.csv",
    "delivery_logs.csv",
    "generation_summary.txt",
)

EXPECTED_COUNTS = {
    "customers": 30000,
    "orders": 100000,
    "items": 287810,
    "stores": 10,
    "logs": 100000,
}


def money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"))


class DataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.checks, cls.counts = validate_data.validate(
            DATA, DATA / "assumptions.csv"
        )

    def test_all_19_data_checks_pass(self) -> None:
        self.assertEqual(len(self.checks), 19)
        failures = [label for label, ok in self.checks.items() if not ok]
        self.assertEqual(failures, [])

    def test_table_row_counts_match_documentation(self) -> None:
        self.assertEqual(self.counts, EXPECTED_COUNTS)

    def test_headline_metrics_match_documentation(self) -> None:
        orders = validate_data.read(DATA / "orders.csv")
        logs = validate_data.read(DATA / "delivery_logs.csv")
        stores = validate_data.read(DATA / "dark_stores.csv")
        delivered = [r for r in orders if r["order_status"] == "delivered"]
        payout = {
            r["order_id"]: Decimal(r["rider_payout_inr"]) for r in logs
        }

        aov = sum(Decimal(r["order_value_inr"]) for r in delivered) / len(delivered)
        cm1 = sum(
            Decimal(r["product_margin_inr"])
            + Decimal(r["ad_income_inr"])
            + Decimal(r["customer_fee_inr"])
            - Decimal(r["platform_discount_inr"])
            for r in delivered
        ) / len(delivered)
        cm2 = sum(
            Decimal(r["product_margin_inr"])
            + Decimal(r["ad_income_inr"])
            + Decimal(r["customer_fee_inr"])
            - Decimal(r["platform_discount_inr"])
            - Decimal(r["picking_packing_cost_inr"])
            - payout[r["order_id"]]
            - Decimal(r["payment_cost_inr"])
            for r in delivered
        ) / len(delivered)

        days = len({r["order_date"] for r in orders})
        fixed_per_order = (
            sum(Decimal(s["daily_fixed_cost_inr"]) for s in stores)
            * days
            / len(delivered)
        )

        self.assertEqual((money(aov), money(cm1), money(cm2)), (
            Decimal("505.19"), Decimal("87.42"), Decimal("19.76")
        ))
        self.assertEqual(money(fixed_per_order), Decimal("26.85"))
        self.assertEqual(money(cm2 - fixed_per_order), Decimal("-7.08"))
        self.assertEqual(len(delivered), 96474)

    def test_assumption_ids_are_unique_and_complete(self) -> None:
        with (DATA / "assumptions.csv").open(newline="", encoding="utf-8-sig") as f:
            rows = list(csv.DictReader(f))
        ids = [r["id"] for r in rows]
        self.assertEqual(len(ids), 78)
        self.assertEqual(len(set(ids)), len(ids))
        self.assertTrue({"I01", "I02", "I03", "I07", "I11", "I17", "S22", "S27"} <= set(ids))

    def test_generation_summary_records_the_documented_run(self) -> None:
        text = (DATA / "generation_summary.txt").read_text(encoding="utf-8")
        self.assertIn("random_seed=42", text)
        self.assertIn("date_range=2026-04-01..2026-09-27 (180 days)", text)
        self.assertIn("customers=30000", text)
        self.assertIn("orders=100000", text)

    def test_regeneration_is_byte_identical(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "generated"
            subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "generate_synthetic_data.py"),
                    "--assumptions",
                    str(DATA / "assumptions.csv"),
                    "--output-dir",
                    str(output),
                ],
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
                timeout=300,
            )
            for name in GENERATED_FILES:
                self.assertEqual(
                    (DATA / name).read_bytes(),
                    (output / name).read_bytes(),
                    f"regenerated {name} differs from the committed file",
                )


if __name__ == "__main__":
    unittest.main()
