ALTER SESSION SET "_ORACLE_SCRIPT"=true;
CREATE USER dev_schema IDENTIFIED BY 1;
CREATE USER prod_schema IDENTIFIED BY 1;

grant all privileges to SYSTEM;

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

grant all privileges to dev_schema;

grant select on sys.v_$session to dev_schema;
-- grant select on sys.v_$sesstat to dev_schema;
-- grant select on sys.v_$statname to dev_schema;
-- grant SELECT ANY DICTIONARY to dev_schema;

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

-- grant select on sys.v_$session to prod_schema;
-- grant select on sys.v_$sesstat to prod_schema;
-- grant select on sys.v_$statname to prod_schema;
grant SELECT ANY DICTIONARY to prod_schema;

-- task 1
-- initialize priority table

CREATE GLOBAL TEMPORARY TABLE tables_priority
(
    id NUMBER UNIQUE NOT NULL,
    table_name VARCHAR2(20),
    schema_name VARCHAR2(20),
    priority NUMBER
);

CREATE SEQUENCE tab_priority_seq START WITH 1;

CREATE OR REPLACE TRIGGER tab_priority_auto_increment
BEFORE INSERT ON tables_priority
FOR EACH ROW
BEGIN
    IF :new.id = 0 THEN
        SELECT tab_priority_seq.nextval
        INTO :new.id
        FROM DUAL;
    END IF;
END;

-- help functions

CREATE OR REPLACE FUNCTION has_fk(schema IN VARCHAR2, tab1 IN VARCHAR2)
RETURN VARCHAR2
IS
    fks_count NUMBER := -1;
BEGIN
    SELECT COUNT(R_CONSTRAINT_NAME) INTO fks_count
    FROM ALL_CONSTRAINTS
    WHERE OWNER = schema AND CONSTRAINT_TYPE = 'R'
    AND TABLE_NAME = tab1 AND LENGTH(R_CONSTRAINT_NAME) > 0;

    DBMS_OUTPUT.PUT_LINE('fks count: ' || fks_count);

    IF fks_count = 0 THEN
        RETURN 'FALSE';
    ELSIF fks_count > 0 THEN
        RETURN 'TRUE';
    end if;
    RETURN 'NULL';
END;

DECLARE
    cursor crs
    IS
    SELECT *
    FROM ALL_CONSTRAINTS
    WHERE OWNER = 'DEV_SCHEMA' AND TABLE_NAME = 'TAB3'
    AND LENGTH(R_CONSTRAINT_NAME) > 0;

BEGIN
    FOR c in crs LOOP
        DBMS_OUTPUT.PUT_LINE(c.R_CONSTRAINT_NAME);
        end loop;

end;


CREATE OR REPLACE FUNCTION get_rel_tab(const_name VARCHAR2)
RETURN VARCHAR2
IS
    res VARCHAR2(30);
BEGIN

    SELECT TABLE_NAME INTO res
    FROM ALL_CONSTRAINTS
    WHERE CONSTRAINT_NAME = const_name;

    RETURN res;
END;

CREATE OR REPLACE PROCEDURE priority_check(schema VARCHAR2, tab VARCHAR2)
IS
    res VARCHAR2(20);
    rel_tab_name VARCHAR2(30);
    temp_tab_name NUMBER;

    CURSOR rels
    IS
    SELECT *
    FROM ALL_CONSTRAINTS
    WHERE OWNER = schema AND TABLE_NAME = tab
    AND LENGTH(R_CONSTRAINT_NAME) > 0;
BEGIN
    res := has_fk(schema, tab);
    DBMS_OUTPUT.PUT_LINE('res: ' || res);
    if res = 'FALSE' THEN
        SELECT COUNT(table_name) INTO temp_tab_name
        FROM tables_priority
        WHERE table_name = tab and schema_name = schema;

        IF temp_tab_name = 0 THEN
            INSERT INTO tables_priority VALUES (0, tab, schema, 0);
