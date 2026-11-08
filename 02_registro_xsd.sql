/* ============================================================================
   Laboratorio 1 - Almacenamiento y validación de ficheros XML en Oracle
   Fichero : 02_registro_xsd.sql
   Objetivo: Registrar el esquema departamentos.xsd en Oracle XML DB mediante
             DBMS_XMLSCHEMA.REGISTERSCHEMA.
   Ejecutar: como HR, en modo SCRIPT (F5) en SQL Developer.
   Notas   :
     - SCHEMAURL es el identificador lógico del esquema dentro de la base de
       datos; no es necesario que la URL exista en Internet.
     - Se registra para almacenamiento BINARY XML (recomendado desde 11g):
       con este modelo Oracle valida COMPLETAMENTE cada documento contra el
       XSD en el momento del INSERT/UPDATE.
   ============================================================================ */

SET SERVEROUTPUT ON
SET DEFINE OFF   -- evita que SQL Developer interprete '&' como variable

-- ----------------------------------------------------------------------------
-- 1. Limpieza previa (permite re-ejecutar el script). Si el esquema no
--    existe se captura el error y se continúa.
--    DELETE_CASCADE_FORCE elimina también las tablas/datos dependientes.
-- ----------------------------------------------------------------------------
BEGIN
  DBMS_XMLSCHEMA.DELETESCHEMA(
    schemaurl     => 'http://www.unir.net/lab1/departamentos.xsd',
    delete_option => DBMS_XMLSCHEMA.DELETE_CASCADE_FORCE);
  DBMS_OUTPUT.PUT_LINE('Esquema anterior eliminado.');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('No había esquema previo: ' || SQLERRM);
END;
/

-- ----------------------------------------------------------------------------
-- 2. Registro del esquema XML
--    El XSD se incluye como literal CLOB con la sintaxis q'~ ... ~' para no
--    tener que duplicar las comillas simples.
-- ----------------------------------------------------------------------------
DECLARE
  v_xsd CLOB := q'~<!--
  ============================================================================
  Laboratorio 1 - Almacenamiento y validación de ficheros XML en Oracle
  Fichero : departamentos.xsd
  Objetivo: Describe el documento XML que devuelve la consulta SQL/XML
            (01_consulta_sqlxml.sql) sobre el esquema HR.
  Tablas  : DEPARTMENTS, LOCATIONS, COUNTRIES, EMPLOYEES y JOBS
  Raíz    : <departamentos>
  ============================================================================
