# Dataset Setup

Download the four source CSV files from:

https://www.datacareerschool.com/datalabs/ecommerce-sales-analysis

Required tables:

- `dbo.customers`
- `dbo.orders`
- `dbo.order_items`
- `dbo.products`

## Import with SQL Server Management Studio

1. Create or select the project database.
2. Right-click the database in SSMS.
3. Choose **Tasks → Import Flat File**.
4. Import each CSV with the table names shown above.
5. Confirm that `order_items.unit_price` allows `NULL`.
6. Select the same database from the SSMS database dropdown.
7. Run the SQL scripts from `01` through `07` in order.

The CSV files are intentionally excluded from the ZIP and should not be
committed to the public repository.
