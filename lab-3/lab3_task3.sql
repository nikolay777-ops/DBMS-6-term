CREATE OR REPLACE PROCEDURE ddl_create_table(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2, tab_name VARCHAR2)
IS
    CURSOR tab_cols IS
    SELECT column_name, data_type, data_length, nullable
    FROM ALL_TAB_COLUMNS
    WHERE OWNER = dev_schema_name AND TABLE_NAME = tab_name
    ORDER BY COLUMN_NAME;

    CURSOR tab_constraints IS
    SELECT ALL_CONSTRAINTS.CONSTRAINT_NAME, ALL_CONSTRAINTS.CONSTRAINT_TYPE,
           ALL_CONSTRAINTS.SEARCH_CONDITION, ALL_IND_COLUMNS.COLUMN_NAME
    FROM ALL_CONSTRAINTS
    INNER JOIN all_ind_columns
        ON all_constraints.constraint_name = all_ind_columns.index_name
    WHERE OWNER = dev_schema_name AND ALL_CONSTRAINTS.TABLE_NAME = tab_name
    ORDER BY ALL_CONSTRAINTS.CONSTRAINT_NAME;

    CURSOR tab_fks(pr VARCHAR2) IS
        SELECT ALL_CONSTRAINTS.CONSTRAINT_NAME, ALL_CONSTRAINTS.CONSTRAINT_TYPE,
               ALL_CONSTRAINTS.SEARCH_CONDITION, ALL_IND_COLUMNS.COLUMN_NAME
        FROM ALL_CONSTRAINTS
        INNER JOIN ALL_IND_COLUMNS
        ON ALL_CONSTRAINTS.CONSTRAINT_NAME = ALL_IND_COLUMNS.INDEX_NAME
        WHERE OWNER = dev_schema_name
          AND ALL_CONSTRAINTS.CONSTRAINT_NAME = pr
        ORDER BY ALL_CONSTRAINTS.CONSTRAINT_NAME;

    CURSOR c_constraints IS
    SELECT r_constraint_name
    FROM all_constraints
    WHERE constraint_type = 'R'
    AND OWNER = dev_schema_name AND TABLE_NAME = tab_name;

    result ALL_SOURCE.text%TYPE;
    pr_key ALL_CONSTRAINTS.R_CONSTRAINT_NAME%TYPE;
    v_r_constraint_name all_constraints.r_constraint_name%TYPE;
    tab2_name ALL_CONSTRAINTS.TABLE_NAME%TYPE;
    c_name ALL_CONSTRAINTS.CONSTRAINT_NAME%TYPE;
    amount NUMBER;

BEGIN
    result := concat('DROP TABLE ', prod_schema_name || '.' || UPPER(tab_name) || ';' || chr(10));
    result := concat(result, 'CREATE TABLE ' || prod_schema_name || '.' || UPPER(tab_name) || '(' || chr(10));
    FOR table_column IN tab_cols
    LOOP
        result := concat(result, chr(9) || table_column.column_name || ' ' || table_column.data_type || '(' || table_column.data_length || ')');
        IF table_column.nullable = 'N' THEN
            result := concat(result, ' NOT NULL');
        END IF;
        result := concat(result, ',' || chr(10));
    END LOOP;
    FOR table_constraint IN tab_constraints
    LOOP
        c_name := table_constraint.CONSTRAINT_NAME;
        result := concat(result, chr(9) || 'CONSTRAINT ' || table_constraint.constraint_name || ' ');
        IF table_constraint.constraint_type = 'U' THEN
            result := concat(result, 'UNIQUE ');
        END IF;
        IF table_constraint.constraint_type = 'P' THEN
            result := concat(result, 'PRIMARY KEY ');
        END IF;
        result := concat(result, '(' || table_constraint.column_name || ' ' || table_constraint.search_condition || '),' || chr(10));
    END LOOP;
    SELECT count(*) INTO amount FROM all_constraints WHERE OWNER = dev_schema_name and table_name = tab_name and constraint_type = 'R';
    IF amount <> 0 THEN
        FOR с IN c_constraints
        LOOP
            v_r_constraint_name := с.R_CONSTRAINT_NAME;
            result := concat(result, chr(9) || 'CONSTRAINT ' || c_name || ' FOREIGN KEY (');
            FOR key IN tab_fks(v_r_constraint_name)
            LOOP
                result := concat(result, key.column_name || ', ');
            END LOOP;
            result := concat(result, ') ');
            result := concat(result, 'REFERENCES ' || prod_schema_name || '.');
            SELECT table_name INTO tab2_name FROM all_constraints WHERE constraint_name = v_r_constraint_name;
            result := concat(result, tab2_name);
            result := concat(result, '(');
            FOR key IN tab_fks(v_r_constraint_name)
            LOOP
                result := concat(result, key.column_name || ', ');
            END LOOP;
            result := concat(result, '),' || chr(10));
        end loop;
