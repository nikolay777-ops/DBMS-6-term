CREATE OR REPLACE PROCEDURE test(choice VARCHAR2)
IS
    CURSOR dev_schema
    IS
    SELECT DISTINCT name
    FROM ALL_SOURCE
    WHERE OWNER = 'DEV_SCHEMA'
    and TYPE = 'FUNCTION';

    temp VARCHAR2(20);
BEGIN

    SELECT DISTINCT name INTO temp FROM ALL_SOURCE WHERE OWNER = 'DEV_SCHEMA' AND TYPE = 'PROCEDURE';

    OPEN dev_schema;

    loop
        FETCH dev_schema INTO temp;
        DBMS_OUTPUT.PUT_LINE(temp);
        exit when dev_schema%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('counter');
    end loop;

    close dev_schema;
end;

SET SERVEROUTPUT ON SIZE unlimited;


SELECT DISTINCT name FROM ALL_SOURCE WHERE OWNER = 'DEV_SCHEMA' AND TYPE = 'FUNCTION';
DROP FUNCTION dev_schema.tt;

CREATE OR REPLACE FUNCTION dev_schema.tt(nm VARCHAR2)
RETURN BOOLEAN
IS
    names VARCHAR2(20);
    CURSOR crs
    IS
    SELECT DISTINCT name FROM ALL_SOURCE WHERE OWNER = 'DEV_SCHEMA' AND TYPE = nm;

BEGIN
--     SELECT DISTINCT name INTO names FROM ALL_SOURCE WHERE OWNER = 'DEV_SCHEMA' AND TYPE = 'FUNCTION' FETCH FIRST 1 ROWS ONLY ;
    FOR cr in crs
    LOOP
        DBMS_OUTPUT.PUT_LINE(cr.NAME);
    END LOOP;

    RETURN FALSE;
end;

DECLARE
    res BOOLEAN;
BEGIN
    res := dev_schema.tt('FUNCTION');
end;

DECLARE
    CURSOR crs
    IS
    SELECT DISTINCT name FROM ALL_SOURCE WHERE OWNER = 'DEV_SCHEMA' AND TYPE = 'FUNCTION';

BEGIN
    FOR cr in crs
    LOOP
        DBMS_OUTPUT.PUT_LINE(cr.NAME);
    END LOOP;
end;

DROP PROCEDURE dev_schema.get_funcs_procs;
--task_2
-- choice params FUNCTION PROCEDURE
CREATE OR REPLACE PROCEDURE get_funcs_procs(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2, choice VARCHAR2)
IS
    CURSOR dev_schema
    IS
    SELECT DISTINCT name
    FROM ALL_SOURCE
    WHERE OWNER = dev_schema_name
    and type = choice;

    dev_text SYS_REFCURSOR;
    prod_text SYS_REFCURSOR;

    dev_args SYS_REFCURSOR;
    prod_args SYS_REFCURSOR;

    amount number;

    args_amount1 number;
    args_amount2 number;

    arg1 all_arguments.argument_name%TYPE;
    type1 all_arguments.data_type%TYPE;

    arg2 all_arguments.argument_name%TYPE;
    type2 all_arguments.data_type%TYPE;

    lines_amount1 number;
    lines_amount2 number;

    line1 all_source.text%TYPE;
    line2 all_source.text%TYPE;

    checked BOOLEAN;
