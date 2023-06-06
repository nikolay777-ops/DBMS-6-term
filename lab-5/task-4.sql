CREATE OR REPLACE DIRECTORY REPORT_DIR AS '/opt/oracle'

DECLARE
    file UTL_FILE.FILE_TYPE;
BEGIN
    file := UTL_FILE.fopen('REPORT_DIR', 'report.html', 'W');
END;

select * from BACKUP_HISTORY;

BEGIN
    generate_report(TO_DATE('2023-05-02 18:15:33', 'YYYY-MM-DD HH24:MI:SS'));
end;

select * from BACKUP_HISTORY;

BEGIN
    BACKUP_HISTORY_PACKAGE.DO_BACKUP_HISTORY(6000000);
END;

select * from label;

DELETE FROM BACKUP_HISTORY WHERE 1=1;

SELECT * FROM BACKUP_HISTORY;

CREATE OR REPLACE PROCEDURE generate_report(desired_date DATE)
IS
    file UTL_FILE.file_type;
    buff VARCHAR(1000);
    num_performer_insert NUMBER;
    num_performer_update NUMBER;
    num_performer_delete NUMBER;

    num_label_insert NUMBER;
    num_label_update NUMBER;
    num_label_delete NUMBER;

    num_music_genre_insert NUMBER;
    num_music_genre_update NUMBER;
    num_music_genre_delete NUMBER;
BEGIN
    file := UTL_FILE.fopen('REPORT_DIR', 'report.html', 'W');
    IF NOT UTL_FILE.IS_OPEN(file) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error in generate_report(). File ' || 'report.html' || ' does not open!');
    END IF;

    buff := HTF.HTMLOPEN || CHR(10) || HTF.headopen || CHR(10) || HTF.title('Report')
            || CHR(10) || HTF.headclose || CHR(10) ||HTF.bodyopen || CHR(10);

    SELECT COUNT(*) INTO num_performer_insert FROM BACKUP_HISTORY
    WHERE (NEW_PERFORMER_ID IS NOT NULL OR OLD_PERFORMER_ID IS NOT NULL)
      AND OPERATION = 'insert' AND OPERATION_DATE >= desired_date;

    SELECT COUNT(*) INTO num_performer_update FROM BACKUP_HISTORY
    WHERE (NEW_PERFORMER_ID IS NOT NULL OR OLD_PERFORMER_ID IS NOT NULL)
      AND OPERATION = 'update' AND OPERATION_DATE >= desired_date;

    SELECT COUNT(*) INTO num_performer_delete FROM BACKUP_HISTORY
    WHERE (NEW_PERFORMER_ID IS NOT NULL OR OLD_PERFORMER_ID IS NOT NULL)
      AND OPERATION = 'delete' AND OPERATION_DATE >= desired_date;

    SELECT COUNT(*) INTO num_label_insert FROM BACKUP_HISTORY
    WHERE (NEW_LABEL_ID IS NOT NULL OR OLD_LABEL_ID IS NOT NULL)
      AND OPERATION = 'insert' AND OPERATION_DATE >= desired_date;

    SELECT COUNT(*) INTO num_label_update FROM BACKUP_HISTORY
    WHERE (NEW_LABEL_ID IS NOT NULL OR OLD_LABEL_ID IS NOT NULL)
      AND OPERATION = 'update' AND OPERATION_DATE >= desired_date;

    SELECT COUNT(*) INTO num_label_delete FROM BACKUP_HISTORY
    WHERE (NEW_LABEL_ID IS NOT NULL OR OLD_LABEL_ID IS NOT NULL)
      AND OPERATION = 'delete' AND OPERATION_DATE >= desired_date;

    SELECT COUNT(*) INTO num_music_genre_insert FROM BACKUP_HISTORY
    WHERE (NEW_MUSIC_GENRE_ID IS NOT NULL OR OLD_MUSIC_GENRE_ID IS NOT NULL)
      AND OPERATION = 'insert' AND OPERATION_DATE >= desired_date;

    SELECT COUNT(*) INTO num_music_genre_update FROM BACKUP_HISTORY
    WHERE (NEW_MUSIC_GENRE_ID IS NOT NULL OR OLD_MUSIC_GENRE_ID IS NOT NULL)
      AND OPERATION = 'update' AND OPERATION_DATE >= desired_date;

    SELECT COUNT(*) INTO num_music_genre_delete FROM BACKUP_HISTORY
    WHERE (NEW_MUSIC_GENRE_ID IS NOT NULL OR OLD_MUSIC_GENRE_ID IS NOT NULL)
      AND OPERATION = 'delete' AND OPERATION_DATE >= desired_date;

    buff := buff || HTF.TABLEOPEN || CHR(10) || HTF.TABLEROWOPEN || CHR(10) || HTF.TABLEHEADER('') || CHR(10) || HTF.TABLEHEADER('Performer') || CHR(10) ||
    HTF.TABLEHEADER('Label') || CHR(10) || HTF.TABLEHEADER('Students') || CHR(10) || HTF.TABLEROWCLOSE || CHR(10);

    buff := buff || HTF.TABLEROWOPEN || CHR(10) || HTF.TABLEHEADER('insert') || CHR(10) || HTF.TABLEDATA(num_music_genre_insert) || CHR(10) ||
    HTF.TABLEDATA(num_label_insert) || CHR(10) || HTF.TABLEDATA(num_performer_insert) || CHR(10) || HTF.TABLEROWCLOSE || CHR(10);

    buff := buff || HTF.TABLEROWOPEN || CHR(10) || HTF.TABLEHEADER('update') || CHR(10) || HTF.TABLEDATA(num_music_genre_update) || CHR(10) ||
    HTF.TABLEDATA(num_label_update) || CHR(10) || HTF.TABLEDATA(num_performer_update) || CHR(10) || HTF.TABLEROWCLOSE || CHR(10);

    buff := buff || HTF.TABLEROWOPEN || CHR(10) || HTF.TABLEHEADER('delete') || CHR(10) || HTF.TABLEDATA(num_music_genre_delete) || CHR(10) ||
    HTF.TABLEDATA(num_label_delete) || CHR(10) || HTF.TABLEDATA(num_performer_delete) || CHR(10) || HTF.TABLEROWCLOSE || CHR(10);

    buff := buff || HTF.TABLECLOSE || CHR(10) || HTF.bodyclose || CHR(10) || HTF.htmlclose;

    UTL_FILE.put_line (file, buff);
    UTL_FILE.fclose(file);
    EXCEPTION WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error in generate_report(). NO_DATA_FOUND');
END generate_report;