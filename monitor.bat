@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   Oracle Master-Master Monitor
echo ========================================

set LOG_DIR=%~dp0logs
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%

:MENU
echo.
echo Selecciona una opción:
echo 1. Verificar estado del cluster
echo 2. Iniciar monitoreo continuo
echo 3. Generar reporte de estado
echo 4. Realizar backup
echo 5. Prueba de replicación
echo 6. Salir
echo.
set /p choice=Ingresa tu opción (1-6): 

if "%choice%"=="1" goto CHECK_STATUS
if "%choice%"=="2" goto START_MONITOR
if "%choice%"=="3" goto GENERATE_REPORT
if "%choice%"=="4" goto BACKUP
if "%choice%"=="5" goto TEST_REPLICATION
if "%choice%"=="6" goto EXIT
goto MENU

:CHECK_STATUS
echo.
echo Verificando estado de contenedores...
docker ps --filter "name=oracle-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo.
echo Verificando salud de contenedores...
for %%c in (oracle-tokyo oracle-londres oracle-newyork) do (
    echo Checking %%c...
    docker inspect --format="{{.State.Health.Status}}" %%c 2>nul || echo %%c: No disponible
)
goto MENU

:START_MONITOR
echo.
echo Iniciando monitoreo continuo (Ctrl+C para detener)...
:MONITOR_LOOP
echo [%time%] Verificando cluster...
for %%c in (oracle-tokyo oracle-londres oracle-newyork) do (
    docker inspect --format="%%c: {{.State.Health.Status}}" %%c 2>nul || echo %%c: ERROR
)
timeout /t 30 >nul
goto MONITOR_LOOP

:GENERATE_REPORT
echo.
echo Generando reporte de estado...
set REPORT_FILE=%LOG_DIR%\cluster_report_%TIMESTAMP%.txt
echo Oracle Master-Master Cluster Report > "%REPORT_FILE%"
echo Generated: %date% %time% >> "%REPORT_FILE%"
echo ================================== >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
docker ps --filter "name=oracle-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo Reporte guardado en: %REPORT_FILE%
goto MENU

:TEST_REPLICATION
echo.
echo Ejecutando prueba de replicación...
echo Insertando datos en Tokyo...
(echo INSERT INTO employees ^(emp_id, first_name, last_name, email, department, salary, node_origin^) VALUES ^(emp_seq.NEXTVAL, 'Test', 'User', 'test.%TIMESTAMP%@tokyo.com', 'TEST', 1000, 'TOKYO'^); & echo COMMIT; & echo SELECT COUNT^(*^) as "Registros en Tokyo" FROM employees; & echo EXIT;) | docker exec -i oracle-tokyo sqlplus repl_admin/Repl123@localhost:1521/TOKYO
echo Datos insertados. Verificar manualmente en otros nodos.
goto MENU

:BACKUP
echo.
echo Realizando backup...
set BACKUP_DIR=%LOG_DIR%\backups\backup_%TIMESTAMP%
mkdir "%BACKUP_DIR%" 2>nul
echo Backup iniciado en: %BACKUP_DIR%
echo (Simulado - implementar según necesidades)
goto MENU

:EXIT
echo.
echo Saliendo del monitor...
exit /b 0