BEGIN
    for dev_schema_iter in dev_schema
    LOOP
        checked := false;

        SELECT COUNT(*) INTO amount
        FROM ALL_SOURCE
        WHERE OWNER = prod_schema_name and type = choice and name = dev_schema_iter.NAME;

        IF amount = 0 THEN
            DBMS_OUTPUT.PUT_LINE(choice || ': ' || dev_schema_iter.NAME);

            IF choice = 'FUNCTION' THEN
                DBMS_OUTPUT.PUT_LINE('DDL function: ');
            ELSIF choice = 'PROCEDURE' THEN
                DBMS_OUTPUT.PUT_LINE('DDL procedure: ');
            end if;

        ELSE
            SELECT COUNT(*) INTO args_amount1
            FROM ALL_ARGUMENTS
            WHERE OWNER = dev_schema_name and OBJECT_NAME = dev_schema_iter.NAME;

            SELECT COUNT(*) INTO args_amount2
            FROM ALL_ARGUMENTS
            WHERE OWNER = prod_schema_name and OBJECT_NAME = dev_schema_iter.NAME;

            IF args_amount1 = args_amount2 THEN
                open dev_args
                FOR
                SELECT ARGUMENT_NAME, DATA_TYPE
                FROM ALL_ARGUMENTS
                WHERE OWNER = dev_schema_name
                    and OBJECT_NAME = dev_schema_iter.NAME
                ORDER BY POSITION;

                open prod_args
                FOR
                SELECT ARGUMENT_NAME, DATA_TYPE
                FROM ALL_ARGUMENTS
                WHERE OWNER = prod_schema_name
                    and OBJECT_NAME = dev_schema_iter.NAME
                ORDER BY POSITION;

                LOOP
                    FETCH dev_args INTO arg1, type1;
                    FETCH prod_args INTO arg2, type2;

                    IF arg1 <> arg2 or type1 <> type2 THEN
                        DBMS_OUTPUT.PUT_LINE(choice || ': ' || dev_schema_iter.NAME);
                        IF choice = 'FUNCTION' THEN
                            DBMS_OUTPUT.PUT_LINE('DDL function: ');
                        ELSIF choice = 'PROCEDURE' THEN
                            DBMS_OUTPUT.PUT_LINE('DDL procedure: ');
                        end if;
                        checked := TRUE;
                        exit;
                    END IF;
                    exit when dev_args%NOTFOUND and prod_args%NOTFOUND;
                END LOOP;

                close dev_args;
                close prod_args;
            ELSE
                IF choice = 'FUNCTION' THEN
                    DBMS_OUTPUT.PUT_LINE('DDL function: ');
                ELSIF choice = 'PROCEDURE' THEN
                    DBMS_OUTPUT.PUT_LINE('DDL procedure: ');
                end if;
            END IF;

            IF checked = FALSE THEN
                SELECT COUNT(*) INTO lines_amount1
                FROM ALL_SOURCE
                WHERE OWNER = dev_schema_name and type = choice and name = dev_schema_iter.NAME;

                SELECT COUNT(*) INTO lines_amount2
                FROM ALL_SOURCE
                WHERE OWNER = prod_schema_name and type = choice and name = dev_schema_iter.NAME;

                IF lines_amount1 = lines_amount2 THEN
                    open dev_text
                    FOR
                    SELECT text
                    FROM ALL_SOURCE
                    WHERE OWNER = dev_schema_name
                        AND name = dev_schema_iter.NAME
                        AND line <> 1
                    ORDER BY line;

                    LOOP
                        FETCH dev_text INTO line1;
                        FETCH prod_text INTO line2;

                        IF line1 <> line2 THEN
                            IF choice = 'FUNCTION' THEN
                                DBMS_OUTPUT.PUT_LINE('DDL function: ');
                            ELSIF choice = 'PROCEDURE' THEN
                                DBMS_OUTPUT.PUT_LINE('DDL procedure: ');
                            end if;
                            exit;
                        END IF;
                        exit WHEN dev_text%NOTFOUND AND prod_text%NOTFOUND;
                    END LOOP;

                    close dev_text;
                    close prod_text;

                    ELSE
                        IF choice = 'FUNCTION' THEN
                            DBMS_OUTPUT.PUT_LINE('DDL function: ');
                        ELSIF choice = 'PROCEDURE' THEN
                            DBMS_OUTPUT.PUT_LINE('DDL procedure: ');
                        end if;
                END IF;
            END IF;
        END IF;
    END LOOP;
END;

-- indexes procedure
CREATE OR REPLACE PROCEDURE get_indexes(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2)
IS
    CURSOR dev_indexes
    IS
    SELECT index_name
    FROM ALL_INDEXES
    WHERE OWNER = dev_schema_name;

    amount number;

    index1_columns SYS_REFCURSOR;
    index2_columns SYS_REFCURSOR;

    columns_amount1 NUMBER;
    columns_amount2 NUMBER;

    index_type1 ALL_INDEXES.index_type%TYPE;
    table_name1 ALL_INDEXES.table_name%TYPE;
    uniqueness1 ALL_INDEXES.uniqueness%TYPE;
    column_name1 ALL_IND_COLUMNS.column_name%TYPE;

    index_type2 ALL_INDEXES.index_type%TYPE;
    table_name2 ALL_INDEXES.table_name%TYPE;
    uniqueness2 ALL_INDEXES.uniqueness%TYPE;
    column_name2 ALL_IND_COLUMNS.column_name%TYPE;
