USE ScratchDB;
GO

-- DDL Trigger
IF OBJECT_ID(N'sp_TriggerDDL', N'TR') IS NOT NULL
	DROP TRIGGER sp_TriggerDDL ON DATABASE;
GO

CREATE TRIGGER sp_TriggerDDL
ON DATABASE -- ALL SERVER
-- Events (Server level): CREATE_DATABASE, ALTER_DATABASE, etc.
-- Events (DB level): DROP_TABLE, ALTER_TABLE, DROP_SYNONYM, etc.
-- Event Groups: DDL_DATABASE_LEVEL_EVENTS, DDL_USER_EVENTS, DDL_TABLE_EVENTS
AFTER CREATE_TABLE, DROP_TABLE 
AS 
   THROW 50000, 'CREATE/DROP TABLE RESTRICTED BY TRIGGER', 0;
GO

USE master;
GO

-- Logon Trigger
IF EXISTS(SELECT * FROM sys.server_triggers WHERE name = N'sp_TriggerLogin')
	DROP TRIGGER sp_TriggerLogin ON ALL SERVER;
GO

CREATE TRIGGER sp_TriggerLogin
ON ALL SERVER 
--WITH EXECUTE AS 'login3'
AFTER LOGON
AS
BEGIN
	IF ORIGINAL_LOGIN() = 'login3'
		THROW 50000, 'LOGIN CANCELLED BY TRIGGER', 0;
END;
GO