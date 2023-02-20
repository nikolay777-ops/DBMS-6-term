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
    SELECT stud_seq.nextval
    INTO :new.id
    FROM DUAL;
END;

CREATE OR REPLACE TRIGGER group_auto_increment
BEFORE INSERT ON groups
FOR EACH ROW
BEGIN
    SELECT group_seq.nextval
    INTO :new.id
    FROM DUAL;
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

BEGIN
    INSERT INTO groups VALUES (0, '053505', 10);
end;
DELETE FROM groups
WHERE name = '053505';

DELETE FROM groups
WHERE id = 4;
SELECT * FROM groups;

SELECT * FROM students;

BEGIN INSERT INTO students VALUES (0, 'Nicko', 4); end;
BEGIN INSERT INTO students VALUES (0, 'Valera', 4); end;
BEGIN INSERT INTO students VALUES (0, 'Obama', 4); end;