BEGIN
    for dev_index in dev_indexes
    LOOP
        SELECT COUNT(*) INTO amount
        FROM ALL_INDEXES
        WHERE OWNER = prod_schema_name and INDEX_NAME = dev_index.INDEX_NAME;
        IF amount = 0 THEN
            DBMS_OUTPUT.PUT_LINE('INDEX: ' || dev_index.INDEX_NAME);
            -- ddl create index
        ELSE
            SELECT INDEX_TYPE, TABLE_NAME, UNIQUENESS
            INTO index_type1, table_name1, uniqueness1
            FROM ALL_INDEXES
            WHERE OWNER = dev_schema_name and INDEX_NAME = dev_index.INDEX_NAME;

            SELECT INDEX_TYPE, TABLE_NAME, UNIQUENESS
            INTO index_type2, table_name2, uniqueness2
            FROM ALL_INDEXES
            WHERE OWNER = prod_schema_name and INDEX_NAME = dev_index.INDEX_NAME;

            IF index_type1 = index_type2 AND table_name1 = table_name2 AND uniqueness1 = uniqueness2 THEN
                SELECT COUNT(*) INTO columns_amount1
                FROM ALL_INDEXES
                INNER JOIN ALL_IND_COLUMNS
                ON ALL_INDEXES.INDEX_NAME = ALL_IND_COLUMNS.INDEX_NAME
                       and ALL_INDEXES.OWNER = ALL_IND_COLUMNS.INDEX_OWNER
                WHERE ALL_INDEXES.OWNER = dev_schema_name AND
                      ALL_INDEXES.INDEX_NAME = dev_index.INDEX_NAME;

                SELECT COUNT(*) INTO columns_amount2
                FROM ALL_INDEXES
                INNER JOIN ALL_IND_COLUMNS
                ON ALL_INDEXES.INDEX_NAME = ALL_IND_COLUMNS.INDEX_NAME
                       and ALL_INDEXES.OWNER = ALL_IND_COLUMNS.INDEX_OWNER
                WHERE ALL_INDEXES.OWNER = prod_schema_name AND
                      ALL_INDEXES.INDEX_NAME = dev_index.INDEX_NAME;

                IF columns_amount1 = columns_amount2 THEN
                    OPEN index1_columns FOR
                        SELECT column_name
                        FROM ALL_IND_COLUMNS
                        WHERE INDEX_OWNER = dev_schema_name
                          AND INDEX_NAME = dev_index.INDEX_NAME
                        GROUP BY column_name;

                    OPEN index2_columns FOR
                        SELECT column_name
                        FROM ALL_IND_COLUMNS
                        WHERE INDEX_OWNER = dev_schema_name
                          AND INDEX_NAME = dev_index.INDEX_NAME
                        GROUP BY column_name;

                    LOOP
                        FETCH index1_columns INTO column_name1;
                        FETCH index2_columns INTO column_name2;

                        IF column_name1 <> column_name2 THEN
                            DBMS_OUTPUT.PUT_LINE('INDEX: '|| dev_index.INDEX_NAME);
                            -- ddl create index
                            exit;
                        END IF;
                        exit when index1_columns%NOTFOUND and index2_columns%NOTFOUND;
                    END LOOP;
                close index1_columns;
                close index2_columns;

                ELSE
                    DBMS_OUTPUT.PUT_LINE('INDEX: ' || dev_index.INDEX_NAME);
                    -- ddl create index
                end if;

            ELSE
                DBMS_OUTPUT.PUT_LINE('INDEX: ' || dev_index.INDEX_NAME);
                -- ddl create index
            END IF;
        END IF;
    end loop;
END;

