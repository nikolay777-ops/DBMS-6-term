BEGIN INSERT INTO groups VALUES (0, '053501', 0); end;
BEGIN INSERT INTO groups VALUES (0, '053502', 0); end;
BEGIN INSERT INTO groups VALUES (0, '053503', 0); end;
BEGIN INSERT INTO groups VALUES (0, '053504', 0); end;


BEGIN INSERT INTO students VALUES (0, 'Nicko', 4); end;
BEGIN INSERT INTO students VALUES (0, 'Valera', 4); end;
BEGIN INSERT INTO students VALUES (0, 'Obama', 4); end;
INSERT INTO students VALUES (0, 'Dima', 2);
INSERT INTO students VALUES (0, 'Valera', 2);

SELECT * FROM student_journal;
SELECT * FROM groups;
SELECT * FROM students;

DROP TABLE students;
DROP TABLE groups;
DROP SEQUENCE stud_seq;
DROP SEQUENCE group_seq;
DROP TABLE student_journal;
DROP SEQUENCE journal_seq;

DELETE FROM groups
WHERE id = 4;


begin
    restore_info('2023-03-21 17:00:47.391712');
end;

CREATE TABLE students
(
    id NUMBER,
    name VARCHAR2(100),
    group_id NUMBER
      );

CREATE TABLE groups
(
    id NUMBER,
    name VARCHAR2(50),
    c_val NUMBER
);

ALTER TABLE students
ADD (
    CONSTRAINT students_pk PRIMARY KEY (id)
    );
ALTER TABLE groups
ADD (
    CONSTRAINT groups_pk PRIMARY KEY (id)
    );

CREATE SEQUENCE stud_seq START WITH 1;
CREATE SEQUENCE group_seq START WITH 1;


CREATE OR REPLACE TRIGGER stud_auto_increment
BEFORE INSERT ON students
FOR EACH ROW
BEGIN
    IF :new.id = 0 THEN
        SELECT stud_seq.nextval
        INTO :new.id
        FROM DUAL;
    END IF;
END;

CREATE OR REPLACE TRIGGER stud_check_integrity
BEFORE INSERT ON students
FOR EACH ROW
FOLLOWS stud_auto_increment
DECLARE
    check_id NUMBER default 0;
BEGIN
    SELECT id INTO check_id
    FROM students
    WHERE students.id = :new.id;

    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('You a good at this!');
END;

CREATE OR REPLACE TRIGGER group_auto_increment
BEFORE INSERT ON groups
FOR EACH ROW
BEGIN
    SELECT group_seq.nextval
    INTO :new.id
    FROM DUAL;
END;

CREATE OR REPLACE TRIGGER group_name_unique
BEFORE INSERT ON groups
FOR EACH ROW
FOLLOWS group_auto_increment
DECLARE
    gr_name VARCHAR2(20);
    app_exception EXCEPTION;
BEGIN
    SELECT name INTO gr_name
    FROM groups
    WHERE groups.id = :new.id;
    RAISE app_exception;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('New group added successfully!');

        WHEN app_exception THEN
        raise_application_error(-20001, 'That name of group already exists!');
END;

CREATE OR REPLACE TRIGGER cascade_delete_groups_students
BEFORE DELETE ON groups
FOR EACH ROW
DECLARE
    CURSOR del_students
    IS
    SELECT * FROM students
    WHERE group_id = :OLD.id;
BEGIN
    FOR del_st IN del_students LOOP
        DELETE FROM students
        WHERE id = del_st.id;
    end loop;
END;

-- task4
CREATE TABLE student_journal
(
    id NUMBER,
    act_date TIMESTAMP NOT NULL,
    action VARCHAR2(10) NOT NULL,
    old_id NUMBER,
    new_id NUMBER,
    group_old NUMBER,
    group_new NUMBER,
    name_old VARCHAR2(100),
    name_new VARCHAR2(100),
    CONSTRAINT stud_journal_pk PRIMARY KEY (id)
);

CREATE SEQUENCE journal_seq
START WITH 1;

CREATE OR REPLACE TRIGGER journal_act_trigger
    AFTER INSERT OR UPDATE OR DELETE ON students
    FOR EACH ROW
DECLARE
    ssDate TIMESTAMP;
BEGIN
    IF INSERTING THEN
        SELECT CURRENT_TIMESTAMP INTO ssDate FROM DUAL;
        INSERT INTO student_journal VALUES (journal_seq.NEXTVAL, ssDate, 'INSERT', NULL, :NEW.id, NULL, :NEW.group_id, NULL, :NEW.name);
    ELSIF UPDATING THEN
        SELECT CURRENT_TIMESTAMP INTO ssDate FROM DUAL;
        INSERT INTO student_journal VALUES (journal_seq.NEXTVAL,
                                            ssDate,
                                            'UPDATE', :OLD.id,
                                            :NEW.id, :OLD.group_id, :NEW.group_id, :OLD.name, :NEW.name);
    ELSIF DELETING THEN
        SELECT CURRENT_TIMESTAMP INTO ssDate FROM DUAL;
        INSERT INTO student_journal VALUES (journal_seq.NEXTVAL,
                                            ssDate,
                                            'DELETE', :OLD.id,
                                            NULL, :OLD.group_id, NULL, :OLD.name, NULL);
    END IF;
END;

CREATE OR REPLACE PROCEDURE restore_info
    (time in VARCHAR2)
IS
--     PRAGMA AUTONOMOUS_TRANSACTION;
    converted_time TIMESTAMP := TO_TIMESTAMP(time, 'yyyy-mm-dd hh24:mi:ss.ff6');
    CURSOR rest IS
    SELECT *
    FROM student_journal
    WHERE act_date >= converted_time
    ORDER BY id DESC;
BEGIN
    FOR act in rest
    LOOP
        IF act.action = 'INSERT' THEN
            DELETE FROM students
            WHERE students.id = act.new_id;
        ELSIF act.action = 'UPDATE' THEN
            UPDATE students
            SET students.name = act.name_old, students.group_id = act.group_old
            WHERE students.id = act.old_id;
        ELSIF act.action = 'DELETE' THEN
            INSERT INTO students VALUES (act.old_id, act.name_old, act.group_old);
        END IF;

--         DELETE FROM student_journal
--         WHERE id = act.id;
    END LOOP;
--     COMMIT;
END;

CREATE OR REPLACE TRIGGER t_update_C_VAL_GROUPS
BEFORE INSERT OR DELETE OR UPDATE OF GROUP_ID ON STUDENTS
FOR EACH ROW
BEGIN
      CASE
          WHEN INSERTING THEN
            IF :NEW.GROUP_ID IS NOT NULL THEN
                UPDATE GROUPS
                SET   GROUPS.C_VAL = GROUPS.C_VAL + 1
                WHERE :NEW.GROUP_ID = GROUPS.ID;
            END IF;
          WHEN UPDATING THEN
            UPDATE GROUPS
            SET   GROUPS.C_VAL = GROUPS.C_VAL + 1
            WHERE :NEW.GROUP_ID = GROUPS.ID;
            UPDATE GROUPS
            SET   GROUPS.C_VAL = GROUPS.C_VAL - 1
            WHERE :OLD.GROUP_ID = GROUPS.ID;
          WHEN DELETING THEN
            IF :OLD.GROUP_ID IS NOT NULL THEN
                UPDATE GROUPS
                SET   GROUPS.C_VAL = GROUPS.C_VAL - 1
                WHERE :OLD.GROUP_ID = GROUPS.ID;
            END IF;
      END CASE;
EXCEPTION WHEN OTHERS THEN RETURN;
END;

