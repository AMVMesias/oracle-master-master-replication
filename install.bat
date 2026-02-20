@echo off
echo ==========================================
echo   Oracle Master-Master Installation
echo ==========================================

cd /d "%~dp0"

echo Paso 1: Verificando Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker no está instalado o no está en el PATH
    pause
    exit /b 1
)

echo Paso 2: Descargando imagen Oracle...
echo (Asegúrate de estar logueado: docker login container-registry.oracle.com)
docker pull container-registry.oracle.com/database/enterprise:19.3.0.0

echo Paso 3: Iniciando contenedores...
docker-compose up -d

echo Paso 4: Esperando inicialización (esto puede tomar 15-30 minutos)...
:WAIT_LOOP
timeout /t 30 >nul
docker ps --filter "name=oracle-" --format "{{.Names}}: {{.Status}}" | findstr "healthy" >nul
if errorlevel 1 (
    echo Esperando que los contenedores estén saludables...
    goto WAIT_LOOP
)

echo Paso 5: Configurando Tokyo...
docker exec -i oracle-tokyo sqlplus /nolog < scripts\01_setup_tokyo.sql

echo Paso 6: Configurando Londres...
docker exec -i oracle-londres sqlplus /nolog < scripts\02_setup_londres.sql

echo Paso 7: Configurando New York...
docker exec -i oracle-newyork sqlplus /nolog < scripts\03_setup_newyork.sql

echo Paso 8: Creando tablas en Tokyo...
docker exec -i oracle-tokyo sqlplus /nolog < scripts\04_create_tables.sql

echo Paso 9: Creando tablas en Londres...
docker exec -i oracle-londres sqlplus /nolog < scripts\05_create_tables_londres.sql

echo Paso 10: Creando tablas en New York...
docker exec -i oracle-newyork sqlplus /nolog < scripts\06_create_tables_newyork.sql

echo Paso 11: Creando database links...
docker exec -i oracle-tokyo sqlplus /nolog < scripts\07_create_links_tokyo.sql
docker exec -i oracle-londres sqlplus /nolog < scripts\08_create_links_londres.sql
docker exec -i oracle-newyork sqlplus /nolog < scripts\09_create_links_newyork.sql

echo Paso 12: Instalando triggers de replicación...
docker exec -i oracle-tokyo sqlplus /nolog < scripts\10_trigger_tokyo.sql
docker exec -i oracle-londres sqlplus /nolog < scripts\11_trigger_londres.sql
docker exec -i oracle-newyork sqlplus /nolog < scripts\12_trigger_newyork.sql

echo.
echo ==========================================
echo   INSTALACIÓN COMPLETADA
echo ==========================================
echo.
echo Conexiones disponibles:
echo Tokyo:    localhost:1521/TOKYO
echo Londres:  localhost:1522/LONDRES  
echo New York: localhost:1523/NEWYORK
echo.
echo Credenciales:
echo SYS:        sys/Oracle123
echo Replicación: repl_admin/Repl123
echo.
echo La replicación maestro-maestro está activa.
echo Inserta datos en cualquier nodo y se propagarán al resto.
echo.
echo Ejecuta 'monitor.bat' para monitorear el cluster
echo.
pause