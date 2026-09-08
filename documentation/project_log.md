# Project Log

## Data Ingestion

### Issue identified

When I first imported `sales_pipeline.csv` directly into the typed MySQL table, the import appeared to complete successfully. However, my row-count check returned only **6,711 records**, rather than the **8,800 records** in the source file.

That left a difference of exactly **2,089 opportunities**, so I investigated before moving forward.

The missing records were not random. They represented every opportunity that was still open:

* **1,589** opportunities in the Engaging stage
* **500** opportunities in the Prospecting stage

These opportunities did not have closure dates or final deal values. Prospecting opportunities also did not yet have engagement dates. The direct import attempted to load these blank fields into typed `DATE` and `DECIMAL` columns, causing the affected rows to be excluded.

### Resolution

I introduced a staging table in which every field was initially stored as text. This allowed all 8,800 source records—including those with blank fields—to be imported without premature type conversion.

I then transferred the records into the properly typed raw table while explicitly converting legitimate blank account, date and value fields to SQL `NULL` values.

### Validation

After completing the revised import, I reconciled the results against the source file and confirmed:

* Won: **4,238**
* Lost: **2,473**
* Engaging: **1,589**
* Prospecting: **500**
* Total: **8,800**

The final raw-table count matched the source-file count, and all four expected deal stages were represented.

### Analytical decision

I retained the open opportunities because their missing closure information was appropriate for their current pipeline stages. An opportunity that has not closed should not be expected to have a closure date or final deal value.

Removing these records would have eliminated MavenTech’s entire active pipeline and distorted measures such as pipeline volume, stage distribution and opportunity ageing.

The issue therefore required an **import correction**, not the deletion of incomplete records.

This experience also reinforced an important validation principle: a successful import message does not necessarily mean that every source record was loaded. Row-count reconciliation was essential for identifying and resolving the problem.
