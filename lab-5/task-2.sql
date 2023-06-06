DROP table backup_history;

CREATE TABLE backup_history(
    id NUMBER GENERATED ALWAYS as identity PRIMARY KEY,
    new_performer_id NUMBER,
    old_performer_id NUMBER,
    performer_name VARCHAR2(50),
    performer_birth DATE,
    royalty NUMBER,
    label_id NUMBER,
    genre_id NUMBER,
    old_label_id NUMBER,
    new_label_id NUMBER,
    label_name VARCHAR2(20),
    label_p_qualoty NUMBER,
    label_create_date DATE,
    old_music_genre_id NUMBER,
    new_music_genre_id NUMBER,
    music_genre_name VARCHAR2(20),
    music_genre_p_quality NUMBER,
    operation_date DATE,
    operation VARCHAR2(6) NOT NULL CHECK (operation in ('insert', 'update', 'delete'))
);
SELECT * FROM backup_history;

CREATE OR REPLACE TRIGGER save_performer_backup_history
AFTER INSERT OR UPDATE OR DELETE
ON PERFORMER
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO backup_history(new_performer_id, performer_name, performer_birth, royalty,
                                   label_id, genre_id, operation_date, operation)
        VALUES (:NEW.id, :NEW.name, :NEW.birth, :NEW.royalty, :NEW.label_id, :NEW.genre_id,
                SYSDATE, 'insert');
    ELSIF UPDATING THEN
        INSERT INTO backup_history(old_performer_id, new_performer_id, performer_name, performer_birth, royalty,
                                   label_id, genre_id, operation_date, operation)
        VALUES (:OLD.id, :NEW.id, :OLD.name, :OLD.birth, :OLD.royalty, :OLD.label_id, :OLD.genre_id,
                SYSDATE, 'update');
    ELSIF DELETING THEN
        INSERT INTO backup_history(old_performer_id, performer_name, performer_birth, royalty,
                                   label_id, genre_id, operation_date, operation)
        VALUES (:OLD.id, :OLD.name, :OLD.birth, :OLD.royalty, :OLD.label_id, :OLD.genre_id,
                SYSDATE, 'delete');
    END IF;
END save_performer_backup_history;

CREATE OR REPLACE TRIGGER save_label_backup_history
AFTER INSERT OR UPDATE OR DELETE
ON label
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO backup_history(new_label_id, label_name, label_p_qualoty, label_create_date,
                                   operation_date, operation)
        VALUES (:NEW.id, :NEW.name, :NEW.p_quality, :NEW.create_date, SYSDATE, 'insert');
    ELSIF UPDATING THEN
        INSERT INTO backup_history(old_label_id, new_label_id, label_name, label_p_qualoty, label_create_date,
                                   operation_date, operation)
        VALUES (:OLD.id, :NEW.id, :OLD.name, :OLD.p_quality, :OLD.create_date, SYSDATE, 'update');
    ELSIF DELETING THEN
        INSERT INTO backup_history(old_label_id, label_name, label_p_qualoty, label_create_date,
                                   operation_date, operation)
        VALUES (:OLD.id, :OLD.name, :OLD.p_quality, :OLD.create_date, SYSDATE, 'delete');
    END IF;
END save_label_backup_history;

CREATE OR REPLACE TRIGGER save_music_genre_backup_history
AFTER INSERT OR UPDATE OR DELETE
ON music_genre
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO backup_history(new_music_genre_id, music_genre_name, music_genre_p_quality,
                                   operation_date, operation)
        VALUES (:NEW.id, :NEW.name, :NEW.p_quality, SYSDATE, 'insert');
    ELSIF UPDATING THEN
        INSERT INTO backup_history(old_music_genre_id, new_music_genre_id, music_genre_name, music_genre_p_quality,
                                   operation_date, operation)
        VALUES (:OLD.id, :NEW.id, :OLD.name, :OLD.p_quality, SYSDATE, 'update');
    ELSIF DELETING THEN
        INSERT INTO backup_history(old_music_genre_id, music_genre_name, music_genre_p_quality,
                                   operation_date, operation)
        VALUES (:OLD.id, :OLD.name, :OLD.p_quality, SYSDATE, 'delete');
    END IF;
END save_music_genre_backup_history;

