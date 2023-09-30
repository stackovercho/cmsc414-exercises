-- Find the phone number for "Mini Wheels Co." 
SELECT phone FROM customers WHERE customerName = "Mini Wheels Co.";

-- Get all the customers in France
SELECT * FROM customers WHERE country = "France";

-- Get the names and credit limits of all the customers and sort in ascending order
SELECT customerName, creditLimit FROM customers ORDER BY customerName;

-- Get the names of all cities where more than one customer lives
-- SELECT COUNT(*), city FROM customers GROUP BY city HAVING COUNT(*) > 1;
SELECT city FROM customers GROUP BY city HAVING COUNT(*) > 1;