--             DBMS_OUTPUT.PUT_LINE('You can create a table: '|| tab);
        end if;

    ELSIF res = 'TRUE' THEN
        DBMS_OUTPUT.PUT_LINE('schema: ' || schema || ' tab: '|| tab);

        for r in rels
            LOOP
                rel_tab_name := get_rel_tab(r.R_CONSTRAINT_NAME);
                res := has_fk(schema, rel_tab_name);
                IF res = 'FALSE' THEN
                    SELECT COUNT(table_name) INTO temp_tab_name
                    FROM tables_priority
                    WHERE table_name = tab and schema_name = schema;

                    IF temp_tab_name = 0 THEN
                        INSERT INTO tables_priority VALUES (0, tab, schema, 1);
                    END IF;

                    SELECT COUNT(table_name) INTO temp_tab_name
                    FROM tables_priority
                    WHERE table_name = rel_tab_name and schema_name = schema;

                    IF temp_tab_name = 0 THEN
                        INSERT INTO tables_priority VALUES (0, rel_tab_name, schema, 1);
                    END IF;
    --                 DBMS_OUTPUT.PUT_LINE('You can create a table: '|| rel_tab_name);
                ELSE
                    DBMS_OUTPUT.PUT_LINE('You have a circle relationship: ' || tab || ' <---> ' || rel_tab_name );
                end if;
            END LOOP;
    end if;
end;

-- there is task1

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

    constraints_amount1 NUMBER;
    constraints_amount2 NUMBER;

    constraint_name1 all_constraints.constraint_name%TYPE;
    constraint_type1 all_constraints.constraint_type%TYPE;
    search_condition1 all_constraints.search_condition%TYPE;

    constraint_name2 all_constraints.constraint_name%TYPE;
    constraint_type2 all_constraints.constraint_type%TYPE;
    search_condition2 all_constraints.search_condition%TYPE;

    checked BOOLEAN;
BEGIN
    FOR dev_schema_table IN dev_schema_tables
    LOOP
        checked := false;
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
                        priority_check(dev_schema_name, dev_schema_table.table_name);
                        DBMS_OUTPUT.PUT_LINE('different columns table: ' || dev_schema_table.table_name);
                        checked := TRUE;
                        exit;
                END IF;
                exit when dev_table_columns%NOTFOUND and prod_table_columns%NOTFOUND;
--                 DBMS_OUTPUT.PUT_LINE('TABLE LOOP: ');
            END LOOP;
            CLOSE dev_table_columns;
            CLOSE prod_table_columns;

            ELSE
                DBMS_OUTPUT.PUT_LINE('Different tables: ' || dev_schema_table.TABLE_NAME);
                priority_check(dev_schema_name, dev_schema_table.table_name);
            END IF;

        IF checked = FALSE THEN

            SELECT COUNT(*) INTO constraints_amount1
            FROM ALL_CONSTRAINTS
            WHERE OWNER = dev_schema_name AND TABLE_NAME = dev_schema_table.TABLE_NAME;

            SELECT COUNT(*) INTO constraints_amount2
            FROM ALL_CONSTRAINTS
            WHERE OWNER = prod_schema_name AND TABLE_NAME = dev_schema_table.TABLE_NAME;

            IF constraints_amount1 = constraints_amount2 THEN
                OPEN dev_table_columns FOR
                    SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE, SEARCH_CONDITION
                    FROM ALL_CONSTRAINTS
                    WHERE OWNER = dev_schema_name and TABLE_NAME = dev_schema_table.TABLE_NAME
                    ORDER BY CONSTRAINT_NAME;

                OPEN prod_table_columns FOR
                    SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE, SEARCH_CONDITION
                    FROM ALL_CONSTRAINTS
                    WHERE OWNER = prod_schema_name and TABLE_NAME = dev_schema_table.TABLE_NAME
                    ORDER BY CONSTRAINT_NAME;

                LOOP
                    FETCH dev_table_columns INTO constraint_name1, constraint_type1, search_condition1;
                    FETCH prod_table_columns INTO constraint_name2, constraint_type2, search_condition2;

                    IF constraint_name1 <> constraint_name2 OR constraint_type1 <> constraint_type2
                           OR search_condition1 <> search_condition2 THEN
                        priority_check(dev_schema_name, dev_schema_table.table_name);
                        DBMS_OUTPUT.PUT_LINE('constraint structure table: ' || dev_schema_table.TABLE_NAME);
                        exit;
                    END IF;
                    exit WHEN dev_table_columns%NOTFOUND and prod_table_columns%NOTFOUND;
                    DBMS_OUTPUT.PUT_LINE('constraint loop: ');
                END LOOP;
                close dev_table_columns;
                close prod_table_columns;

                ELSE
                    priority_check(dev_schema_name, dev_schema_table.table_name);
                    DBMS_OUTPUT.PUT_LINE('no constraint table: ' || dev_schema_table.TABLE_NAME);
            END IF;
        END IF;

    END LOOP;
