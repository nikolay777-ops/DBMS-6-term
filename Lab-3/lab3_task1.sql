ALTER SESSION SET "_ORACLE_SCRIPT"=true;
CREATE USER dev_schema IDENTIFIED BY 1;
CREATE USER prod_schema IDENTIFIED BY 1;

grant create session to dev_schema;
grant create table to dev_schema;
grant create procedure to dev_schema;
grant create trigger to dev_schema;
grant create view to dev_schema;
grant create sequence to dev_schema;
grant alter any table to dev_schema;
grant alter any procedure to dev_schema;
grant alter any trigger to dev_schema;
grant alter profile to dev_schema;
grant delete any table to dev_schema;
grant drop any table to dev_schema;
grant drop any procedure to dev_schema;
grant drop any trigger to dev_schema;
grant drop any view to dev_schema;
grant drop profile to dev_schema;

grant select on sys.v_$session to dev_schema;
grant select on sys.v_$sesstat to dev_schema;
grant select on sys.v_$statname to dev_schema;
grant SELECT ANY DICTIONARY to dev_schema;

grant create session to prod_schema;
grant create table to prod_schema;
grant create procedure to prod_schema;
grant create trigger to prod_schema;
grant create view to prod_schema;
grant create sequence to prod_schema;
grant alter any table to prod_schema;
grant alter any procedure to prod_schema;
grant alter any trigger to prod_schema;
grant alter profile to prod_schema;
grant delete any table to prod_schema;
grant drop any table to prod_schema;
grant drop any procedure to prod_schema;
grant drop any trigger to prod_schema;
grant drop any view to prod_schema;
grant drop profile to prod_schema;

grant select on sys.v_$session to prod_schema;
grant select on sys.v_$sesstat to prod_schema;
grant select on sys.v_$statname to prod_schema;
grant SELECT ANY DICTIONARY to prod_schema;

-- task 1
CREATE OR REPLACE PROCEDURE get_tables(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2)
IS
    CURSOR dev_schema_tables
    IS
    SELECT * FROM ALL_TABLES
    WHERE OWNER = dev_schema_name;

    columns_amount1 NUMBER;
    columns_amount2 NUMBER;

    dev_table_columns SYS_REFCURSOR;
    prod_table_columns SYS_REFCURSOR;

    column_name1 ALL_TAB_COLUMNS.COLUMN_NAME%TYPE;
    data_type1 ALL_TAB_COLUMNS.DATA_TYPE%TYPE;
    data_length1 ALL_TAB_COLUMNS.DATA_LENGTH%TYPE;
    nullable1 ALL_TAB_COLUMNS.NULLABLE%TYPE;

    column_name2 ALL_TAB_COLUMNS.COLUMN_NAME%TYPE;
    data_type2 ALL_TAB_COLUMNS.DATA_TYPE%TYPE;
    data_length2 ALL_TAB_COLUMNS.DATA_LENGTH%TYPE;
    nullable2 ALL_TAB_COLUMNS.NULLABLE%TYPE;
BEGIN
    FOR dev_schema_table IN dev_schema_tables
    LOOP
        SELECT COUNT(*) INTO columns_amount1
        FROM ALL_TABLES
        WHERE OWNER = dev_schema_name AND TABLE_NAME = dev_schema_table.TABLE_NAME;

        SELECT COUNT(*) INTO columns_amount2
        FROM ALL_TABLES
        WHERE OWNER = prod_schema_name AND TABLE_NAME = dev_schema_table.TABLE_NAME;

        IF columns_amount1 = columns_amount2 THEN
            OPEN dev_table_columns FOR
                SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = dev_schema_name AND TABLE_NAME = dev_schema_table.TABLE_NAME
                ORDER BY COLUMN_NAME;

            OPEN prod_table_columns FOR
                SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, NULLABLE
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = prod_schema_name AND TABLE_NAME = dev_schema_table.TABLE_NAME
                ORDER BY COLUMN_NAME;

            LOOP
                FETCH dev_table_columns INTO column_name1, data_type1, data_length1, nullable1;
                FETCH prod_table_columns INTO column_name2, data_type2, data_length2, nullable2;

                IF column_name1 <> column_name2 OR data_type1 <> data_type2
                       OR data_length1 <> data_length2 OR nullable1 <> nullable2
                    THEN
                        DBMS_OUTPUT.PUT_LINE('Table: ' || dev_schema_table.table_name);
                        exit;
                END IF;
                exit when dev_table_columns%NOTFOUND and prod_table_columns%NOTFOUND;
            END LOOP;
            CLOSE dev_table_columns;
            CLOSE prod_table_columns;

            ELSE
                DBMS_OUTPUT.PUT_LINE('Table: ' || dev_schema_table.TABLE_NAME);
            END IF;


    END LOOP;
END;

BEGIN
    get_tables('DEV_SCHEMA', 'PROD_SCHEMA');
END;

DROP TABLE DEV_SCHEMA.tab1;

CREATE TABLE PROD_SCHEMA.tab1
(
    id NUMBER,
    dt TIMESTAMP,
    name VARCHAR2(15)
);

CREATE TABLE DEV_SCHEMA.tab1
(
    id NUMBER,
    oops NUMBER,
    name VARCHAR2(15)
);

SELECT * FROM ALL_TABLES WHERE OWNER = 'DEV_SCHEMA' or OWNER = 'PROD_SCHEMA';

BEGIN
    DBMS_OUTPUT.PUT_LINE('Lox');
end;

