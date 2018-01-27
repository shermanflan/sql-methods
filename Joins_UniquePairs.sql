USE TSQL2012;
GO

/*-----------------------------------------------------
 * Join semantics
 * The ON clause accepts TRUE (rejects UNKNOWN).
 * Table operators are logically processed from left to 
 * right. 
 * The result table of the first table operator is treated 
 * as the left input to the second table operator; the 
 * result of the second table operator is treated as the left 
 * input to the third table operator; and so on.
 *
 * CROSS JOIN: Cartesian product
 * INNER JOIN: Cartesian product > Filter
 * OUTER JOIN: Cartesian product > Filter > Add Outer Rows
 *	- i.e. an outer join returns both inner and outer rows	
 *-----------------------------------------------------*/

-- Produce unique pairs (non-equi join)
SELECT
	E1.empid, E1.firstname, E1.lastname,
	E2.empid, E2.firstname, E2.lastname
FROM HR.Employees AS E1
	INNER JOIN HR.Employees AS E2
		-- Excludes self pairs (=) and mirrored pairs (>)
		ON E1.empid < E2.empid;
