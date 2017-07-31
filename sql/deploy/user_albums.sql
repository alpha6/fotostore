-- Deploy fotostore:user_albums to sqlite
-- requires: users
-- requires: albums

BEGIN;

CREATE TABLE user_albums (
    record_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id   INTEGER REFERENCES users (user_id),
    album_id  INTEGER REFERENCES albums (album_id) 
);


COMMIT;
