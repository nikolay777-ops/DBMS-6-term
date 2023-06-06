grant all privileges to SYSTEM;

CREATE OR REPLACE DIRECTORY MY_DIR AS '/opt/oracle';


CREATE OR REPLACE PACKAGE json_parser AS
FUNCTION parse_all_or_distinct(json_select IN JSON_OBJECT_T) RETURN VARCHAR2;
FUNCTION column_parse(json_cols IN JSON_ARRAY_T, tab_name IN VARCHAR2) RETURN VARCHAR2;
FUNCTION table_parse(json_tables IN JSON_ARRAY_T) RETURN VARCHAR2;
FUNCTION parse_tab_name_or_select(table_obj IN JSON_OBJECT_T) RETURN VARCHAR2;
FUNCTION parse_from(json_from IN JSON_ARRAY_T) RETURN VARCHAR2;
FUNCTION parse_where(json_where IN JSON_ARRAY_T) RETURN VARCHAR2;
FUNCTION parse_join(json_join IN JSON_ARRAY_T) RETURN VARCHAR2;
FUNCTION parse_select(json_select IN JSON_OBJECT_T) RETURN VARCHAR2;
FUNCTION parse_dml(json_dml IN JSON_OBJECT_T) RETURN VARCHAR2;
FUNCTION parse_ddl(json_ddl IN JSON_OBJECT_T) RETURN VARCHAR2;
FUNCTION parse_json(json_str IN VARCHAR2) RETURN VARCHAR2;
FUNCTION read(dir VARCHAR2, fname VARCHAR2) RETURN VARCHAR2;
END json_parser;


