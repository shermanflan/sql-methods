USE AdventureWorks2017;
GO

-- List unused indexes
SELECT	OBJECT_NAME(i.[object_id]) AS [Table Name] 
		, i.name
FROM	sys.indexes AS i
	INNER JOIN sys.objects AS o 
		ON i.[object_id] = o.[object_id]
WHERE	i.index_id NOT IN (	SELECT	ddius.index_id
							FROM	sys.dm_db_index_usage_stats AS ddius
							WHERE	ddius.[object_id] = i.[object_id]
									AND i.index_id = ddius.index_id
									AND database_id = DB_ID() )
		AND o.[type] = 'U'
ORDER BY [Table Name] ASC;

-- Identify indexes that are being maintained but not used
SELECT	'[' + DB_NAME() + '].[' + su.[name] + '].[' + o.[name] + ']' AS [statement] 
		, i.[name] AS [index_name] 
		, ddius.[user_seeks] + ddius.[user_scans] + ddius.[user_lookups] AS [user_reads]
		, ddius.[user_updates] AS [user_writes]
		, SUM(SP.rows) AS [total_rows]
		, 'DROP INDEX [' + i.[name] + '] ON [' + su.[name] + '].[' + o.[name]
			+ '] WITH ( ONLINE = OFF )' AS [drop_command]
FROM	sys.dm_db_index_usage_stats ddius
	INNER JOIN sys.indexes i 
		ON	ddius.[object_id] = i.[object_id]
			AND i.[index_id] = ddius.[index_id]
	INNER JOIN sys.partitions SP 
		ON	ddius.[object_id] = SP.[object_id]
			AND SP.[index_id] = ddius.[index_id]
	INNER JOIN sys.objects o 
		ON ddius.[object_id] = o.[object_id]
	INNER JOIN sys.sysusers su 
		ON o.[schema_id] = su.[UID]
WHERE	ddius.[database_id] = DB_ID() -- current database only
		AND OBJECTPROPERTY(ddius.[object_id], 'IsUserTable') = 1
		AND ddius.[index_id] > 0
GROUP BY	su.[name] ,
			o.[name] ,
			i.[name] ,
			ddius.[user_seeks] + ddius.[user_scans] + ddius.[user_lookups] ,
			ddius.[user_updates]
HAVING ddius.[user_seeks] + ddius.[user_scans] + ddius.[user_lookups] = 0
ORDER BY ddius.[user_updates] DESC ,
			su.[name] ,
			o.[name] ,
			i.[name];

-- Potentially inefficient non-clustered indexes (writes > reads)
SELECT	OBJECT_NAME(ddius.[object_id]) AS [Table Name]
		, i.name AS [Index Name]
		, i.index_id
		, user_updates AS [Total Writes]
		, user_seeks + user_scans + user_lookups AS [Total Reads]
		, user_updates - ( user_seeks + user_scans + user_lookups ) AS [Difference]
FROM	sys.dm_db_index_usage_stats AS ddius WITH ( NOLOCK )
	INNER JOIN sys.indexes AS i WITH ( NOLOCK )
		ON ddius.[object_id] = i.[object_id]
			AND i.index_id = ddius.index_id
WHERE OBJECTPROPERTY(ddius.[object_id], 'IsUserTable') = 1
		AND ddius.database_id = DB_ID()
		AND user_updates > ( user_seeks + user_scans + user_lookups )
		AND i.index_id > 1
ORDER BY [Difference] DESC ,
		[Total Writes] DESC ,
		[Total Reads] ASC ;

-- Detailed activity information for indexes not used for user reads
SELECT '[' + DB_NAME() + '].[' + su.[name] + '].[' + o.[name] + ']' AS [statement] ,
		i.[name] AS [index_name] ,
		ddius.[user_seeks] + ddius.[user_scans] + ddius.[user_lookups] AS [user_reads] ,
		ddius.[user_updates] AS [user_writes] ,
		ddios.[leaf_insert_count] ,
		ddios.[leaf_delete_count] ,
		ddios.[leaf_update_count] ,
		ddios.[nonleaf_insert_count] ,
		ddios.[nonleaf_delete_count] ,
		ddios.[nonleaf_update_count]
FROM sys.dm_db_index_usage_stats ddius
	INNER JOIN sys.indexes i 
		ON ddius.[object_id] = i.[object_id]
			AND i.[index_id] = ddius.[index_id]
	INNER JOIN sys.partitions SP 
		ON ddius.[object_id] = SP.[object_id]
			AND SP.[index_id] = ddius.[index_id]
	INNER JOIN sys.objects o 
		ON ddius.[object_id] = o.[object_id]
	INNER JOIN sys.sysusers su 
		ON o.[schema_id] = su.[UID]
	INNER JOIN sys.[dm_db_index_operational_stats](DB_ID(), NULL, NULL, NULL) AS ddios
		ON ddius.[index_id] = ddios.[index_id]
			AND ddius.[object_id] = ddios.[object_id]
			AND SP.[partition_number] = ddios.[partition_number]
			AND ddius.[database_id] = ddios.[database_id]
WHERE OBJECTPROPERTY(ddius.[object_id], 'IsUserTable') = 1
	AND ddius.[index_id] > 0
	AND ddius.[user_seeks] + ddius.[user_scans] + ddius.[user_lookups] = 0
ORDER BY ddius.[user_updates] DESC ,
		su.[name] ,
		o.[name] ,
		i.[name];

-- MISSING INDEXES
SELECT user_seeks * avg_total_user_cost * ( avg_user_impact * 0.01 ) AS [index_advantage] ,
		dbmigs.last_user_seek ,
		dbmid.[statement] AS [Database.Schema.Table] ,
		dbmid.equality_columns ,
		dbmid.inequality_columns ,
		dbmid.included_columns ,
		dbmigs.unique_compiles ,
		dbmigs.user_seeks ,
		dbmigs.avg_total_user_cost ,
		dbmigs.avg_user_impact
FROM sys.dm_db_missing_index_group_stats AS dbmigs WITH ( NOLOCK )
	INNER JOIN sys.dm_db_missing_index_groups AS dbmig WITH ( NOLOCK )
		ON dbmigs.group_handle = dbmig.index_group_handle
	INNER JOIN sys.dm_db_missing_index_details AS dbmid WITH ( NOLOCK )
		ON dbmig.index_handle = dbmid.index_handle
WHERE dbmid.[database_id] = DB_ID()
ORDER BY index_advantage DESC ;