--         SELECT r_constraint_name INTO pr_key FROM all_constraints WHERE owner = dev_schema_name AND table_name = tab_name AND constraint_type = 'R';

    END IF;
    result := concat(result, ');');
    result := replace(result, ',' || chr(10) || ')', chr(10) || ')');
    result := replace(result, ', )', ')');
    dbms_output.put_line(result);
END;

CREATE OR REPLACE PROCEDURE ddl_create_procedure(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2, procedure_name VARCHAR2)
IS
    CURSOR proc_text IS
        SELECT TEXT
        FROM all_source
        WHERE OWNER = dev_schema_name
            AND NAME = procedure_name
            and TYPE = 'PROCEDURE'
            and LINE <> 1;
    CURSOR proc_args IS
        SELECT ARGUMENT_NAME, DATA_TYPE
        FROM all_arguments
        WHERE OWNER = dev_schema_name
            AND OBJECT_NAME = procedure_name
            AND POSITION <> 0;
    result all_source.text%TYPE;
BEGIN
    result := concat('CREATE OR REPLACE PROCEDURE ' || prod_schema_name || '.' || procedure_name, '(');
    FOR arg IN proc_args
    LOOP
        result := concat(result, arg.argument_name || ' ' || arg.data_type || ', ');
    END LOOP;
    result := concat(result, ') IS' || chr(10));

    FOR line IN proc_text
    LOOP
        result := concat(result, line.text);
    END LOOP;
    result := replace(result, ', )', ')');
    result := replace(result, '()');
    dbms_output.put_line(result);
END;

CREATE OR REPLACE PROCEDURE ddl_create_function(dev_schema_name VARCHAR2, function_name VARCHAR2, prod_schema_name VARCHAR2) IS
    CURSOR procedure_text IS
        SELECT TEXT
        FROM all_source
        WHERE OWNER = dev_schema_name
            AND NAME = function_name
            AND TYPE = 'FUNCTION'
            AND LINE <> 1;
    CURSOR procedure_args IS
        SELECT ARGUMENT_NAME, DATA_TYPE
        FROM all_arguments
        WHERE OWNER = dev_schema_name
            AND OBJECT_NAME = function_name
            AND POSITION <> 0;
    arg_type all_arguments.data_type%TYPE;
    result all_source.text%TYPE;
BEGIN
    result := concat('CREATE OR REPLACE FUNCTION ' || prod_schema_name || '.' || function_name, '(');
    FOR arg IN procedure_args
    LOOP
        result := concat(result, arg.argument_name || ' ' || arg.data_type || ', ');
    END LOOP;
    SELECT DATA_TYPE INTO arg_type FROM all_arguments WHERE OWNER = dev_schema_name AND OBJECT_NAME = function_name AND POSITION = 0;
    result := concat(result, ') RETURN ' || arg_type || ' IS' || chr(10));

    FOR line IN procedure_text
    LOOP
        result := concat(result, line.text);
    END LOOP;
    result := replace(result, ', )', ')');
    result := replace(result, '()');
    dbms_output.put_line(result);
END;

CREATE OR REPLACE PROCEDURE ddl_create_index(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2, ind_name VARCHAR2) IS
    tab_name all_indexes.table_name%TYPE;

    CURSOR index_columns IS
        SELECT COLUMN_NAME
        FROM all_ind_columns
        INNER JOIN all_indexes
        ON all_ind_columns.INDEX_NAME = all_indexes.INDEX_NAME
            AND all_ind_columns.INDEX_OWNER = all_indexes.OWNER
        WHERE index_owner = dev_schema_name
            AND all_indexes.INDEX_NAME = ind_name;
    result all_source.text%TYPE;