-->
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">

  <!-- ===================== TIPOS SIMPLES ===================== -->

  <!-- Identificadores numéricos (department_id NUMBER(4), employee_id NUMBER(6)) -->
  <xs:simpleType name="tIdDepartamento">
    <xs:restriction base="xs:positiveInteger">
      <xs:maxInclusive value="9999"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="tIdEmpleado">
    <xs:restriction base="xs:positiveInteger">
      <xs:maxInclusive value="999999"/>
    </xs:restriction>
  </xs:simpleType>

  <!-- Cadenas no vacías con longitud máxima (VARCHAR2 de HR) -->
  <xs:simpleType name="tTexto30">
    <xs:restriction base="xs:string">
      <xs:minLength value="1"/>
      <xs:maxLength value="30"/>
    </xs:restriction>
  </xs:simpleType>

  <xs:simpleType name="tTexto40">
    <xs:restriction base="xs:string">
      <xs:minLength value="1"/>
      <xs:maxLength value="40"/>
    </xs:restriction>
  </xs:simpleType>

  <!-- Email de HR: identificador en mayúsculas (p. ej. SKING), máx. 25 -->
  <xs:simpleType name="tEmail">
    <xs:restriction base="xs:string">
      <xs:pattern value="[A-Z]+"/>
      <xs:maxLength value="25"/>
    </xs:restriction>
  </xs:simpleType>

  <!-- Código de puesto (jobs.job_id), p. ej. AD_PRES, IT_PROG -->
  <xs:simpleType name="tCodigoPuesto">
    <xs:restriction base="xs:string">
      <xs:pattern value="[A-Z]{2}_[A-Z]{2,7}"/>
    </xs:restriction>
  </xs:simpleType>

  <!-- Salario NUMBER(8,2) con restricción CHECK (salary > 0) -->
  <xs:simpleType name="tSalario">
    <xs:restriction base="xs:decimal">
      <xs:minExclusive value="0"/>
      <xs:totalDigits value="8"/>
      <xs:fractionDigits value="2"/>
    </xs:restriction>
  </xs:simpleType>

  <!-- Comisión NUMBER(2,2): valores entre 0 y 0.99 -->
  <xs:simpleType name="tComision">
    <xs:restriction base="xs:decimal">
      <xs:minInclusive value="0"/>
      <xs:maxInclusive value="0.99"/>
      <xs:fractionDigits value="2"/>
    </xs:restriction>
  </xs:simpleType>

  <!-- ===================== TIPOS COMPLEJOS ===================== -->

  <!-- Puesto: texto (job_title) + atributo codigo (job_id) -->
  <xs:complexType name="tPuesto">
    <xs:simpleContent>
      <xs:extension base="tTexto40">
        <xs:attribute name="codigo" type="tCodigoPuesto" use="required"/>
      </xs:extension>
    </xs:simpleContent>
  </xs:complexType>

  <!-- Empleado (tablas EMPLOYEES + JOBS) -->
  <xs:complexType name="tEmpleado">
    <xs:sequence>
      <xs:element name="nombre"            type="tTexto30" minOccurs="0"/>
      <xs:element name="apellidos"         type="tTexto30"/>
      <xs:element name="email"             type="tEmail"/>
      <xs:element name="fechaContratacion" type="xs:date"/>
      <xs:element name="puesto"            type="tPuesto"/>
      <xs:element name="salario"           type="tSalario"/>
      <xs:element name="comision"          type="tComision" minOccurs="0"/>
    </xs:sequence>
    <xs:attribute name="id" type="tIdEmpleado" use="required"/>
  </xs:complexType>

  <!-- Lista de empleados de un departamento, con atributo total -->
  <xs:complexType name="tEmpleados">
    <xs:sequence>
      <xs:element name="empleado" type="tEmpleado" maxOccurs="unbounded"/>
    </xs:sequence>
    <xs:attribute name="total" type="xs:positiveInteger" use="required"/>
  </xs:complexType>

  <!-- Departamento (tablas DEPARTMENTS + LOCATIONS + COUNTRIES) -->
  <xs:complexType name="tDepartamento">
    <xs:sequence>
      <xs:element name="nombre"    type="tTexto30"/>
      <xs:element name="ciudad"    type="tTexto30"/>
      <xs:element name="pais"      type="tTexto40"/>
      <xs:element name="empleados" type="tEmpleados"/>
    </xs:sequence>
    <xs:attribute name="id" type="tIdDepartamento" use="required"/>
  </xs:complexType>

  <!-- ===================== ELEMENTO RAÍZ ===================== -->
  <xs:element name="departamentos">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="departamento" type="tDepartamento" maxOccurs="unbounded"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>

</xs:schema>~';
BEGIN
  DBMS_XMLSCHEMA.REGISTERSCHEMA(
    schemaurl => 'http://www.unir.net/lab1/departamentos.xsd', -- identificador
    schemadoc => XMLTYPE(v_xsd),     -- contenido del XSD
    local     => TRUE,               -- esquema local (solo visible para HR)
    gentypes  => FALSE,              -- no generar tipos objeto-relacionales
    gentables => FALSE,              -- no crear tablas por defecto
    options   => DBMS_XMLSCHEMA.REGISTER_BINARYXML); -- almacenamiento binario
  DBMS_OUTPUT.PUT_LINE('Esquema registrado correctamente.');
END;
/

-- ----------------------------------------------------------------------------
-- 3. Verificación: el esquema aparece en la vista USER_XML_SCHEMAS
--    (LOCAL = YES, BINARY = YES)
-- ----------------------------------------------------------------------------
SELECT schema_url, local, binary
FROM   user_xml_schemas
WHERE  schema_url = 'http://www.unir.net/lab1/departamentos.xsd';

-- Contenido del esquema registrado (columna XMLTYPE SCHEMA)
SELECT x.schema.getClobVal() AS xsd_registrado
FROM   user_xml_schemas x
WHERE  x.schema_url = 'http://www.unir.net/lab1/departamentos.xsd';
