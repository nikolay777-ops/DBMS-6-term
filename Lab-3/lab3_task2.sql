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