BEGIN
    SELECT TABLE_NAME INTO tab_name FROM ALL_INDEXES WHERE OWNER = dev_schema_name and INDEX_NAME = ind_name;
    result := concat('DROP INDEX ' || prod_schema_name || '.' || ind_name || ';' || chr(10), 'CREATE INDEX ' || prod_schema_name || '.' || ind_name || ' ON ' || prod_schema_name || '.' || tab_name || '(');
    FOR index_column IN index_columns
    LOOP
        result := concat(result, index_column.column_name || ', ');
    END LOOP;
    result := concat(result, ');');
    result := replace(result, ', )', ')');
    dbms_output.put_line(result);
end;

CREATE OR REPLACE PROCEDURE ddl_create_package(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2, package_name VARCHAR2) IS
    CURSOR package_text IS
        SELECT TEXT
        FROM all_source
        WHERE OWNER = dev_schema_name
            AND NAME = package_name
            AND TYPE = 'PACKAGE'
            AND LINE <> 1;
    result all_source.text%TYPE;
BEGIN
    result := concat('CREATE OR REPLACE PACKAGE ' || prod_schema_name || '.' || package_name, ' IS');

    FOR line IN package_text
    LOOP
        result := concat(result, line.text);
    END LOOP;
    dbms_output.put_line(result);
END;

CREATE OR REPLACE PROCEDURE delete_tables(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2) IS
    CURSOR TABLES IS
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = prod_schema_name
        MINUS
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_schema_name;
BEGIN
    FOR tab IN TABLES
    LOOP
        dbms_output.put_line('DROP TABLE ' || prod_schema_name || '.' || tab.table_name || ';');
    END LOOP;
END;

CREATE OR REPLACE PROCEDURE delete_procedures(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2) IS
    CURSOR procedures IS
        SELECT OBJECT_NAME FROM ALL_PROCEDURES WHERE OWNER = prod_schema_name AND TYPE = 'PROCEDURE'
        MINUS
        SELECT OBJECT_NAME FROM ALL_PROCEDURES WHERE OWNER = dev_schema_name and TYPE = 'PROCEDURE';
BEGIN
    FOR proc IN procedures
    LOOP
        dbms_output.put_line('DROP PROCEDURE ' || prod_schema_name || '.' || proc.object_name || ';');
    END LOOP;
END;

CREATE OR REPLACE PROCEDURE delete_functions(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2) IS
    CURSOR FUNCTIONS IS
        SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = prod_schema_name AND OBJECT_TYPE = 'FUNCTION'
        MINUS
        SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = dev_schema_name AND OBJECT_TYPE = 'FUNCTION';
BEGIN
    FOR func IN FUNCTIONS
    LOOP
        dbms_output.put_line('DROP FUNCTION ' || prod_schema_name || '.' || func.object_name || ';');
    END LOOP;
END;

CREATE OR REPLACE PROCEDURE delete_indexes(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2) IS
    CURSOR inds IS
        SELECT INDEX_NAME FROM ALL_INDEXES WHERE OWNER = prod_schema_name
        MINUS
        SELECT INDEX_NAME FROM ALL_INDEXES WHERE OWNER= dev_schema_name;
BEGIN
    FOR ind IN inds
    LOOP
        dbms_output.put_line('DROP INDEX ' || prod_schema_name || '.' || ind.index_name || ';');
    END LOOP;
END;

CREATE OR REPLACE PROCEDURE delete_packages(dev_schema_name VARCHAR2, prod_schema_name VARCHAR2) IS
    CURSOR PACKAGES IS
        SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = prod_schema_name AND OBJECT_TYPE = 'PACKAGE'
        MINUS
        SELECT OBJECT_NAME FROM ALL_OBJECTS WHERE OWNER = dev_schema_name AND OBJECT_TYPE = 'PACKAGE';
BEGIN
    FOR pkg IN PACKAGES
    LOOP
        dbms_output.put_line('DROP PACKAGE ' || prod_schema_name || '.' || pkg.object_name || ';');
    END LOOP;
END;
