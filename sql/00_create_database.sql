/*
  CoopCore - Script 00
  Archivo: 00_create_database.sql
  Fase: Control de acceso (Tema 1)
  Objetivo: Crear la base de datos CoopCoreDB.
  Nota: Script idempotente.
*/

USE master;
GO

IF DB_ID(N'CoopCoreDB') IS NULL
BEGIN
    PRINT N'Creando la base de datos CoopCoreDB...';
    CREATE DATABASE CoopCoreDB;
END
ELSE
BEGIN
    PRINT N'La base de datos CoopCoreDB ya existe. No se realiza creacion.';
END;
GO
