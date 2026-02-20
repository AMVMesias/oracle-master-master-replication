-- Trigger de replicación en LONDRES
-- Replica INSERT/UPDATE/DELETE hacia Tokyo y NewYork via database links
CONNECT repl_admin/Repl123@localhost:1521/LONDRES;

CREATE OR REPLACE TRIGGER trg_replica_londres
AFTER INSERT OR UPDATE OR DELETE ON employees
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- Solo replicar datos que se originaron en ESTE nodo
    IF INSERTING AND :NEW.node_origin = 'LONDRES' THEN
        BEGIN
            INSERT INTO employees@tokyo_link (emp_id, first_name, last_name, email, department, salary, hire_date, node_origin)
            VALUES (:NEW.emp_id, :NEW.first_name, :NEW.last_name, :NEW.email, :NEW.department, :NEW.salary, :NEW.hire_date, 'LONDRES');
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'TOKYO', SQLERRM);
                COMMIT;
        END;
        BEGIN
            INSERT INTO employees@newyork_link (emp_id, first_name, last_name, email, department, salary, hire_date, node_origin)
            VALUES (:NEW.emp_id, :NEW.first_name, :NEW.last_name, :NEW.email, :NEW.department, :NEW.salary, :NEW.hire_date, 'LONDRES');
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'NEWYORK', SQLERRM);
                COMMIT;
        END;

    ELSIF UPDATING AND :NEW.node_origin = 'LONDRES' THEN
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
            UPDATE employees@newyork_link
            SET first_name = :NEW.first_name, last_name = :NEW.last_name,
                email = :NEW.email, department = :NEW.department,
                salary = :NEW.salary, modified_at = CURRENT_TIMESTAMP
            WHERE emp_id = :OLD.emp_id;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'NEWYORK', SQLERRM);
                COMMIT;
        END;

    ELSIF DELETING AND :OLD.node_origin = 'LONDRES' THEN
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
            DELETE FROM employees@newyork_link WHERE emp_id = :OLD.emp_id;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO replication_audit (audit_id, table_name, operation, node_name, details)
                VALUES (audit_seq.NEXTVAL, 'EMPLOYEES', 'REPL_ERR', 'NEWYORK', SQLERRM);
                COMMIT;
        END;
    END IF;
END;
/

EXIT;
