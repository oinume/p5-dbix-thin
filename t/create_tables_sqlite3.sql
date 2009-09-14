CREATE TABLE user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',
    created_at DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    updated_at DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00'
);

