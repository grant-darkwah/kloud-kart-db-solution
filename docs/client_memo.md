# Memo to Nana

**From:** Grant Sarfo Darkwah
**Date:** 27 November 2026
**Subject:** Improving Kloud Kart's Inventory, Reporting and Stock Management

## What I found

My review identified several issues that could affect Kloud Kart's daily operations and the accuracy of its business reports.

Some sales records were not properly linked to customer or order information. I also found differences between the amounts recorded for certain orders and the value of the items included in those orders. In addition, some products had negative stock figures, while parts of the product category structure were incomplete or incorrectly organised.

These issues make it harder to rely on the information when making decisions about sales, stock levels and customer spending.

## What I built

I have completed and tested improvements addressing the four areas you identified.

| What you asked for | Status | Evidence |
|---|---|---|
| Prevent two customers from purchasing the last available item at the same time. | **Completed and tested** | Across 25 tests involving two customers competing for the last item, only one customer successfully purchased it in every test. |
| Make the Monday spending report available quickly. | **Completed and tested** | The report took an average of approximately 17 milliseconds to run in the test environment. |
| See low-stock products across the full product category structure. | **Completed and tested** | The report identified 1,358 low-stock products, representing 5,034 units across the category structure. |
| Keep a record of changes to stock levels. | **Completed and tested, with limitations** | Stock changes are now automatically recorded, including the quantity before and after each change. Ordinary attempts to alter or delete these records are blocked. |

I also tested a high-demand sales scenario involving 400 customers competing for 50 available units. Exactly 50 purchases succeeded, while the remaining 350 were declined. No errors occurred during the test.

## What I recommend

I recommend that all customer purchases follow the new purchasing process to prevent multiple customers from being allocated the same available stock.

The Monday spending report can now support regular business reporting. However, the differences identified in 2,279 historical orders should be reviewed against the original sales records before those figures are used for financial corrections or formal reconciliation.

The inventory team should also review products with negative stock figures and categories with incomplete records. Correcting these issues will improve the reliability of future stock reports.

Finally, access to stock records should be limited to authorised personnel to protect the accuracy of inventory information.

## What I could not stand behind

The improvements provide better visibility and control, but some existing data problems remain unresolved.

I cannot confirm that every historical stock movement has a complete record. Some older records do not contain enough information to establish the exact stock quantity before and after a movement or identify the individual responsible.

The system records the account used to make a stock change, but this does not always identify the employee who performed it. Authorised database administrators may also bypass some of the protections.

I also cannot confirm that all historical sales totals are correct. The 2,279 differences identified during the review require further investigation.

Finally, the performance results were measured in a test environment. Actual performance may vary under live business conditions.

The improvements have passed the final testing process. I recommend a controlled review and backup before introducing them into the live business environment.