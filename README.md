<p align="center">
  <img src="https://img.shields.io/badge/Oracle-F80000?style=for-the-badge&logo=oracle&logoColor=white" alt="Oracle"/>
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
  <img src="https://img.shields.io/badge/PL%2FSQL-336791?style=for-the-badge&logo=oracle&logoColor=white" alt="PL/SQL"/>
</p>

# 🔄 Replicación Maestro-Maestro con Oracle

Implementación de un **clúster de replicación Maestro-Maestro** con 3 nodos Oracle 19c Enterprise (Tokyo, Londres, New York) usando Docker Compose. Cada nodo puede recibir escrituras y propagarlas al resto, con supplemental logging, archive log y Oracle GoldenGate habilitados.

## 🎯 Descripción

Este proyecto demuestra:

- **Replicación multi-maestro** — Escrituras en cualquier nodo se propagan a los demás
- **3 instancias Oracle 19c Enterprise** — Orquestadas con Docker Compose en una red privada
- **Supplemental logging** — Captura de cambios en primary keys e índices únicos
- **Auditoría automática** — Triggers que registran toda operación DML
- **Monitoreo interactivo** — Script `.bat` para verificar estado y probar replicación

## 🏗️ Arquitectura

```
              Red Docker (oracle-cluster — 172.20.0.0/16)
  ┌──────────────────────────────────────────────────────────┐
  │                                                          │
  │  ┌──────────────┐    ┌──────────────┐    ┌─────────────┐│
  │  │ oracle-tokyo │◄──►│oracle-londres│◄──►│oracle-newyork│
  │  │ 172.20.0.10  │    │ 172.20.0.11  │    │ 172.20.0.12 ││
  │  │ Puerto 1521  │    │ Puerto 1522  │    │ Puerto 1523 ││
  │  └──────────────┘    └──────────────┘    └─────────────┘│
  │         ▲                                       ▲       │
  │         └───────────── Replicación ─────────────┘       │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

## 🚀 Inicio Rápido

### Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) con al menos **6 GB de RAM** asignados
- Acceso al Oracle Container Registry:
  ```bash
  docker login container-registry.oracle.com
  ```

### Instalación

```bash
# 1. Clonar el repositorio
git clone https://github.com/AMVMesias/oracle-master-master-replication.git
cd oracle-master-master-replication

# 2. Ejecutar el instalador (Windows)
install.bat

# 3. Monitorear el clúster
monitor.bat
```

El instalador descarga la imagen Oracle Enterprise 19c, levanta los 3 contenedores, espera los health checks y ejecuta los scripts SQL de configuración en orden.

## 📁 Estructura del Proyecto

```
oracle-master-master-replication/
│
├── docker-compose.yml          # Clúster de 3 nodos Oracle Enterprise 19c
├── install.bat                 # Instalación automatizada (12 pasos)
├── monitor.bat                 # Monitor interactivo del clúster
│
├── config/
│   ├── tokyo/tnsnames.ora      # Resolución TNS para Tokyo
│   ├── londres/tnsnames.ora    # Resolución TNS para Londres
│   └── newyork/tnsnames.ora    # Resolución TNS para New York
│
└── scripts/
    ├── 01_setup_tokyo.sql      # Archivelog, supplemental logging, usuario repl_admin
    ├── 02_setup_londres.sql    # Misma configuración para Londres
    ├── 03_setup_newyork.sql    # Misma configuración para New York
    ├── 04_create_tables.sql    # Tablas y secuencias en Tokyo (inicio: 1000)
    ├── 05_create_tables_londres.sql   # Tablas y secuencias en Londres (inicio: 1001)
    ├── 06_create_tables_newyork.sql   # Tablas y secuencias en New York (inicio: 1002)
    ├── 07_create_links_tokyo.sql      # Database links: Tokyo → Londres, NewYork
    ├── 08_create_links_londres.sql    # Database links: Londres → Tokyo, NewYork
    ├── 09_create_links_newyork.sql    # Database links: NewYork → Tokyo, Londres
    ├── 10_trigger_tokyo.sql    # Trigger de replicación en Tokyo
    ├── 11_trigger_londres.sql  # Trigger de replicación en Londres
    └── 12_trigger_newyork.sql  # Trigger de replicación en New York
