-- Creates the Glue Data Catalog database `movielens` that holds all project tables.
-- Run with: .\aws\athena_run.ps1 aws\athena\ddl\00_database.sql

CREATE DATABASE IF NOT EXISTS movielens
COMMENT 'BDF MovieLens 32M project tables';