END;

SELECT * FROM ALL_TABLES WHERE OWNER = 'DEV_SCHEMA' OR OWNER = 'PROD_SCHEMA' ORDER BY OWNER;
DROP TABLE dev_schema.tab3;
DROP TABLE prod_schema.tab3;
DROP TABLE dev_schema.tab2;
DROP TABLE prod_schema.tab2;
DROP TABLE dev_schema.tab1;
DROP TABLE prod_schema.tab1;


SELECT * FROM tables_priority ORDER BY priority;
SELECT * FROM ALL_CONSTRAINTS WHERE OWNER = 'DEV_SCHEMA' OR OWNER = 'PROD_SCHEMA';
SELECT * FROM ALL_TABLES WHERE OWNER = 'DEV_SCHEMA' OR OWNER = 'PROD_SCHEMA';

CREATE TABLE DEV_SCHEMA.tab1
(
    id NUMBER NOT NULL,
    oops NUMBER,
    nm VARCHAR2(15),

    CONSTRAINT dev_tab1_pk PRIMARY KEY(id)
);

CREATE TABLE DEV_SCHEMA.tab2
(
    id NUMBER NOT NULL,
    ind NUMBER,
    nickname VARCHAR2(15),

    CONSTRAINT dev_tab2_pk PRIMARY KEY (id)
);

CREATE TABLE DEV_SCHEMA.tab3
(
    id NUMBER NOT NULL,
    oops NUMBER,
    name VARCHAR2(15),

    CONSTRAINT dev_tab3_pk PRIMARY KEY (id)
);

CREATE TABLE PROD_SCHEMA.tab1
(
    id NUMBER NOT NULL,
    james NUMBER,
    post VARCHAR2(20),

    CONSTRAINT prod_tab1_pk PRIMARY KEY (id)
);

CREATE TABLE PROD_SCHEMA.tab2
(
    id NUMBER NOT NULL,
    ind NUMBER,
    nickname VARCHAR2(15),

    CONSTRAINT prod_tab2_pk PRIMARY KEY (id)
);

CREATE TABLE PROD_SCHEMA.tab3
(
    id NUMBER NOT NULL,
    oops NUMBER,
    name VARCHAR2(15),

    CONSTRAINT prod_tab3_pk PRIMARY KEY (id)
);

ALTER TABLE dev_schema.tab2 ADD CONSTRAINT dev_tab2_fk_tab3 FOREIGN KEY (id) REFERENCES DEV_SCHEMA.tab3 (id);

ALTER TABLE dev_schema.tab3 ADD CONSTRAINT dev_tab3_fk_tab1 FOREIGN KEY (id) REFERENCES DEV_SCHEMA.tab1 (id);
ALTER TABLE dev_schema.tab3 ADD CONSTRAINT dev_tab3_fk_tab2 FOREIGN KEY (id) REFERENCES DEV_SCHEMA.tab2 (id);

ALTER TABLE PROD_SCHEMA.tab2 ADD CONSTRAINT prod_tab2_fk_tab3 FOREIGN KEY (id) REFERENCES PROD_SCHEMA.tab3 (id);
ALTER TABLE PROD_SCHEMA.tab3 ADD CONSTRAINT prod_tab3_fk_tab1 FOREIGN KEY (id) REFERENCES PROD_SCHEMA.tab1 (id);

BEGIN
    get_tables('DEV_SCHEMA', 'PROD_SCHEMA');
END;

SELECT * FROM tables_priority;


SELECT * FROM ALL_TABLES WHERE OWNER = 'DEV_SCHEMA';