```

## 🔌 Conexiones

| Nodo      | Host        | Puerto | Servicio  |
|-----------|-------------|--------|-----------|
| Tokyo     | `localhost` | `1521` | `TOKYO`   |
| Londres   | `localhost` | `1522` | `LONDRES` |
| New York  | `localhost` | `1523` | `NEWYORK` |

**Credenciales**

| Usuario      | Contraseña   | Rol                   |
|--------------|--------------|-----------------------|
| `sys`        | `Oracle123`  | SYSDBA                |
| `repl_admin` | `Repl123`    | Administrador de replicación |

## 📊 Esquema de Base de Datos

### Tabla `employees`

| Columna       | Tipo            | Descripción                   |
|---------------|-----------------|-------------------------------|
| `emp_id`      | `NUMBER(10)` PK | Auto-incrementado vía `emp_seq` |
| `first_name`  | `VARCHAR2(50)`  | Nombre del empleado           |
| `last_name`   | `VARCHAR2(50)`  | Apellido del empleado         |
| `email`       | `VARCHAR2(100)` | Email único                   |
| `department`  | `VARCHAR2(50)`  | Departamento                  |
| `salary`      | `NUMBER(10,2)`  | Salario                       |
| `node_origin` | `VARCHAR2(20)`  | Nodo de origen del registro   |

### Tabla `replication_audit`

Registra todas las operaciones DML sobre `employees` con timestamp y nodo de origen.

## 🔗 Mecanismo de Replicación

La replicación maestro-maestro se implementa con:

1. **Database Links** — Cada nodo tiene links hacia los otros 2 nodos via Easy Connect (`//hostname:port/service`)
2. **Triggers con `PRAGMA AUTONOMOUS_TRANSACTION`** — Un trigger `AFTER INSERT OR UPDATE OR DELETE` en cada nodo que propaga los cambios hacia los otros 2 nodos via los database links
3. **Control de `node_origin`** — Cada trigger verifica que `node_origin` corresponda al nodo local antes de replicar, evitando bucles infinitos de replicación
4. **Secuencias con offset** — Cada nodo genera IDs con `INCREMENT BY 3` desde un punto de inicio diferente (Tokyo: 1000, Londres: 1001, NewYork: 1002), garantizando que nunca colisionen

```
Tokyo (INSERT emp_id=1000)
  ├──► londres_link ──► INSERT en Londres (no replica: node_origin='TOKYO' ≠ 'LONDRES')
  └──► newyork_link ──► INSERT en NewYork (no replica: node_origin='TOKYO' ≠ 'NEWYORK')
```

## 🖥️ Monitor del Clúster

El script `monitor.bat` ofrece un menú interactivo:

1. **Verificar estado** — Estado de contenedores y puertos
2. **Monitoreo continuo** — Polling cada 30 segundos
3. **Generar reporte** — Archivo de estado con timestamp
4. **Respaldo** — Placeholder para flujos de backup
5. **Prueba de replicación** — Inserta datos en Tokyo para verificar propagación

## ⚙️ Configuración de Cada Nodo

Cada instancia Oracle se configura con:

| Configuración | Detalle |
|---|---|
| **Archive Log** | Habilitado para captura de redo logs |
| **Supplemental Logging** | Primary keys + índices únicos |
| **GoldenGate** | `enable_goldengate_replication=TRUE` |
| **TNS Names** | Resolución de los 3 nodos para conectividad cruzada |
| **Tablespace** | `replicate_data` — 500 MB, autoextend hasta 2 GB |
| **SGA / PGA** | Gestionado por Oracle (auto-tuning) |

## 🛠️ Tecnologías

| Tecnología | Uso |
|---|---|
| **Oracle Database 19c Enterprise** | Motor de base de datos relacional |
| **Docker Compose** | Orquestación de contenedores |
| **PL/SQL** | Triggers, secuencias y auditoría |
| **TNS** | Oracle Net Services |
| **Batch Scripts** | Automatización de instalación y monitoreo |

## 📝 Licencia

Este proyecto está bajo la Licencia MIT — ver el archivo [LICENSE](LICENSE) para más detalles.
