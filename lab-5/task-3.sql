ALTER TRIGGER save_music_genre_backup_history DISABLE;
ALTER TRIGGER save_label_backup_history DISABLE;
ALTER TRIGGER save_performer_backup_history DISABLE;

ALTER TRIGGER save_music_genre_backup_history ENABLE ;
ALTER TRIGGER save_label_backup_history ENABLE;
ALTER TRIGGER save_performer_backup_history ENABLE;

SELECT id, OPERATION, TO_CHAR(OPERATION_DATE, 'YYYY-MM-DD HH24:MI:SS') operation_date FROM BACKUP_HISTORY;

CREATE OR REPLACE PACKAGE backup_history_package AS
    PROCEDURE do_backup_history(to_date IN DATE);
    PROCEDURE do_backup_history(date_period IN NUMBER);
END backup_history_package;

CREATE OR REPLACE PACKAGE BODY backup_history_package AS
    PROCEDURE restore_performer(rec IN BACKUP_HISTORY%rowtype)
    IS
    BEGIN
        IF rec.OPERATION = 'insert' THEN
            DELETE FROM PERFORMER WHERE id = rec.NEW_PERFORMER_ID;
        ELSIF rec.OPERATION = 'update' THEN
            UPDATE PERFORMER
            SET id = rec.OLD_PERFORMER_ID, name = rec.PERFORMER_NAME,
                birth = rec.PERFORMER_BIRTH, royalty = rec.royalty, label_id = rec.LABEL_ID, genre_id = rec.GENRE_ID
            WHERE id = rec.NEW_PERFORMER_ID;
        ELSE
            INSERT INTO PERFORMER(id, name, birth, royalty, label_id, genre_id)
            VALUES (rec.OLD_PERFORMER_ID, rec.PERFORMER_NAME,
                    rec.PERFORMER_BIRTH, rec.ROYALTY, rec.LABEL_ID, rec.GENRE_ID );
        end if;
    END restore_performer;

    PROCEDURE restore_label(rec IN BACKUP_HISTORY%rowtype)
    IS
    BEGIN
        IF rec.OPERATION = 'insert' THEN
            DELETE FROM LABEL WHERE id = rec.NEW_LABEL_ID;
        ELSIF rec.OPERATION = 'update' THEN
            UPDATE LABEL
            SET id = rec.OLD_LABEL_ID, name = rec.LABEL_NAME, p_quality = rec.LABEL_P_QUALOTY,
                create_date = rec.LABEL_CREATE_DATE
            WHERE id = rec.NEW_LABEL_ID;
        ELSE
            INSERT INTO label(id, name, P_QUALITY, CREATE_DATE)
            VALUES(rec.OLD_LABEL_ID, rec.LABEL_NAME, rec.LABEL_P_QUALOTY, rec.LABEL_CREATE_DATE);
        end if;
    END restore_label;

    PROCEDURE restore_music_genre(rec IN BACKUP_HISTORY%rowtype)
    IS
    BEGIN
         IF rec.OPERATION = 'insert' THEN
            DELETE FROM MUSIC_GENRE WHERE id = rec.NEW_MUSIC_GENRE_ID;
        ELSIF rec.OPERATION = 'update' THEN
            UPDATE MUSIC_GENRE
            SET id = rec.OLD_MUSIC_GENRE_ID, name = rec.MUSIC_GENRE_NAME,
                p_quality = rec.MUSIC_GENRE_P_QUALITY
            WHERE id = rec.NEW_MUSIC_GENRE_ID;
        ELSE
            INSERT INTO MUSIC_GENRE(id, name, P_QUALITY)
            VALUES(rec.OLD_MUSIC_GENRE_ID, rec.MUSIC_GENRE_NAME, rec.MUSIC_GENRE_P_QUALITY);
        end if;
    END restore_music_genre;

    PROCEDURE do_backup_history(to_date IN DATE)
    IS
        CURSOR history(h_date BACKUP_HISTORY.operation_date%TYPE)
        IS
        SELECT * FROM BACKUP_HISTORY
        WHERE operation_date >= h_date
        ORDER BY id DESC;
    BEGIN
        FOR record IN history(to_date) LOOP
            IF record.NEW_PERFORMER_ID IS NOT NULL OR record.OLD_PERFORMER_ID IS NOT NULL THEN
                restore_performer(record);
            ELSIF record.NEW_LABEL_ID IS NOT NULL OR record.OLD_LABEL_ID IS NOT NULL THEN
                restore_label(record);
            ELSIF record.NEW_MUSIC_GENRE_ID IS NOT NULL OR record.OLD_MUSIC_GENRE_ID IS NOT NULL THEN
                restore_music_genre(record);
            end if;
            delete from BACKUP_HISTORY where id = record.ID;
        END LOOP;
    END do_backup_history;

    PROCEDURE do_backup_history(date_period IN NUMBER)
    IS
    BEGIN
        do_backup_history(SYSDATE - NUMTODSINTERVAL(date_period / 1000, 'SECOND'));
    END do_backup_history;
END backup_history_package;