CREATE OR REPLACE PACKAGE BODY json_parser AS
    FUNCTION parse_all_or_distinct(json_select IN JSON_OBJECT_T)
    RETURN VARCHAR2
    IS
        query_qual VARCHAR2(10);
    BEGIN
        query_qual := UPPER(json_select.get_string('all_or_distinct_or_star'));

        IF query_qual = 'DISTINCT' THEN
            RETURN query_qual;
        ELSIF query_qual = '*' THEN
            RETURN query_qual;
            END IF;
        RETURN NULL;
    END parse_all_or_distinct;


    FUNCTION column_parse(json_cols IN JSON_ARRAY_T, tab_name IN VARCHAR2) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        col_obj JSON_OBJECT_T;
    BEGIN
        FOR i in 0..json_cols.get_size - 1 LOOP
            col_obj := TREAT(json_cols.get(i) AS JSON_OBJECT_T);
            IF NOT col_obj.has('col_name') THEN
                RAISE_APPLICATION_ERROR(-20005, 'Error in column_parse(). There is not "col_name"');
            END IF;
            IF tab_name IS NOT NULL THEN
                buff := buff || tab_name || '.' || col_obj.get_string('col_name');
            ELSE
                buff := buff ||  col_obj.get_string('col_name');
            END IF;

            IF col_obj.has('as') THEN
                buff := buff || ' ' || col_obj.get_string('as');
            END IF;
            buff := buff || ', ';
        END LOOP;
        RETURN RTRIM(buff, ', ');
    END column_parse;


    FUNCTION table_parse(json_tables IN JSON_ARRAY_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        table_obj JSON_OBJECT_T;
        table_name VARCHAR2(100);
    BEGIN
        FOR i IN 0..json_tables.get_size - 1 LOOP
            buff := buff || CHR(10);
            table_obj := TREAT(json_tables.get(i) AS JSON_OBJECT_T);
            table_name := table_obj.get_string('table_name');
            buff := buff || column_parse(table_obj.get_array('cols'), table_name) || ', ';
        END LOOP;
        RETURN RTRIM(buff, ', ');
    END table_parse;


    FUNCTION parse_tab_name_or_select(table_obj IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(1000);
        is_as BOOLEAN := FALSE;
    BEGIN
        IF table_obj.has('table_name') AND table_obj.get_string('table_name') IS NOT NULL AND
          table_obj.has('select') AND table_obj.get_object('select') IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20007, 'Error in parse_tab_name_or_select(). There is "table_name" and "select" sections');
        END IF;

        is_as := table_obj.has('as');
        IF table_obj.has('table_name') AND table_obj.get_string('table_name') IS NOT NULL THEN
            buff := buff || table_obj.get_string('table_name');
            IF is_as THEN
                buff := buff || ' ' || table_obj.get_string('as');
            END IF;
        ELSIF table_obj.has('select') AND table_obj.get_object('select') IS NOT NULL THEN
            buff := buff || '(' || parse_select(table_obj.get_object('select')) || ') ';
            IF is_as THEN
                buff := buff || table_obj.get_string('as');
            END IF;
        ELSE
            RAISE_APPLICATION_ERROR(-20008, 'Error in parse_tab_name_or_select(). UNREACHABLE!');
        END IF;

        RETURN buff;
    END parse_tab_name_or_select;


    FUNCTION parse_from(json_from IN JSON_ARRAY_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        table_obj JSON_OBJECT_T;
    BEGIN
        FOR i IN 0..json_from.get_size - 1 LOOP
            table_obj := TREAT(json_from.get(i) AS JSON_OBJECT_T);
            buff := buff || parse_tab_name_or_select(table_obj) || ', ';
        END LOOP;
        RETURN RTRIM(buff, ', ');
    END parse_from;


    FUNCTION parse_operand(condition_obj IN JSON_OBJECT_T, hs IN VARCHAR2) RETURN VARCHAR2
    IS
        buff VARCHAR2(1000);
        is_dot_needed BOOLEAN := FALSE;
    BEGIN
        IF condition_obj.has(hs || '_tab_name') AND condition_obj.get_string(hs ||'_tab_name') IS NOT NULL THEN
            buff := condition_obj.get_string(hs || '_tab_name');
            is_dot_needed := TRUE;
        END IF;

        IF NOT condition_obj.has(hs ||'_col_name_or_val') THEN
            RAISE_APPLICATION_ERROR(-20009, 'Error in parse_where(). There is no "' || hs ||'_col_name_or_val"');
        END IF;

        IF is_dot_needed THEN
            buff := buff || '.';
        END IF;
        IF condition_obj.get_string(hs || '_col_name_or_val') IS NULL THEN
            buff := buff || '(' ||parse_select(condition_obj.get_object(hs || '_col_name_or_val').get_object('select')) || ')';
        ELSE
            buff := buff || condition_obj.get_string(hs || '_col_name_or_val');
        END IF;
        RETURN buff;
    END parse_operand;

    FUNCTION parse_lhs_operand(condition_obj IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
    BEGIN
        RETURN parse_operand(condition_obj, 'lhs');
    END parse_lhs_operand;


    FUNCTION parse_rhs_operand(condition_obj IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
    BEGIN
        RETURN parse_operand(condition_obj, 'rhs');
    END parse_rhs_operand;

    FUNCTION parse_condition(condition_obj IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        lhs VARCHAR2(1000);
        rhs VARCHAR2(1000);
        for_between VARCHAR2(1000);
        comp_operator VARCHAR2(30);
    BEGIN
        IF NOT condition_obj.has('comp_operator') THEN
            RAISE_APPLICATION_ERROR(-20010, 'Error in parse_condition(). There is not "comp_operator" section');
        END IF;
        comp_operator := condition_obj.get_string('comp_operator');
        rhs := parse_rhs_operand(condition_obj);
        IF comp_operator = 'EXISTS' or comp_operator = 'NOT EXISTS' THEN
            buff := buff || comp_operator || '(' || rhs || ')';
        ELSIF comp_operator = 'BETWEEN' THEN
            lhs := parse_lhs_operand(condition_obj);
            for_between := parse_operand(condition_obj, 'for_between');
            buff := buff || lhs || ' BETWEEN ' || rhs || ' AND ' || for_between;
        ELSIF comp_operator = 'LIKE' THEN
            lhs := parse_lhs_operand(condition_obj);
            buff := buff || lhs || ' ' || comp_operator || ' ' || '''' || rhs || '''' ;
        ELSE
            lhs := parse_lhs_operand(condition_obj);
            buff := buff || lhs || ' ' || comp_operator || ' ' || rhs;
        END IF;
        IF condition_obj.has('post_and_or_operator') AND condition_obj.get_string('post_and_or_operator') IS NOT NULL THEN
            buff := buff || ' ' || condition_obj.get_string('post_and_or_operator') || ' ';
        END IF;

        RETURN buff;
    END parse_condition;

    FUNCTION parse_where(json_where IN JSON_ARRAY_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        condition_obj JSON_OBJECT_T;
    BEGIN
        FOR i IN 0..json_where.get_size - 1 LOOP
            condition_obj := TREAT(json_where.get(i) AS JSON_OBJECT_T);
            buff := buff || parse_condition(condition_obj);
        END LOOP;
        RETURN buff;
    END parse_where;

    FUNCTION parse_join(json_join IN JSON_ARRAY_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        join_obj JSON_OBJECT_T;
    BEGIN
        FOR i in 0..json_join.get_size - 1 LOOP
            join_obj := TREAT(json_join.get(i) AS JSON_OBJECT_T);
            IF NOT join_obj.has('type') OR join_obj.get_string('type') IS NULL THEN
                RAISE_APPLICATION_ERROR(-20011, 'Error in parse_join(). There is no "type"');
            END IF;
            buff := buff || join_obj.get_string('type') || ' JOIN ';

            IF NOT join_obj.has('rhs') OR join_obj.get_object('rhs') IS NULL THEN
                RAISE_APPLICATION_ERROR(-20011, 'Error in parse_join(). There is no "rhs"');
            END IF;
            buff := buff || parse_tab_name_or_select(join_obj.get_object('rhs')) || CHR(10) || 'ON ';

            IF NOT join_obj.has('on') OR join_obj.get_array('on') IS NULL THEN
                RAISE_APPLICATION_ERROR(-20012, 'Error in parse_join(). There is no "on"');
            END IF;
            buff := buff || parse_where(join_obj.get_array('on')) || CHR(10);
        END LOOP;
        RETURN buff;
    END parse_join;


    FUNCTION parse_select(json_select IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
    BEGIN
        buff := 'SELECT ';
        IF json_select.has('all_or_distinct_or_star') THEN
            buff := buff || parse_all_or_distinct(json_select);
        END IF;

        IF NOT json_select.has('tables') AND INSTR(buff, '*') <= 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Error in parse_select(). There is not "tables" section and ');
        ELSIF INSTR(buff, '*') <= 0 THEN
            buff := buff || ' ' || table_parse(json_select.get_array('tables'));
        END IF;

        IF NOT json_select.has('from') THEN
            RAISE_APPLICATION_ERROR(-20006, 'Error in parse_select(). There is not "from" section');
        END IF;

        buff := buff || CHR(10) || 'FROM ' || parse_from(json_select.get_array('from')) || CHR(10);

        IF json_select.has('where') THEN
            buff := buff || 'WHERE ' || parse_where(json_select.get_array('where')) || CHR(10);
        END IF;

        IF json_select.has('join') THEN
            buff := buff || parse_join(json_select.get_array('join'));
        END IF;

        RETURN buff;
    END parse_select;


    FUNCTION parse_value(val_obj JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
    BEGIN
        IF val_obj.has('val') AND val_obj.get_string('val') IS NOT NULL AND
          val_obj.has('select') AND val_obj.get_object('select') IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20014, 'Error in parse_value(). There is "val" and "select" sections');
        END IF;
        IF val_obj.has('val') AND val_obj.get_string('val') IS NOT NULL THEN
            buff := buff || val_obj.get_string('val');
        ELSIF val_obj.has('select') AND val_obj.get_object('select') IS NOT NULL THEN
            buff := buff || '(' || parse_select(val_obj.get_object('select')) || ') ';
        ELSE
            RAISE_APPLICATION_ERROR(-20008, 'Error in parse_value(). UNREACHABLE!');
        END IF;

        RETURN buff;
    END parse_value;


    FUNCTION parse_values(json_values IN JSON_ARRAY_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        val_obj JSON_OBJECT_T;
    BEGIN
        FOR i IN 0..json_values.get_size - 1 LOOP
            val_obj := TREAT(json_values.get(i) AS JSON_OBJECT_T);
            buff := buff || parse_value(val_obj) || ', ';
        END LOOP;

        RETURN RTRIM(buff, ', ');
    END parse_values;


    FUNCTION parse_insert(json_dml IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        tab_name VARCHAR2(128);
    BEGIN
        buff := 'INSERT INTO ';
        IF NOT json_dml.has('table_name') OR json_dml.get_string('table_name') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20012, 'Error in parse_insert(). There is no "table_name" section');
        END IF;
        tab_name := json_dml.get_string('table_name');
        buff := buff || tab_name || '(';

        IF NOT json_dml.has('cols') OR json_dml.get_array('cols') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20013, 'Error in parse_insert(). There is no "cols" section');
        END IF;
        buff := buff || column_parse(json_dml.get_array('cols'), NULL) || ') VALUES(';

        IF NOT json_dml.has('values') OR json_dml.get_array('values') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20015, 'Error in parse_insert(). There is no "values" section');
        END IF;
        buff := buff || parse_values(json_dml.get_array('values')) || ');';

        RETURN buff;
    END parse_insert;


    FUNCTION column_parse_values_for_update(json_dml IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        json_cols JSON_ARRAY_T;
        json_values JSON_ARRAY_T;
        col_obj JSON_OBJECT_T;
        val_obj JSON_OBJECT_T;
    BEGIN
        IF NOT json_dml.has('cols') OR json_dml.get_array('cols') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20013, 'Error in column_parse_values_for_update(). There is no "cols" section');
        END IF;
        json_cols := json_dml.get_array('cols');

        IF NOT json_dml.has('values') OR json_dml.get_array('values') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20015, 'Error in column_parse_values_for_update(). There is no "values" section');
        END IF;
        json_values := json_dml.get_array('values');

        IF json_cols.get_size != json_values.get_size THEN
            RAISE_APPLICATION_ERROR(-20017, 'Error in column_parse_values_for_update(). Num of cols != num of values.');
        END IF;

        FOR i in 0..json_cols.get_size - 1 LOOP
            col_obj := TREAT(json_cols.get(i) AS JSON_OBJECT_T);
            val_obj := TREAT(json_values.get(i) AS JSON_OBJECT_T);

            IF NOT col_obj.has('col_name') OR col_obj.get_string('col_name') IS NULL THEN
                RAISE_APPLICATION_ERROR(-20018, 'Error in column_parse_values_for_update().  There is no "col_name" section in cols');
            END IF;

            buff := buff || col_obj.get_string('col_name') || ' = ' || parse_value(val_obj) || ', ';
        END LOOP;

        RETURN RTRIM(buff, ', ');
    END column_parse_values_for_update;


    FUNCTION parse_update(json_dml IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        tab_name VARCHAR2(128);
    BEGIN
        buff := 'UPDATE ';
        IF NOT json_dml.has('table_name') OR json_dml.get_string('table_name') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20012, 'Error in parse_update(). There is no "table_name" section');
        END IF;
        tab_name := json_dml.get_string('table_name');
        buff := buff || tab_name || ' SET ' || column_parse_values_for_update(json_dml);
        RETURN buff;
    END parse_update;


    FUNCTION parse_delete(json_dml IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        tab_name VARCHAR2(128);
    BEGIN
        buff := 'DELETE FROM ';
        IF NOT json_dml.has('table_name') OR json_dml.get_string('table_name') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20012, 'Error in parse_delete(). There is no "table_name" section');
        END IF;
        tab_name := json_dml.get_string('table_name');
        buff := buff || tab_name;

        RETURN buff;
    END parse_delete;



    FUNCTION parse_dml(json_dml IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        dml_type VARCHAR2(20);
    BEGIN
        IF NOT json_dml.has('type') OR json_dml.get_string('type') IS NULL THEN
           RAISE_APPLICATION_ERROR(-20012, 'Error in parse_dml(). There is no "type" section');
        END IF;
        dml_type := json_dml.get_string('type');

        IF UPPER(dml_type) = 'INSERT' THEN
            RETURN parse_insert(json_dml);
        ELSIF UPPER(dml_type) = 'DELETE' THEN
            buff := parse_delete(json_dml);
        ELSIF UPPER(dml_type) = 'UPDATE' THEN
            buff := parse_update(json_dml);
        END IF;

        IF json_dml.has('where') THEN
            buff := buff || ' WHERE ' || parse_where(json_dml.get_array('where'));
        END IF;
        buff := buff || ';';

        RETURN buff;
    END parse_dml;


    FUNCTION parse_ddl_cols(json_cols IN JSON_ARRAY_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        col_obj JSON_OBJECT_T;
    BEGIN
        FOR i in 0..json_cols.get_size - 1 LOOP
            col_obj := TREAT(json_cols.get(i) AS JSON_OBJECT_T);
            IF NOT col_obj.has('col_name') OR col_obj.get_string('col_name') IS NULL THEN
                RAISE_APPLICATION_ERROR(-20005, 'Error in parse_ddl_cols(). There is not "col_name"');
            END IF;
            buff := buff || col_obj.get_string('col_name') || ' ';

            IF NOT col_obj.has('data_type') OR col_obj.get_string('data_type') IS NULL THEN
                RAISE_APPLICATION_ERROR(-20020, 'Error in parse_ddl_cols(). There is not "data_type"');
            END IF;
            buff := buff || col_obj.get_string('data_type');

            IF col_obj.has('constraint') AND col_obj.get_string('constraint') IS NOT NULL THEN
                buff := buff || ' ' || col_obj.get_string('constraint');
            END IF;

            buff := buff || ',' || CHR(10);
        END LOOP;

        RETURN RTRIM(buff, ',' || CHR(10));
    END parse_ddl_cols;


    FUNCTION parse_create_table(json_ddl IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
    BEGIN
        buff := 'CREATE TABLE ';
        IF NOT json_ddl.has('table_name') OR json_ddl.get_string('table_name') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20012, 'Error in parse_create_table(). There is no "table_name" section');
        END IF;
        buff := buff || json_ddl.get_string('table_name') || ' (' || CHR(10);

        IF NOT json_ddl.has('cols') OR json_ddl.get_array('cols') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20012, 'Error in parse_create_table(). There is no "cols" section');
        END IF;
        buff := buff || parse_ddl_cols(json_ddl.get_array('cols'));

        RETURN buff || CHR(10) || ');';
    END parse_create_table;


    FUNCTION parse_drop_table(json_ddl IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
    BEGIN
        buff := 'DROP TABLE ';
        IF NOT json_ddl.has('table_name') OR json_ddl.get_string('table_name') IS NULL THEN
            RAISE_APPLICATION_ERROR(-20012, 'Error in parse_drop_table(). There is no "table_name" section');
        END IF;
        buff := buff || json_ddl.get_string('table_name') || ';';
        RETURN buff;
    END parse_drop_table;


    FUNCTION parse_ddl(json_ddl IN JSON_OBJECT_T) RETURN VARCHAR2
    IS
        buff VARCHAR2(10000);
        ddl_type VARCHAR2(20);
    BEGIN
        IF NOT json_ddl.has('type') OR json_ddl.get_string('type') IS NULL THEN
           RAISE_APPLICATION_ERROR(-20012, 'Error in parse_ddl(). There is no "type" section');
        END IF;
        ddl_type := json_ddl.get_string('type');

        IF UPPER(ddl_type) = 'CREATE' THEN
            RETURN parse_create_table(json_ddl);
        ELSIF UPPER(ddl_type) = 'DROP' THEN
            RETURN parse_drop_table(json_ddl);
        ELSE
            RAISE_APPLICATION_ERROR(-20022, 'Error in parse_ddl(). UNREACHABLE!');
        END IF;
    END parse_ddl;


    FUNCTION parse_json(json_str IN VARCHAR2) RETURN VARCHAR2
    IS
        json_obj JSON_OBJECT_T;
    BEGIN
        json_obj := JSON_OBJECT_T(json_str);
        IF json_obj IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Error in parse_json(). json_obj = NULL');
        ELSIF json_obj.has('select') THEN
            RETURN parse_select(json_obj.get_object('select')) || ';';
        ELSIF json_obj.has('DML') THEN
            RETURN parse_dml(json_obj.get_object('DML'));
        ELSIF json_obj.has('DDL') THEN
            RETURN parse_ddl(json_obj.get_object('DDL'));
        ELSE
            RAISE_APPLICATION_ERROR(-20002, 'Error in parse_json(). UNREACHABLE!');
        END IF;

    END parse_json;


    FUNCTION read(dir VARCHAR2, fname VARCHAR2) RETURN VARCHAR2
    IS
        file UTL_FILE.FILE_TYPE;
        buff VARCHAR2(10000);
        str VARCHAR2(500);
    BEGIN
        file := UTL_FILE.FOPEN(dir, fname, 'R', 32767);
        IF NOT UTL_FILE.IS_OPEN(file) THEN
            DBMS_OUTPUT.PUT_LINE('File ' || fname || ' does not open!');
            RETURN NULL;
        END IF;

        LOOP
            BEGIN
                UTL_FILE.GET_LINE(file, str);
                buff := buff || str;
                EXCEPTION
                    WHEN OTHERS THEN EXIT;
            END;
        END LOOP;
        UTL_FILE.FCLOSE(file);
        RETURN buff;
    END read;
END json_parser;

DROP table tab1;
DROP table tab2;

CREATE TABLE tab1 (
    id NUMBER UNIQUE NOT NULL,
    name VARCHAR2(50),
    surname VARCHAR2(50),
    val NUMBER
);

CREATE TABLE tab2 (
    id NUMBER UNIQUE NOT NULL,
    price NUMBER NOT NULL,
    salary NUMBER NOT NULL
);

DROP SEQUENCE tab1_seq;
DROP SEQUENCE tab2_seq;
CREATE SEQUENCE tab1_seq START WITH 1;
CREATE SEQUENCE tab2_seq START WITH 1;


CREATE OR REPLACE TRIGGER tab1_auto_increment
BEFORE INSERT ON tab1
FOR EACH ROW
BEGIN
    IF :new.id = 0 THEN
        SELECT tab1_seq.nextval
        INTO :new.id
        FROM DUAL;
    END IF;
END;

CREATE OR REPLACE TRIGGER tab2_auto_increment
BEFORE INSERT ON tab2
FOR EACH ROW
BEGIN
    IF :new.id = 0 THEN
        SELECT tab2_seq.nextval
        INTO :new.id
        FROM DUAL;
    END IF;
END;

SELECT json_parser.parse_json(json_parser.read('MY_DIR', 'tab-1.json')) FROM dual;
SELECT json_parser.parse_json(json_parser.read('MY_DIR', 'tab-2.json')) FROM dual;
SELECT json_parser.parse_json(json_parser.read('MY_DIR', 'task.json')) FROM dual;

CREATE TABLE tab1 (
id INTEGER PRIMARY KEY,
name VARCHAR2(50),
val INTEGER
);

CREATE TABLE tab2 (
id INTEGER PRIMARY KEY,
name VARCHAR2(50),
val INTEGER
);

SELECT *
FROM tab1
WHERE tab1.id in (SELECT
id
FROM tab2
WHERE name LIKE '%a%' AND val BETWEEN 2 AND 4
)
;