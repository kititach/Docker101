CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL
);

INSERT INTO employees (name, department) VALUES
('Alice', 'Engineering'),
('Bob', 'Marketing'),
('Charlie', 'Sales');
