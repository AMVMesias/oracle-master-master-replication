-- Crear tablas de prueba para replicación
CONNECT repl_admin/Repl123@localhost:1521/TOKYO;

-- Tabla de empleados
CREATE TABLE employees (
    emp_id NUMBER(10) PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE,
    department VARCHAR2(50),
    salary NUMBER(10,2),
    hire_date DATE DEFAULT SYSDATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    node_origin VARCHAR2(20) DEFAULT 'TOKYO'
);

-- Tabla de audit trail
CREATE TABLE replication_audit (
    audit_id NUMBER(15) PRIMARY KEY,
    table_name VARCHAR2(50),
    operation VARCHAR2(10),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    node_name VARCHAR2(20),
    details CLOB
);

-- Secuencias
CREATE SEQUENCE emp_seq START WITH 1000 INCREMENT BY 3;
CREATE SEQUENCE audit_seq START WITH 1 INCREMENT BY 3;

-- Trigger para modificaciones
CREATE OR REPLACE TRIGGER trg_emp_modified
BEFORE UPDATE ON employees
FOR EACH ROW
BEGIN
    :NEW.modified_at := CURRENT_TIMESTAMP;
END;
/

-- Trigger para auditoría
CREATE OR REPLACE TRIGGER trg_emp_audit
AFTER INSERT OR UPDATE OR DELETE ON employees
FOR EACH ROW
BEGIN
    INSERT INTO replication_audit (
        audit_id, table_name, operation, node_name, details
    ) VALUES (
        audit_seq.NEXTVAL,
        'EMPLOYEES',
        CASE 
            WHEN INSERTING THEN 'INSERT'
            WHEN UPDATING THEN 'UPDATE'
            WHEN DELETING THEN 'DELETE'
        END,
        'TOKYO',
        'Employee ID: ' || COALESCE(:NEW.emp_id, :OLD.emp_id)
    );
END;
/

-- Datos de prueba
INSERT INTO employees (emp_id, first_name, last_name, email, department, salary, node_origin)
VALUES (emp_seq.NEXTVAL, 'Juan', 'Pérez', 'juan.perez@tokyo.com', 'IT', 50000, 'TOKYO');

INSERT INTO employees (emp_id, first_name, last_name, email, department, salary, node_origin)
VALUES (emp_seq.NEXTVAL, 'María', 'González', 'maria.gonzalez@tokyo.com', 'HR', 45000, 'TOKYO');

COMMIT;
EXIT;