/* ============================================================================
   Laboratorio 1 - Almacenamiento y validación de ficheros XML en Oracle
   Fichero : 01_consulta_sqlxml.sql
   Objetivo: Generar, con funciones SQL/XML, un documento XML que se ajusta al
             esquema departamentos.xsd a partir del esquema de ejemplo HR.
   Entorno : Oracle Database 21c + SQL Developer, conectado como HR a la PDB
             (por ejemplo, XEPDB1 en Oracle XE 21c u ORCLPDB1 en Enterprise).
   Tablas  : DEPARTMENTS, LOCATIONS, COUNTRIES, EMPLOYEES, JOBS (5 tablas).
   Funciones SQL/XML utilizadas:
     - XMLELEMENT    : crea un elemento XML.
     - XMLATTRIBUTES : añade atributos al elemento creado por XMLELEMENT.
     - XMLFOREST     : crea una secuencia de elementos hermanos, uno por
                       columna; si la columna es NULL, omite el elemento.
     - XMLAGG        : función de agregación que concatena varios fragmentos
                       XML (una fila por departamento / por empleado).
     - XMLSERIALIZE  : convierte el XMLTYPE en texto (CLOB) indentado.
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- 0. Comprobación previa: el usuario conectado debe ser HR
-- ----------------------------------------------------------------------------
SELECT USER                                   AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME')     AS contenedor
FROM   dual;


-- ----------------------------------------------------------------------------
-- 1. Consulta relacional de partida (sin XML) para comprobar los datos
--    Departamentos seleccionados: 10, 20, 40, 60, 70, 90 y 110 (15 empleados).
--    Para obtener TODOS los departamentos basta con eliminar la condición IN.
-- ----------------------------------------------------------------------------
SELECT d.department_id, d.department_name, l.city, c.country_name,
       e.employee_id, e.first_name, e.last_name, e.email,
       e.hire_date, j.job_id, j.job_title, e.salary, e.commission_pct
FROM   departments d
       JOIN locations l ON l.location_id   = d.location_id
       JOIN countries c ON c.country_id    = l.country_id
       JOIN employees e ON e.department_id = d.department_id
       JOIN jobs      j ON j.job_id        = e.job_id
WHERE  d.department_id IN (10, 20, 40, 60, 70, 90, 110)
ORDER  BY d.department_id, e.employee_id;


-- ----------------------------------------------------------------------------
-- 2. Consulta SQL/XML: devuelve UN único documento XML (tipo XMLTYPE)
-- ----------------------------------------------------------------------------
SELECT XMLELEMENT("departamentos",
         -- Declaración del espacio de nombres xsi y referencia al XSD
         -- registrado en Oracle (útil para validadores externos y para XML DB)
         XMLATTRIBUTES(
           'http://www.w3.org/2001/XMLSchema-instance'  AS "xmlns:xsi",
           'http://www.unir.net/lab1/departamentos.xsd' AS "xsi:noNamespaceSchemaLocation"),
         -- Un <departamento> por cada fila de DEPARTMENTS, ordenados por id
         XMLAGG(
           XMLELEMENT("departamento",
             XMLATTRIBUTES(d.department_id AS "id"),
             XMLFOREST(d.department_name AS "nombre",
                       l.city            AS "ciudad",
                       c.country_name    AS "pais"),
             -- Subconsulta correlacionada: lista de empleados del departamento
             (SELECT XMLELEMENT("empleados",
                       XMLATTRIBUTES(COUNT(*) AS "total"),
                       XMLAGG(
                         XMLELEMENT("empleado",
                           XMLATTRIBUTES(e.employee_id AS "id"),
                           XMLFOREST(e.first_name AS "nombre",
                                     e.last_name  AS "apellidos",
                                     e.email      AS "email",
                                     -- xs:date exige el formato AAAA-MM-DD
                                     TO_CHAR(e.hire_date, 'YYYY-MM-DD') AS "fechaContratacion"),
                           XMLELEMENT("puesto",
                             XMLATTRIBUTES(j.job_id AS "codigo"),
                             j.job_title),
                           XMLFOREST(e.salary AS "salario",
                                     -- NULL => XMLFOREST no genera <comision>
                                     TO_CHAR(e.commission_pct, 'FM0.00') AS "comision")
                         ) ORDER BY e.employee_id))
              FROM   employees e
                     JOIN jobs j ON j.job_id = e.job_id
              WHERE  e.department_id = d.department_id)
           ) ORDER BY d.department_id)
       ) AS documento_xml
FROM   departments d
       JOIN locations l ON l.location_id = d.location_id
       JOIN countries c ON c.country_id  = l.country_id
WHERE  d.department_id IN (10, 20, 40, 60, 70, 90, 110)
  -- Solo departamentos con al menos un empleado (<empleados> exige 1..n)
  AND  EXISTS (SELECT 1 FROM employees e2 WHERE e2.department_id = d.department_id);


-- ----------------------------------------------------------------------------
-- 3. Misma consulta, serializada como texto indentado (CLOB) y volcada al
--    fichero departamentos.xml. Ejecutar como SCRIPT (F5) en SQL Developer.
--    Cambie la ruta del SPOOL si es necesario (la carpeta debe existir).
-- ----------------------------------------------------------------------------
SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET PAGESIZE 0
SET LINESIZE 32767
SET HEADING OFF
SET FEEDBACK OFF
SET TRIMSPOOL ON
SET ECHO OFF

SPOOL C:\lab1\departamentos.xml

SELECT XMLSERIALIZE(DOCUMENT
         XMLELEMENT("departamentos",
           XMLATTRIBUTES(
             'http://www.w3.org/2001/XMLSchema-instance'  AS "xmlns:xsi",
             'http://www.unir.net/lab1/departamentos.xsd' AS "xsi:noNamespaceSchemaLocation"),
           XMLAGG(
             XMLELEMENT("departamento",
               XMLATTRIBUTES(d.department_id AS "id"),
               XMLFOREST(d.department_name AS "nombre",
                         l.city            AS "ciudad",
                         c.country_name    AS "pais"),
               (SELECT XMLELEMENT("empleados",
                         XMLATTRIBUTES(COUNT(*) AS "total"),
                         XMLAGG(
                           XMLELEMENT("empleado",
                             XMLATTRIBUTES(e.employee_id AS "id"),
                             XMLFOREST(e.first_name AS "nombre",
                                       e.last_name  AS "apellidos",
                                       e.email      AS "email",
                                       TO_CHAR(e.hire_date, 'YYYY-MM-DD') AS "fechaContratacion"),
                             XMLELEMENT("puesto",
                               XMLATTRIBUTES(j.job_id AS "codigo"),
                               j.job_title),
                             XMLFOREST(e.salary AS "salario",
                                       TO_CHAR(e.commission_pct, 'FM0.00') AS "comision")
                           ) ORDER BY e.employee_id))
                FROM   employees e
                       JOIN jobs j ON j.job_id = e.job_id
                WHERE  e.department_id = d.department_id)
             ) ORDER BY d.department_id)
         )
       AS CLOB VERSION '1.0' INDENT SIZE = 2) AS documento_xml
FROM   departments d
       JOIN locations l ON l.location_id = d.location_id
       JOIN countries c ON c.country_id  = l.country_id
WHERE  d.department_id IN (10, 20, 40, 60, 70, 90, 110)
  AND  EXISTS (SELECT 1 FROM employees e2 WHERE e2.department_id = d.department_id);

SPOOL OFF

SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 50