CREATE OR REPLACE procedure get_packages(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2)
IS
    CURSOR dev_packages
    IS
    SELECT DISTINCT name
    FROM ALL_SOURCE
    WHERE OWNER = dev_schema_name AND TYPE = 'PACKAGE';

    dev_package_text SYS_REFCURSOR;
    prod_package_text SYS_REFCURSOR;

    amount number;

    lines_amount1 number;
    lines_amount2 number;

    line1 ALL_SOURCE.TEXT%TYPE;
    line2 ALL_SOURCE.TEXT%TYPE;
BEGIN
    FOR dev_package in dev_packages
    LOOP
        SELECT COUNT(*) INTO amount
        FROM ALL_SOURCE
        WHERE OWNER = prod_schema_name and TYPE = 'PACKAGE' and name = dev_package.NAME;

        IF amount = 0 THEN
            DBMS_OUTPUT.PUT_LINE('PACKAGE: ' || dev_package.NAME);
            -- ddl package
        ELSE
            SELECT COUNT(*) INTO lines_amount1
            FROM ALL_SOURCE
            WHERE OWNER = dev_schema_name AND type = 'PACKAGE'
                AND NAME = dev_package.NAME;

            SELECT COUNT(*) INTO lines_amount1
            FROM ALL_SOURCE
            WHERE OWNER = prod_schema_name AND type = 'PACKAGE'
                AND NAME = dev_package.NAME;

            IF lines_amount1 = lines_amount2 THEN
                OPEN dev_package_text FOR
                    SELECT text
                    FROM ALL_SOURCE
                    WHERE OWNER = dev_schema_name
                    AND NAME = dev_package.NAME
                    AND line <> 1
                    ORDER BY line;

                OPEN prod_package_text FOR
                    SELECT text
                    FROM ALL_SOURCE
                    WHERE OWNER = prod_schema_name
                    AND NAME = dev_package.NAME
                    AND line <> 1
                    ORDER BY line;

                LOOP
                    FETCH dev_package_text INTO line1;
                    FETCH prod_package_text INTO line2;

                    IF line1 <> line2 THEN
                        DBMS_OUTPUT.PUT_LINE('PACKAGE: ' || dev_package.NAME);
                        -- ddl create package
                        exit;
                    end if;
                    exit WHEN dev_package_text%NOTFOUND and prod_package_text%NOTFOUND;
                END LOOP;
                close dev_package_text;
                close prod_package_text;

            ELSE
                DBMS_OUTPUT.PUT_LINE('PACKAGE: ' || dev_package.NAME);
                -- ddl create package
            END IF;
        end if;
    END LOOP;
END;


BEGIN
    get_funcs_procs('DEV_SCHEMA', 'PROD_SCHEMA', 'PROCEDURE');
END;

create or replace function dev_schema.test_func1(arg1 number, arg2 number) return number is
begin
    return 1;
end;
    create or replace function dev_schema.test_func2(arg1 number, arg2 number) return number is
begin
    return 1;
end;

create or replace procedure dev_schema.test_proc1(arg1 number, arg2 varchar2)
IS
    num1 NUMBER := 0;
begin
    num1 := num1 - 1;
end;

create table dev_schema.mytable(
    id number,
    val number,
    constraint id_unique unique (id)
);

create table prod_schema.mytable(
    id number,
    val number
);

DROP table dev_schema.mytable;
DROP TABLE prod_schema.mytable;

DROP INDEX prod_schema.test_index1;
create index dev_schema.test_index1 on dev_schema.mytable(id);
create index prod_schema.test_index1 on prod_schema.mytable(id);

BEGIN
    get_indexes('DEV_SCHEMA', 'PROD_SCHEMA');
end;

SELECT * FROM ALL_INDEXES WHERE OWNER = 'PROD_SCHEMA';

CREATE OR REPLACE PACKAGE dev_schema.test_pkg IS

	PROCEDURE Out_Screen(TOSC IN VARCHAR2);

	FUNCTION Add_Two_Num(A IN NUMBER, B IN NUMBER) RETURN NUMBER;

	FUNCTION Min_Two_Num(A IN NUMBER, B IN NUMBER) RETURN NUMBER;

	FUNCTION FACTORIAL(NUM IN NUMBER) RETURN NUMBER;

END test_pkg;

BEGIN
    get_packages('DEV_SCHEMA', 'PROD_SCHEMA');
end;

