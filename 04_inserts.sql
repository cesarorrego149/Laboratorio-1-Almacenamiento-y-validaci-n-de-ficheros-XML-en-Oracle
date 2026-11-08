/* ============================================================================
   Laboratorio 1 - Almacenamiento y validación de ficheros XML en Oracle
   Fichero : 04_inserts.sql
   Objetivo: Insertar en LAB1_DEPARTAMENTOS_XML un documento que SE AJUSTA al
             esquema (se acepta) y otro que NO se ajusta (Oracle lo rechaza).
   Ejecutar: como HR, en modo SCRIPT (F5), después de 03_crear_tabla.sql.
   ============================================================================ */

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ============================================================================
-- INSERT 1 (VÁLIDO): documento escrito a mano con dos departamentos.
--   Cumple todas las reglas del XSD: raíz <departamentos>, atributos id y
--   total presentes, elementos en el orden de la secuencia, fecha en formato
--   xs:date, email en mayúsculas, salario > 0 y comisión entre 0 y 0.99.
--   Resultado esperado: "1 fila insertadas."
-- ============================================================================
INSERT INTO lab1_departamentos_xml (id, descripcion, documento)
VALUES (1, 'Documento válido escrito a mano',
  XMLTYPE(
'<departamentos xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xsi:noNamespaceSchemaLocation="http://www.unir.net/lab1/departamentos.xsd">
  <departamento id="10">
    <nombre>Administration</nombre>
    <ciudad>Seattle</ciudad>
    <pais>United States of America</pais>
    <empleados total="1">
      <empleado id="200">
        <nombre>Jennifer</nombre>
        <apellidos>Whalen</apellidos>
        <email>JWHALEN</email>
        <fechaContratacion>2003-09-17</fechaContratacion>
        <puesto codigo="AD_ASST">Administration Assistant</puesto>
        <salario>4400</salario>
      </empleado>
    </empleados>
  </departamento>
  <departamento id="80">
    <nombre>Sales</nombre>
    <ciudad>Oxford</ciudad>
    <pais>United Kingdom</pais>
    <empleados total="1">
      <empleado id="145">
        <nombre>John</nombre>
        <apellidos>Russell</apellidos>
        <email>JRUSSEL</email>
        <fechaContratacion>2004-10-01</fechaContratacion>
        <puesto codigo="SA_MAN">Sales Manager</puesto>
        <salario>14000</salario>
        <comision>0.40</comision>
      </empleado>
    </empleados>
  </departamento>
</departamentos>'));

-- ============================================================================
-- INSERT 2 (VÁLIDO): el documento se genera directamente con la consulta
--   SQL/XML de 01_consulta_sqlxml.sql (INSERT ... SELECT).
--   Demuestra que el XML producido por la consulta se ajusta al esquema.
--   Resultado esperado: "1 fila insertadas."
-- ============================================================================
INSERT INTO lab1_departamentos_xml (id, descripcion, documento)
SELECT 2, 'Documento generado con la consulta SQL/XML',
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
           ) ORDER BY d.department_id))
FROM   departments d
       JOIN locations l ON l.location_id = d.location_id
       JOIN countries c ON c.country_id  = l.country_id
WHERE  d.department_id IN (10, 20, 40, 60, 70, 90, 110)
  AND  EXISTS (SELECT 1 FROM employees e2 WHERE e2.department_id = d.department_id);

COMMIT;

