-- Database Links desde LONDRES hacia los otros nodos
CONNECT repl_admin/Repl123@localhost:1521/LONDRES;

CREATE DATABASE LINK tokyo_link
  CONNECT TO repl_admin IDENTIFIED BY Repl123
  USING '//oracle-tokyo:1521/TOKYO';

CREATE DATABASE LINK newyork_link
  CONNECT TO repl_admin IDENTIFIED BY Repl123
  USING '//oracle-newyork:1521/NEWYORK';

-- Verificar links
SELECT db_link, host FROM user_db_links;

EXIT;
