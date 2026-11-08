/* ============================================================================
   Laboratorio 1 - Almacenamiento y validación de ficheros XML en Oracle
   Fichero : 03_crear_tabla.sql
   Objetivo: Crear una tabla con una columna XMLTYPE asociada al esquema
             registrado en 02_registro_xsd.sql.
   Ejecutar: como HR, después de 02_registro_xsd.sql.
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- 1. Borrado previo (permite re-ejecutar el script)
-- ----------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE lab1_departamentos_xml PURGE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;   -- ORA-00942: la tabla no existe
END;
/

-- ----------------------------------------------------------------------------
-- 2. Creación de la tabla
--    - id, descripcion, fecha_carga: columnas relacionales de control.
--    - documento: columna XMLTYPE.
--    Cláusula XMLTYPE COLUMN ... :
--      STORE AS BINARY XML  -> modelo de almacenamiento binario.
--      XMLSCHEMA "url"      -> esquema registrado al que se asocia la columna.
--      ELEMENT "raiz"       -> elemento global del XSD que debe ser la raíz.
--    Las comillas dobles son obligatorias: URL y nombre del elemento son
--    sensibles a mayúsculas/minúsculas.
-- ----------------------------------------------------------------------------
CREATE TABLE lab1_departamentos_xml (
  id           NUMBER         CONSTRAINT lab1_dep_xml_pk PRIMARY KEY,
  descripcion  VARCHAR2(100),
  fecha_carga  DATE           DEFAULT SYSDATE,
  documento    XMLTYPE
)
XMLTYPE COLUMN documento STORE AS BINARY XML
  XMLSCHEMA "http://www.unir.net/lab1/departamentos.xsd"
  ELEMENT   "departamentos";

-- ----------------------------------------------------------------------------
-- 3. Verificación de la asociación columna <-> esquema
-- ----------------------------------------------------------------------------
SELECT table_name, column_name, xmlschema, element_name, storage_type
FROM   user_xml_tab_cols
WHERE  table_name = 'LAB1_DEPARTAMENTOS_XML';
