# Power BI status — verified inventory and acceptance criteria

**Status: in progress.** This file records what can be checked without Power BI
Desktop. It is not a claim that the dashboard is finished.

## 1. What was inspected

On 17 November 2026 the committed
`powerbi/quick_commerce_profitability.pbix` (16,626,400 bytes) was opened as a
ZIP package and its report definition JSON was read. No Power BI Desktop was
available, so the report was **not rendered**, and no measure value, visual
layout or relationship was verified inside Power BI itself.

## 2. Verified inventory

| Item | Observed |
|---|---|
| Package integrity | Valid ZIP; 17 entries; `DataModel` and `Report/definition/` present |
| Pages | 1 page, `Page 1` (`a771e3159ce53a287b54`) |
| Visuals | 5 card visuals, no charts, tables, slicers or text boxes |
| Card measures | `Total Orders`, `Delivered Orders`, `Delivered GMV`, `AOV`, `Orders per Store per Day` |
| Screenshots | No `docs/images/` directory and no PNG/JPG in the repository |
| README status | “The two-tab Power BI dashboard and the final screenshots are still in progress.” |

`Delivered GMV` is used by one card but is **not defined** in
`powerbi/measures.md`, which defines `Delivered Net Order Value`. The name must
be aligned before the report is called complete.

The expected measure values are already listed in section 3 of
[`powerbi/measures.md`](../powerbi/measures.md). They are SQL-derived targets,
not observed Power BI outputs.

## 3. Acceptance criteria before calling the dashboard complete

- [ ] Align the card measure name (`Delivered GMV` vs `Delivered Net Order Value`).
- [ ] Add the second page planned in the README; the current file has one page.
- [ ] Add visuals for store contribution/ranking, contribution trend, rain and stockout comparisons, and the four lever sensitivities.
- [ ] Open the report in Power BI Desktop and confirm every measure in `powerbi/measures.md` matches its expected value.
- [ ] Confirm no ambiguous relationship path was introduced (the model must not add `delivery_logs[store_id] → dark_stores[store_id]` alongside the order path).
- [ ] Export screenshots to `docs/images/` and link them from `README.md`.
- [ ] Record the refresh path for `data/*.csv` in the README.

Until every box is checked, describe the deliverable as a **Power BI model and
measure specification with a starter report**, not a completed dashboard.
