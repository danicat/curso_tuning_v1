/* pratica12b.sql: Estatísticas
 * Copyright (C) 2016 Daniela Petruzalek
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

SELECT DBMS_STATS.get_prefs('GLOBAL_TEMP_TABLE_STATS') FROM dual;

BEGIN
  DBMS_STATS.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SHARED');
END;
/

BEGIN
  DBMS_STATS.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SESSION');
END;
/

DROP TABLE gtt1;

CREATE GLOBAL TEMPORARY TABLE gtt1 (
  id NUMBER,
  description VARCHAR2(20)
)
ON COMMIT PRESERVE ROWS;


-- Set the GTT statistics to SHARED.
BEGIN
  DBMS_STATS.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SHARED');
END;
/

-- Insert some data and gather the shared statistics.
INSERT INTO test.gtt1
SELECT level, 'description'
FROM   dual
CONNECT BY level <= 5;

EXEC DBMS_STATS.gather_table_stats('CURSO','GTT1');

-- Display the statistics information and scope.
COLUMN table_name FORMAT A20

SELECT table_name, num_rows, scope
FROM   dba_tab_statistics
WHERE  owner = 'CURSO'
AND    table_name = 'GTT1';

-- Reset the GTT statistics preference to SESSION.
BEGIN
  DBMS_STATS.set_global_prefs (
    pname   => 'GLOBAL_TEMP_TABLE_STATS',
    pvalue  => 'SESSION');
END;
/

INSERT INTO gtt1
SELECT level, 'description'
FROM   dual
CONNECT BY level <= 1000;
COMMIT;

EXEC DBMS_STATS.gather_table_stats('CURSO','GTT1');

-- Display the statistics information and scope.
COLUMN table_name FORMAT A20

SELECT table_name, num_rows, scope
FROM   dba_tab_statistics
WHERE  owner = 'CURSO'
AND    table_name = 'GTT1';

---------------------------------------------
-- Fazer a consulta abaixo em outra sessão --
---------------------------------------------

-- Display the statistics information and scope.
COLUMN table_name FORMAT A20

SELECT table_name, num_rows, scope
FROM   dba_tab_statistics
WHERE  owner = 'CURSO'
AND    table_name = 'GTT1';

-- Referência
-- https://oracle-base.com/articles/12c/session-private-statistics-for-global-temporary-tables-12cr1