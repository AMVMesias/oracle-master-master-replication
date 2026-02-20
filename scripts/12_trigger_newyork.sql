-- Trigger de replicación en NEWYORK
-- Replica INSERT/UPDATE/DELETE hacia Tokyo y Londres via database links
CONNECT repl_admin/Repl123@localhost:1521/NEWYORK;

CREATE OR REPLACE TRIGGER trg_replica_newyork
AFTER INSERT OR UPDATE OR DELETE ON employees
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- Solo replicar datos que se originaron en ESTE nodo
    IF INSERTING AND :NEW.node_origin = 'NEWYORK' THEN
        BEGIN
            INSERT INTO employees@tokyo_link (emp_id, first_name, last_name, email, department, salary, hire_date, node_origin)
            VALUES (:NEW.emp_id, :NEW.first_name, :NEW.last_name, :NEW.email, :NEW.department, :NEW.salary, :NEW.hire_date, 'NEWYORK');
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'TOKYO', SQLERRM);
                COMMIT;
        END;
        BEGIN
            INSERT INTO employees@londres_link (emp_id, first_name, last_name, email, department, salary, hire_date, node_origin)
            VALUES (:NEW.emp_id, :NEW.first_name, :NEW.last_name, :NEW.email, :NEW.department, :NEW.salary, :NEW.hire_date, 'NEWYORK');
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'LONDRES', SQLERRM);
                COMMIT;
        END;

    ELSIF UPDATING AND :NEW.node_origin = 'NEWYORK' THEN
        BEGIN
            UPDATE employees@tokyo_link
            SET first_name = :NEW.first_name, last_name = :NEW.last_name,
                email = :NEW.email, department = :NEW.department,
                salary = :NEW.salary, modified_at = CURRENT_TIMESTAMP
            WHERE emp_id = :OLD.emp_id;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'TOKYO', SQLERRM);
                COMMIT;
        END;
        BEGIN
            UPDATE employees@londres_link
            SET first_name = :NEW.first_name, last_name = :NEW.last_name,
                email = :NEW.email, department = :NEW.department,
                salary = :NEW.salary, modified_at = CURRENT_TIMESTAMP
            WHERE emp_id = :OLD.emp_id;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'LONDRES', SQLERRM);
                COMMIT;
        END;

    ELSIF DELETING AND :OLD.node_origin = 'NEWYORK' THEN
        BEGIN
            DELETE FROM employees@tokyo_link WHERE emp_id = :OLD.emp_id;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'TOKYO', SQLERRM);
                COMMIT;
        END;
        BEGIN
            DELETE FROM employees@londres_link WHERE emp_id = :OLD.emp_id;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'LONDRES', SQLERRM);
                COMMIT;
        END;
    END IF;
END;
/

EXIT;
