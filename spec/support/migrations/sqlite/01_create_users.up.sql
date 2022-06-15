CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    active BOOL NOT NULL,
    created_at DATETIME(6) DEFAULT (datetime('now')),
    updated_at DATETIME(6) DEFAULT (datetime('now'))
);