-- ============================================================================
-- INSERT 3 (NO VÁLIDO): falta el elemento obligatorio <apellidos>.
--   En el XSD, <apellidos> no tiene minOccurs="0", por lo que es obligatorio
--   (minOccurs = 1 por defecto) y debe aparecer entre <nombre> y <email>.
--   Resultado esperado: Oracle rechaza la fila con un error del tipo
--     ORA-31061: XDB error: XML event error
--     ORA-19202: Error occurred in XML processing
--     LSX-00213: only 0 occurrences of particle "apellidos", minimum is 1
--   (el texto exacto puede variar ligeramente según la versión/parche).
-- ============================================================================
INSERT INTO lab1_departamentos_xml (id, descripcion, documento)
VALUES (3, 'Documento NO válido: falta <apellidos>',
  XMLTYPE(
'<departamentos xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xsi:noNamespaceSchemaLocation="http://www.unir.net/lab1/departamentos.xsd">
  <departamento id="60">
    <nombre>IT</nombre>
    <ciudad>Southlake</ciudad>
    <pais>United States of America</pais>
    <empleados total="1">
      <empleado id="103">
        <nombre>Alexander</nombre>
        <email>AHUNOLD</email>
        <fechaContratacion>2006-01-03</fechaContratacion>
        <puesto codigo="IT_PROG">Programmer</puesto>
        <salario>9000</salario>
      </empleado>
    </empleados>
  </departamento>
</departamentos>'));

-- ============================================================================
-- INSERT 4 (NO VÁLIDO, opcional): estructura correcta pero valores que
--   incumplen las facetas del XSD: salario negativo (minExclusive 0).
--   Resultado esperado: error ORA-31061 / ORA-19202 acompañado de un
--   mensaje LSX que indica el valor que viola la restricción.
-- ============================================================================
INSERT INTO lab1_departamentos_xml (id, descripcion, documento)
VALUES (4, 'Documento NO válido: salario negativo',
  XMLTYPE(
'<departamentos xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xsi:noNamespaceSchemaLocation="http://www.unir.net/lab1/departamentos.xsd">
  <departamento id="60">
    <nombre>IT</nombre>
    <ciudad>Southlake</ciudad>
    <pais>United States of America</pais>
    <empleados total="1">
      <empleado id="104">
        <nombre>Bruce</nombre>
        <apellidos>Ernst</apellidos>
        <email>BERNST</email>
        <fechaContratacion>2007-05-21</fechaContratacion>
        <puesto codigo="IT_PROG">Programmer</puesto>
        <salario>-6000</salario>
      </empleado>
    </empleados>
  </departamento>
</departamentos>'));

ROLLBACK;  -- por si algún cliente dejó la transacción abierta tras el error

-- ============================================================================
-- COMPROBACIONES
-- ============================================================================

-- a) Solo deben existir las filas 1 y 2; XMLISVALID = 1 confirma la validez
SELECT id, descripcion, fecha_carga,
       XMLISVALID(documento) AS es_valido
FROM   lab1_departamentos_xml
ORDER  BY id;

-- b) Lectura relacional del XML almacenado con XMLTABLE
SELECT t.id, d.dep_id, d.departamento, e.emp_id, e.apellidos, e.puesto, e.salario
FROM   lab1_departamentos_xml t,
       XMLTABLE('/departamentos/departamento'
                PASSING t.documento
                COLUMNS dep_id       NUMBER        PATH '@id',
                        departamento VARCHAR2(30)  PATH 'nombre',
                        lista_emp    XMLTYPE       PATH 'empleados') d,
       XMLTABLE('/empleados/empleado'
                PASSING d.lista_emp
                COLUMNS emp_id       NUMBER        PATH '@id',
                        apellidos    VARCHAR2(30)  PATH 'apellidos',
                        puesto       VARCHAR2(40)  PATH 'puesto',
                        salario      NUMBER        PATH 'salario') e
ORDER  BY t.id, d.dep_id, e.emp_id;

-- c) Validación explícita sin insertar: XMLISVALID devuelve 0 (no válido)
SELECT XMLISVALID(
         XMLTYPE('<departamentos><departamento id="1"><nombre>X</nombre></departamento></departamentos>'),
         'http://www.unir.net/lab1/departamentos.xsd') AS es_valido
FROM   dual;

-- d) Validación explícita con schemaValidate(): lanza la excepción y muestra
--    el motivo (ORA-31154: invalid XML document + detalle LSX).
DECLARE
  v_doc XMLTYPE := XMLTYPE(
    '<departamentos><departamento id="1"><nombre>X</nombre></departamento></departamentos>');
BEGIN
  v_doc := v_doc.createSchemaBasedXML('http://www.unir.net/lab1/departamentos.xsd');
  v_doc.schemaValidate();
  DBMS_OUTPUT.PUT_LINE('Documento válido');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Documento NO válido -> ' || SQLERRM);
END;
/
