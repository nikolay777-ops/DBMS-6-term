ALTER SESSION SET "_ORACLE_SCRIPT"=true;
create user lab5 identified by 11;

GRANT ALL PRIVILEGES to lab5;

DROP table performer;
DROP table label;
DROP table music_genre;

CREATE TABLE performer(
    id NUMBER PRIMARY KEY,
    name VARCHAR2(50) NOT NULL,
    birth DATE NOT NULL,
    royalty NUMBER NOT NULL,
    label_id NUMBER,
    genre_id NUMBER,
    CONSTRAINT fk_perf_to_label FOREIGN KEY(label_id) REFERENCES label(id),
    CONSTRAINT fk_perf_to_genre FOREIGN KEY(genre_id) REFERENCES music_genre(id)
);

CREATE TABLE label(
    id NUMBER PRIMARY KEY,
    name VARCHAR2(20),
    p_quality NUMBER,
    create_date DATE NOT NULL
);

CREATE TABLE music_genre (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(20),
    p_quality NUMBER
);
DROP trigger update_label_p_quality;
ALTER TRIGGER update_label_p_quality DISABLE ;

CREATE OR REPLACE TRIGGER update_label_p_quality
BEFORE INSERT OR DELETE OR UPDATE OF LABEL_ID ON PERFORMER
FOR EACH ROW
BEGIN
    CASE
        WHEN INSERTING THEN
        IF :NEW.label_id IS NOT NULL THEN
            UPDATE label
            SET label.p_quality = label.p_quality + 1
            WHERE :NEW.label_id = label.ID;
        end if;
        WHEN UPDATING THEN
            UPDATE label
            SET label.p_quality = label.p_quality + 1
            WHERE :NEW.label_id = label.ID;
            UPDATE label
            SET label.p_quality = label.p_quality - 1
            WHERE :OLD.label_id = label.ID;
        WHEN DELETING THEN
            IF :OLD.label_id IS NOT NULL THEN
                UPDATE label
                SET label.p_quality = label.p_quality - 1
                WHERE :OLD.label_id = label.ID;
            end if;
    END CASE;
END;

CREATE OR REPLACE TRIGGER update_music_genre_p_quality
BEFORE INSERT OR DELETE OR UPDATE OF genre_id ON PERFORMER
FOR EACH ROW
BEGIN
    CASE
        WHEN INSERTING THEN
        IF :NEW.genre_id IS NOT NULL THEN
            UPDATE music_genre
            SET music_genre.p_quality = music_genre.p_quality + 1
            WHERE :NEW.genre_id = music_genre.ID;
        end if;
        WHEN UPDATING THEN
            UPDATE music_genre
            SET music_genre.p_quality = music_genre.p_quality + 1
            WHERE :NEW.genre_id = music_genre.ID;
            UPDATE music_genre
            SET music_genre.p_quality = music_genre.p_quality - 1
            WHERE :OLD.genre_id = music_genre.ID;
        WHEN DELETING THEN
            IF :OLD.genre_id IS NOT NULL THEN
                UPDATE music_genre
                SET music_genre.p_quality = music_genre.p_quality - 1
                WHERE :OLD.genre_id = music_genre.ID;
            end if;
    END CASE;
END;

INSERT INTO label(id, name, p_quality, create_date)
VALUES (
        0, 'Warner Music', 0, TO_DATE('2013-08-08', 'YYYY-MM-DD')
       );
INSERT INTO label(id, name, p_quality, create_date)
VALUES (
        1, 'Def Jam Records', 0, TO_DATE('2013-08-08', 'YYYY-MM-DD')
       );
INSERT INTO label(id, name, p_quality, create_date)
VALUES (
        2, 'Interscope', 0, TO_DATE('2013-08-08', 'YYYY-MM-DD')
       );

INSERT INTO music_genre(id, name, p_quality)
VALUES
(0, 'rock', 0);
INSERT INTO music_genre(id, name, p_quality)
VALUES
(1, 'hip-hop', 0);
INSERT INTO music_genre(id, name, p_quality)
VALUES
(2, 'punk', 0);

INSERT INTO PERFORMER(id, name, birth, royalty, label_id, genre_id)
VALUES
(
 0, 'Kiss', TO_DATE('1988-02-01', 'YYYY-MM-DD'), 150, 0, 0
)

INSERT INTO PERFORMER(id, name, birth, royalty, label_id, genre_id)
VALUES
(
 1, 'Metallica', TO_DATE('1978-02-01', 'YYYY-MM-DD'), 150, 0, 0
)

INSERT INTO PERFORMER(id, name, birth, royalty, label_id, genre_id)
VALUES
(
 2, 'Eminem', TO_DATE('1999-02-01', 'YYYY-MM-DD'), 250, 1, 1
);
